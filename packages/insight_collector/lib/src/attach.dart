import 'dart:async';

import 'package:vm_service/vm_service.dart';

import 'session.dart';
import 'timeline.dart';

const _rebuildExtension = 'ext.flutter.profileUserWidgetBuilds';

/// A live session on a VM Service client the caller already owns.
///
/// The handle never opens a socket and never disposes [service]. The CLI
/// opens its own client and disposes that. The DevTools panel passes
/// `serviceManager`'s client and leaves it open.
class InsightSessionHandle {
  InsightSessionHandle({required this.service, this.rebuilds = true});

  final VmService service;
  final bool rebuilds;

  /// Fires after [snapshot] changes. Bursts in one event-loop turn collapse
  /// into one call.
  void Function()? onEvent;

  SessionBuilder? builder;
  Map<String, Object?>? snapshot;

  /// False when `ext.insight.agent` is missing. Frames are still recorded.
  bool agentPresent = false;

  bool ready = false;

  String? _isolateId;
  List<String>? _previousTimeline;
  StreamSubscription<Event>? _extensions;
  StreamSubscription<Event>? _timeline;
  var _stopped = false;
  var _notifyScheduled = false;

  Future<void> start() async {
    final isolateId = await _flutterIsolate(service);
    _isolateId = isolateId;
    await _rejectWeb(service, isolateId);
    final mode = await _mode(service, isolateId);
    final session = SessionBuilder(
      flutterVersion: '',
      dartVersion: '',
      mode: mode,
      startedAt: DateTime.now(),
    );
    builder = session;
    try {
      if (rebuilds) {
        _previousTimeline = await _enableDartTimeline(service);
      }
      await _ensureStream(service, 'Extension');
      _extensions = service.onExtensionEvent.listen((event) {
        final data = event.extensionData?.data;
        if (data == null) {
          return;
        }
        final payload = Map<String, Object?>.from(data);
        switch (event.extensionKind) {
          case 'Flutter.Frame':
            session.addFrame(payload);
          case 'Insight.Event':
            session.addAgent(payload);
        }
        _publish();
      });
      if (rebuilds) {
        await _ensureStream(service, 'Timeline');
        _timeline = service.onTimelineEvent.listen((event) {
          for (final timelineEvent in event.timelineEvents ?? const []) {
            final raw = timelineEvent.json;
            if (raw == null) {
              continue;
            }
            final parsed = widgetRebuildFromTimeline(
              Map<String, Object?>.from(raw),
            );
            if (parsed == null) {
              continue;
            }
            session.addRebuild(timeUs: parsed.timeUs, name: parsed.name);
          }
          _publish();
        });
        await _setRebuilds(service, isolateId, enabled: true);
      }
      final agent = await _requestAgent(service, isolateId, session);
      agentPresent = agent != null;
      final versions = await _versions(service, isolateId, agent);
      session
        ..flutterVersion = versions.flutterVersion
        ..dartVersion = versions.dartVersion;
      ready = true;
      _publish();
    } catch (error) {
      await stop(strict: false);
      rethrow;
    }
  }

  /// Turns build profiling off and drops the stream subscriptions.
  ///
  /// When [strict] is set, a flag that is still on after this call throws.
  /// A disconnect passes [strict] false, because the isolate may already be
  /// gone.
  Future<void> stop({bool strict = true}) async {
    if (_stopped) {
      return;
    }
    _stopped = true;
    await _extensions?.cancel();
    await _timeline?.cancel();
    _extensions = null;
    _timeline = null;
    final isolateId = _isolateId;
    if (!rebuilds || isolateId == null) {
      return;
    }
    try {
      await _setRebuilds(service, isolateId, enabled: false);
      if (strict) {
        await _assertRebuildsOff(service, isolateId);
      }
      final previous = _previousTimeline;
      if (previous != null) {
        await service.setVMTimelineFlags(previous);
      }
    } catch (error) {
      if (strict) {
        rethrow;
      }
    }
  }

  void _publish() {
    final session = builder;
    if (session == null) {
      return;
    }
    snapshot = session.build();
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      onEvent?.call();
    });
  }
}

Future<void> _ensureStream(VmService service, String stream) async {
  try {
    await service.streamListen(stream);
  } on RPCError catch (error) {
    if (!error.message.contains('already subscribed')) {
      rethrow;
    }
  }
}

Future<List<String>> _enableDartTimeline(VmService service) async {
  final flags = await service.getVMTimelineFlags();
  final previous = List<String>.from(flags.recordedStreams ?? const []);
  if (!previous.contains('Dart')) {
    await service.setVMTimelineFlags([...previous, 'Dart']);
  }
  return previous;
}

Future<void> _setRebuilds(
  VmService service,
  String isolateId, {
  required bool enabled,
}) {
  return service.callServiceExtension(
    _rebuildExtension,
    isolateId: isolateId,
    args: {'enabled': enabled ? 'true' : 'false'},
  );
}

Future<void> _assertRebuildsOff(VmService service, String isolateId) async {
  final response = await service.callServiceExtension(
    _rebuildExtension,
    isolateId: isolateId,
  );
  if (response.json?['enabled'] != 'false') {
    throw StateError('$_rebuildExtension stayed on after the session.');
  }
}

Future<void> _rejectWeb(VmService service, String isolateId) async {
  final isolate = await service.getIsolate(isolateId);
  for (final library in isolate.libraries ?? const <LibraryRef>[]) {
    final uri = library.uri ?? '';
    if (uri.startsWith('dart:ui_web') || uri.startsWith('dart:html')) {
      throw StateError('Flutter web is unsupported.');
    }
  }
}

Future<String> _flutterIsolate(VmService service) async {
  final vm = await service.getVM();
  String? fallback;
  for (final ref in vm.isolates ?? const <IsolateRef>[]) {
    final id = ref.id;
    if (id == null) {
      continue;
    }
    final isolate = await service.getIsolate(id);
    final rpcs = isolate.extensionRPCs ?? const <String>[];
    if (!rpcs.contains('ext.flutter.debugDumpApp')) {
      continue;
    }
    fallback ??= id;
    if ((ref.name ?? '').contains('main')) {
      return id;
    }
  }
  if (fallback == null) {
    throw StateError(
      'No Flutter isolate is exposing the VM service. '
      'Release builds are unsupported.',
    );
  }
  return fallback;
}

Future<String> _mode(VmService service, String isolateId) async {
  final isolate = await service.getIsolate(isolateId);
  final rpcs = isolate.extensionRPCs ?? const <String>[];
  if (rpcs.contains('ext.flutter.debugPaint')) {
    return 'debug';
  }
  return 'profile';
}

Future<({String flutterVersion, String dartVersion})> _versions(
  VmService service,
  String isolateId,
  Map<String, Object?>? agent,
) async {
  final vm = await service.getVM();
  final dartFromVm = (vm.version ?? '').split(' ').first;
  final flutterFromAgent = _versionToken(agent?['flutter']);
  final dartFromAgent = _versionToken(agent?['dart']);
  if (flutterFromAgent != null) {
    final dartVersion = dartFromAgent ?? dartFromVm;
    if (dartVersion.isEmpty) {
      throw StateError('The VM did not report a Dart version.');
    }
    return (flutterVersion: flutterFromAgent, dartVersion: dartVersion);
  }
  if (dartFromVm.isEmpty) {
    throw StateError('The VM did not report a Dart version.');
  }
  final isolate = await service.getIsolate(isolateId);
  String? libraryId;
  for (final library in isolate.libraries ?? const <LibraryRef>[]) {
    if (library.uri == 'package:flutter/src/services/flutter_version.dart') {
      libraryId = library.id;
      break;
    }
  }
  if (libraryId == null) {
    throw StateError(
      'Flutter version is unavailable. The in-app agent did not answer, '
      'and FlutterVersion is not loaded in the isolate.',
    );
  }
  final response = await service.evaluate(
    isolateId,
    libraryId,
    'FlutterVersion.version',
  );
  final value = _versionToken(response.json?['valueAsString']);
  if (value == null) {
    throw StateError('FlutterVersion.version was not a string.');
  }
  return (flutterVersion: value, dartVersion: dartFromVm);
}

String? _versionToken(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value.split(' ').first;
}

Future<Map<String, Object?>?> _requestAgent(
  VmService service,
  String isolateId,
  SessionBuilder builder,
) async {
  try {
    final response = await service.callServiceExtension(
      'ext.insight.agent',
      isolateId: isolateId,
    );
    final json = response.json;
    if (json == null) {
      return null;
    }
    final payload = Map<String, Object?>.from(json);
    builder.addAgent(payload);
    return payload;
  } on RPCError {
    return null;
  }
}
