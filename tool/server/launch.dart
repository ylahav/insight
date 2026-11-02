import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:insight_collector/insight_collector.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service_io.dart';

import '../repository.dart';
import 'hub.dart';
import 'runner.dart';
import 'script.dart';

/// Starts the switch and the phones, and records the one process the scenario names.
class Exchange2Launcher {
  Exchange2Launcher({
    required this.root,
    required this.flutterBin,
    required this.device,
    required this.mode,
    required this.driver,
    required this.insightServer,
    required this.out,
    this.lines,
  });

  final Directory root;
  final String flutterBin;
  final String device;
  final String mode;
  final String driver;
  final String insightServer;
  final File out;

  /// How many seats surround the switch. Phone windows read this as `LINES`.
  final int? lines;
  final _processes = <Process>[];
  final _built = <String, Future<String>>{};

  Future<void> launch(Start step) async {
    final phone = step.name == 'phone';
    final directory = Directory.fromUri(
      root.uri.resolve(
        phone ? 'examples/exchange2/phone' : 'examples/exchange2/switch',
      ),
    );
    final binary = _built[directory.path];
    if (binary == null) {
      await _stopStale(phone ? 'exchange2_phone.exe' : 'exchange2_switch.exe');
    }
    final disableImpeller =
        device == 'windows' && await _supportsNoImpeller(flutterBin);
    final args = <String>[
      'run',
      '-d',
      device,
      '--$mode',
      if (disableImpeller) '--no-enable-impeller',
      if (binary != null) '--use-application-binary=${await binary}',
    ];
    final environment = Map<String, String>.from(Platform.environment);
    environment['INSIGHT_SERVER'] = insightServer;
    environment['SWITCH_URL'] = 'http://127.0.0.1:8765';
    if (lines != null) {
      environment['LINES'] = '$lines';
    }
    if (phone) {
      environment['LINE'] = step.instance;
    } else {
      environment['DRIVER'] = driver;
    }
    stdout.writeln('Starting ${step.name} ${step.instance}.');
    final process = await Process.start(
      Platform.isWindows ? 'cmd' : flutterBin,
      Platform.isWindows ? ['/c', flutterBin, ...args] : args,
      workingDirectory: directory.path,
      environment: environment,
    );
    _processes.add(process);
    final label = '${step.name} ${step.instance}';
    if (binary != null) {
      _lines(process.stdout).listen((line) => stdout.writeln('[$label] $line'));
      _lines(process.stderr).listen((line) => stderr.writeln('[$label] $line'));
      return;
    }
    final built = Completer<String>();
    _built[directory.path] = built.future;
    void onLine(String line) {
      stdout.writeln('[$label] $line');
      if (built.isCompleted) {
        return;
      }
      if (line.contains('Build process failed')) {
        built.completeError(StateError('$label failed to build.'));
        return;
      }
      final match = RegExp(r'Built\s+(\S+\.exe)').firstMatch(line);
      if (match == null) {
        return;
      }
      built.complete(_exePath(directory, match.group(1)!));
    }

    _lines(process.stdout).listen(onLine);
    _lines(process.stderr).listen((line) => onLine(line));
    unawaited(
      process.exitCode.then((code) {
        if (!built.isCompleted) {
          built.completeError(
            StateError('$label exited ($code) before the build finished.'),
          );
        }
      }),
    );
    await built.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        throw StateError('$label did not finish building.');
      },
    );
  }

  Future<ScenarioRecording> record(Registration registration) async {
    if (registration.vmServiceUri.isEmpty) {
      throw StateError(
        '${registration.name} ${registration.instance} '
        'did not report a VM Service address.',
      );
    }
    final service = await vmServiceConnectUri(
      convertToWebSocketUrl(
        serviceProtocolUrl: Uri.parse(registration.vmServiceUri),
      ).toString(),
    );
    final handle = InsightSessionHandle(service: service);
    await handle.start();
    return _FileRecording(service, handle, out);
  }

  Future<void> stop() async {
    for (final process in _processes) {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
      } else {
        process.kill();
      }
    }
  }
}

class _FileRecording implements ScenarioRecording {
  _FileRecording(this.service, this.handle, this.out);

  final dynamic service;
  final InsightSessionHandle handle;
  final File out;

  @override
  Future<void> stop() async {
    await handle.stop();
    final session = handle.snapshot ?? handle.builder!.build();
    await out.parent.create(recursive: true);
    await out.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(session)}\n',
    );
    stdout.writeln('Wrote ${out.path}.');
    await service.dispose();
  }
}

String _exePath(Directory directory, String raw) {
  if (File(raw).isAbsolute) {
    return raw;
  }
  return File.fromUri(directory.uri.resolve(raw.replaceAll('\\', '/'))).path;
}

Stream<String> _lines(Stream<List<int>> stream) {
  return stream.transform(utf8.decoder).transform(const LineSplitter());
}

/// A previous run can leave the program open. The Windows install step
/// cannot replace that file, and the build stops with MSB3073.
Future<void> _stopStale(String executable) async {
  if (!Platform.isWindows) {
    return;
  }
  await Process.run('taskkill', ['/F', '/IM', executable]);
}

Future<bool> _supportsNoImpeller(String flutterBin) async {
  final result = await Process.run(
    Platform.isWindows ? 'cmd' : flutterBin,
    Platform.isWindows ? ['/c', flutterBin, 'run', '-h'] : ['run', '-h'],
  );
  return '${result.stdout}\n${result.stderr}'.contains('--no-enable-impeller');
}

/// The checkout that contains the exchange2 apps.
Directory? findExchange2Root() => findRepository();
