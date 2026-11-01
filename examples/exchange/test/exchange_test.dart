import 'package:exchange/src/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a free line rings until the called phone answers', () {
    final opened = Exchange.opened(3);
    final dialing = opened.offHook(1);
    final ringing = dialing.dial(1, 2);

    expect(ringing.line(1).status, LineStatus.calling);
    expect(ringing.line(2).status, LineStatus.ringing);
    expect(ringing.line(2).peer, 1);
    expect(ringing.rings, [(1, 2)]);
    expect(ringing.calls, isEmpty);

    final connected = ringing.offHook(2);
    expect(connected.line(1).status, LineStatus.inCall);
    expect(connected.line(1).peer, 2);
    expect(connected.line(2).peer, 1);
    expect(connected.calls, [(1, 2)]);
    expect(connected.rings, isEmpty);

    final third = connected.offHook(3).dial(3, 1);
    expect(third.line(3).status, LineStatus.busyTone);
    expect(third.line(3).attempt, 1);
    expect(third.calls, [(1, 2)]);
  });

  test('hook on from the called phone stops the ring', () {
    final ringing = Exchange.opened(3).offHook(1).dial(1, 2);
    final cleared = ringing.onHook(2);

    expect(cleared.line(1).status, LineStatus.idle);
    expect(cleared.line(2).status, LineStatus.idle);
    expect(cleared.rings, isEmpty);
  });

  test('a phone cannot dial itself or a missing line', () {
    final exchange = Exchange.opened(3).offHook(1);
    expect(exchange.dial(1, 1).line(1).attempt, isNull);
    expect(exchange.dial(1, 1).line(1).status, LineStatus.busyTone);
    expect(exchange.dial(1, 8).line(1).attempt, isNull);
  });

  test('01 waits, and the caller rings before the freed line', () {
    final busy = Exchange.opened(4).offHook(1).dial(1, 2).offHook(3).dial(3, 1);
    final waiting = busy.dial(3, 0).dial(3, 1);
    expect(waiting.line(3).status, LineStatus.waiting);
    expect(waiting.line(3).waitingFor, 1);
    expect(waiting.waiting.single.target, 1);

    final alsoWaiting = waiting.offHook(4).dial(4, 1).dial(4, 0).dial(4, 1);
    final released = alsoWaiting.onHook(1);

    expect(released.line(1).status, LineStatus.idle);
    expect(released.line(3).status, LineStatus.recall);
    expect(released.line(3).hookOn, isFalse);
    expect(released.line(3).signal, LineSignal.ringing);
    expect(released.line(3).peer, 1);
    expect(released.rings, isEmpty);
    expect(released.line(4).status, LineStatus.waiting);

    final held = released.offHook(2).dial(2, 1);
    expect(held.line(2).status, LineStatus.busyTone);
    expect(held.line(1).status, LineStatus.idle);
    expect(held.line(3).status, LineStatus.recall);

    final closed = held.onHook(2).onHook(3);
    expect(closed.line(3).status, LineStatus.recallRing);
    expect(closed.line(3).hookOn, isTrue);
    expect(closed.line(1).status, LineStatus.idle);

    final ringing = closed.offHook(3);
    expect(ringing.line(3).status, LineStatus.calling);
    expect(ringing.line(1).status, LineStatus.ringing);
    expect(ringing.rings, [(3, 1)]);
    expect(ringing.line(4).status, LineStatus.waiting);
  });

  test('calling a waiting line keeps the camp-on', () {
    final waiting = Exchange.opened(4)
        .offHook(1)
        .dial(1, 2)
        .offHook(2)
        .offHook(3)
        .dial(3, 1)
        .dial(3, 0)
        .dial(3, 1);
    expect(waiting.line(3).status, LineStatus.waiting);

    final ringing = waiting.offHook(4).dial(4, 3);

    expect(ringing.line(4).status, LineStatus.calling);
    expect(ringing.line(3).status, LineStatus.ringing);
    expect(ringing.line(3).peer, 4);
    expect(ringing.line(3).waitingFor, 1);
    expect(ringing.line(3).detail, 'Waiting for 1');
    expect(ringing.rings, [(4, 3)]);
    expect(ringing.waiting, [const CampOn(waiter: 3, target: 1)]);
    expect(ringing.calls, [(1, 2)]);

    final back = ringing.onHook(4);
    expect(back.line(4).status, LineStatus.idle);
    expect(back.line(3).status, LineStatus.waiting);
    expect(back.line(3).waitingFor, 1);
    expect(back.waiting, [const CampOn(waiter: 3, target: 1)]);

    final again = back.offHook(4).dial(4, 3).offHook(3);
    expect(again.line(3).status, LineStatus.inCall);
    expect(again.line(3).waitingFor, 1);
    expect(again.line(3).detail, 'In call with 4, waiting for 1');
    expect(again.waiting, [const CampOn(waiter: 3, target: 1)]);

    final freed = again.onHook(1);
    expect(freed.line(1).status, LineStatus.idle);
    expect(freed.line(3).status, LineStatus.inCall);
    expect(freed.waiting, [const CampOn(waiter: 3, target: 1)]);

    final recalled = freed.onHook(4);
    expect(recalled.line(4).status, LineStatus.idle);
    expect(recalled.line(3).status, LineStatus.recall);
    expect(recalled.line(3).peer, 1);
    expect(recalled.waiting, isEmpty);
  });

  test('hooking on cancels a camp-on request', () {
    final waiting = Exchange.opened(
      3,
    ).offHook(1).dial(1, 2).offHook(3).dial(3, 2).dial(3, 0).dial(3, 1);
    final cancelled = waiting.onHook(3);
    expect(cancelled.waiting, isEmpty);
    expect(cancelled.line(3).status, LineStatus.idle);
    expect(cancelled.onHook(1).calls, isEmpty);
  });

  test('01 after dialing your own number does not ring line 1', () {
    final exchange = Exchange.opened(
      5,
    ).offHook(5).dial(5, 5).dial(5, 0).dial(5, 1);

    expect(exchange.line(5).status, LineStatus.busyTone);
    expect(exchange.line(5).attempt, isNull);
    expect(exchange.line(1).status, LineStatus.idle);
    expect(exchange.rings, isEmpty);
    expect(exchange.waiting, isEmpty);
  });

  test('01 with no busy line records nothing', () {
    final exchange = Exchange.opened(3).offHook(1).dial(1, 0).dial(1, 1);
    expect(exchange.line(1).status, LineStatus.busyTone);
    expect(exchange.line(1).attempt, isNull);
    expect(exchange.waiting, isEmpty);
  });

  test('after 0, dialing a line that just freed connects', () {
    final hearing = Exchange.opened(
      3,
    ).offHook(1).dial(1, 2).offHook(3).dial(3, 2).dial(3, 0);
    expect(hearing.line(3).digits, '0');

    final freed = hearing.onHook(2);
    final ringing = freed.dial(3, 2);

    expect(ringing.line(3).status, LineStatus.calling);
    expect(ringing.line(2).status, LineStatus.ringing);
    expect(ringing.rings, [(3, 2)]);

    final connected = ringing.offHook(2);
    expect(connected.line(3).peer, 2);
    expect(connected.line(2).peer, 3);
    expect(connected.calls, [(2, 3)]);
  });

  test('01 rings the caller first when that line is already idle', () {
    final hearing = Exchange.opened(
      3,
    ).offHook(1).dial(1, 2).offHook(3).dial(3, 1).dial(3, 0);
    final freed = hearing.onHook(2);
    final recall = freed.dial(3, 1);

    expect(recall.line(3).status, LineStatus.recall);
    expect(recall.line(3).signal, LineSignal.ringing);
    expect(recall.line(1).status, LineStatus.idle);
    expect(recall.rings, isEmpty);

    final closed = recall.onHook(3);
    expect(closed.line(3).hookOn, isTrue);
    expect(closed.line(1).status, LineStatus.idle);

    final ringing = closed.offHook(3);
    expect(ringing.line(1).status, LineStatus.ringing);
    expect(ringing.rings, [(3, 1)]);
  });

  test('the phone shows hook and one signal', () {
    final idle = Exchange.opened(3).line(1);
    expect(idle.hookLabel, 'Hook on');
    expect(idle.signal, LineSignal.none);

    final dialing = Exchange.opened(3).offHook(1).line(1);
    expect(dialing.hookLabel, 'Hook off');
    expect(dialing.signal, LineSignal.line);

    final ringing = Exchange.opened(3).offHook(1).dial(1, 2);
    expect(ringing.line(2).hookLabel, 'Hook on');
    expect(ringing.line(2).signal, LineSignal.ringing);
    expect(ringing.line(1).signal, LineSignal.ringing);

    final busy = ringing.offHook(3).dial(3, 2).line(3);
    expect(busy.hookLabel, 'Hook off');
    expect(busy.signal, LineSignal.busy);

    final voice = ringing.offHook(2).line(1);
    expect(voice.hookLabel, 'Hook off');
    expect(voice.signal, LineSignal.voice);
  });

  test('the line count stays between 3 and 9', () {
    expect(() => Exchange.opened(2), throwsArgumentError);
    expect(() => Exchange.opened(10), throwsArgumentError);
  });
}
