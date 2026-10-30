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
  });

  final int timeUs;
  final String title;
  final String detail;
  final List<String> widgets;
}

/// Changes in time order, earliest first. Wrapper widgets are omitted.
/// Rebuild-only frames are omitted. A span is included once, on its
/// earliest frame.
List<BesideLine> besideLines(Iterable<Map<String, Object?>> events) {
  final grouping = groupFrames(events);
  final lines = <BesideLine>[];
  final seenSpans = <Map<String, Object?>>[];
  for (final frame in grouping.frames) {
    final widgets = [
      for (final name in frame.rebuilds)
        if (!isWrapperWidget(name)) name,
    ];
    final detail = _frameDetail(frame.frame);
    for (final state in frame.states) {
      lines.add(
        BesideLine(
          timeUs: _time(state['timeUs']),
          title: _stateTitle(state),
          detail: detail,
          widgets: widgets,
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
          detail: detail,
          widgets: widgets,
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
  return lines;
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

String _frameDetail(Map<String, Object?> frame) {
  final elapsed = frame['elapsedUs'];
  final ms = elapsed is int ? (elapsed / 1000).toStringAsFixed(1) : '?';
  final id = frame['id'];
  if (id is String) {
    return '$ms ms · $id';
  }
  return '$ms ms';
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
