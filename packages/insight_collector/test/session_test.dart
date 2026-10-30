import 'package:insight_collector/insight_collector.dart';
import 'package:test/test.dart';

void main() {
  SessionBuilder builder() {
    return SessionBuilder(
      flutterVersion: '3.47.8',
      dartVersion: '3.13.7',
      mode: 'profile',
      startedAt: DateTime.utc(2026, 10, 28, 6),
    );
  }

  test('frames and agent.ready sort onto one clock', () {
    final session = builder()
      ..addFrame({
        'startTime': 500800,
        'build': 2100,
        'raster': 1400,
        'elapsed': 4200,
      })
      ..addAgent({'schemaVersion': 1, 'kind': 'agent.ready', 'timeUs': 1000});

    final built = session.build();
    final events = built['events'] as List<Map<String, Object?>>;

    expect(built['schemaVersion'], 1);
    expect(built['mode'], 'profile');
    expect(built['rejected'], 0);
    expect(events.map((event) => event['id']), ['agent_1', 'frame_1']);
    expect(events[1]['buildUs'], 2100);
    expect(events[1]['targetUs'], isNull);
    expect(events[1]['budgetExceeded'], isNull);
  });

  test('a negative duration is rejected and the session continues', () {
    final session = builder()
      ..addFrame({'startTime': 10, 'build': -1, 'raster': 1, 'elapsed': 1})
      ..addFrame({'startTime': 20, 'build': 1, 'raster': 1, 'elapsed': 1});

    final built = session.build();
    expect(built['rejected'], 1);
    expect((built['events'] as List).length, 1);
  });

  test('a second agent.ready does not create a second record', () {
    final session = builder()
      ..addAgent({'schemaVersion': 1, 'kind': 'agent.ready', 'timeUs': 1})
      ..addAgent({'schemaVersion': 1, 'kind': 'agent.ready', 'timeUs': 2});

    final built = session.build();
    expect(built['rejected'], 0);
    expect((built['events'] as List).length, 1);
    expect((built['events'] as List).single['timeUs'], 1);
  });

  test('a wrong agent schema blocks later agent messages', () {
    final session = builder()
      ..addAgent({'schemaVersion': 2, 'kind': 'agent.ready', 'timeUs': 1})
      ..addAgent({'schemaVersion': 1, 'kind': 'agent.ready', 'timeUs': 2});

    final built = session.build();
    expect(built['rejected'], 2);
    expect(built['events'], isEmpty);
  });

  test('a widget build is kept and a framework phase is not', () {
    expect(
      widgetRebuildFromTimeline({
        'ph': 'B',
        'cat': 'Dart',
        'name': 'CounterText',
        'ts': 501200,
      }),
      (timeUs: 501200, name: 'CounterText'),
    );
    expect(
      widgetRebuildFromTimeline({
        'ph': 'B',
        'cat': 'Dart',
        'name': 'BlocBuilder<CounterCubit, int>',
        'ts': 4,
      })?.name,
      'BlocBuilder<CounterCubit, int>',
    );
    expect(
      widgetRebuildFromTimeline({
        'ph': 'E',
        'cat': 'Dart',
        'name': 'CounterText',
        'ts': 1,
      }),
      isNull,
    );
    expect(
      widgetRebuildFromTimeline({
        'ph': 'B',
        'cat': 'Dart',
        'name': 'BUILD',
        'ts': 1,
      }),
      isNull,
    );
    expect(
      widgetRebuildFromTimeline({
        'ph': 'B',
        'cat': 'Dart',
        'name': 'LAYOUT (root)',
        'ts': 1,
      }),
      isNull,
    );
    expect(
      widgetRebuildFromTimeline({
        'ph': 'B',
        'cat': 'Embedder',
        'name': 'FlutterEngineOnVsync',
        'ts': 1,
      }),
      isNull,
    );
    expect(
      widgetRebuildFromTimeline({
        'ph': 'B',
        'cat': 'GC',
        'name': 'Scavenge',
        'ts': 1,
      }),
      isNull,
    );

    final session = builder()
      ..addRebuild(timeUs: 501200, name: 'CounterText')
      ..addFrame({
        'startTime': 500800,
        'build': 1,
        'raster': 1,
        'elapsed': 4200,
      });
    final events = session.build()['events'] as List<Map<String, Object?>>;
    expect(events.map((event) => event['type']), ['frame', 'widget.rebuild']);
    expect(events.last['name'], 'CounterText');
    expect(events.last['id'], 'widget_1');
  });

  test('a rebuild lands in the frame whose interval contains it', () {
    final grouping = groupFrames([
      {'type': 'frame', 'id': 'frame_1', 'timeUs': 500800, 'elapsedUs': 4200},
      {
        'type': 'widget.rebuild',
        'id': 'widget_1',
        'timeUs': 501200,
        'name': 'TicketDetail',
      },
      {'type': 'widget.rebuild', 'timeUs': 510000, 'name': 'CounterText'},
    ]);

    expect(grouping.frames.single.rebuilds, ['TicketDetail']);
    expect(grouping.outside, ['CounterText']);
  });

  test('state, async, rebuild, and frame share one order', () {
    final session = builder()
      ..addFrame({
        'startTime': 500800,
        'build': 2100,
        'raster': 1400,
        'elapsed': 4200,
      })
      ..addRebuild(timeUs: 501200, name: 'TicketDetail')
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'state.changed',
        'timeUs': 500000,
        'adapter': 'bloc',
        'name': 'BoardBloc',
        'event': 'TicketSelected',
        'summary': 'BoardIdle',
        'value': null,
      })
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'async.start',
        'timeUs': 500100,
        'spanId': 'fetch-1',
        'name': 'fetchData',
      })
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'async.end',
        'timeUs': 500900,
        'spanId': 'fetch-1',
        'status': 'completed',
        'error': null,
      });

    final events = session.build()['events'] as List<Map<String, Object?>>;
    expect(events.map((event) => event['id']), [
      'state_1',
      'async_1',
      'frame_1',
      'widget_1',
    ]);
    expect(events[1]['endUs'], 500900);
    expect(events[1]['status'], 'completed');
    expect(events[1].containsKey('spanId'), isFalse);
    expect(events[1].containsKey('stackTrace'), isFalse);

    final grouping = groupFrames(events);
    expect(grouping.frames.single.states.single['name'], 'BoardBloc');
    expect(grouping.frames.single.spans.single['name'], 'fetchData');
    expect(grouping.frames.single.rebuilds, ['TicketDetail']);
    expect(grouping.states, isEmpty);
    expect(grouping.spans, isEmpty);
  });

  test('a later state message with the same time updates the record', () {
    final session = builder()
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'state.changed',
        'timeUs': 40,
        'adapter': 'bloc',
        'name': 'BoardBloc',
        'event': 'TicketSelected',
        'summary': 'BoardIdle',
        'value': null,
      })
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'state.changed',
        'timeUs': 40,
        'adapter': 'bloc',
        'name': 'BoardBloc',
        'event': 'TicketSelected',
        'summary': 'BoardReady',
        'value': {'previous': '0', 'next': '1'},
      });

    final built = session.build();
    final events = built['events'] as List<Map<String, Object?>>;
    expect(built['rejected'], 0);
    expect(events, hasLength(1));
    expect(events.single['summary'], 'BoardReady');
    expect(events.single['value'], {'previous': '0', 'next': '1'});
  });

  test('a state change outside 32 ms stays ungrouped', () {
    final grouping = groupFrames([
      {'type': 'state.changed', 'timeUs': 0, 'name': 'BoardBloc'},
      {'type': 'frame', 'timeUs': 32001, 'elapsedUs': 1000},
    ]);

    expect(grouping.frames.single.states, isEmpty);
    expect(grouping.states.single['name'], 'BoardBloc');
  });

  test('a riverpod change is kept and an unknown adapter is rejected', () {
    final session = builder()
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'state.changed',
        'timeUs': 5,
        'adapter': 'riverpod',
        'name': 'NotifierProvider<Count, int>',
        'event': null,
        'summary': 'int',
        'value': null,
      })
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'state.changed',
        'timeUs': 6,
        'adapter': 'provider',
        'name': 'Counter',
        'event': null,
        'summary': 'int',
        'value': null,
      });

    final built = session.build();
    final events = built['events'] as List<Map<String, Object?>>;
    expect(built['rejected'], 1);
    expect(events, hasLength(1));
    expect(events.single['adapter'], 'riverpod');
    expect(events.single['event'], isNull);
  });

  test('a cubit change keeps a null event', () {
    final session = builder()
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'state.changed',
        'timeUs': 5,
        'adapter': 'bloc',
        'name': 'CounterCubit',
        'event': null,
        'summary': 'int',
        'value': null,
      });

    final event = (session.build()['events'] as List).single;
    expect(event['event'], isNull);
    expect(event['value'], isNull);
  });

  test('an unfinished span is kept and an error is truncated', () {
    final open = builder()
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'async.start',
        'timeUs': 10,
        'spanId': 'span-1',
        'name': 'future',
      });
    final openEvent = (open.build()['events'] as List).single;
    expect(openEvent['status'], 'unfinished');
    expect(openEvent['endUs'], isNull);
    expect(openEvent['error'], isNull);

    final failed = builder()
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'async.start',
        'timeUs': 10,
        'spanId': 'span-1',
        'name': 'throw',
      })
      ..addAgent({
        'schemaVersion': 1,
        'kind': 'async.end',
        'timeUs': 12,
        'spanId': 'span-1',
        'status': 'error',
        'error': 'x' * 240,
      });
    final errorEvent = (failed.build()['events'] as List).single;
    expect(errorEvent['status'], 'error');
    expect(errorEvent['endUs'], 12);
    expect((errorEvent['error'] as String).length, 200);
    expect(errorEvent.containsKey('stackTrace'), isFalse);
  });

  test('a state change 32 ms before a frame groups with that frame', () {
    final grouping = groupFrames([
      {'type': 'state.changed', 'timeUs': 0, 'name': 'BoardBloc'},
      {'type': 'frame', 'timeUs': 32000, 'elapsedUs': 1000},
    ]);

    expect(grouping.frames.single.states.single['name'], 'BoardBloc');
    expect(grouping.states, isEmpty);
  });
}
