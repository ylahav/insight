import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// In-app agent. [attach] registers the connect handshake and posts
/// `agent.ready` once. A collector that connects later calls
/// `ext.insight.agent`, which posts the event again, because [postEvent]
/// is discarded while nobody is listening.
abstract final class Insight {
  static var captureStateValues = false;

  /// Replaces [postEvent] in tests. Production leaves this null.
  @visibleForTesting
  static void Function(Map<String, Object?> message)? debugEventSink;

  static bool _attached = false;
  static var _spanCount = 0;

  static void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    registerExtension('ext.insight.agent', _onAgent);
    _postReady();
  }

  /// Posts one `user.action`. [name] is the control the user tapped,
  /// such as `phone-1`. An empty name is not posted.
  static void action(String name) {
    if (name.isEmpty) {
      return;
    }
    _emit(Timeline.now, {'kind': 'user.action', 'name': _clip(name, 80)});
  }

  /// Posts one `state.changed` and returns its `timeUs`.
  ///
  /// [value] is sent only when [captureStateValues] is set. Otherwise the
  /// wire `value` is null, even if the caller passed strings.
  static int stateChanged({
    required String adapter,
    required String name,
    required String? event,
    required String summary,
    ({String? previous, String? next})? value,
  }) {
    final timeUs = Timeline.now;
    _emit(
      timeUs,
      _stateFields(
        adapter: adapter,
        name: name,
        event: event,
        summary: summary,
        value: value,
      ),
    );
    return timeUs;
  }

  /// Posts the same `state.changed` again so the collector can replace
  /// `summary` and `value` on the record from [stateChanged].
  static void reviseState({
    required int timeUs,
    required String adapter,
    required String name,
    required String? event,
    required String summary,
    ({String? previous, String? next})? value,
  }) {
    _emit(
      timeUs,
      _stateFields(
        adapter: adapter,
        name: name,
        event: event,
        summary: summary,
        value: value,
      ),
    );
  }

  /// Traces [future]. The span name is [name], or `future` when omitted.
  /// An error is rethrown after the span is closed.
  static Future<T> traceFuture<T>(Future<T> future, {String? name}) async {
    final spanId = _nextSpanId();
    final label = _label(name, 'future');
    _asyncStart(spanId, label);
    try {
      final value = await future;
      _asyncEnd(spanId, status: 'completed', error: null);
      return value;
    } catch (error) {
      _asyncEnd(spanId, status: 'error', error: _errorText(error));
      rethrow;
    }
  }

  /// Traces [source] from the moment it is listened to.
  /// The span name is [name], or `stream` when omitted.
  static Stream<T> traceStream<T>(Stream<T> source, {String? name}) async* {
    final spanId = _nextSpanId();
    final label = _label(name, 'stream');
    _asyncStart(spanId, label);
    try {
      yield* source;
      _asyncEnd(spanId, status: 'completed', error: null);
    } catch (error) {
      _asyncEnd(spanId, status: 'error', error: _errorText(error));
      rethrow;
    }
  }

  static Future<ServiceExtensionResponse> _onAgent(
    String method,
    Map<String, String> parameters,
  ) async {
    final timeUs = _postReady();
    return ServiceExtensionResponse.result(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'agent.ready',
        'timeUs': timeUs,
        'flutter': FlutterVersion.version,
        'dart': FlutterVersion.dartVersion,
      }),
    );
  }

  static int _postReady() {
    final timeUs = Timeline.now;
    _emit(timeUs, {'kind': 'agent.ready'});
    return timeUs;
  }

  static Map<String, Object?> _stateFields({
    required String adapter,
    required String name,
    required String? event,
    required String summary,
    required ({String? previous, String? next})? value,
  }) {
    return {
      'kind': 'state.changed',
      'adapter': adapter,
      'name': _clip(name, 120),
      'event': event == null ? null : _clip(event, 120),
      'summary': _clip(summary, 80),
      'value': _wireValue(value),
    };
  }

  static Object? _wireValue(({String? previous, String? next})? value) {
    if (!captureStateValues || value == null) {
      return null;
    }
    return {
      'previous': _clipNullable(value.previous, 120),
      'next': _clipNullable(value.next, 120),
    };
  }

  static void _asyncStart(String spanId, String name) {
    _emit(Timeline.now, {
      'kind': 'async.start',
      'spanId': spanId,
      'name': name,
    });
  }

  static void _asyncEnd(
    String spanId, {
    required String status,
    required String? error,
  }) {
    _emit(Timeline.now, {
      'kind': 'async.end',
      'spanId': spanId,
      'status': status,
      'error': error,
    });
  }

  static void _emit(int timeUs, Map<String, Object?> fields) {
    final message = <String, Object?>{
      'schemaVersion': 1,
      'timeUs': timeUs,
      ...fields,
    };
    final sink = debugEventSink;
    if (sink != null) {
      sink(message);
      return;
    }
    postEvent('Insight.Event', message);
  }

  static String _nextSpanId() {
    _spanCount += 1;
    return 'span-$_spanCount';
  }

  static String _label(String? name, String fallback) {
    if (name == null || name.isEmpty) {
      return fallback;
    }
    return _clip(name, 80);
  }

  static String _errorText(Object error) {
    return _clip(error.toString(), 200);
  }

  static String _clip(String value, int max) {
    return value.length > max ? value.substring(0, max) : value;
  }

  static String? _clipNullable(String? value, int max) {
    if (value == null) {
      return null;
    }
    return _clip(value, max);
  }
}
