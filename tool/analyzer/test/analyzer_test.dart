import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight_analyzer/main.dart';
import 'package:insight_analyzer/src/result.dart';
import 'package:insight_analyzer/src/times.dart';

void main() {
  test('the shortest time is best and the longest is worst', () {
    expect(timeMark(4500, [15400, 4500]), TimeMark.best);
    expect(timeMark(15400, [15400, 4500]), TimeMark.worst);
    expect(timeMark(1315, [1315, 1263]), TimeMark.none);
    expect(timeMark(2000, [1000, 2000, 3000]), TimeMark.none);
    expect(timeMark(1000, [1000, 2000, 3000]), TimeMark.best);
    expect(timeMark(3000, [1000, 2000, 3000]), TimeMark.worst);
    expect(timeMark(15400, [15400]), TimeMark.none);
    expect(timeText(4500, TimeMark.best), '4.5 ms best');
  });

  test('a comparison file is not one recording', () {
    expect(
      () => readRunResult({'kind': 'insight.compare', 'steps': []}),
      throwsFormatException,
    );
  });

  test('a session shows the scenario it stored and its steps', () {
    final result = _session(board: 'plinth', name: 'PlinthButton');

    expect(result.board, 'plinth');
    expect(result.scenarioPath, 'examples/exchange/ring.txt');
    expect(result.steps.single.widgets, ['PlinthButton']);
  });

  test('two recordings compare against the first', () {
    final pair = readPair(
      _session(board: 'plinth', name: 'PlinthButton', elapsedUs: 15400),
      _session(
        board: 'bloc',
        name: 'LinePhone',
        elapsedUs: 4500,
        path: 'examples/exchange/ring.txt',
      ),
    );

    expect(pair.note, contains('Both recordings played'));
    expect(pair.reading.join('\n'), contains('longer on the left'));
    expect(pair.rows.single.any((row) => row.$2 == 'LinePhone'), isTrue);
  });

  test('a manual recording exports the taps it recorded', () {
    final result = readRunResult({
      'schemaVersion': 1,
      'mode': 'debug',
      'events': [
        {'type': 'user.action', 'timeUs': 20, 'name': 'phone-1'},
        {'type': 'user.action', 'timeUs': 10, 'name': 'lines-3'},
      ],
    });

    expect(result.scenario, isNull);
    expect(result.taps, 'tap lines-3\ntap phone-1\n');
  });

  test('export writes the taps next to the recording', () async {
    final directory = await Directory.systemTemp.createTemp('analyzer');
    addTearDown(() => directory.delete(recursive: true));
    final resultFile = File('${directory.path}/1.json');
    const scenario = 'tap phone-1\nsee Calling 2\n';
    await resultFile.writeAsString(jsonEncode({'schemaVersion': 1}));

    final out = tapsFileFor(resultFile.path, 'examples/exchange/ring.txt');
    await out.writeAsString(scenario);

    expect(out.path, endsWith('${Platform.pathSeparator}ring.txt'));
    expect(out.readAsStringSync(), scenario);
  });

  testWidgets('the screen shows one recording', (tester) async {
    final run = OpenedRun(
      path: r'C:\sessions\1.json',
      result: _session(
        board: 'plinth',
        name: 'PlinthButton',
        action: 'phone-1',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzerHome(
          runs: [run],
          onSelect: () {},
          onAdd: () {},
          onExport: (_) {},
          onRemove: (_) {},
        ),
      ),
    );

    expect(find.text('1.json'), findsOneWidget);
    expect(find.text('examples/exchange/ring.txt'), findsOneWidget);
    expect(find.text('plinth · profile'), findsOneWidget);
    expect(find.text('tap phone-1'), findsOneWidget);
    expect(find.text('PlinthButton'), findsOneWidget);
    expect(find.text('Rebuilt 1 widget.'), findsOneWidget);
    expect(find.textContaining('best'), findsNothing);
    expect(find.byKey(const Key('export-taps')), findsOneWidget);
    expect(find.byKey(const Key('add-result')), findsOneWidget);
    expect(find.text('Add result'), findsOneWidget);
  });

  testWidgets('an added recording is compared with the first', (tester) async {
    final first = OpenedRun(
      path: r'C:\sessions\2.json',
      result: _session(
        board: 'plinth',
        name: 'PlinthButton',
        elapsedUs: 15400,
        extra: 'PlinthPaper',
      ),
    );
    final added = OpenedRun(
      path: r'C:\sessions\3.json',
      result: _session(board: 'bloc', name: 'LinePhone', elapsedUs: 4500),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzerHome(
          runs: [first, added],
          onSelect: () {},
          onAdd: () {},
          onExport: (_) {},
          onRemove: (_) {},
        ),
      ),
    );

    expect(find.text('2.json'), findsOneWidget);
    expect(find.text('3.json'), findsOneWidget);
    expect(find.text('PlinthButton'), findsOneWidget);
    expect(find.text('LinePhone'), findsOneWidget);
    expect(find.textContaining('longer on the left'), findsOneWidget);
    expect(find.textContaining('15.4 ms worst'), findsOneWidget);
    expect(find.textContaining('4.5 ms best'), findsOneWidget);
    expect(find.byKey(const Key('remove-result-1')), findsOneWidget);
  });

  testWidgets('three recordings sit in one row', (tester) async {
    final runs = [
      for (final name in ['1.json', '2.json', '3.json'])
        OpenedRun(
          path: 'C:\\sessions\\$name',
          result: _session(board: 'bloc', name: 'LinePhone'),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzerHome(
          runs: runs,
          onSelect: () {},
          onAdd: () {},
          onExport: (_) {},
          onRemove: (_) {},
        ),
      ),
    );

    final first = tester.getTopLeft(find.text('1.json'));
    final second = tester.getTopLeft(find.text('2.json'));
    final third = tester.getTopLeft(find.text('3.json'));
    expect(first.dy, second.dy);
    expect(second.dy, third.dy);
    expect(first.dx, lessThan(second.dx));
    expect(second.dx, lessThan(third.dx));
  });

  testWidgets('a hand recording shows its mode and start, not missing fields', (
    tester,
  ) async {
    final run = OpenedRun(
      path: r'C:\sessions\insight-session.json',
      result: readRunResult({
        'schemaVersion': 1,
        'flutter': '3.47.8',
        'mode': 'debug',
        'startedAt': '2026-10-31T16:19:38.936435Z',
        'events': <Object?>[],
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzerHome(
          runs: [run],
          onSelect: () {},
          onAdd: () {},
          onExport: (_) {},
          onRemove: (_) {},
        ),
      ),
    );

    expect(
      find.text('debug · Flutter 3.47.8 · 2026-10-31 16:19'),
      findsOneWidget,
    );
    expect(
      find.text('This recording did not store which scenario was played.'),
      findsNothing,
    );
    expect(find.text('No git commit was stored.'), findsNothing);
    expect(find.text('Time grouping, not a cause.'), findsNothing);
    expect(find.byKey(const Key('export-taps')), findsNothing);
    expect(find.textContaining('Export waits'), findsNothing);
  });

  testWidgets('a manual recording offers export taps', (tester) async {
    final run = OpenedRun(
      path: r'C:\sessions\insight-session.json',
      result: readRunResult({
        'schemaVersion': 1,
        'mode': 'debug',
        'events': [
          {'type': 'user.action', 'timeUs': 10, 'name': 'phone-3'},
        ],
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzerHome(
          runs: [run],
          onSelect: () {},
          onAdd: () {},
          onExport: (_) {},
          onRemove: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('export-taps')), findsOneWidget);
    expect(find.text('Export taps'), findsOneWidget);
  });

  testWidgets('the tool offers select file before any recording', (
    tester,
  ) async {
    await tester.pumpWidget(const AnalyzerApp());
    expect(find.byKey(const Key('select-file')), findsOneWidget);
    expect(find.text('Select file'), findsOneWidget);
    expect(find.text('Select a recording.'), findsOneWidget);
    expect(find.byKey(const Key('add-result')), findsNothing);
  });
}

RunResult _session({
  required String board,
  required String name,
  int elapsedUs = 15400,
  String? extra,
  String? action,
  String path = 'examples/exchange/ring.txt',
}) {
  return readRunResult({
    'schemaVersion': 1,
    'mode': 'profile',
    'play': {
      'board': board,
      'scenarioPath': path,
      'scenario': 'tap phone-1\n',
      'commit': 'abcdef1234567890',
      'branch': 'main',
      'subject': 'Point the repository at ylahav/insight.',
    },
    'events': [
      if (action != null)
        {'type': 'user.action', 'timeUs': 90, 'name': action},
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'ExchangeCubit',
        'summary': 'Exchange',
      },
      {
        'type': 'frame',
        'timeUs': 110,
        'elapsedUs': elapsedUs,
        'buildUs': 1648,
        'rasterUs': 945,
        'id': 'frame_6',
      },
      {'type': 'widget.rebuild', 'timeUs': 120, 'name': name},
      if (extra != null)
        {'type': 'widget.rebuild', 'timeUs': 121, 'name': extra},
    ],
  });
}
