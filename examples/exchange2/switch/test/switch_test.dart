import 'dart:io';

import 'package:exchange2_agent/switch_client.dart';
import 'package:exchange2_rules/exchange.dart';
import 'package:exchange2_switch/src/actions.dart';
import 'package:exchange2_switch/src/http.dart';
import 'package:exchange2_switch/src/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  test('two phones camp on one line, and 01 can be split by a hang-up', () async {
    final actions = SwitchActions(store: MemorySwitchStore());
    for (var number = 1; number <= 5; number++) {
      await actions.register(number);
    }
    await actions.hook(1, off: true);
    await actions.digit(1, 2);
    await actions.hook(2, off: true);
    expect(actions.exchange.calls, [(1, 2)]);
    expect(actions.log.map((entry) => entry.detail), contains('1 digit 2'));

    await actions.hook(3, off: true);
    await actions.digit(3, 1);
    await actions.digit(3, 0);
    await actions.digit(3, 1);
    await actions.hook(4, off: true);
    await actions.digit(4, 1);
    await actions.digit(4, 0);
    await actions.digit(4, 1);
    expect(actions.exchange.waiting, [
      const CampOn(waiter: 3, target: 1),
      const CampOn(waiter: 4, target: 1),
    ]);
    expect(
      actions.log.map((entry) => entry.detail),
      containsAll(['3 waiting for 1', '4 waiting for 1']),
    );

    await actions.hook(1, off: false);
    expect(actions.exchange.line(3).status, LineStatus.recall);
    expect(actions.log.last.detail, '3 ringing');
    expect(actions.exchange.line(4).status, LineStatus.waiting);
  });

  test('a phone receives the snapshot the switch stores', () async {
    final actions = SwitchActions(store: MemorySwitchStore());
    final server = await shelf_io.serve(
      switchHandler(actions),
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(server.close);
    final client = SwitchClient(
      Uri.parse('http://127.0.0.1:${server.port}'),
    );

    final registered = await client.register(1);
    expect(registered.hook, 'on');
    final off = await client.hook(1, off: true);
    expect(off.hook, 'off');
    expect(off.digits, ['1', '0']);

    await client.register(2);
    final calling = await client.digit(1, '2');
    expect(calling.detail, 'Calling 2');

    expect(
      () => client.digit(2, '1'),
      throwsA(isA<SwitchException>().having((error) => error.status, 'status', 409)),
    );
  });
}
