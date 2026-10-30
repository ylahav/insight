import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Starts an app, reads the VM Service address from `flutter run`, and
/// records one session with `insight_cli`.
///
/// From the repository root:
///
/// ```text
/// dart run tool/record.dart --app examples/desk --duration 15
/// ```
///
/// The app window opens first. Press Enter, then do one action while the
/// recording runs. Leave the Insight tab closed.
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

  final root = _repositoryRoot();
  final appDir = Directory.fromUri(root.uri.resolve(options.app));
  if (!File.fromUri(appDir.uri.resolve('pubspec.yaml')).existsSync()) {
    stderr.writeln('No pubspec.yaml in ${appDir.path}.');
    exitCode = 64;
    return;
  }
  final outFile = File(options.out ?? '${appDir.path}/insight-session.json');
  final flutterArgs = <String>[
    'run',
    '-d',
    options.device,
    '--${options.mode}',
    if (options.device == 'windows') '--no-enable-impeller',
  ];

  stdout.writeln(
    'Starting ${options.app} (${options.mode}) on ${options.device}.',
  );
  final flutter = await _start(
    Platform.isWindows ? 'cmd' : 'flutter',
    Platform.isWindows ? ['/c', 'flutter', ...flutterArgs] : flutterArgs,
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
    uri = await uriReady.future.timeout(const Duration(minutes: 3));
  } on Object catch (error) {
    stderr.writeln(error);
    await _stop(flutter);
    exitCode = 1;
    return;
  }

  stdout.writeln('');
  stdout.writeln('VM Service: $uri');
  if (!options.now) {
    stdout.writeln(
      'Press Enter to record for ${options.duration} seconds. '
      'Do one action in the app window while it records. '
      'Leave the Insight tab closed.',
    );
    stdin.readLineSync();
  } else {
    stdout.writeln(
      'Recording for ${options.duration} seconds. '
      'Do one action in the app window now.',
    );
  }

  final cliArgs = <String>[
    'run',
    'insight_cli',
    '--uri',
    uri,
    '--duration',
    '${options.duration}',
    '--out',
    outFile.absolute.path,
    if (!options.rebuilds) '--no-rebuilds',
  ];
  final cli = await Process.start(
    'dart',
    cliArgs,
    workingDirectory: '${root.path}/packages/insight_cli',
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await cli.exitCode;
  await _stop(flutter);
  stdout.writeln('Stopped ${options.app}.');
  exitCode = code;
}

final _vmServiceUri = RegExp(
  r'A Dart VM Service on \S+ is available at:\s*(http://\S+)',
);

const _usage = '''
Starts an app and records one Insight session.

dart run tool/record.dart [--app examples/desk] [--duration 15]
    [--out path] [--device windows] [--profile] [--now] [--no-rebuilds]

--app        App directory, relative to the repository root.
--duration   Seconds to record. Default 15.
--out        Session file. Default is insight-session.json in the app directory.
--device     flutter device id. Default windows.
--profile    Profile mode. The default is debug.
--now        Start recording as soon as the app prints its address.
--no-rebuilds  Leave user-widget rebuilds off.
''';

class _Options {
  _Options({
    required this.app,
    required this.duration,
    required this.device,
    required this.mode,
    required this.now,
    required this.rebuilds,
    required this.help,
    this.out,
  });

  final String app;
  final int duration;
  final String? out;
  final String device;
  final String mode;
  final bool now;
  final bool rebuilds;
  final bool help;

  static _Options? parse(List<String> arguments) {
    var app = 'examples/desk';
    var duration = 15;
    String? out;
    var device = 'windows';
    var mode = 'debug';
    var now = false;
    var rebuilds = true;
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
        case '--now':
          now = true;
        case '--profile':
          mode = 'profile';
        case '--debug':
          mode = 'debug';
        case '--no-rebuilds':
          rebuilds = false;
        case '--app':
          final value = next();
          if (value == null) {
            stderr.writeln('--app needs a directory.');
            return null;
          }
          app = value;
        case '--duration':
          final value = next();
          final seconds = value == null ? null : int.tryParse(value);
          if (seconds == null || seconds < 1) {
            stderr.writeln(
              '--duration must be a whole number of seconds, at least 1.',
            );
            return null;
          }
          duration = seconds;
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
        default:
          stderr.writeln('Unknown argument $argument.');
          stderr.writeln(_usage);
          return null;
      }
    }
    return _Options(
      app: app,
      duration: duration,
      out: out,
      device: device,
      mode: mode,
      now: now,
      rebuilds: rebuilds,
      help: help,
    );
  }
}

Directory _repositoryRoot() {
  final current = Directory.current;
  if (Directory.fromUri(current.uri.resolve('packages/insight_cli'))
      .existsSync()) {
    return current;
  }
  return File(Platform.script.toFilePath()).parent.parent;
}

Stream<String> _lines(Stream<List<int>> stream) {
  return stream.transform(utf8.decoder).transform(const LineSplitter());
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
