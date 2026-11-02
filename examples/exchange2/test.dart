import 'dart:io';

import '../../tool/insight_server.dart' as server;

/// Runs one exchange2 scenario file.
///
/// ```text
/// dart run examples/exchange2/test.dart bloc examples/exchange2/scenarios/answered-call.txt
/// dart run examples/exchange2/test.dart riverpod examples/exchange2/scenarios/answered-call.txt
/// ```
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stdout.writeln(_usage);
    exitCode = 64;
    return;
  }
  if (arguments.first == '--help' || arguments.first == '-h') {
    stdout.writeln(_usage);
    return;
  }
  const profiles = {'bloc', 'riverpod', 'plinth'};
  final profile = arguments.first;
  if (!profiles.contains(profile)) {
    stderr.writeln('The profile is bloc, riverpod, or plinth.');
    stdout.writeln(_usage);
    exitCode = 64;
    return;
  }
  if (arguments.length < 2) {
    stderr.writeln('The scenario file is missing.');
    stdout.writeln(_usage);
    exitCode = 64;
    return;
  }
  await server.main([
    '--scenario',
    arguments[1],
    '--driver',
    profile,
    ...arguments.skip(2),
  ]);
}

const _usage = '''
Runs one scenario. The switch and the phones start, play the file, then stop.

test.ps1 <profile> <scenario>
dart run examples/exchange2/test.dart <profile> <scenario>

profile    bloc, riverpod, or plinth.
           plinth keeps Bloc and draws the desk with Plinth widgets.
scenario   The scenario file.
           Further arguments are passed to the Insight server,
           such as --debug.
''';
