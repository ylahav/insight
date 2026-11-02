import 'package:insight_collector/insight_collector.dart';
import 'package:test/test.dart';

void main() {
  test('a tap in the 32 ms window is shown above that step', () {
    final lines = besideLines([
      {'type': 'user.action', 'timeUs': 90, 'name': 'phone-1'},
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'ExchangeCubit',
        'summary': 'Exchange',
      },
      {'type': 'frame', 'timeUs': 110, 'elapsedUs': 1700, 'id': 'frame_1'},
      {'type': 'user.action', 'timeUs': 200, 'name': 'digit-1-2'},
      {
        'type': 'state.changed',
        'timeUs': 210,
        'name': 'ExchangeCubit',
        'summary': 'Exchange',
      },
      {'type': 'user.action', 'timeUs': 1000, 'name': 'phone-2'},
      {
        'type': 'state.changed',
        'timeUs': 40000,
        'name': 'ExchangeCubit',
        'summary': 'Exchange',
      },
    ]);

    expect(lines[0].action, 'tap phone-1');
    expect(lines[1].action, 'tap digit-1-2');
    expect(lines[2].action, isNull);
  });

  test('two ticks stay readable when their widgets differ', () {
    final scoped = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'second',
        'summary': 'int',
      },
      {'type': 'frame', 'timeUs': 110, 'elapsedUs': 1700, 'id': 'frame_159'},
      {'type': 'widget.rebuild', 'timeUs': 120, 'name': 'TextButton'},
      {'type': 'widget.rebuild', 'timeUs': 130, 'name': 'SecondReadout'},
      {'type': 'widget.rebuild', 'timeUs': 140, 'name': 'Text'},
    ]);
    final wide = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'second',
        'summary': 'int',
      },
      {'type': 'frame', 'timeUs': 110, 'elapsedUs': 1700, 'id': 'frame_69'},
      {'type': 'widget.rebuild', 'timeUs': 120, 'name': 'WideShelf'},
      {'type': 'widget.rebuild', 'timeUs': 130, 'name': 'SecondReadout'},
      {'type': 'widget.rebuild', 'timeUs': 140, 'name': 'MarkCard'},
      {'type': 'widget.rebuild', 'timeUs': 150, 'name': 'Padding'},
    ]);

    expect(scoped.single.title, 'second → int');
    expect(scoped.single.detail, '1.7 ms · frame_159');
    expect(scoped.single.widgets, ['SecondReadout']);
    expect(wide.single.widgets, ['WideShelf', 'SecondReadout', 'MarkCard']);

    expect(besideStepRows(scoped.single, wide.single), [
      ('second → int', 'second → int'),
      ('1.7 ms · frame_159', '1.7 ms · frame_69'),
      (null, 'WideShelf'),
      ('SecondReadout', 'SecondReadout'),
      (null, 'MarkCard'),
    ]);
    expect(besideReading(scoped, wide), [
      'Elapsed is the same in step 1 (1.7 ms).',
      'Step 1 rebuilt 1 widget on the left and 3 widgets on the right. '
          'Elapsed time matches.',
    ]);
  });

  test('a profile frame lists build, raster, and elapsed', () {
    final lines = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'ExchangeCubit',
        'summary': 'Exchange',
      },
      {
        'type': 'frame',
        'timeUs': 110,
        'buildUs': 1648,
        'rasterUs': 945,
        'elapsedUs': 15400,
        'id': 'frame_6',
      },
      {'type': 'widget.rebuild', 'timeUs': 120, 'name': 'PlinthButton'},
    ]);

    expect(
      lines.single.detail,
      'build 1.6 ms · raster 0.9 ms · elapsed 15.4 ms · frame_6',
    );
    expect(lines.single.buildUs, 1648);
    expect(lines.single.rasterUs, 945);
    expect(lines.single.elapsedUs, 15400);
  });

  test(
    'the reading follows each step and keeps a longer list apart from the time',
    () {
      final left = [
        BesideLine(
          timeUs: 1,
          title: 'ExchangeCubit → Exchange',
          detail: '',
          widgets: List.filled(8, 'PlinthButton'),
          buildUs: 1648,
          rasterUs: 945,
          elapsedUs: 15400,
        ),
        BesideLine(
          timeUs: 2,
          title: 'ExchangeCubit → Exchange',
          detail: '',
          widgets: List.filled(6, 'PlinthLine'),
          buildUs: 1403,
          rasterUs: 847,
          elapsedUs: 3043,
        ),
        BesideLine(
          timeUs: 3,
          title: 'ExchangeCubit → Exchange',
          detail: '',
          widgets: List.filled(4, 'PlinthLine'),
          buildUs: 1315,
          rasterUs: 308,
          elapsedUs: 2604,
        ),
      ];
      final right = [
        BesideLine(
          timeUs: 1,
          title: 'exchange → Exchange',
          detail: '',
          widgets: List.filled(4, 'DialKey'),
          buildUs: 1507,
          rasterUs: 1696,
          elapsedUs: 4517,
        ),
        BesideLine(
          timeUs: 2,
          title: 'exchange → Exchange',
          detail: '',
          widgets: List.filled(4, 'LinePhone'),
          buildUs: 1338,
          rasterUs: 977,
          elapsedUs: 4280,
        ),
        BesideLine(
          timeUs: 3,
          title: 'exchange → Exchange',
          detail: '',
          widgets: List.filled(4, 'LinePhone'),
          buildUs: 1263,
          rasterUs: 532,
          elapsedUs: 2505,
        ),
      ];

      expect(besideReading(left, right), [
        'Build is longer on the left in steps 1 and 2 (1.6 ms, 1.5 ms; 1.4 ms, 1.3 ms), '
            'and the same in step 3 (1.3 ms).',
        'Raster is longer on the right in steps 1, 2, and 3 '
            '(0.9 ms, 1.7 ms; 0.8 ms, 1.0 ms; 0.3 ms, 0.5 ms).',
        'Elapsed is longer on the left in steps 1 and 3 (15.4 ms, 4.5 ms; 2.6 ms, 2.5 ms), '
            'and longer on the right in step 2 (3.0 ms, 4.3 ms).',
        'Step 1 rebuilt 8 widgets on the left and 4 widgets on the right, '
            'and the left elapsed time is longer.',
        'Step 2 rebuilt 6 widgets on the left and 4 widgets on the right, '
            'and the left elapsed time is shorter.',
      ]);
    },
  );

  test('different boards are the names in the reading', () {
    final bloc = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'ExchangeCubit',
        'summary': 'Exchange',
      },
      {'type': 'frame', 'timeUs': 110, 'elapsedUs': 2000, 'id': 'frame_1'},
    ]);
    final riverpod = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'exchange',
        'summary': 'Exchange',
      },
      {'type': 'frame', 'timeUs': 110, 'elapsedUs': 3000, 'id': 'frame_1'},
    ]);

    expect(
      besideReading(bloc, riverpod, leftName: 'bloc', rightName: 'riverpod'),
      [
        'Elapsed is longer on riverpod in step 1 (bloc 2.0 ms, riverpod 3.0 ms).',
      ],
    );
  });

  test('an ungrouped state stays in the list', () {
    final lines = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 0,
        'name': 'tree',
        'summary': 'WideTree',
      },
      {'type': 'frame', 'timeUs': 32001, 'elapsedUs': 1000, 'id': 'frame_1'},
    ]);

    expect(
      compareDocument(
        left: lines,
        right: const [],
        leftPath: 'left.json',
        rightPath: 'right.json',
        leftPlay: PlayedScenario(path: 'ring.txt', script: 'tap phone-1\n'),
        rightPlay: PlayedScenario(path: 'ring.txt', script: 'tap phone-1\r\n'),
        git: const {'commit': 'abc', 'branch': 'main'},
      ),
      {
        'schemaVersion': 1,
        'kind': 'insight.compare',
        'scenarioSame': true,
        'scenarioNote': 'Both recordings played ring.txt.',
        'left': {'path': 'left.json'},
        'right': {'path': 'right.json'},
        'scenarioPath': 'ring.txt',
        'scenario': 'tap phone-1\n',
        'git': {'commit': 'abc', 'branch': 'main'},
        'steps': [
          {
            'left': {
              'title': 'tree → WideTree',
              'detail': 'ungrouped',
              'widgets': <String>[],
            },
            'right': null,
          },
        ],
        'reading': ['Step 1 is only in the left file.'],
      },
    );
    expect(lines.single.detail, 'ungrouped');
    expect(lines.single.title, 'tree → WideTree');
    expect(lines.single.widgets, isEmpty);
  });

  test('different scenario files are not the same taps', () {
    final played = scenarioReading(
      left: PlayedScenario(
        path: 'ring.txt',
        board: 'bloc',
        script: 'tap open\n',
      ),
      right: PlayedScenario(
        path: 'busy.txt',
        board: 'plinth',
        script: 'tap phone-3\n',
      ),
    );

    expect(played.same, isFalse);
    expect(
      played.note,
      'The recordings did not play the same scenario. '
      'Left played ring.txt. Right played busy.txt. '
      'The boards are bloc and plinth.',
    );
  });

  test('a span that overlaps two frames is listed once', () {
    final lines = besideLines([
      {
        'type': 'async.span',
        'name': 'loadBoard',
        'status': 'completed',
        'startUs': 100,
        'endUs': 500,
      },
      {'type': 'frame', 'timeUs': 100, 'elapsedUs': 200, 'id': 'frame_1'},
      {'type': 'frame', 'timeUs': 300, 'elapsedUs': 200, 'id': 'frame_2'},
    ]);

    expect(lines, hasLength(1));
    expect(lines.single.title, 'loadBoard → completed · 2 frames');
    expect(lines.single.detail, '0.2 ms · frame_1');
  });
}
