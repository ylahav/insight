import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:insight_collector/insight_collector.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'repository.dart';

/// Plays one exchange scenario from a file and records it.
///
/// The app stays on the setup page until the collector is listening. Then
/// `ext.flutter.exchange.play` runs the file. Each line is `tap <key>` or
/// `see <text>`. `tap open` follows `--board`. Run the same file twice with a
/// different `--board` and read the files with `tool/compare.dart`.
///
/// ```text
/// dart run tool/play.dart --board bloc --out examples/exchange/1.json
/// dart run tool/play.dart --board plinth --out examples/exchange/2.json
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

  final root = findRepository();
  if (root == null) {
    stderr.writeln(
      'play needs the Insight repository. '
      'It runs examples/exchange from that checkout.',
    );
    exitCode = 64;
    return;
  }
  final scenario = _scenarioFile(root, options.scenario);
  if (!scenario.existsSync()) {
    stderr.writeln('No scenario file at ${scenario.path}.');
    exitCode = 64;
    return;
  }
  final script = await scenario.readAsString();
  final appDir = Directory.fromUri(root.uri.resolve('examples/exchange'));
  final outFile = File(options.out);
  final flutterBin = options.flutter ?? 'flutter';
  final disableImpeller =
      options.device == 'windows' && await _supportsNoImpeller(flutterBin);
  final flutterArgs = <String>[
    'run',
    '-d',
    options.device,
    '--${options.mode}',
    if (disableImpeller) '--no-enable-impeller',
    '--dart-define=EXCHANGE_PLAY=true',
    '--dart-define=EXCHANGE_BOARD=${options.board}',
  ];

  stdout.writeln(
    'Starting the exchange (${options.mode}, ${options.board}) '
    'on ${options.device}.',
  );
  final flutter = await _start(
    Platform.isWindows ? 'cmd' : flutterBin,
    Platform.isWindows ? ['/c', flutterBin, ...flutterArgs] : flutterArgs,
    appDir.path,
  );

  final uriReady = Completer<String>();
  void onLine(String line) {
    stdout.writeln(line);
    if (uriReady.isCompleted) {
      return;
    }
    final uri = _vmServiceUri.firstMatch(line)?.group(1);
    if (uri != null) {
      uriReady.complete(uri);
    } else if (line.contains('Lost connection to device')) {
      uriReady.completeError(
        StateError('The app closed before a VM Service address was printed.'),
      );
    }
  }

  _lines(flutter.stdout).listen(onLine);
  _lines(flutter.stderr).listen(onLine);
  unawaited(
    flutter.exitCode.then((code) {
      if (!uriReady.isCompleted) {
        uriReady.completeError(
          StateError('flutter run exited ($code) before printing an address.'),
        );
      }
    }),
  );

  String uri;
  try {
    uri = await uriReady.future.timeout(const Duration(minutes: 5));
  } on Object catch (error) {
    stderr.writeln(error);
    await _stop(flutter);
    exitCode = 1;
    return;
  }

  stdout.writeln('VM Service: $uri');
  VmService? service;
  try {
    service = await vmServiceConnectUri(
      convertToWebSocketUrl(serviceProtocolUrl: Uri.parse(uri)).toString(),
    );
    final isolateId = await _isolateWithPlay(service);
    final handle = InsightSessionHandle(service: service, rebuilds: true);
    await handle.start();
    stdout.writeln('Playing ${scenario.path}.');
    await service.callServiceExtension(
      'ext.flutter.exchange.play',
      isolateId: isolateId,
      args: {'script': script},
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    await handle.stop();
    final session = handle.snapshot ?? handle.builder!.build();
    session['play'] = {
      'board': options.board,
      'scenarioPath': options.scenario,
      'scenario': script,
      ...await _git(root, options.scenario),
    };
    await outFile.parent.create(recursive: true);
    await outFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(session)}\n',
    );
    final events = session['events'] as List<Object?>;
    final frames = events.where((event) {
      return event is Map && event['type'] == 'frame';
    }).length;
    final rebuilds = events.where((event) {
      return event is Map && event['type'] == 'widget.rebuild';
    }).length;
    final states = events.where((event) {
      return event is Map && event['type'] == 'state.changed';
    }).length;
    stdout.writeln(
      'Wrote ${outFile.path} '
      '($frames frames, $rebuilds rebuilds, $states state changes).',
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await service?.dispose();
    await _stop(flutter);
    stdout.writeln('Stopped the exchange.');
  }
}

final _vmServiceUri = RegExp(
  r'A Dart VM Service on \S+ is available at:\s*(http://\S+)',
);

const _usage = '''
Plays one exchange scenario from a file and records it.

play --out examples/exchange/1.json
    [--scenario examples/exchange/ring.txt] [--board bloc]
    [--device windows] [--flutter path] [--debug]

From a checkout: dart run tool/play.dart --out examples/exchange/1.json

--out        Session file. Required.
--scenario   Step file. Default examples/exchange/ring.txt.
             Each line is "tap <key>" or "see <text>". "tap open" follows --board.
--board      bloc, riverpod, or plinth. Default bloc.
--device     flutter device id. Default windows.
--flutter    Flutter tool to run. Default is flutter on PATH.
--profile    Profile mode. This is the default.
--debug      Debug mode.

Run the same file twice with a different --board, then
compare --left <first> --right <second>.
Leave the Insight tab closed.
''';

const _boards = {'bloc', 'riverpod', 'plinth'};

class _Options {
  _Options({
    required this.board,
    required this.scenario,
    required this.out,
    required this.device,
    required this.mode,
    required this.help,
    this.flutter,
  });

  final String board;
  final String scenario;
  final String out;
  final String? flutter;
  final String device;
  final String mode;
  final bool help;

  static _Options? parse(List<String> arguments) {
    var board = 'bloc';
    var scenario = 'examples/exchange/ring.txt';
    String? out;
    String? flutterBin;
    var device = 'windows';
    var mode = 'profile';
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
        case '--board':
          final value = next();
          if (value == null || !_boards.contains(value)) {
            stderr.writeln('--board must be bloc, riverpod, or plinth.');
            return null;
          }
          board = value;
        case '--scenario':
          final value = next();
          if (value == null) {
            stderr.writeln('--scenario needs a path.');
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
        default:
          stderr.writeln('Unknown argument $argument.');
          stderr.writeln(_usage);
          return null;
      }
    }
    if (help) {
      return _Options(
        board: board,
        scenario: scenario,
        out: out ?? '',
        flutter: flutterBin,
        device: device,
        mode: mode,
        help: true,
      );
    }
    if (out == null) {
      stderr.writeln('--out needs a path.');
      stderr.writeln(_usage);
      return null;
    }
    return _Options(
      board: board,
      scenario: scenario,
      out: out,
      flutter: flutterBin,
      device: device,
      mode: mode,
      help: false,
    );
  }
}

File _scenarioFile(Directory root, String path) {
  final direct = File(path);
  if (direct.isAbsolute || direct.existsSync()) {
    return direct;
  }
  return File.fromUri(root.uri.resolve(path));
}

Future<Map<String, Object?>> _git(Directory root, String scenarioPath) async {
  Future<String> read(List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: root.path,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      return '';
    }
    return (result.stdout as String).trim();
  }

  final commit = await read(['rev-parse', 'HEAD']);
  final branch = await read(['rev-parse', '--abbrev-ref', 'HEAD']);
  final subject = await read(['log', '-1', '--format=%s']);
  final status = await read(['status', '--porcelain', '--', scenarioPath]);
  return {
    if (commit.isNotEmpty) 'commit': commit,
    if (branch.isNotEmpty) 'branch': branch,
    if (subject.isNotEmpty) 'subject': subject,
    'scenarioDirty': status.isNotEmpty,
  };
}

Future<String> _isolateWithPlay(VmService service) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final vm = await service.getVM();
    for (final ref in vm.isolates ?? const <IsolateRef>[]) {
      final id = ref.id;
      if (id == null) {
        continue;
      }
      final isolate = await service.getIsolate(id);
      final rpcs = isolate.extensionRPCs ?? const <String>[];
      if (rpcs.contains('ext.flutter.exchange.play')) {
        return id;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError(
    'ext.flutter.exchange.play was not registered. '
    'The exchange was started without the play flag.',
  );
}

Stream<String> _lines(Stream<List<int>> stream) {
  return stream.transform(utf8.decoder).transform(const LineSplitter());
}

Future<bool> _supportsNoImpeller(String flutterBin) async {
  final result = await Process.run(
    Platform.isWindows ? 'cmd' : flutterBin,
    Platform.isWindows ? ['/c', flutterBin, 'run', '-h'] : ['run', '-h'],
  );
  return '${result.stdout}\n${result.stderr}'.contains('--no-enable-impeller');
}

Future<Process> _start(
  String executable,
  List<String> arguments,
  String workingDirectory,
) {
  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
}

Future<void> _stop(Process process) async {
  if (Platform.isWindows) {
    await Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
    return;
  }
  process.kill();
}
