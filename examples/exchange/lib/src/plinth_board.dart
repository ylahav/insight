import 'package:flutter/material.dart';
import 'package:insight/insight.dart';
import 'package:plinth_components/plinth_components.dart';

import 'board.dart';
import 'exchange.dart';
import 'exchange_scope.dart';

/// The same switch, drawn with Plinth widgets.
class PlinthBoard extends StatelessWidget {
  const PlinthBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return RoundDesk(phone: (number) => PlinthLine(number: number));
  }
}

class PlinthLine extends StatelessWidget {
  const PlinthLine({required this.number, super.key});

  final int number;

  @override
  Widget build(BuildContext context) {
    final line = ExchangeScope.lineOf(context, number);
    final lineCount = LineCountScope.of(context);
    final actions = ExchangeActions.of(context);
    final showDigits =
        line.status == LineStatus.dialing || line.status == LineStatus.busyTone;
    final body = phoneColor(number);
    final label = labelOn(body);
    return Column(
      children: [
        GestureDetector(
          key: Key('phone-$number'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Insight.action('phone-$number');
            if (line.status == LineStatus.idle ||
                line.status == LineStatus.ringing ||
                line.status == LineStatus.recallRing) {
              actions.offHook(number);
            } else {
              actions.onHook(number);
            }
          },
          child: PlinthPaper(
            p: PlinthSize.xs,
            radius: PlinthSize.lg,
            bg: body,
            child: Column(
              children: [
                Text(
                  '$number',
                  style: TextStyle(
                    color: label,
                    fontSize: 28,
                    fontFamily: 'Georgia',
                  ),
                ),
                Text(
                  line.hookLabel,
                  style: TextStyle(
                    color: label,
                    fontSize: 12,
                    fontFamily: 'Georgia',
                  ),
                ),
                if (line.signal != LineSignal.none)
                  FittedBox(
                    child: PlinthBadge(
                      line.signalLabel,
                      color: _badgeColor(line.signal),
                    ),
                  ),
                if (line.detail.isNotEmpty)
                  FittedBox(
                    child: Text(
                      line.detail,
                      style: TextStyle(
                        color: label,
                        fontSize: 12,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (line.status == LineStatus.ringing ||
            line.status == LineStatus.recallRing)
          PlinthButton(
            key: Key('hook-on-$number'),
            size: PlinthSize.xs,
            color: 'red',
            onPressed: () {
              Insight.action('hook-on-$number');
              actions.onHook(number);
            },
            child: const Text('Hook on'),
          ),
        if (showDigits)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: [
              for (var digit = 1; digit <= lineCount; digit++)
                _Digit(number: number, digit: digit),
              _Digit(number: number, digit: 0),
            ],
          ),
      ],
    );
  }

  String _badgeColor(LineSignal signal) {
    return switch (signal) {
      LineSignal.none => 'gray',
      LineSignal.line => 'yellow',
      LineSignal.ringing => 'orange',
      LineSignal.busy => 'red',
      LineSignal.voice => 'green',
    };
  }
}

class _Digit extends StatelessWidget {
  const _Digit({required this.number, required this.digit});

  final int number;
  final int digit;

  @override
  Widget build(BuildContext context) {
    return PlinthButton(
      key: Key('digit-$number-$digit'),
      size: PlinthSize.xs,
      color: 'gray',
      onPressed: () {
        Insight.action('digit-$number-$digit');
        ExchangeActions.of(context).dial(number, digit);
      },
      child: Text('$digit'),
    );
  }
}
