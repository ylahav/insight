import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_shelf/src/shelf.dart';
import 'package:riverpod_shelf/src/shelf_page.dart';

void main() {
  setUp(ShelfBuilds.reset);

  testWidgets('a scoped tick rebuilds the clock and not the marks', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ShelfApp()));
    await tester.pump();
    final cards = ShelfBuilds.cards;
    final clock = ShelfBuilds.clock;

    await tester.tap(find.text('Tick'));
    await tester.pump();

    expect(find.text('Second 1'), findsOneWidget);
    expect(ShelfBuilds.clock, greaterThan(clock));
    expect(ShelfBuilds.cards, cards);
    expect(find.byType(ScopedShelf), findsOneWidget);
  });

  testWidgets('a wide tick rebuilds the marks', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShelfApp()));
    await tester.pump();
    await tester.tap(find.text('Wide'));
    await tester.pump();
    final cards = ShelfBuilds.cards;

    await tester.tap(find.text('Tick'));
    await tester.pump();

    expect(ShelfBuilds.cards, greaterThan(cards));
    expect(find.byType(WideShelf), findsOneWidget);
    expect(find.text('Atlas'), findsOneWidget);
  });
}
