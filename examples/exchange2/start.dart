import 'dart:io';

import '../../tool/server/launch.dart';
import '../../tool/server/script.dart';

/// Starts the switch and one phone for each line, and leaves them up.
///
/// ```text
/// dart run examples/exchange2/start.dart
/// dart run examples/exchange2/start.dart riverpod 5
/// dart run examples/exchange2/start.dart plinth
/// ```
///
/// The first argument is bloc, riverpod, or plinth. The default is bloc.
/// The line count is 1 to 9. The default is 3. Press Enter to stop.
Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }
  final request = _request(arguments);
  if (request == null) {
    exitCode = 64;
    return;
  }
  final lines = request.lines;
  final profile = request.profile;
  final root = findExchange2Root();
  if (root == null) {
    stderr.writeln('Start this from the Insight repository.');
    exitCode = 64;
    return;
  }

  final launcher = Exchange2Launcher(
    root: root,
    flutterBin: 'flutter',
    device: 'windows',
    mode: 'profile',
    driver: profile,
    insightServer: 'http://127.0.0.1:8790',
    out: File('examples/exchange2/insight-session.json'),
    lines: lines,
  );
  final sigint = ProcessSignal.sigint.watch().listen((_) async {
    await launcher.stop();
    exit(130);
  });
  try {
    stdout.writeln('Starting the $profile switch and $lines phones.');
    await launcher.launch(const Start('switch', '1'));
    for (var number = 1; number <= lines; number++) {
      await launcher.launch(Start('phone', '$number'));
    }
    stdout.writeln('The desk and $lines phones are up. Press Enter to stop.');
    stdin.readLineSync();
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await sigint.cancel();
    await launcher.stop();
  }
}

({String profile, int lines})? _request(List<String> arguments) {
  if (arguments.isEmpty) {
    return (profile: 'bloc', lines: 3);
  }
  if (arguments.length > 2) {
    stderr.writeln(_usage);
    return null;
  }
  final profile = arguments.first;
  if (!_profiles.contains(profile)) {
    stderr.writeln('The profile is bloc, riverpod, or plinth.');
    return null;
  }
  if (arguments.length == 1) {
    return (profile: profile, lines: 3);
  }
  final lines = int.tryParse(arguments[1]);
  if (lines == null || lines < 1 || lines > 9) {
    stderr.writeln('The line count is a whole number from 1 to 9.');
    return null;
  }
  return (profile: profile, lines: lines);
}

const _profiles = {'bloc', 'riverpod', 'plinth'};

const _usage = '''
Starts the switch and one phone for each line. They stay up until Enter.

start.ps1 [profile] [lines]
dart run examples/exchange2/start.dart [profile] [lines]

profile   bloc, riverpod, or plinth. Default bloc.
          plinth keeps Bloc and draws the desk with Plinth widgets.
lines     How many phones. 1 to 9. Default 3.
''';
