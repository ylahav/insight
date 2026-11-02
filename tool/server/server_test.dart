import 'dart:io';

import 'package:test/test.dart';

import 'hub.dart';
import 'runner.dart';
import 'script.dart';

void main() {
  test('a scenario names start, delay, tap, and see', () {
    final steps = parseScenario('''
# two phones
start switch
start phone 1
record switch
on phone 1
tap hook
delay 150
see Calling 2
''');

    expect(steps[0], isA<Start>());
    expect((steps[1] as Start).instance, '1');
    expect(steps[3], isA<Target>());
    expect((steps[5] as Delay).milliseconds, 150);
    expect((steps[6] as See).text, 'Calling 2');
  });

  test('a scenario path may be absolute', () {
    final file = File('examples/exchange2/scenarios/answered-call.txt');
    final found = scenarioFile(Directory.current, file.absolute.path);
    expect(found.path, file.absolute.path);
  });

  test('delay is a whole number of milliseconds', () {
    expect(() => parseScenario('delay soon'), throwsFormatException);
  });

  test('delay waits and each step goes to the named program', () async {
    final hub = Hub();
    hub.register(
      const Registration(
        role: 'phone',
        name: 'phone',
        instance: '1',
        vmServiceUri: 'http://phone',
      ),
    );
    hub.register(
      const Registration(
        role: 'switch',
        name: 'switch',
        instance: '1',
        vmServiceUri: 'http://switch',
      ),
    );
    final seen = <String>[];
    Future<void> agent(String name, String instance) async {
      while (seen.length < 2) {
        final command = await hub.poll(
          name,
          instance,
          wait: const Duration(milliseconds: 200),
        );
        if (command == null) {
          continue;
        }
        seen.add(
          '${command.command} $name $instance ${command.target ?? command.text}',
        );
        hub.complete(name, instance, command.id, ok: true);
      }
    }

    final agents = Future.wait([agent('phone', '1'), agent('switch', '1')]);
    final started = DateTime.now();
    await runScenario(
      parseScenario('''
on phone 1
tap hook
delay 40
on switch
see 1 and 2
'''),
      hub,
    );
    expect(
      DateTime.now().difference(started).inMilliseconds,
      greaterThanOrEqualTo(40),
    );
    expect(seen, ['tap phone 1 hook', 'see switch 1 1 and 2']);
    await agents;
  });
}
