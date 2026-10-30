import 'package:desk/src/board.dart';
import 'package:desk/src/desk_page.dart';
import 'package:desk/src/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DeskBuilds.reset);

  testWidgets('load shows the six tickets', (tester) async {
    await tester.pumpWidget(const DeskApp());
    await _load(tester);

    expect(find.byType(TicketCard), findsNWidgets(6));
    expect(find.text('North window'), findsOneWidget);
    expect(find.text('Load the board.'), findsNothing);
  });

  testWidgets('a scoped tick rebuilds the clock and not the cards', (
    tester,
  ) async {
    await tester.pumpWidget(const DeskApp());
    await _load(tester);
    final cards = DeskBuilds.cards;
    final clock = DeskBuilds.clock;

    await tester.tap(find.text('Tick'));
    await tester.pump();

    expect(find.text('Second 1'), findsOneWidget);
    expect(DeskBuilds.clock, greaterThan(clock));
    expect(DeskBuilds.cards, cards);
  });

  testWidgets('a wide tick rebuilds the cards', (tester) async {
    await tester.pumpWidget(const DeskApp());
    await _load(tester);
    await tester.tap(find.text('Wide'));
    await tester.pump();
    final cards = DeskBuilds.cards;

    await tester.tap(find.text('Tick'));
    await tester.pump();

    expect(DeskBuilds.cards, greaterThan(cards));
    expect(find.byType(WideBoard), findsOneWidget);
  });

  testWidgets('open filters to the tickets that are not done', (tester) async {
    await tester.pumpWidget(const DeskApp());
    await _load(tester);

    await tester.tap(
      find.descendant(of: find.byType(FilterBar), matching: find.text('Open')),
    );
    await tester.pump();

    expect(find.text('North window'), findsOneWidget);
    expect(find.text('Roof leak'), findsNothing);
    expect(find.byType(TicketCard), findsNWidgets(4));
  });

  testWidgets('selecting a ticket fills the detail and one card', (
    tester,
  ) async {
    await tester.pumpWidget(const DeskApp());
    await _load(tester);
    final cards = DeskBuilds.cards;

    await tester.tap(find.text('North window'));
    await tester.pump();

    expect(find.widgetWithText(TicketDetail, 'North window'), findsOneWidget);
    expect(DeskBuilds.cards, cards + 1);
  });

  testWidgets('a failed load shows the failure line', (tester) async {
    await tester.pumpWidget(const DeskApp());

    await tester.tap(find.text('Fail load'));
    await tester.pump();
    await tester.pump(boardPause);
    await tester.pump();

    expect(find.text('The load failed.'), findsOneWidget);
    expect(find.byType(TicketCard), findsNothing);
  });
}

Future<void> _load(WidgetTester tester) async {
  await tester.tap(find.text('Load'));
  await tester.pump();
  await tester.pump(boardPause);
  await tester.pump();
}
