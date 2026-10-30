import 'package:flutter_test/flutter_test.dart';
import 'package:insight/insight.dart';

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

  test('traceFuture posts one completed span', () async {
    await Insight.traceFuture<int>(Future<int>.value(1), name: 'complete');

    expect(messages, hasLength(2));
    expect(messages[0]['kind'], 'async.start');
    expect(messages[0]['name'], 'complete');
    expect(messages[1]['kind'], 'async.end');
    expect(messages[1]['status'], 'completed');
    expect(messages[1]['error'], isNull);
    expect(messages[1]['spanId'], messages[0]['spanId']);
    expect(messages[1].containsKey('stackTrace'), isFalse);
  });

  test('a throwing future posts an error and rethrows', () async {
    await expectLater(
      Insight.traceFuture<void>(Future<void>.error(StateError('failed'))),
      throwsStateError,
    );

    expect(messages.last['status'], 'error');
    expect(messages.last['error'], 'Bad state: failed');
    expect((messages.last['error'] as String).length, lessThanOrEqualTo(200));
    expect(messages.last['name'], isNull);
  });

  test('state values stay off unless the app opts in', () {
    Insight.stateChanged(
      adapter: 'bloc',
      name: 'CounterCubit',
      event: null,
      summary: 'int',
      value: (previous: '0', next: '1'),
    );
    expect(messages.single['value'], isNull);

    Insight.captureStateValues = true;
    final timeUs = Insight.stateChanged(
      adapter: 'bloc',
      name: 'CounterCubit',
      event: null,
      summary: 'int',
      value: (previous: '0', next: '1'),
    );
    Insight.reviseState(
      timeUs: timeUs,
      adapter: 'bloc',
      name: 'CounterCubit',
      event: null,
      summary: 'int',
      value: (previous: '1', next: '2'),
    );

    expect(messages[1]['value'], {'previous': '0', 'next': '1'});
    expect(messages[2]['timeUs'], timeUs);
    expect(messages[2]['value'], {'previous': '1', 'next': '2'});
  });

  test('a stream span closes when the stream finishes', () async {
    await Insight.traceStream<int>(Stream<int>.fromIterable([1])).drain<void>();

    expect(messages.first['kind'], 'async.start');
    expect(messages.first['name'], 'stream');
    expect(messages.last['status'], 'completed');
  });
}
