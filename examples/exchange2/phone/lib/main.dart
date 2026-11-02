import 'dart:io';

import 'package:exchange2_agent/insight_agent.dart';
import 'package:exchange2_agent/switch_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';
import 'package:insight_bloc/insight_bloc.dart';

import 'src/handset.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Insight.attach();
  Bloc.observer = InsightBlocObserver();
  final line = _line();
  final switchUrl = _setting(
    'SWITCH_URL',
    fallback: 'http://127.0.0.1:8765',
  );
  final insight = _setting(
    'INSIGHT_SERVER',
    fallback: 'http://127.0.0.1:8790',
  );

  if (line < 1 || line > 9) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: Color(0xff1e3330),
          child: Center(
            child: Text(
              'Set LINE to a number from 1 to 9.',
              style: TextStyle(color: Color(0xffd5ddd6), fontFamily: 'Georgia'),
            ),
          ),
        ),
      ),
    );
    return;
  }

  final cubit = PhoneCubit(client: SwitchClient(Uri.parse(switchUrl)), number: line);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BlocProvider.value(
        value: cubit,
        child: Handset(number: line),
      ),
    ),
  );
  await Future.wait([
    cubit.run(),
    InsightAgent(
      server: Uri.parse(insight),
      role: 'phone',
      name: 'phone',
      instance: '$line',
    ).serve(
      onTap: cubit.press,
      onSee: (text) => _untilText(cubit, text),
    ),
  ]);
}

int _line() {
  final fromEnv = int.tryParse(Platform.environment['LINE'] ?? '');
  if (fromEnv != null) {
    return fromEnv;
  }
  return const int.fromEnvironment('LINE');
}

String _setting(String name, {required String fallback}) {
  final fromEnv = Platform.environment[name];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  return String.fromEnvironment(name, defaultValue: fallback);
}

Future<String?> _untilText(PhoneCubit cubit, String text) async {
  for (var frame = 0; frame < 90; frame++) {
    if (phoneText(cubit.state).any((line) => line.contains(text))) {
      return null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  return 'The board never showed "$text".';
}
