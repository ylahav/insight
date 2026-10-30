import 'package:flutter_test/flutter_test.dart';
import 'package:insight_collector/insight_collector.dart';
import 'package:insight_devtools/src/view.dart';

void main() {
  FrameGrouping sample() {
    final span = <String, Object?>{
      'type': 'async.span',
      'id': 'async_1',
      'name': 'loadBoard',
      'status': 'completed',
    };
    return groupFrames([
      {
        'type': 'state.changed',
        'id': 'state_1',
        'timeUs': 500000,
        'name': 'BoardBloc',
        'event': 'TicketSelected',
        'summary': 'BoardReady',
      },
      {'type': 'frame', 'id': 'frame_1', 'timeUs': 500800, 'elapsedUs': 4200},
      {'type': 'widget.rebuild', 'timeUs': 501200, 'name': 'TicketCard'},
      {'type': 'widget.rebuild', 'timeUs': 501300, 'name': 'Text'},
      {'type': 'widget.rebuild', 'timeUs': 501400, 'name': 'SizedBox'},
      span,
      {'type': 'frame', 'id': 'frame_2', 'timeUs': 510000, 'elapsedUs': 2000},
      {'type': 'widget.rebuild', 'timeUs': 510100, 'name': 'CounterText'},
    ]);
  }

  test('a moment keeps the app widget and hides wrappers', () {
    final rows = panelRows(
      sample(),
      showAllFrames: false,
      showAllWidgets: false,
    );

    expect(rows.frames, hasLength(1));
    expect(rows.frames.single.frame.frame['id'], 'frame_1');
    expect(rows.frames.single.widgets.keys, ['TicketCard']);
    expect(rows.frames.single.hiddenWidgets, 2);
    expect(rows.frames.single.frame.states.single['event'], 'TicketSelected');
  });

  test('a span is shown once, on the earliest frame, with a frame count', () {
    final grouping = groupFrames([
      {
        'type': 'async.span',
        'id': 'async_1',
        'name': 'loadBoard',
        'status': 'completed',
        'startUs': 100,
        'endUs': 5000,
      },
      {'type': 'frame', 'id': 'frame_1', 'timeUs': 0, 'elapsedUs': 1000},
      {'type': 'frame', 'id': 'frame_2', 'timeUs': 2000, 'elapsedUs': 1000},
    ]);
    // The span map must be the same instance on every frame. groupFrames
    // does that when the event is one object in the input list.
    final rows = panelRows(
      grouping,
      showAllFrames: false,
      showAllWidgets: false,
    );

    expect(rows.frames, hasLength(1));
    expect(rows.frames.single.frame.frame['id'], 'frame_1');
    expect(rows.frames.single.spans.single.frames, 2);
    expect(rows.frames.single.spans.single.span['name'], 'loadBoard');
  });

  test('show all frames includes a rebuild that has no bloc event', () {
    final rows = panelRows(
      sample(),
      showAllFrames: true,
      showAllWidgets: false,
    );

    expect(rows.frames.map((row) => row.frame.frame['id']), [
      'frame_2',
      'frame_1',
    ]);
    expect(rows.frames.first.widgets.keys, ['CounterText']);
  });

  test('the flow reads changes from earliest to latest', () {
    final rows = panelRows(
      sample(),
      showAllFrames: true,
      showAllWidgets: false,
    );
    final steps = flowSteps(rows);

    expect(steps.map((step) => step.frameId), ['frame_1', 'frame_2']);
    expect(
      stateChange(steps.first.states.single),
      'BoardBloc → TicketSelected → BoardReady',
    );
    expect(steps.first.widgets.keys, ['TicketCard']);
    expect(steps.last.states, isEmpty);
  });

  test('an ungrouped change stays in the flow by its own time', () {
    final grouping = groupFrames([
      {
        'type': 'state.changed',
        'timeUs': 0,
        'name': 'ClockCubit',
        'event': null,
        'summary': 'ClockTick',
      },
      {'type': 'frame', 'id': 'frame_1', 'timeUs': 40000, 'elapsedUs': 1000},
      {
        'type': 'state.changed',
        'timeUs': 39000,
        'name': 'FilterCubit',
        'event': null,
        'summary': 'FilterOpen',
      },
    ]);
    final steps = flowSteps(
      panelRows(grouping, showAllFrames: false, showAllWidgets: false),
    );

    expect(steps, hasLength(2));
    expect(steps.first.ungrouped, isTrue);
    expect(stateChange(steps.first.states.single), 'ClockCubit → ClockTick');
    expect(stateChange(steps.last.states.single), 'FilterCubit → FilterOpen');
  });

  test('a generic Flutter widget is still a wrapper', () {
    expect(isWrapperWidget('BlocBuilder<CounterCubit, int>'), isTrue);
    expect(isWrapperWidget('TextButton'), isTrue);
    expect(isWrapperWidget('CounterText'), isFalse);
    expect(isWrapperWidget('_LightOption'), isFalse);
  });
}
