import 'group.dart';
import 'names.dart';

/// One change from a session, with the frame it groups with.
///
/// Two lists of these are what the side-by-side reader prints. Nothing
/// here decides that the lists should match.
class BesideLine {
  BesideLine({
    required this.timeUs,
    required this.title,
    required this.detail,
    required this.widgets,
    this.buildUs,
    this.rasterUs,
    this.elapsedUs,
    this.action,
  });

  final int timeUs;
  final String title;
  final String detail;
  final List<String> widgets;

  /// `tap <control>` when a `user.action` falls in the 32 ms before this
  /// line. The file stores the action on its own. This link is time grouping.
  final String? action;

  /// Frame parts, in microseconds. Null when the frame did not record them,
  /// and null on an ungrouped change.
  final int? buildUs;
  final int? rasterUs;
  final int? elapsedUs;
}

/// Changes in time order, earliest first. Wrapper widgets are omitted.
/// Rebuild-only frames are omitted. A span is included once, on its
/// earliest frame.
List<BesideLine> besideLines(Iterable<Map<String, Object?>> events) {
  final actions = [
    for (final event in events)
      if (event['type'] == 'user.action') event,
  ];
  final grouping = groupFrames(events);
  final lines = <BesideLine>[];
  final seenSpans = <Map<String, Object?>>[];
  for (final frame in grouping.frames) {
    final widgets = [
      for (final name in frame.rebuilds)
        if (!isWrapperWidget(name)) name,
    ];
    final parts = _frameParts(frame.frame);
    for (final state in frame.states) {
      lines.add(
        BesideLine(
          timeUs: _time(state['timeUs']),
          title: _stateTitle(state),
          detail: parts.detail,
          widgets: widgets,
          buildUs: parts.buildUs,
          rasterUs: parts.rasterUs,
          elapsedUs: parts.elapsedUs,
        ),
      );
    }
    for (final span in frame.spans) {
      if (seenSpans.any((seen) => identical(seen, span))) {
        continue;
      }
      seenSpans.add(span);
      lines.add(
        BesideLine(
          timeUs: _time(span['startUs']),
          title: _spanTitle(span, _spanFrameCount(grouping, span)),
          detail: parts.detail,
          widgets: widgets,
          buildUs: parts.buildUs,
          rasterUs: parts.rasterUs,
          elapsedUs: parts.elapsedUs,
        ),
      );
    }
  }
  for (final state in grouping.states) {
    lines.add(
      BesideLine(
        timeUs: _time(state['timeUs']),
        title: _stateTitle(state),
        detail: 'ungrouped',
        widgets: const [],
      ),
    );
  }
  for (final span in grouping.spans) {
    lines.add(
      BesideLine(
        timeUs: _time(span['startUs']),
        title: _spanTitle(span, 0),
        detail: 'ungrouped',
        widgets: const [],
      ),
    );
  }
  lines.sort((a, b) => a.timeUs.compareTo(b.timeUs));
  return _withActions(lines, actions);
}

const _actionWindowUs = 32000;

/// Each line takes the latest unused action at or before it, inside 32 ms.
List<BesideLine> _withActions(
  List<BesideLine> lines,
  List<Map<String, Object?>> actions,
) {
  if (actions.isEmpty) {
    return lines;
  }
  final used = <int>{};
  return [
    for (final line in lines) _claimAction(line, actions, used),
  ];
}

BesideLine _claimAction(
  BesideLine line,
  List<Map<String, Object?>> actions,
  Set<int> used,
) {
  var best = -1;
  var bestTime = -1;
  for (var i = 0; i < actions.length; i++) {
    if (used.contains(i)) {
      continue;
    }
    final time = actions[i]['timeUs'];
    final name = actions[i]['name'];
    if (time is! int || name is! String || name.isEmpty) {
      continue;
    }
    if (time > line.timeUs || line.timeUs - time > _actionWindowUs) {
      continue;
    }
    if (best < 0 || time >= bestTime) {
      best = i;
      bestTime = time;
    }
  }
  if (best < 0) {
    return line;
  }
  used.add(best);
  return BesideLine(
    timeUs: line.timeUs,
    title: line.title,
    detail: line.detail,
    widgets: line.widgets,
    buildUs: line.buildUs,
    rasterUs: line.rasterUs,
    elapsedUs: line.elapsedUs,
    action: 'tap ${actions[best]['name']}',
  );
}

String _stateTitle(Map<String, Object?> state) {
  final name = state['name'];
  final event = state['event'];
  final summary = state['summary'];
  if (event is String) {
    return '$name → $event → $summary';
  }
  return '$name → $summary';
}

String _spanTitle(Map<String, Object?> span, int frames) {
  final change = '${span['name']} → ${span['status']}';
  if (frames == 0) {
    return change;
  }
  final count = frames == 1 ? '1 frame' : '$frames frames';
  return '$change · $count';
}

({String detail, int? buildUs, int? rasterUs, int? elapsedUs}) _frameParts(
  Map<String, Object?> frame,
) {
  final elapsed = frame['elapsedUs'];
  final build = frame['buildUs'];
  final raster = frame['rasterUs'];
  final elapsedUs = elapsed is int ? elapsed : null;
  final buildUs = build is int ? build : null;
  final rasterUs = raster is int ? raster : null;
  final elapsedText = elapsedUs == null ? '?' : _ms(elapsedUs);
  final id = frame['id'];
  final idText = id is String ? ' · $id' : '';
  final detail = buildUs != null && rasterUs != null
      ? 'build ${_ms(buildUs)} · raster ${_ms(rasterUs)} · '
            'elapsed $elapsedText$idText'
      : '$elapsedText$idText';
  return (
    detail: detail,
    buildUs: buildUs,
    rasterUs: rasterUs,
    elapsedUs: elapsedUs,
  );
}

String _ms(int microseconds) =>
    '${(microseconds / 1000).toStringAsFixed(1)} ms';

/// What the two columns show, after the steps.
///
/// Steps are paired by order. Each sentence compares a number the columns
/// already print, or counts the names in them. Nothing here names a cause.
List<String> besideReading(List<BesideLine> left, List<BesideLine> right) {
  final lines = <String>[
    ?_metricLine('Build', left, right, (line) => line.buildUs),
    ?_metricLine('Raster', left, right, (line) => line.rasterUs),
    ?_metricLine('Elapsed', left, right, (line) => line.elapsedUs),
    ..._nameLines(left, right),
  ];
  return lines;
}

String? _metricLine(
  String label,
  List<BesideLine> left,
  List<BesideLine> right,
  int? Function(BesideLine line) read,
) {
  final count = left.length > right.length ? left.length : right.length;
  final largerLeft = <({int step, String leftMs, String rightMs})>[];
  final largerRight = <({int step, String leftMs, String rightMs})>[];
  final same = <({int step, String ms})>[];
  for (var i = 0; i < count; i++) {
    final leftUs = i < left.length ? read(left[i]) : null;
    final rightUs = i < right.length ? read(right[i]) : null;
    if (leftUs == null || rightUs == null) {
      continue;
    }
    final leftMs = _ms(leftUs);
    final rightMs = _ms(rightUs);
    final step = i + 1;
    if (leftMs == rightMs) {
      same.add((step: step, ms: leftMs));
    } else if (leftUs > rightUs) {
      largerLeft.add((step: step, leftMs: leftMs, rightMs: rightMs));
    } else {
      largerRight.add((step: step, leftMs: leftMs, rightMs: rightMs));
    }
  }
  if (largerLeft.isEmpty && largerRight.isEmpty && same.isEmpty) {
    return null;
  }
  final clauses = <String>[
    if (largerLeft.isNotEmpty)
      'longer on the left in ${_stepList(largerLeft.map((pair) => pair.step))} '
          '(${_pairs(largerLeft)})',
    if (largerRight.isNotEmpty)
      'longer on the right in ${_stepList(largerRight.map((pair) => pair.step))} '
          '(${_pairs(largerRight)})',
    if (same.isNotEmpty)
      'the same in ${_stepList(same.map((pair) => pair.step))} '
          '(${same.map((pair) => pair.ms).join(', ')})',
  ];
  return '$label is ${_joinClauses(clauses)}.';
}

String _pairs(List<({int step, String leftMs, String rightMs})> pairs) {
  return pairs
      .map((pair) => '${pair.leftMs}, ${pair.rightMs}')
      .join('; ');
}

List<String> _nameLines(List<BesideLine> left, List<BesideLine> right) {
  final count = left.length > right.length ? left.length : right.length;
  final lines = <String>[];
  for (var i = 0; i < count; i++) {
    final hasLeft = i < left.length;
    final hasRight = i < right.length;
    final step = i + 1;
    if (!hasLeft || !hasRight) {
      lines.add(
        'Step $step is only in the ${hasLeft ? 'left' : 'right'} file.',
      );
      continue;
    }
    final leftCount = left[i].widgets.length;
    final rightCount = right[i].widgets.length;
    if (leftCount == rightCount) {
      continue;
    }
    final more = leftCount > rightCount ? 'left' : 'right';
    final names =
        'Step $step rebuilt ${_nameCount(leftCount)} on the left and '
        '${_nameCount(rightCount)} on the right';
    final elapsed = _elapsedRelation(left[i].elapsedUs, right[i].elapsedUs);
    if (elapsed == null) {
      lines.add('$names.');
      continue;
    }
    if (elapsed == more) {
      lines.add('$names, and the $more elapsed time is longer.');
      continue;
    }
    if (elapsed == 'same') {
      lines.add('$names. Elapsed time matches.');
      continue;
    }
    lines.add('$names, and the $more elapsed time is shorter.');
  }
  return lines;
}

/// `left`, `right`, or `same` from the milliseconds the print shows.
String? _elapsedRelation(int? leftUs, int? rightUs) {
  if (leftUs == null || rightUs == null) {
    return null;
  }
  final leftMs = _ms(leftUs);
  final rightMs = _ms(rightUs);
  if (leftMs == rightMs) {
    return 'same';
  }
  return leftUs > rightUs ? 'left' : 'right';
}

String _nameCount(int count) => count == 1 ? '1 widget' : '$count widgets';

String _stepList(Iterable<int> steps) {
  final values = steps.toList();
  if (values.length == 1) {
    return 'step ${values.single}';
  }
  if (values.length == 2) {
    return 'steps ${values[0]} and ${values[1]}';
  }
  final head = values.take(values.length - 1).join(', ');
  return 'steps $head, and ${values.last}';
}

String _joinClauses(List<String> clauses) {
  if (clauses.length == 1) {
    return clauses.single;
  }
  if (clauses.length == 2) {
    return '${clauses[0]}, and ${clauses[1]}';
  }
  final head = clauses.take(clauses.length - 1).join(', ');
  return '$head, and ${clauses.last}';
}

int _spanFrameCount(FrameGrouping grouping, Map<String, Object?> span) {
  var count = 0;
  for (final frame in grouping.frames) {
    if (frame.spans.any((candidate) => identical(candidate, span))) {
      count += 1;
    }
  }
  return count;
}

int _time(Object? value) => value is int ? value : 0;

/// The scenario a recording says it played. Written by `tool/play.dart`.
class PlayedScenario {
  PlayedScenario({this.path, this.board, this.script});

  final String? path;
  final String? board;
  final String? script;

  static PlayedScenario? fromSession(Map<Object?, Object?> session) {
    final play = session['play'];
    if (play is! Map) {
      return null;
    }
    final script = play['scenario'];
    final path = play['scenarioPath'];
    final board = play['board'];
    if (script is! String && path is! String && board is! String) {
      return null;
    }
    return PlayedScenario(
      path: path is String ? path : null,
      board: board is String ? board : null,
      script: script is String ? script : null,
    );
  }
}

String _scenarioBody(String script) =>
    script.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trimRight();

/// Whether two recordings played the same taps, and the sentence to show.
///
/// [same] is null when a recording did not store its scenario. The script
/// text is the check. The board is not part of the scenario.
({bool? same, String note}) scenarioReading({
  PlayedScenario? left,
  PlayedScenario? right,
}) {
  final leftScript = left?.script;
  final rightScript = right?.script;
  if (leftScript == null && rightScript == null) {
    return (
      same: null,
      note: 'Neither recording stored which scenario was played.',
    );
  }
  if (leftScript == null) {
    return (
      same: null,
      note: 'The left recording did not store which scenario was played.',
    );
  }
  if (rightScript == null) {
    return (
      same: null,
      note: 'The right recording did not store which scenario was played.',
    );
  }
  final same = _scenarioBody(leftScript) == _scenarioBody(rightScript);
  final boards = _boardSentence(left, right);
  if (!same) {
    final note =
        'The recordings did not play the same scenario. '
        'Left played ${_scenarioLabel(left)}. '
        'Right played ${_scenarioLabel(right)}.';
    return (same: false, note: boards == null ? note : '$note $boards');
  }
  final sharedPath = left!.path != null && left.path == right!.path
      ? left.path
      : null;
  final taps = sharedPath == null
      ? 'Both recordings played the same taps. '
            'Left used ${_scenarioLabel(left)}. '
            'Right used ${_scenarioLabel(right)}.'
      : 'Both recordings played $sharedPath.';
  return (same: true, note: boards == null ? taps : '$taps $boards');
}

String _scenarioLabel(PlayedScenario? stamp) =>
    stamp?.path ?? 'an unnamed scenario';

String? _boardSentence(PlayedScenario? left, PlayedScenario? right) {
  final leftBoard = left?.board;
  final rightBoard = right?.board;
  if (leftBoard == null && rightBoard == null) {
    return null;
  }
  return 'Left opened ${leftBoard ?? 'an unrecorded board'}. '
      'Right opened ${rightBoard ?? 'an unrecorded board'}.';
}

/// One results file written by `tool/compare.dart --out`.
///
/// The steps are the two columns. The scenario text is included only when
/// both recordings stored the same taps. [git] is whatever the caller learned
/// about that script.
Map<String, Object?> compareDocument({
  required List<BesideLine> left,
  required List<BesideLine> right,
  required String leftPath,
  required String rightPath,
  String? leftMode,
  String? rightMode,
  String? leftStartedAt,
  String? rightStartedAt,
  PlayedScenario? leftPlay,
  PlayedScenario? rightPlay,
  Map<String, Object?>? git,
}) {
  final count = left.length > right.length ? left.length : right.length;
  final played = scenarioReading(left: leftPlay, right: rightPlay);
  final scenario = played.same == true ? leftPlay?.script : null;
  final scenarioPath = played.same == true ? leftPlay?.path : null;
  return {
    'schemaVersion': 1,
    'kind': 'insight.compare',
    'scenarioSame': played.same,
    'scenarioNote': played.note,
    'left': {
      'path': leftPath,
      if (leftMode != null) 'mode': leftMode,
      if (leftStartedAt != null) 'startedAt': leftStartedAt,
      if (leftPlay?.board != null) 'board': leftPlay!.board,
    },
    'right': {
      'path': rightPath,
      if (rightMode != null) 'mode': rightMode,
      if (rightStartedAt != null) 'startedAt': rightStartedAt,
      if (rightPlay?.board != null) 'board': rightPlay!.board,
    },
    if (scenarioPath != null) 'scenarioPath': scenarioPath,
    if (scenario != null) 'scenario': scenario,
    if (git != null) 'git': git,
    'steps': [
      for (var i = 0; i < count; i++)
        {
          'left': i < left.length ? _column(left[i]) : null,
          'right': i < right.length ? _column(right[i]) : null,
        },
    ],
    'reading': besideReading(left, right),
  };
}

Map<String, Object?> _column(BesideLine line) {
  return {
    'title': line.title,
    'detail': line.detail,
    'widgets': line.widgets,
  };
}

/// One step of the side-by-side print.
///
/// The title is the first row and the frame line is the second. Widget
/// names follow. A name present in both files shares a row. A name present
/// in one file occupies that file's column. Order inside each file is kept.
List<(String?, String?)> besideStepRows(BesideLine? left, BesideLine? right) {
  return [
    (left?.title ?? '—', right?.title ?? '—'),
    (left?.detail, right?.detail),
    ...alignWidgetNames(left?.widgets ?? const [], right?.widgets ?? const []),
  ];
}

/// Pairs equal names onto one row and leaves the others in their own column.
List<(String?, String?)> alignWidgetNames(
  List<String> left,
  List<String> right,
) {
  final n = left.length;
  final m = right.length;
  final lengths = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      if (left[i] == right[j]) {
        lengths[i][j] = lengths[i + 1][j + 1] + 1;
      } else {
        final skipLeft = lengths[i + 1][j];
        final skipRight = lengths[i][j + 1];
        lengths[i][j] = skipLeft >= skipRight ? skipLeft : skipRight;
      }
    }
  }
  final rows = <(String?, String?)>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (left[i] == right[j]) {
      rows.add((left[i], right[j]));
      i += 1;
      j += 1;
    } else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
      rows.add((left[i], null));
      i += 1;
    } else {
      rows.add((null, right[j]));
      j += 1;
    }
  }
  while (i < n) {
    rows.add((left[i], null));
    i += 1;
  }
  while (j < m) {
    rows.add((null, right[j]));
    j += 1;
  }
  return rows;
}
