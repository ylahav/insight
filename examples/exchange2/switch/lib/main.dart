import 'dart:io';

import 'package:exchange2_agent/insight_agent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insight/insight.dart';
import 'package:insight_bloc/insight_bloc.dart';
import 'package:insight_riverpod/insight_riverpod.dart';
import 'package:plinth_components/plinth_components.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'src/actions.dart';
import 'src/desk.dart';
import 'src/http.dart';
import 'src/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Insight.attach();
  final store = SqliteSwitchStore('exchange2.db');
  await store.open();
  final actions = SwitchActions(store: store);
  final driver = _driver();
  final Widget desk;
  if (driver == 'riverpod') {
    riverpodActions = actions;
    desk = const ProviderScope(
      observers: [InsightRiverpodObserver()],
      child: _RiverpodDesk(),
    );
  } else {
    Bloc.observer = InsightBlocObserver();
    desk = BlocProvider(
      create: (_) => ExchangeCubit(actions),
      child: driver == 'plinth' ? const _PlinthHost() : const _BlocDesk(),
    );
  }

  try {
    final server = await shelf_io.serve(
      switchHandler(actions),
      InternetAddress.loopbackIPv4,
      8765,
    );
    stdout.writeln('Switch listening on ${server.port}.');
  } on SocketException {
    stderr.writeln('Port 8765 is already taken.');
    exit(1);
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: driver == 'plinth'
          ? ThemeData(
              useMaterial3: true,
              extensions: [PlinthTheme.defaultTheme],
            )
          : null,
      home: desk,
    ),
  );

  final insight =
      Platform.environment['INSIGHT_SERVER'] ??
      const String.fromEnvironment(
        'INSIGHT_SERVER',
        defaultValue: 'http://127.0.0.1:8790',
      );
  await InsightAgent(
    server: Uri.parse(insight),
    role: 'switch',
    name: 'switch',
    instance: '1',
  ).serve(
    onTap: (target) async {
      throw StateError('The switch has no $target.');
    },
    onSee: (text) => _untilText(actions, text),
  );
}

class _BlocDesk extends StatelessWidget {
  const _BlocDesk();

  @override
  Widget build(BuildContext context) {
    context.watch<ExchangeCubit>();
    return SwitchDesk(actions: context.read<ExchangeCubit>().actions);
  }
}

class _PlinthHost extends StatelessWidget {
  const _PlinthHost();

  @override
  Widget build(BuildContext context) {
    context.watch<ExchangeCubit>();
    return PlinthDesk(actions: context.read<ExchangeCubit>().actions);
  }
}

class _RiverpodDesk extends ConsumerWidget {
  const _RiverpodDesk();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(exchangeProvider);
    return SwitchDesk(actions: riverpodActions!);
  }
}

Future<String?> _untilText(SwitchActions actions, String text) async {
  for (var frame = 0; frame < 90; frame++) {
    if (deskText(actions).any((line) => line.contains(text))) {
      return null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  return 'The board never showed "$text".';
}

String _driver() {
  final fromEnv = Platform.environment['DRIVER'];
  if (fromEnv == 'bloc' || fromEnv == 'riverpod' || fromEnv == 'plinth') {
    return fromEnv as String;
  }
  final defined = const String.fromEnvironment('DRIVER', defaultValue: 'bloc');
  if (defined == 'riverpod' || defined == 'plinth') {
    return defined;
  }
  return 'bloc';
}
