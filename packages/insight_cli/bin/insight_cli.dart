import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:insight_collector/cli.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'uri',
      mandatory: true,
      help: 'VM Service URI printed by flutter run.',
    )
    ..addOption(
      'duration',
      defaultsTo: '2',
      help: 'How many seconds to record. At least 1.',
    )
    ..addOption(
      'out',
      defaultsTo: 'insight-session.json',
      help: 'Where to write the session file.',
    )
    ..addFlag(
      'rebuilds',
      defaultsTo: true,
      help:
          'Record user-widget rebuilds. Pass --no-rebuilds to leave that off.',
    );
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on ArgParserException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  final seconds = int.tryParse(results['duration'] as String);
  if (seconds == null || seconds < 1) {
    stderr.writeln('--duration must be a whole number of seconds, at least 1.');
    exitCode = 64;
    return;
  }

  try {
    final session = await InsightCollector().record(
      vmServiceUri: results['uri'] as String,
      duration: Duration(seconds: seconds),
      rebuilds: results['rebuilds'] as bool,
    );
    final file = File(results['out'] as String);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(session)}\n',
    );
    final events = session['events'] as List<Object?>;
    final frames = events.where((event) {
      return event is Map && event['type'] == 'frame';
    }).length;
    final rebuilds = events.where((event) {
      return event is Map && event['type'] == 'widget.rebuild';
    }).length;
    final states = events.where((event) {
      return event is Map && event['type'] == 'state.changed';
    }).length;
    final spans = events.where((event) {
      return event is Map && event['type'] == 'async.span';
    }).length;
    stdout.writeln(
      'Wrote ${file.path} '
      '($frames frames, $rebuilds rebuilds, $states state changes, $spans spans).',
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
