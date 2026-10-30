import 'package:insight_collector/insight_collector.dart';

/// Flutter widgets that sit around the app's own widgets.
///
/// Hidden in the panel until the reader asks for them. The session file
/// still stores every rebuild.
const wrapperWidgetNames = <String>{
  'AbsorbPointer',
  'Align',
  'AnimatedBuilder',
  'AnimatedContainer',
  'AnimatedOpacity',
  'AspectRatio',
  'AppBar',
  'Baseline',
  'Card',
  'Chip',
  'ChoiceChip',
  'BlocBuilder',
  'BlocConsumer',
  'BlocListener',
  'Builder',
  'Center',
  'ColoredBox',
  'Column',
  'ConstrainedBox',
  'Container',
  'CustomScrollView',
  'DecoratedBox',
  'DefaultTextStyle',
  'Directionality',
  'Divider',
  'ElevatedButton',
  'Expanded',
  'FadeTransition',
  'FilledButton',
  'FilterChip',
  'FittedBox',
  'Flex',
  'FloatingActionButton',
  'Flexible',
  'FutureBuilder',
  'GestureDetector',
  'GridView',
  'Icon',
  'IconButton',
  'IconTheme',
  'IgnorePointer',
  'IndexedStack',
  'InkWell',
  'LayoutBuilder',
  'LimitedBox',
  'ListTile',
  'ListView',
  'ListenableBuilder',
  'Listener',
  'Material',
  'MouseRegion',
  'Offstage',
  'OutlinedButton',
  'Opacity',
  'OverflowBox',
  'Padding',
  'PhysicalModel',
  'Positioned',
  'RichText',
  'Row',
  'SafeArea',
  'Scaffold',
  'Semantics',
  'SingleChildScrollView',
  'SizeTransition',
  'SizedBox',
  'SlideTransition',
  'Spacer',
  'Stack',
  'StreamBuilder',
  'Text',
  'TextButton',
  'ValueListenableBuilder',
  'Wrap',
};

bool isWrapperWidget(String name) {
  final angle = name.indexOf('<');
  final head = angle == -1 ? name : name.substring(0, angle);
  return wrapperWidgetNames.contains(head);
}

class ShownFrame {
  ShownFrame({
    required this.frame,
    required this.spans,
    required this.widgets,
    required this.hiddenWidgets,
  });

  final GroupedFrame frame;

  /// Spans whose earliest overlapping frame is this one, with the number
  /// of frames each span overlaps.
  final List<({Map<String, Object?> span, int frames})> spans;
  final Map<String, int> widgets;
  final int hiddenWidgets;
}

class PanelRows {
  PanelRows({
    required this.frames,
    required this.states,
    required this.spans,
    required this.rebuilds,
  });

  final List<ShownFrame> frames;
  final List<Map<String, Object?>> states;
  final List<Map<String, Object?>> spans;
  final List<String> rebuilds;
}

PanelRows panelRows(
  FrameGrouping grouping, {
  required bool showAllFrames,
  required bool showAllWidgets,
}) {
  final frames = <ShownFrame>[];
  for (final frame in grouping.frames) {
    final spans = <({Map<String, Object?> span, int frames})>[];
    for (final span in frame.spans) {
      if (!_isEarliestSpan(grouping, frame, span)) {
        continue;
      }
      spans.add((span: span, frames: _spanFrameCount(grouping, span)));
    }
    final counts = <String, int>{};
    var hidden = 0;
    for (final name in frame.rebuilds) {
      if (!showAllWidgets && isWrapperWidget(name)) {
        hidden += 1;
        continue;
      }
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final moment = frame.states.isNotEmpty || spans.isNotEmpty;
    if (!moment && !showAllFrames) {
      continue;
    }
    if (!moment && counts.isEmpty && hidden == 0) {
      continue;
    }
    frames.add(
      ShownFrame(
        frame: frame,
        spans: spans,
        widgets: counts,
        hiddenWidgets: hidden,
      ),
    );
  }
  return PanelRows(
    frames: frames.reversed.toList(),
    states: grouping.states,
    spans: grouping.spans,
    rebuilds: [
      for (final name in grouping.outside)
        if (showAllFrames && (showAllWidgets || !isWrapperWidget(name))) name,
    ],
  );
}

bool _isEarliestSpan(
  FrameGrouping grouping,
  GroupedFrame frame,
  Map<String, Object?> span,
) {
  for (final other in grouping.frames) {
    if (other.spans.any((candidate) => identical(candidate, span))) {
      return identical(other, frame);
    }
  }
  return false;
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

class FlowStep {
  FlowStep({
    required this.timeUs,
    required this.states,
    required this.spans,
    required this.widgets,
    required this.hiddenWidgets,
    required this.ungrouped,
    this.frameId,
    this.elapsedUs,
  });

  final int timeUs;
  final List<Map<String, Object?>> states;
  final List<({Map<String, Object?> span, int frames})> spans;
  final Map<String, int> widgets;
  final int hiddenWidgets;
  final bool ungrouped;
  final String? frameId;
  final int? elapsedUs;
}

/// Changes in time order, earliest first.
///
/// The order is the sequence of records. It is not a cause.
List<FlowStep> flowSteps(PanelRows rows) {
  final steps = <FlowStep>[
    for (final shown in rows.frames)
      FlowStep(
        timeUs: _time(shown.frame.frame['timeUs']),
        states: shown.frame.states,
        spans: shown.spans,
        widgets: shown.widgets,
        hiddenWidgets: shown.hiddenWidgets,
        ungrouped: false,
        frameId: shown.frame.frame['id'] as String?,
        elapsedUs: _optionalTime(shown.frame.frame['elapsedUs']),
      ),
    for (final state in rows.states)
      FlowStep(
        timeUs: _time(state['timeUs']),
        states: [state],
        spans: const [],
        widgets: const {},
        hiddenWidgets: 0,
        ungrouped: true,
      ),
    for (final span in rows.spans)
      FlowStep(
        timeUs: _time(span['startUs']),
        states: const [],
        spans: [(span: span, frames: 0)],
        widgets: const {},
        hiddenWidgets: 0,
        ungrouped: true,
      ),
  ];
  steps.sort((a, b) => a.timeUs.compareTo(b.timeUs));
  return steps;
}

String stateChange(Map<String, Object?> state) {
  final name = state['name'];
  final event = state['event'];
  final summary = state['summary'];
  if (event is String) {
    return '$name → $event → $summary';
  }
  return '$name → $summary';
}

String spanChange(Map<String, Object?> span, int frames) {
  final change = '${span['name']} → ${span['status']}';
  if (frames == 0) {
    return change;
  }
  final count = frames == 1 ? '1 frame' : '$frames frames';
  return '$change · $count';
}

int _time(Object? value) => value is int ? value : 0;

int? _optionalTime(Object? value) => value is int ? value : null;
