import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:insight/insight.dart';

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

/// Jack colors. One per line, in telephone-pair order.
const phoneColors = <Color>[
  Color(0xff2f6fbf),
  Color(0xffe07a2f),
  Color(0xff2f9a62),
  Color(0xff8d5a3c),
  Color(0xff6e7c8a),
  Color(0xffc4473a),
  Color(0xffc9a227),
  Color(0xff6d5cae),
  Color(0xffd06a8a),
];

Color phoneColor(int number) => phoneColors[(number - 1) % phoneColors.length];

Color labelOn(Color color) =>
    color.computeLuminance() > 0.45 ? ink : const Color(0xfff7f4ee);

/// Where the phones sit, and where a cord meets a phone.
class DeskGeometry {
  DeskGeometry(this.size, this.lineCount);

  final Size size;
  final int lineCount;

  static const slot = Size(118, 168);

  Offset get hub => size.center(Offset.zero);

  double get radius {
    if (size.isEmpty) {
      return 0;
    }
    final limit = math.min(size.width, size.height) / 2 - slot.height / 2 - 8;
    return math.max(limit, 36);
  }

  Offset centerOf(int number) {
    final angle = -math.pi / 2 + (number - 1) * 2 * math.pi / lineCount;
    return hub + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  /// A point on the phone's inner edge, toward the switch.
  Offset cordEnd(int number) {
    final phone = centerOf(number);
    final delta = hub - phone;
    final length = delta.distance;
    final inset = slot.shortestSide / 2 + 2;
    if (length <= inset) {
      return phone;
    }
    return phone + delta / length * inset;
  }
}

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
    return RoundDesk(phone: (number) => LinePhone(number: number));
  }
}

/// Switch in the middle. Phones stand on a circle around it.
class RoundDesk extends StatelessWidget {
  const RoundDesk({required this.phone, super.key});

  final Widget Function(int number) phone;

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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final geometry = DeskGeometry(constraints.biggest, lineCount);
                return Stack(
                  children: [
                    const Positioned.fill(child: SwitchDesk()),
                    for (var number = 1; number <= lineCount; number++)
                      Positioned(
                        left:
                            geometry.centerOf(number).dx -
                            DeskGeometry.slot.width / 2,
                        top:
                            geometry.centerOf(number).dy -
                            DeskGeometry.slot.height / 2,
                        width: DeskGeometry.slot.width,
                        height: DeskGeometry.slot.height,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: DeskGeometry.slot.width,
                            child: phone(number),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
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
    final line = WholeSwitch.of(context)
        ? ExchangeScope.of(context).line(number)
        : ExchangeScope.lineOf(context, number);
    final lineCount = LineCountScope.of(context);
    final actions = ExchangeActions.of(context);
    final showDigits =
        line.status == LineStatus.dialing || line.status == LineStatus.busyTone;
    final body = phoneColor(number);
    final label = labelOn(body);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Material(
            color: body,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: Key('phone-$number'),
              borderRadius: BorderRadius.circular(18),
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
                          style: TextStyle(
                            color: label,
                            fontSize: 32,
                            fontFamily: 'Georgia',
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      line.hookLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: label,
                        fontSize: 12,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    if (line.signal != LineSignal.none)
                      Text(
                        line.signalLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: label,
                          fontSize: 12,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    if (line.detail.isNotEmpty)
                      Text(
                        line.detail,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: label,
                          fontSize: 12,
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
              onPressed: () {
                Insight.action('hook-on-$number');
                actions.onHook(number);
              },
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
        onPressed: () {
          Insight.action('digit-$number-$digit');
          ExchangeActions.of(context).dial(number, digit);
        },
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
    if (size.isEmpty) {
      return;
    }
    final geometry = DeskGeometry(size, lineCount);
    final hub = geometry.hub;
    canvas.drawCircle(hub, 16, Paint()..color = panel);
    canvas.drawCircle(
      hub,
      16,
      Paint()
        ..color = enamel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final call in calls) {
      _drawCord(canvas, geometry, call);
    }
    final showRing = blink == null || blink!.value >= 0.5;
    if (showRing) {
      for (final ring in rings) {
        _drawCord(canvas, geometry, ring);
      }
    }
  }

  void _drawCord(Canvas canvas, DeskGeometry geometry, (int, int) pair) {
    final from = geometry.cordEnd(pair.$1);
    final to = geometry.cordEnd(pair.$2);
    final hub = geometry.hub;
    final mix = Color.lerp(phoneColor(pair.$1), phoneColor(pair.$2), 0.5)!;
    _leg(canvas, from, hub, phoneColor(pair.$1), mix);
    _leg(canvas, to, hub, phoneColor(pair.$2), mix);
  }

  void _leg(Canvas canvas, Offset from, Offset hub, Color start, Color end) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [start, end],
      ).createShader(Rect.fromPoints(from, hub))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, hub, paint);
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
