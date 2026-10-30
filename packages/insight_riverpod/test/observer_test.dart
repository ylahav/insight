import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/insight.dart';
import 'package:insight_riverpod/insight_riverpod.dart';

void main() {
  final messages = <Map<String, Object?>>[];

  setUp(() {
    messages.clear();
    Insight.captureStateValues = false;
    Insight.debugEventSink = messages.add;
  });

  tearDown(() {
    Insight.captureStateValues = false;
    Insight.debugEventSink = null;
  });

  test('a notifier update has a null event and a null value', () {
    final container = ProviderContainer(
      observers: const [InsightRiverpodObserver()],
    );
    addTearDown(container.dispose);

    container.read(countProvider);
    expect(messages, isEmpty);

    container.read(countProvider.notifier).increment();

    expect(messages, hasLength(1));
    expect(messages.single['kind'], 'state.changed');
    expect(messages.single['adapter'], 'riverpod');
    expect(messages.single['name'], countProvider.runtimeType.toString());
    expect(messages.single['event'], isNull);
    expect(messages.single['summary'], 'int');
    expect(messages.single['value'], isNull);
  });

  test('a provider name is used when one is set', () {
    final container = ProviderContainer(
      observers: const [InsightRiverpodObserver()],
    );
    addTearDown(container.dispose);

    container.read(namedCountProvider.notifier).increment();

    expect(messages.single['name'], 'count');
  });

  test('opt-in values are previous and next strings', () {
    Insight.captureStateValues = true;
    final container = ProviderContainer(
      observers: const [InsightRiverpodObserver()],
    );
    addTearDown(container.dispose);

    container.read(countProvider.notifier).increment();

    expect(messages.single['value'], {'previous': '0', 'next': '1'});
  });
}

class Count extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final countProvider = NotifierProvider<Count, int>(Count.new);

final namedCountProvider = NotifierProvider<Count, int>(
  Count.new,
  name: 'count',
);
