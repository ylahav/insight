import 'package:insight_collector/insight_collector.dart';

/// One recording Analyzer has opened.
class OpenedRun {
  OpenedRun({required this.path, required this.result});

  final String path;
  final RunResult result;
}

/// One recording, as Analyzer shows it.
class RunResult {
  RunResult({
    required this.lines,
    required this.mode,
    this.flutter,
    this.startedAt,
    this.board,
    this.scenarioPath,
    this.scenario,
    this.taps,
    this.commit,
    this.branch,
    this.subject,
    this.scenarioDirty = false,
  });

  final String? mode;
  final String? flutter;
  final String? startedAt;
  final String? board;
  final String? scenarioPath;
  final String? scenario;

  /// The tap file to write. The stored scenario when `play` saved one,
  /// otherwise the taps recorded on the session.
  final String? taps;
  final String? commit;
  final String? branch;
  final String? subject;
  final bool scenarioDirty;
  final List<BesideLine> lines;

  List<RunStep> get steps => [
    for (final line in lines)
      RunStep(
        title: line.title,
        detail: line.detail,
        widgets: line.widgets,
        action: line.action,
      ),
  ];

  String get heading {
    final started = _started(startedAt);
    final sdk = flutter == null ? null : 'Flutter $flutter';
    return [?board, ?mode, ?sdk, ?started].join(' · ');
  }

  /// Branch, short commit, and subject. Null when the recording stored none.
  String? get gitLine {
    final git = [?branch, ?commit?.substring(0, 7), ?subject].join(' · ');
    return git.isEmpty ? null : git;
  }

  /// The scenario path when `play` stored one. Null when it did not.
  String? get scenarioNote => scenarioPath == null
      ? null
      : scenarioDirty
      ? '$scenarioPath has uncommitted edits.'
      : scenarioPath;

  static String? _started(String? value) {
    if (value == null || value.length < 16) {
      return value;
    }
    return '${value.substring(0, 10)} ${value.substring(11, 16)}';
  }

  PlayedScenario? get played =>
      scenario == null && scenarioPath == null && board == null
      ? null
      : PlayedScenario(path: scenarioPath, board: board, script: scenario);
}

class RunStep {
  RunStep({
    required this.title,
    required this.detail,
    required this.widgets,
    this.action,
  });

  final String title;
  final String detail;
  final List<String> widgets;
  final String? action;
}

/// The first recording against one that was added.
class PairReading {
  PairReading({
    required this.note,
    required this.reading,
    required this.rows,
  });

  final String note;
  final List<String> reading;
  final List<List<(String?, String?)>> rows;
}

PairReading readPair(RunResult left, RunResult right) {
  final played = scenarioReading(left: left.played, right: right.played);
  final count = left.lines.length > right.lines.length
      ? left.lines.length
      : right.lines.length;
  return PairReading(
    note: played.note,
    reading: besideReading(left.lines, right.lines),
    rows: [
      for (var i = 0; i < count; i++)
        besideStepRows(
          i < left.lines.length ? left.lines[i] : null,
          i < right.lines.length ? right.lines[i] : null,
        ),
    ],
  );
}

String recordingName(String path) => path.split(RegExp(r'[\\/]')).last;

RunResult readRunResult(Object? decoded) {
  if (decoded is! Map) {
    throw const FormatException('This file is not a session.');
  }
  if (decoded['kind'] == 'insight.compare') {
    throw const FormatException(
      'This file is a comparison. Analyzer reads one recording.',
    );
  }
  if (decoded['schemaVersion'] != 1) {
    throw const FormatException('This file is not a schema-1 session.');
  }
  final events = decoded['events'];
  if (events is! List) {
    throw const FormatException('This session has no events.');
  }
  final play = decoded['play'];
  final mode = decoded['mode'];
  final flutter = decoded['flutter'];
  final startedAt = decoded['startedAt'];
  return RunResult(
    mode: mode is String ? mode : null,
    flutter: flutter is String ? flutter : null,
    startedAt: startedAt is String ? startedAt : null,
    board: play is Map && play['board'] is String
        ? play['board'] as String
        : null,
    scenarioPath: play is Map && play['scenarioPath'] is String
        ? play['scenarioPath'] as String
        : null,
    scenario: play is Map && play['scenario'] is String
        ? play['scenario'] as String
        : null,
    taps: _taps(
      play is Map && play['scenario'] is String
          ? play['scenario'] as String
          : null,
      events,
    ),
    commit: play is Map && play['commit'] is String
        ? play['commit'] as String
        : null,
    branch: play is Map && play['branch'] is String
        ? play['branch'] as String
        : null,
    subject: play is Map && play['subject'] is String
        ? play['subject'] as String
        : null,
    scenarioDirty: play is Map && play['scenarioDirty'] == true,
    lines: besideLines(
      events.whereType<Map>().map((event) => event.cast<String, Object?>()),
    ),
  );
}

String? _taps(String? scenario, List<Object?> events) {
  if (scenario != null && scenario.trim().isNotEmpty) {
    return scenario;
  }
  final actions = <({int timeUs, String name})>[];
  for (final event in events) {
    if (event is! Map || event['type'] != 'user.action') {
      continue;
    }
    final name = event['name'];
    if (name is! String || name.isEmpty) {
      continue;
    }
    final timeUs = event['timeUs'];
    actions.add((timeUs: timeUs is int ? timeUs : 0, name: name));
  }
  if (actions.isEmpty) {
    return null;
  }
  actions.sort((a, b) => a.timeUs.compareTo(b.timeUs));
  return '${actions.map((action) => 'tap ${action.name}').join('\n')}\n';
}

String rebuiltCount(int count) {
  final widgets = count == 1 ? '1 widget' : '$count widgets';
  return 'Rebuilt $widgets.';
}
