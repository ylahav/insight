/// Display grouping for a schema-1 session.
///
/// The session file does not store these links. This is time grouping, not
/// a cause. A rebuild belongs to the latest frame whose interval
/// `[timeUs, timeUs + elapsedUs]` contains it. A state change belongs to the
/// earliest frame that starts at or after it, when the gap is at most 32 ms.
/// An async span belongs to every frame that overlaps it.
class GroupedFrame {
  GroupedFrame(this.frame);

  final Map<String, Object?> frame;
  final List<String> rebuilds = [];
  final List<Map<String, Object?>> states = [];
  final List<Map<String, Object?>> spans = [];
}

class FrameGrouping {
  FrameGrouping({
    required this.frames,
    required this.outside,
    required this.states,
    required this.spans,
  });

  final List<GroupedFrame> frames;

  /// Rebuild names that fell outside every frame interval.
  final List<String> outside;

  /// State changes that missed the 32 ms window.
  final List<Map<String, Object?>> states;

  /// Spans that overlapped no frame.
  final List<Map<String, Object?>> spans;
}

const _stateGroupWindowUs = 32000;

FrameGrouping groupFrames(Iterable<Map<String, Object?>> events) {
  final frames = <GroupedFrame>[];
  final rebuilds = <Map<String, Object?>>[];
  final states = <Map<String, Object?>>[];
  final spans = <Map<String, Object?>>[];
  for (final event in events) {
    switch (event['type']) {
      case 'frame':
        frames.add(GroupedFrame(event));
      case 'widget.rebuild':
        rebuilds.add(event);
      case 'state.changed':
        states.add(event);
      case 'async.span':
        spans.add(event);
    }
  }
  frames.sort((a, b) {
    return (a.frame['timeUs']! as int).compareTo(b.frame['timeUs']! as int);
  });
  final outside = <String>[];
  for (final rebuild in rebuilds) {
    final time = rebuild['timeUs'];
    final name = rebuild['name'];
    if (time is! int || name is! String) {
      continue;
    }
    final index = _latestStartAtOrBefore(frames, time);
    var placed = false;
    for (var i = index; i >= 0; i--) {
      final start = frames[i].frame['timeUs']! as int;
      if (time - start > 1000000) {
        break;
      }
      final elapsed = frames[i].frame['elapsedUs']! as int;
      if (time <= start + elapsed) {
        frames[i].rebuilds.add(name);
        placed = true;
        break;
      }
    }
    if (!placed) {
      outside.add(name);
    }
  }
  final ungroupedStates = <Map<String, Object?>>[];
  for (final state in states) {
    final time = state['timeUs'];
    if (time is! int) {
      continue;
    }
    final index = _earliestStartAtOrAfter(frames, time);
    if (index < 0) {
      ungroupedStates.add(state);
      continue;
    }
    final start = frames[index].frame['timeUs']! as int;
    if (start - time > _stateGroupWindowUs) {
      ungroupedStates.add(state);
      continue;
    }
    frames[index].states.add(state);
  }
  final sessionEnd = _sessionEnd(frames, rebuilds, states, spans);
  final ungroupedSpans = <Map<String, Object?>>[];
  for (final span in spans) {
    final start = span['startUs'];
    if (start is! int) {
      continue;
    }
    final endUs = span['endUs'];
    final end = endUs is int ? endUs : sessionEnd;
    var placed = false;
    for (final frame in frames) {
      final frameStart = frame.frame['timeUs']! as int;
      final elapsed = frame.frame['elapsedUs']! as int;
      if (start <= frameStart + elapsed && end >= frameStart) {
        frame.spans.add(span);
        placed = true;
      }
    }
    if (!placed) {
      ungroupedSpans.add(span);
    }
  }
  return FrameGrouping(
    frames: frames,
    outside: outside,
    states: ungroupedStates,
    spans: ungroupedSpans,
  );
}

int _sessionEnd(
  List<GroupedFrame> frames,
  List<Map<String, Object?>> rebuilds,
  List<Map<String, Object?>> states,
  List<Map<String, Object?>> spans,
) {
  var end = 0;
  for (final frame in frames) {
    final start = frame.frame['timeUs'];
    final elapsed = frame.frame['elapsedUs'];
    if (start is int && elapsed is int && start + elapsed > end) {
      end = start + elapsed;
    }
  }
  for (final event in [...rebuilds, ...states]) {
    final time = event['timeUs'];
    if (time is int && time > end) {
      end = time;
    }
  }
  for (final span in spans) {
    final start = span['startUs'];
    final stop = span['endUs'];
    if (start is int && start > end) {
      end = start;
    }
    if (stop is int && stop > end) {
      end = stop;
    }
  }
  return end;
}

int _latestStartAtOrBefore(List<GroupedFrame> frames, int time) {
  var low = 0;
  var high = frames.length - 1;
  var found = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    final start = frames[mid].frame['timeUs']! as int;
    if (start <= time) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return found;
}

int _earliestStartAtOrAfter(List<GroupedFrame> frames, int time) {
  var low = 0;
  var high = frames.length - 1;
  var found = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    final start = frames[mid].frame['timeUs']! as int;
    if (start >= time) {
      found = mid;
      high = mid - 1;
    } else {
      low = mid + 1;
    }
  }
  return found;
}
