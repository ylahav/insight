import 'package:exchange/src/board.dart';
import 'package:exchange/src/exchange_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth_components/plinth_components.dart';

void main() {
  testWidgets('a bloc call rebuilds the two phones and the cords', (
    tester,
  ) async {
    await _open(tester, bloc: true);
    ExchangeBuilds.reset();

    await tester.tap(find.byKey(const Key('phone-1')));
    await tester.pump();
    expect(ExchangeBuilds.phones, 1);
    expect(ExchangeBuilds.switchDesk, 0);

    ExchangeBuilds.reset();
    await tester.tap(find.byKey(const Key('digit-1-2')));
    await tester.pump();

    expect(ExchangeBuilds.phones, 2);
    expect(ExchangeBuilds.switchDesk, 1);
    expect(find.text('Hook off'), findsOneWidget);
    expect(find.text('Hook on'), findsWidgets);
    expect(find.text('Calling 2'), findsOneWidget);
    expect(find.text('Ringing signal'), findsNWidgets(2));
    expect(find.text('2 is ringing'), findsOneWidget);

    ExchangeBuilds.reset();
    await tester.tap(find.byKey(const Key('phone-2')));
    await tester.pump();

    expect(find.text('Voice'), findsNWidgets(2));
    expect(find.text('In call with 2'), findsOneWidget);
    expect(find.text('In call with 1'), findsOneWidget);
    expect(find.text('1 and 2'), findsOneWidget);
    expect(ExchangeBuilds.phones, 2);
    expect(ExchangeBuilds.switchDesk, 1);
  });

  testWidgets('a riverpod call lists the same phones', (tester) async {
    await _open(tester, bloc: false);
    ExchangeBuilds.reset();

    await tester.tap(find.byKey(const Key('phone-1')));
    await tester.pump();
    ExchangeBuilds.reset();
    await tester.tap(find.byKey(const Key('digit-1-2')));
    await tester.pump();

    expect(ExchangeBuilds.phones, 2);
    expect(ExchangeBuilds.switchDesk, 1);
    expect(find.text('Ringing signal'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('phone-2')));
    await tester.pump();

    expect(find.text('In call with 2'), findsOneWidget);
    expect(find.text('1 and 2'), findsOneWidget);
  });

  testWidgets('dialing a busy phone leaves the other phones unbuilt', (
    tester,
  ) async {
    await _open(tester, bloc: true);
    await tester.tap(find.byKey(const Key('phone-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('digit-1-2')));
    await tester.pump();
    ExchangeBuilds.reset();

    await tester.tap(find.byKey(const Key('phone-3')));
    await tester.pump();
    ExchangeBuilds.reset();
    await tester.tap(find.byKey(const Key('digit-3-1')));
    await tester.pump();

    expect(find.text('Busy signal'), findsOneWidget);
    expect(find.text('Hook off'), findsNWidgets(2));
    expect(ExchangeBuilds.phones, 1);
    expect(ExchangeBuilds.switchDesk, 0);
  });

  testWidgets('hook on from the ringing phone clears it', (tester) async {
    await _open(tester, bloc: true);
    await tester.tap(find.byKey(const Key('phone-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('digit-1-2')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('hook-on-2')));
    await tester.pump();

    expect(find.text('Ringing signal'), findsNothing);
    expect(find.text('Calling 2'), findsNothing);
    expect(find.text('Tap a phone and dial a line.'), findsOneWidget);
  });

  testWidgets('the wide board rebuilds the phone that is not in the call', (
    tester,
  ) async {
    await _openWide(tester);
    await tester.tap(find.byKey(const Key('phone-1')));
    await tester.pump();
    ExchangeBuilds.reset();

    await tester.tap(find.byKey(const Key('digit-1-2')));
    await tester.pump();

    expect(find.text('Calling 2'), findsOneWidget);
    expect(find.text('2 is ringing'), findsOneWidget);
    expect(ExchangeBuilds.phones, 3);
    expect(ExchangeBuilds.switchDesk, 1);
  });

  testWidgets('the enamel board leaves that phone unbuilt', (tester) async {
    await _open(tester, bloc: true);
    await tester.tap(find.byKey(const Key('phone-1')));
    await tester.pump();
    ExchangeBuilds.reset();

    await tester.tap(find.byKey(const Key('digit-1-2')));
    await tester.pump();

    expect(find.text('Calling 2'), findsOneWidget);
    expect(find.text('2 is ringing'), findsOneWidget);
    expect(ExchangeBuilds.phones, 2);
    expect(ExchangeBuilds.switchDesk, 1);
  });

  testWidgets('the plinth board rings with plinth widgets', (tester) async {
    await tester.pumpWidget(const ExchangeApp());
    await tester.tap(find.byKey(const Key('lines-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-plinth')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('phone-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('digit-1-2')));
    await tester.pump();

    expect(find.byType(PlinthPaper), findsWidgets);
    expect(find.byType(PlinthButton), findsWidgets);
    expect(find.text('Calling 2'), findsOneWidget);
    expect(find.text('2 is ringing'), findsOneWidget);
    expect(find.byType(LinePhone), findsNothing);

    await tester.tap(find.byKey(const Key('phone-2')));
    await tester.pump();

    expect(find.text('VOICE'), findsNWidgets(2));
    expect(find.text('In call with 1'), findsOneWidget);
    expect(find.text('1 and 2'), findsOneWidget);
  });
}

Future<void> _open(WidgetTester tester, {required bool bloc}) async {
  await tester.pumpWidget(const ExchangeApp());
  await tester.tap(find.byKey(const Key('lines-3')));
  await tester.pump();
  await tester.tap(find.byKey(Key(bloc ? 'open-bloc' : 'open-riverpod')));
  await tester.pumpAndSettle();
}

Future<void> _openWide(WidgetTester tester) async {
  await tester.pumpWidget(const ExchangeApp());
  await tester.tap(find.byKey(const Key('lines-3')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('open-wide')));
  await tester.pumpAndSettle();
}
