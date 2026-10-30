import 'package:flutter/material.dart';

import 'exchange.dart';
import 'exchange_scope.dart';

const panel = Color(0xff1e3330);
const enamel = Color(0xffd5ddd6);
const ink = Color(0xff1b2824);
const cord = Color(0xffe0a84a);
const busyLamp = Color(0xffd24b3a);
const talkLamp = Color(0xff2f9e6b);
const waitLamp = Color(0xff3d8ea6);
const idleLamp = Color(0xff8aa094);
const lineLamp = Color(0xfff7f1dc);

/// Rebuild counters for the widget tests. Insight records the same split.
class ExchangeBuilds {
  static int phones = 0;
  static int switchDesk = 0;

  static void reset() {
    phones = 0;
    switchDesk = 0;
  }
}

class ExchangeBoard extends StatelessWidget {
  const ExchangeBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final lineCount = LineCountScope.of(context);
    return ColoredBox(
      color: panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Exchange',
                  style: TextStyle(
                    color: enamel,
                    fontSize: 22,
                    fontFamily: 'Georgia',
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close the board',
                    style: TextStyle(color: cord),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var number = 1; number <= lineCount; number++)
                  Expanded(child: LinePhone(number: number)),
              ],
            ),
          ),
          const Expanded(child: SwitchDesk()),
        ],
      ),
    );
  }
}

class LinePhone extends StatelessWidget {
  const LinePhone({required this.number, super.key});

  final int number;

  @override
  Widget build(BuildContext context) {
    ExchangeBuilds.phones++;
    final line = ExchangeScope.lineOf(context, number);
    final lineCount = LineCountScope.of(context);
    final actions = ExchangeActions.of(context);
    final showDigits =
        line.status == LineStatus.dialing || line.status == LineStatus.busyTone;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Material(
            color: enamel,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: Key('phone-$number'),
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (line.status == LineStatus.idle ||
                    line.status == LineStatus.ringing ||
                    line.status == LineStatus.recallRing) {
                  actions.offHook(number);
                } else {
                  actions.onHook(number);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Lamp(signal: line.signal),
                        const SizedBox(width: 8),
                        Text(
                          '$number',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 36,
                            fontFamily: 'Georgia',
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      line.hookLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    if (line.signal != LineSignal.none)
                      Text(
                        line.signalLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    if (line.detail.isNotEmpty)
                      Text(
                        line.detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontFamily: 'Georgia',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (line.status == LineStatus.ringing ||
              line.status == LineStatus.recallRing)
            TextButton(
              key: Key('hook-on-$number'),
              onPressed: () => actions.onHook(number),
              child: const Text(
                'Hook on',
                style: TextStyle(color: enamel, fontFamily: 'Georgia'),
              ),
            ),
          if (showDigits)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var digit = 1; digit <= lineCount; digit++)
                    DialKey(number: number, digit: digit),
                  DialKey(number: number, digit: 0),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class DialKey extends StatelessWidget {
  const DialKey({required this.number, required this.digit, super.key});

  final int number;
  final int digit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: TextButton(
        key: Key('digit-$number-$digit'),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: enamel,
          backgroundColor: const Color(0xff29403c),
        ),
        onPressed: () => ExchangeActions.of(context).dial(number, digit),
        child: Text(
          '$digit',
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
        ),
      ),
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp({required this.signal});

  final LineSignal signal;

  @override
  Widget build(BuildContext context) {
    final color = switch (signal) {
      LineSignal.none => idleLamp,
      LineSignal.line => lineLamp,
      LineSignal.ringing => cord,
      LineSignal.busy => busyLamp,
      LineSignal.voice => talkLamp,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: signal == LineSignal.line
            ? Border.all(color: ink, width: 1)
            : null,
      ),
    );
  }
}

class SwitchDesk extends StatefulWidget {
  const SwitchDesk({super.key});

  @override
  State<SwitchDesk> createState() => _SwitchDeskState();
}

class _SwitchDeskState extends State<SwitchDesk>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  void _syncBlink(bool active) {
    if (active) {
      if (!_blink.isAnimating) {
        _blink.repeat(reverse: true);
      }
    } else if (_blink.isAnimating) {
      _blink.stop();
      _blink.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    ExchangeBuilds.switchDesk++;
    final exchange = ExchangeScope.switchOf(context);
    final lineCount = LineCountScope.of(context);
    final calls = exchange.calls;
    final rings = exchange.rings;
    final recalls = exchange.recalls;
    final animate =
        rings.isNotEmpty && !MediaQuery.disableAnimationsOf(context);
    _syncBlink(animate);
    return CustomPaint(
      painter: _CordPainter(
        lineCount: lineCount,
        calls: calls,
        rings: rings,
        blink: animate ? _blink : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (calls.isEmpty &&
                rings.isEmpty &&
                recalls.isEmpty &&
                exchange.waiting.isEmpty)
              const Text(
                'Tap a phone and dial a line.',
                style: TextStyle(
                  color: enamel,
                  fontFamily: 'Georgia',
                  fontSize: 16,
                ),
              ),
            for (final recall in recalls)
              Text(
                '${recall.$1} is ringing',
                style: const TextStyle(
                  color: cord,
                  fontFamily: 'Georgia',
                  fontSize: 18,
                ),
              ),
            for (final ring in rings)
              Text(
                '${ring.$2} is ringing',
                style: const TextStyle(
                  color: cord,
                  fontFamily: 'Georgia',
                  fontSize: 18,
                ),
              ),
            for (final call in calls)
              Text(
                '${call.$1} and ${call.$2}',
                style: const TextStyle(
                  color: cord,
                  fontFamily: 'Georgia',
                  fontSize: 18,
                ),
              ),
            for (final request in exchange.waiting)
              Text(
                '${request.waiter} is waiting for ${request.target}',
                style: const TextStyle(
                  color: waitLamp,
                  fontFamily: 'Georgia',
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CordPainter extends CustomPainter {
  _CordPainter({
    required this.lineCount,
    required this.calls,
    required this.rings,
    this.blink,
  }) : super(repaint: blink);

  final int lineCount;
  final List<(int, int)> calls;
  final List<(int, int)> rings;
  final Animation<double>? blink;

  @override
  void paint(Canvas canvas, Size size) {
    final hub = Offset(size.width / 2, size.height * 0.42);
    final cordPaint = Paint()
      ..color = cord
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(hub, 8, Paint()..color = cord);
    for (final call in calls) {
      _drawCord(canvas, size, call, cordPaint);
    }
    final showRing = blink == null || blink!.value >= 0.5;
    if (showRing) {
      for (final ring in rings) {
        _drawCord(canvas, size, ring, cordPaint);
      }
    }
  }

  void _drawCord(Canvas canvas, Size size, (int, int) pair, Paint paint) {
    final from = _slot(pair.$1, size);
    final to = _slot(pair.$2, size);
    final hub = Offset(size.width / 2, size.height * 0.42);
    canvas.drawLine(from, hub, paint);
    canvas.drawLine(hub, to, paint);
  }

  Offset _slot(int number, Size size) {
    return Offset((number - 0.5) * size.width / lineCount, 0);
  }

  @override
  bool shouldRepaint(_CordPainter oldDelegate) {
    if (oldDelegate.lineCount != lineCount ||
        oldDelegate.calls.length != calls.length ||
        oldDelegate.rings.length != rings.length ||
        oldDelegate.blink != blink) {
      return true;
    }
    for (var i = 0; i < calls.length; i++) {
      if (oldDelegate.calls[i] != calls[i]) {
        return true;
      }
    }
    for (var i = 0; i < rings.length; i++) {
      if (oldDelegate.rings[i] != rings[i]) {
        return true;
      }
    }
    return false;
  }
}
