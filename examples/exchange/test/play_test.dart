import 'dart:io';

import 'package:exchange/src/exchange_app.dart';
import 'package:exchange/src/play.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a scenario command is tap or see', () {
    expect(playScript('press phone-1', 'bloc'), throwsFormatException);
  });

  testWidgets('the scenario file is the sequence', (tester) async {
    await tester.pumpWidget(const ExchangeApp());
    await playScript(
      'tap lines-3\ntap open\ntap phone-1\n',
      'bloc',
      settle: () => tester.pump(const Duration(milliseconds: 50)),
      tap: (name) => tester.tap(find.byKey(Key(name))),
    );
    expect(find.text('Hook off'), findsOneWidget);
    expect(find.text('1 and 2'), findsNothing);
  });

  testWidgets('the played ring connects on the enamel board', (tester) async {
    await _play(tester, 'bloc');
    expect(find.text('1 and 2'), findsOneWidget);
    expect(find.text('In call with 2'), findsOneWidget);
    expect(find.text('Voice'), findsNWidgets(2));
  });

  testWidgets('the played ring connects with riverpod', (tester) async {
    await _play(tester, 'riverpod');
    expect(find.text('1 and 2'), findsOneWidget);
    expect(find.text('In call with 1'), findsOneWidget);
  });

  testWidgets('the played ring connects on the plinth board', (tester) async {
    await _play(tester, 'plinth');
    expect(find.text('1 and 2'), findsOneWidget);
    expect(find.text('In call with 1'), findsOneWidget);
    expect(find.text('VOICE'), findsNWidgets(2));
  });
}

Future<void> _play(WidgetTester tester, String board) async {
  await tester.pumpWidget(const ExchangeApp());
  await playScript(
    _ringScript(),
    board,
    settle: () => tester.pump(const Duration(milliseconds: 50)),
    tap: (name) => tester.tap(find.byKey(Key(name))),
  );
}

String _ringScript() {
  for (final path in [
    'scenarios/answered-call.txt',
    'examples/exchange/scenarios/answered-call.txt',
  ]) {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
  }
  throw StateError('answered-call.txt was not found.');
}
