import 'dart:convert';
import 'dart:io';

/// Checks a profile session from `examples/bloc_counter`.
///
/// A passing file is the support claim for that Flutter stable. Hand-written
/// JSON is not. From the repository root, after a profile recording:
///
/// ```text
/// dart run tool/parser_check.dart --file path --flutter 3.44
/// ```
Future<void> main(List<String> arguments) async {
  final options = _parse(arguments);
  if (options == null) {
    exitCode = 64;
    return;
  }
  final file = File(options.file);
  if (!file.existsSync()) {
    stderr.writeln('No session file at ${file.path}.');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map) {
    stderr.writeln('The session file is not a JSON object.');
    exitCode = 1;
    return;
  }
  final session = decoded.cast<String, Object?>();
  final failures = _failures(session, options.flutterLine);
  if (failures.isEmpty) {
    final events = session['events'] as List;
    stdout.writeln(
      'Parser check passed for Flutter ${session['flutter']} '
      '(${events.length} events).',
    );
    return;
  }
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  exitCode = 1;
}

List<String> _failures(Map<String, Object?> session, String flutterLine) {
  final failures = <String>[];
  void need(bool ok, String message) {
    if (!ok) {
      failures.add(message);
    }
  }

  need(session['schemaVersion'] == 1, 'schemaVersion is not 1.');
  need(session['mode'] == 'profile', 'mode is not profile.');
  need(session['rejected'] == 0, 'rejected is not 0.');
  final flutter = session['flutter'];
  need(
    flutter is String && flutter.startsWith('$flutterLine.'),
    'flutter is not a $flutterLine.x version.',
  );
  final dartVersion = session['dart'];
  need(dartVersion is String && dartVersion.isNotEmpty, 'dart is empty.');

  final events = session['events'];
  if (events is! List) {
    failures.add('events is not a list.');
    return failures;
  }

  var frames = 0;
  var agentReady = 0;
  var counterText = 0;
  var counterCubit = 0;
  for (final event in events) {
    if (event is! Map) {
      failures.add('An event is not an object.');
      continue;
    }
    switch (event['type']) {
      case 'frame':
        frames++;
        for (final field in ['buildUs', 'rasterUs', 'elapsedUs']) {
          final value = event[field];
          need(
            value is int && value >= 0,
            'A frame has $field that is not an integer >= 0.',
          );
        }
      case 'agent.ready':
        agentReady++;
      case 'widget.rebuild':
        if (event['name'] == 'CounterText') {
          counterText++;
        }
      case 'state.changed':
        if (event['name'] == 'CounterCubit' && event['event'] == null) {
          counterCubit++;
        }
    }
  }
  need(frames >= 1, 'The session has no frame.');
  need(agentReady == 1, 'agent.ready count is $agentReady, expected 1.');
  need(counterText >= 1, 'No widget.rebuild is named CounterText.');
  need(
    counterCubit >= 1,
    'No state.changed is CounterCubit with a null event.',
  );
  return failures;
}

class _Parsed {
  _Parsed({required this.file, required this.flutterLine});

  final String file;
  final String flutterLine;
}

_Parsed? _parse(List<String> arguments) {
  String? file;
  String? flutterLine;
  for (var i = 0; i < arguments.length; i++) {
    String? next() {
      if (i + 1 >= arguments.length) {
        return null;
      }
      return arguments[++i];
    }

    switch (arguments[i]) {
      case '--file':
        file = next();
      case '--flutter':
        flutterLine = next();
      default:
        stderr.writeln('Unknown argument ${arguments[i]}.');
        stderr.writeln(_usage);
        return null;
    }
  }
  if (file == null || flutterLine == null) {
    stderr.writeln(_usage);
    return null;
  }
  return _Parsed(file: file, flutterLine: flutterLine);
}

const _usage = '''
Checks a profile session from examples/bloc_counter.

dart run tool/parser_check.dart --file path --flutter 3.44
''';
