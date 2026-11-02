import 'package:flutter/material.dart';
import 'package:insight/insight.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insight_riverpod/insight_riverpod.dart';
import 'package:plinth_components/plinth_components.dart';

import 'bloc_host.dart' as bloc;
import 'board.dart';
import 'exchange_scope.dart';
import 'riverpod_host.dart' as riverpod;

enum ExchangeDriver { bloc, riverpod }

class ExchangeApp extends StatelessWidget {
  const ExchangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: panel,
        fontFamily: 'Georgia',
        extensions: [PlinthTheme.defaultTheme],
        colorScheme: const ColorScheme.dark(
          surface: panel,
          primary: cord,
          onSurface: enamel,
        ),
      ),
      home: const SetupPage(),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  int _lineCount = 5;

  void _open(ExchangeDriver driver, {bool plinth = false, bool wide = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BoardPage(
          driver: driver,
          lineCount: _lineCount,
          plinth: plinth,
          wide: wide,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: panel,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How many lines?',
                style: TextStyle(
                  color: enamel,
                  fontSize: 32,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '0 starts a service. 01 waits for a busy line.',
                style: TextStyle(
                  color: enamel,
                  fontSize: 16,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var count = 3; count <= 9; count++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextButton(
                        key: Key('lines-$count'),
                        onPressed: () {
                          Insight.action('lines-$count');
                          setState(() => _lineCount = count);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: enamel,
                          backgroundColor: _lineCount == count
                              ? const Color(0xff29403c)
                              : null,
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 28,
                            fontFamily: 'Georgia',
                            decoration: _lineCount == count
                                ? TextDecoration.underline
                                : null,
                            decorationColor: cord,
                            decorationThickness: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    key: const Key('open-bloc'),
                    onPressed: () {
                      Insight.action('open-bloc');
                      _open(ExchangeDriver.bloc);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: enamel,
                      side: const BorderSide(color: cord),
                    ),
                    child: const Text('Open with Bloc'),
                  ),
                  OutlinedButton(
                    key: const Key('open-riverpod'),
                    onPressed: () {
                      Insight.action('open-riverpod');
                      _open(ExchangeDriver.riverpod);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: enamel,
                      side: const BorderSide(color: cord),
                    ),
                    child: const Text('Open with Riverpod'),
                  ),
                  OutlinedButton(
                    key: const Key('open-wide'),
                    onPressed: () {
                      Insight.action('open-wide');
                      _open(ExchangeDriver.bloc, wide: true);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: enamel,
                      side: const BorderSide(color: cord),
                    ),
                    child: const Text('Open the wide board'),
                  ),
                  OutlinedButton(
                    key: const Key('open-plinth'),
                    onPressed: () {
                      Insight.action('open-plinth');
                      _open(ExchangeDriver.bloc, plinth: true);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: enamel,
                      side: const BorderSide(color: cord),
                    ),
                    child: const Text('Open the Plinth board'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BoardPage extends StatelessWidget {
  const BoardPage({
    required this.driver,
    required this.lineCount,
    this.plinth = false,
    this.wide = false,
    super.key,
  });

  final ExchangeDriver driver;
  final int lineCount;
  final bool plinth;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return LineCountScope(
      lineCount: lineCount,
      child: WholeSwitch(
        enabled: wide,
        child: switch (driver) {
          ExchangeDriver.bloc => BlocProvider(
            create: (_) => bloc.ExchangeCubit(lineCount),
            child: bloc.ExchangeHost(plinth: plinth),
          ),
          ExchangeDriver.riverpod => ProviderScope(
            overrides: [
              riverpod.lineCountProvider.overrideWithValue(lineCount),
            ],
            observers: const [InsightRiverpodObserver()],
            child: const riverpod.ExchangeHost(),
          ),
        },
      ),
    );
  }
}
