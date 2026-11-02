import 'package:exchange2_agent/line_snapshot.dart';
import 'package:exchange2_rules/exchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plinth_components/plinth_components.dart';

import 'actions.dart';
import 'store.dart';

const _panel = Color(0xff1e3330);
const _enamel = Color(0xffd5ddd6);

/// Bloc holder. The HTTP server calls [actions]; this emit is what Insight records.
class ExchangeCubit extends Cubit<Exchange> {
  ExchangeCubit(this.actions) : super(actions.exchange) {
    actions.onChanged = (value) {
      if (!isClosed) {
        emit(value);
      }
    };
  }

  final SwitchActions actions;
}

/// Set before the Riverpod desk is built. Bloc uses [ExchangeCubit] instead.
SwitchActions? riverpodActions;

/// Riverpod holder. The provider name is `exchange`.
class ExchangeNotifier extends Notifier<Exchange> {
  @override
  Exchange build() {
    final actions = riverpodActions!;
    actions.onChanged = (value) => state = value;
    return actions.exchange;
  }
}

final exchangeProvider = NotifierProvider<ExchangeNotifier, Exchange>(
  ExchangeNotifier.new,
  name: 'exchange',
);

class SwitchDesk extends StatelessWidget {
  const SwitchDesk({required this.actions, super.key});

  final SwitchActions actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: actions,
      builder: (context, _) {
        return ColoredBox(
          color: _panel,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Switch',
                  style: TextStyle(
                    color: _enamel,
                    fontSize: 28,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 16),
                for (final line in actions.exchange.lines) LineRow(line: line),
                for (final pair in actions.exchange.calls)
                  Text(
                    '${pair.$1} and ${pair.$2}',
                    style: const TextStyle(
                      color: _enamel,
                      fontFamily: 'Georgia',
                    ),
                  ),
                const SizedBox(height: 16),
                ActivityLog(entries: actions.log),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LineRow extends StatelessWidget {
  const LineRow({required this.line, super.key});

  final Line line;

  @override
  Widget build(BuildContext context) {
    final signal = signalLabel(line.signal.name);
    final hook = line.hookOn ? 'Hook on' : 'Hook off';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${line.number}  $hook  $signal  ${line.detail}',
        style: const TextStyle(
          color: _enamel,
          fontSize: 18,
          fontFamily: 'Georgia',
        ),
      ),
    );
  }
}

class ActivityLog extends StatelessWidget {
  const ActivityLog({required this.entries, super.key});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Text(
            entry.detail,
            style: const TextStyle(
              color: _enamel,
              fontSize: 16,
              fontFamily: 'Georgia',
            ),
          ),
      ],
    );
  }
}

/// The same desk, drawn with Plinth widgets. The state row stays [ExchangeCubit].
class PlinthDesk extends StatelessWidget {
  const PlinthDesk({required this.actions, super.key});

  final SwitchActions actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: actions,
      builder: (context, _) {
        return ColoredBox(
          color: _panel,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final line in actions.exchange.lines) PlinthLine(line: line),
              for (final pair in actions.exchange.calls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PlinthBadge(
                    '${pair.$1} and ${pair.$2}',
                    color: 'green',
                  ),
                ),
              const SizedBox(height: 12),
              PlinthLog(entries: actions.log),
            ],
          ),
        );
      },
    );
  }
}

class PlinthLine extends StatelessWidget {
  const PlinthLine({required this.line, super.key});

  final Line line;

  @override
  Widget build(BuildContext context) {
    final signal = signalLabel(line.signal.name);
    final hook = line.hookOn ? 'Hook on' : 'Hook off';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PlinthPaper(
        p: PlinthSize.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${line.number}'),
            Text(hook),
            if (signal.isNotEmpty)
              PlinthBadge(signal, color: _badgeColor(line.signal)),
            if (line.detail.isNotEmpty) Text(line.detail),
          ],
        ),
      ),
    );
  }
}

class PlinthLog extends StatelessWidget {
  const PlinthLog({required this.entries, super.key});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return PlinthPaper(
      p: PlinthSize.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final entry in entries) Text(entry.detail)],
      ),
    );
  }
}

String _badgeColor(LineSignal signal) {
  return switch (signal) {
    LineSignal.none => 'gray',
    LineSignal.line => 'yellow',
    LineSignal.ringing => 'orange',
    LineSignal.busy || LineSignal.missing => 'red',
    LineSignal.voice => 'green',
  };
}

/// Text the Insight server can `see` on the desk.
List<String> deskText(SwitchActions actions) {
  return [
    for (final pair in actions.exchange.calls) '${pair.$1} and ${pair.$2}',
    for (final line in actions.exchange.lines) ...[
      '${line.number}',
      line.hookOn ? 'Hook on' : 'Hook off',
      signalLabel(line.signal.name),
      line.detail,
    ],
    for (final entry in actions.log) entry.detail,
  ];
}
