import 'package:bloc_counter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a tap increments CounterText', (tester) async {
    await tester.pumpWidget(const CounterApp());
    await tester.pump();

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.widgetWithText(CounterText, '1'), findsOneWidget);
  });
}
