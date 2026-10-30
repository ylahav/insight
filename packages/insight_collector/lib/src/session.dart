import 'dart:convert';

const _stateAdapters = {'bloc', 'riverpod'};

/// Builds a schema-version-1 session from raw VM payloads.
///
/// Frame payloads are the `extensionData` of a `Flutter.Frame` event.
/// Agent payloads are the `extensionData` of an `Insight.Event`.
class SessionBuilder {
  SessionBuilder({
    required this.flutterVersion,
    required this.dartVersion,
    required this.mode,
    required this.startedAt,
  });

  String flutterVersion;
  String dartVersion;
  final String mode;
  final DateTime startedAt;

  int rejected = 0;
  var _agentBlocked = false;
  var _sawReady = false;
  final List<Map<String, Object?>> _events = [];
  final Map<String, Map<String, Object?>> _openSpans = {};

  /// Returns false when the frame was dropped.
  bool addFrame(Map<String, Object?> data) {
    final start = _nonNegative(data['startTime']);
    final build = _nonNegative(data['build']);
    final raster = _nonNegative(data['raster']);
    final elapsed = _nonNegative(data['elapsed']);
    if (start == null || build == null || raster == null || elapsed == null) {
      rejected += 1;
      return false;
    }
    _events.add({
      'type': 'frame',
      'timeUs': start,
      'buildUs': build,
      'rasterUs': raster,
      'elapsedUs': elapsed,
      'targetUs': null,
      'budgetExceeded': null,
    });
    return true;
  }

  /// Returns false when the agent message was dropped.
  bool addAgent(Map<String, Object?> data) {
    if (_encodedSize(data) > 8192) {
      rejected += 1;
      return false;
    }
    if (data['schemaVersion'] != 1) {
      rejected += 1;
      _agentBlocked = true;
      return false;
    }
    if (_agentBlocked) {
      rejected += 1;
      return false;
    }
    final timeUs = data['timeUs'];
    if (timeUs is! int) {
      rejected += 1;
      return false;
    }
    switch (data['kind']) {
      case 'agent.ready':
        return _addReady(timeUs);
      case 'state.changed':
        return _addState(data, timeUs);
      case 'async.start':
        return _addAsyncStart(data, timeUs);
      case 'async.end':
        return _addAsyncEnd(data, timeUs);
      default:
        rejected += 1;
        return false;
    }
  }

  bool _addReady(int timeUs) {
    if (_sawReady) {
      return true;
    }
    _sawReady = true;
    _events.add({'type': 'agent.ready', 'timeUs': timeUs, 'schemaVersion': 1});
    return true;
  }

  /// A second message with the same [timeUs], name, and event replaces
  /// `summary` and `value`. That is the `onChange` update of an `onEvent` record.
  bool _addState(Map<String, Object?> data, int timeUs) {
    final adapter = data['adapter'];
    if (timeUs < 0 || adapter is! String || !_stateAdapters.contains(adapter)) {
      rejected += 1;
      return false;
    }
    final name = _clip(data['name'], 120);
    final summary = _clip(data['summary'], 80);
    if (!data.containsKey('event') || name == null || summary == null) {
      rejected += 1;
      return false;
    }
    final event = data['event'];
    String? eventName;
    if (event != null) {
      eventName = _clip(event, 120);
      if (eventName == null) {
        rejected += 1;
        return false;
      }
    }
    final value = _stateValue(data['value']);
    if (value == _invalidValue) {
      rejected += 1;
      return false;
    }
    final existing = _stateRecord(timeUs, adapter, name, eventName);
    if (existing != null) {
      existing['summary'] = summary;
      existing['value'] = value;
      return true;
    }
    _events.add({
      'type': 'state.changed',
      'timeUs': timeUs,
      'adapter': adapter,
      'name': name,
      'event': eventName,
      'summary': summary,
      'value': value,
    });
    return true;
  }

  bool _addAsyncStart(Map<String, Object?> data, int timeUs) {
    final spanId = data['spanId'];
    final name = _clip(data['name'], 80);
    if (timeUs < 0 ||
        spanId is! String ||
        spanId.isEmpty ||
        spanId.length > 80 ||
        name == null ||
        _openSpans.containsKey(spanId)) {
      rejected += 1;
      return false;
    }
    final record = <String, Object?>{
      'type': 'async.span',
      'name': name,
      'startUs': timeUs,
      'endUs': null,
      'status': 'unfinished',
      'error': null,
    };
    _events.add(record);
    _openSpans[spanId] = record;
    return true;
  }

  bool _addAsyncEnd(Map<String, Object?> data, int timeUs) {
    final spanId = data['spanId'];
    final status = data['status'];
    if (timeUs < 0 ||
        spanId is! String ||
        (status != 'completed' && status != 'error')) {
      rejected += 1;
      return false;
    }
    final record = _openSpans.remove(spanId);
    if (record == null) {
      rejected += 1;
      return false;
    }
    String? error;
    if (status == 'error') {
      error = _clip(data['error'], 200);
      if (error == null) {
        _openSpans[spanId] = record;
        rejected += 1;
        return false;
      }
    }
    record['endUs'] = timeUs;
    record['status'] = status;
    record['error'] = error;
    return true;
  }

  Map<String, Object?>? _stateRecord(
    int timeUs,
    String adapter,
    String name,
    String? event,
  ) {
    for (final record in _events) {
      if (record['type'] == 'state.changed' &&
          record['timeUs'] == timeUs &&
          record['adapter'] == adapter &&
          record['name'] == name &&
          record['event'] == event) {
        return record;
      }
    }
    return null;
  }

  /// Returns false when the rebuild was dropped.
  bool addRebuild({required int timeUs, required String name}) {
    if (timeUs < 0 || name.isEmpty) {
      rejected += 1;
      return false;
    }
    _events.add({
      'type': 'widget.rebuild',
      'timeUs': timeUs,
      'name': name.length > 120 ? name.substring(0, 120) : name,
    });
    return true;
  }

  Map<String, Object?> build() {
    _events.sort((a, b) {
      final byTime = _timeOf(a).compareTo(_timeOf(b));
      if (byTime != 0) {
        return byTime;
      }
      return _rank(a['type'] as String).compareTo(_rank(b['type'] as String));
    });
    final counts = <String, int>{};
    for (final event in _events) {
      final prefix = _prefix(event['type'] as String);
      final next = (counts[prefix] ?? 0) + 1;
      counts[prefix] = next;
      event['id'] = '${prefix}_$next';
    }
    return {
      'schemaVersion': 1,
      'flutter': flutterVersion,
      'dart': dartVersion,
      'mode': mode,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'events': _events,
      'rejected': rejected,
    };
  }
}

int _timeOf(Map<String, Object?> event) {
  if (event['type'] == 'async.span') {
    return event['startUs']! as int;
  }
  return event['timeUs']! as int;
}

int _rank(String type) {
  return switch (type) {
    'agent.ready' => 0,
    'state.changed' => 1,
    'async.span' => 2,
    'widget.rebuild' => 3,
    'frame' => 4,
    _ => 5,
  };
}

String _prefix(String type) {
  return switch (type) {
    'agent.ready' => 'agent',
    'state.changed' => 'state',
    'async.span' => 'async',
    'widget.rebuild' => 'widget',
    'frame' => 'frame',
    _ => 'event',
  };
}

int? _nonNegative(Object? value) {
  if (value is int && value >= 0) {
    return value;
  }
  return null;
}

int _encodedSize(Map<String, Object?> data) {
  return utf8.encode(jsonEncode(data)).length;
}

const _invalidValue = Object();

String? _clip(Object? value, int max) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value.length > max ? value.substring(0, max) : value;
}

Object? _stateValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    return _invalidValue;
  }
  if (!value.containsKey('previous') || !value.containsKey('next')) {
    return _invalidValue;
  }
  final previous = _optionalText(value['previous']);
  final next = _optionalText(value['next']);
  if (previous == _invalidValue || next == _invalidValue) {
    return _invalidValue;
  }
  return {'previous': previous, 'next': next};
}

Object? _optionalText(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    return _invalidValue;
  }
  return value.length > 120 ? value.substring(0, 120) : value;
}
