import 'dart:io';

import 'server/http.dart';
import 'server/hub.dart';
import 'server/launch.dart';
import 'server/runner.dart';
import 'server/script.dart';

/// Reads one exchange2 scenario, starts the programs it names, and sends
/// each step to the program that registered for it.
///
/// ```text
/// dart run tool/insight_server.dart
///     --scenario examples/exchange2/scenarios/answered-call.txt
/// ```
Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options == null) {
    exitCode = 64;
    return;
  }
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  final root = findExchange2Root();
  if (root == null) {
    stderr.writeln(
      'The Insight server needs the Insight repository. '
      'Run it from that checkout.',
    );
    exitCode = 64;
    return;
  }

  late final List<Step> steps;
  try {
    steps = parseScenario(
      scenarioFile(root, options.scenario).readAsStringSync(),
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 64;
    return;
  }

  final hub = Hub();
  final server = await serveHub(hub, options.port);
  final launcher = Exchange2Launcher(
    root: root,
    flutterBin: options.flutter ?? 'flutter',
    device: options.device,
    mode: options.mode,
    driver: options.driver,
    insightServer: 'http://127.0.0.1:${server.port}',
    out: File(options.out ?? 'examples/exchange2/insight-session.json'),
    lines: _phoneLines(steps),
  );
  stdout.writeln('Insight server listening on ${server.port}.');
  final sigint = ProcessSignal.sigint.watch().listen((_) async {
    await launcher.stop();
    exit(130);
  });
  try {
    await runScenario(
      steps,
      hub,
      launch: launcher.launch,
      record: steps.any((step) => step is Record) ? launcher.record : null,
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await sigint.cancel();
    await launcher.stop();
    await server.close(force: true);
  }
}

const _usage = '''
Runs one exchange2 scenario. Programs register here, and each step is sent
to the program the scenario names. delay waits on this server.

insight_server --scenario examples/exchange2/scenarios/answered-call.txt
    [--out examples/exchange2/insight-session.json] [--driver bloc]
    [--device windows] [--port 8790] [--profile]

From a checkout: dart run tool/insight_server.dart
    --scenario examples/exchange2/scenarios/answered-call.txt

--scenario   Step file. start, record, on, tap, see, and delay.
--out        Session file, when the scenario says record.
--driver     bloc, riverpod, or plinth, for the switch. Default bloc.
--device     flutter device id. Default windows.
--flutter    Flutter tool to run. Default is flutter on PATH.
--port       This server. Default 8790.
--profile    Profile mode. This is the default.
--debug      Debug mode.
''';

int? _phoneLines(List<Step> steps) {
  var highest = 0;
  for (final step in steps) {
    if (step is Start && step.name == 'phone') {
      final number = int.tryParse(step.instance) ?? 0;
      if (number > highest) {
        highest = number;
      }
    }
  }
  if (highest == 0) {
    return null;
  }
  return highest;
}

class _Options {
  _Options({
    required this.scenario,
    required this.device,
    required this.mode,
    required this.driver,
    required this.port,
    required this.help,
    this.out,
    this.flutter,
  });

  final String scenario;
  final String? out;
  final String? flutter;
  final String device;
  final String mode;
  final String driver;
  final int port;
  final bool help;

  static _Options? parse(List<String> arguments) {
    String? scenario;
    String? out;
    String? flutterBin;
    var device = 'windows';
    var mode = 'profile';
    var driver = 'bloc';
    var port = 8790;
    var help = false;

    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      String? next() {
        if (i + 1 >= arguments.length) {
          return null;
        }
        return arguments[++i];
      }

      switch (argument) {
        case '--help' || '-h':
          help = true;
        case '--profile':
          mode = 'profile';
        case '--debug':
          mode = 'debug';
        case '--scenario':
          final value = next();
          if (value == null) {
            stderr.writeln('--scenario needs a file.');
            return null;
          }
          scenario = value;
        case '--out':
          final value = next();
          if (value == null) {
            stderr.writeln('--out needs a path.');
            return null;
          }
          out = value;
        case '--driver':
          final value = next();
          if (value != 'bloc' && value != 'riverpod' && value != 'plinth') {
            stderr.writeln('--driver is bloc, riverpod, or plinth.');
            return null;
          }
          driver = value!;
        case '--device':
          final value = next();
          if (value == null) {
            stderr.writeln('--device needs an id.');
            return null;
          }
          device = value;
        case '--flutter':
          final value = next();
          if (value == null) {
            stderr.writeln('--flutter needs a path to the Flutter tool.');
            return null;
          }
          flutterBin = value;
        case '--port':
          final value = next();
          final parsed = value == null ? null : int.tryParse(value);
          if (parsed == null || parsed < 1) {
            stderr.writeln('--port needs a whole number.');
            return null;
          }
          port = parsed;
        default:
          stderr.writeln('Unknown argument $argument.');
          stderr.writeln(_usage);
          return null;
      }
    }
    if (help) {
      return _Options(
        scenario: '',
        device: device,
        mode: mode,
        driver: driver,
        port: port,
        help: true,
      );
    }
    if (scenario == null) {
      stderr.writeln('--scenario needs a file.');
      stderr.writeln(_usage);
      return null;
    }
    return _Options(
      scenario: scenario,
      out: out,
      flutter: flutterBin,
      device: device,
      mode: mode,
      driver: driver,
      port: port,
      help: false,
    );
  }
}
