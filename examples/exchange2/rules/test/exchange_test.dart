import 'package:exchange2_rules/exchange.dart';
import 'package:test/test.dart';

void main() {
  test('a registered phone rings until the called phone answers', () {
    final exchange = Exchange.empty().register(1).register(2);
    final connected = exchange.offHook(1).dial(1, 2).offHook(2);

    expect(connected.calls, [(1, 2)]);
    expect(connected.line(1).detail, 'In call with 2');
    expect(connected.line(2).detail, 'In call with 1');
  });

  test('dialing a line that has not registered says it does not exist', () {
    final exchange = Exchange.empty().register(1).offHook(1).dial(1, 2);

    expect(exchange.line(1).status, LineStatus.noSuchLine);
    expect(exchange.line(1).signal, LineSignal.missing);
    expect(exchange.line(1).signalLabel, 'Line does not exist');
    expect(exchange.line(1).attempt, isNull);
    expect(exchange.has(2), isFalse);
  });

  test('a second register leaves the line as it is', () {
    final waiting = Exchange.empty()
        .register(1)
        .register(2)
        .offHook(1)
        .dial(1, 2)
        .offHook(2)
        .register(3)
        .offHook(3)
        .dial(3, 1)
        .dial(3, 0)
        .dial(3, 1);
    final again = waiting.register(3);

    expect(again.line(3).status, LineStatus.waiting);
    expect(identical(again, waiting), isTrue);
  });

  test('two camp-ons and a 01 split by a hang-up', () {
    var exchange = Exchange.empty()
        .register(1)
        .register(2)
        .register(3)
        .register(4)
        .register(5);
    exchange = exchange.offHook(1).dial(1, 2).offHook(2);
    exchange = exchange.offHook(3).dial(3, 1).dial(3, 0).dial(3, 1);
    exchange = exchange.offHook(4).dial(4, 1).dial(4, 0).dial(4, 1);
    expect(exchange.waiting, [
      const CampOn(waiter: 3, target: 1),
      const CampOn(waiter: 4, target: 1),
    ]);

    exchange = exchange.onHook(1);
    expect(exchange.line(3).status, LineStatus.recall);
    expect(exchange.line(4).status, LineStatus.waiting);

    exchange = exchange.onHook(3).offHook(3).offHook(1).onHook(3);
    expect(exchange.line(4).status, LineStatus.recall);
    exchange = exchange.onHook(4).offHook(4).offHook(1);
    expect(exchange.calls, [(1, 4)]);

    exchange = exchange.offHook(5).dial(5, 1).dial(5, 0);
    expect(exchange.line(5).digits, '0');
    expect(exchange.line(5).attempt, 1);
    exchange = exchange.onHook(1);
    expect(exchange.line(1).status, LineStatus.idle);
    exchange = exchange.dial(5, 1);
    expect(exchange.line(5).status, LineStatus.recall);
    expect(exchange.line(1).status, LineStatus.idle);
  });
}
