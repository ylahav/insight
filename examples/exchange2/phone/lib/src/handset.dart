import 'package:exchange2_agent/line_snapshot.dart';
import 'package:exchange2_agent/switch_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';

const _panel = Color(0xff1e3330);
const _enamel = Color(0xffd5ddd6);

class PhoneCubit extends Cubit<LineSnapshot?> {
  PhoneCubit({required this.client, required this.number}) : super(null);

  final SwitchClient client;
  final int number;
  var _open = true;

  Future<void> run() async {
    while (_open && state == null) {
      try {
        final snapshot = await Insight.traceFuture(
          client.register(number),
          name: 'POST register',
        );
        _apply(snapshot);
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    while (_open) {
      final after = state?.revision ?? 0;
      try {
        final snapshot = await Insight.traceFuture(
          client.wait(number, after: after),
          name: 'GET wait',
        );
        _apply(snapshot);
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> press(String target) async {
    if (target == 'hook') {
      Insight.action('hook');
      final off = state?.hookOn ?? false;
      if (state == null) {
        throw StateError('The phone is not registered.');
      }
      _apply(
        await Insight.traceFuture(
          client.hook(number, off: off),
          name: 'POST hook',
        ),
      );
      return;
    }
    const prefix = 'digit-';
    if (target.startsWith(prefix)) {
      Insight.action(target);
      final digit = target.substring(prefix.length);
      _apply(
        await Insight.traceFuture(
          client.digit(number, digit),
          name: 'POST digit',
        ),
      );
      return;
    }
    throw StateError('The phone has no $target.');
  }

  void _apply(LineSnapshot snapshot) {
    final current = state;
    if (current != null && snapshot.revision < current.revision) {
      return;
    }
    if (current != null &&
        snapshot.revision == current.revision &&
        snapshot.hook == current.hook &&
        snapshot.signal == current.signal &&
        snapshot.detail == current.detail) {
      return;
    }
    if (!isClosed) {
      emit(snapshot);
    }
  }

  @override
  Future<void> close() {
    _open = false;
    return super.close();
  }
}

class Handset extends StatefulWidget {
  const Handset({required this.number, super.key});

  final int number;

  @override
  State<Handset> createState() => _HandsetState();
}

class _HandsetState extends State<Handset> {
  var _open = false;
  var _needed = false;

  void _sync(LineSnapshot? snapshot) {
    final needed = snapshot != null && snapshot.digits.isNotEmpty;
    if (needed && !_needed) {
      _open = true;
    }
    _needed = needed;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhoneCubit, LineSnapshot?>(
      builder: (context, snapshot) {
        _sync(snapshot);
        final hook = snapshot == null
            ? 'Connecting'
            : (snapshot.hookOn ? 'Hook on' : 'Hook off');
        final signal = snapshot == null ? '' : signalLabel(snapshot.signal);
        final detail = snapshot?.detail ?? '';
        return Material(
          color: _panel,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${widget.number}',
                        style: const TextStyle(
                          color: _enamel,
                          fontSize: 48,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      InkWell(
                        key: const Key('hook'),
                        onTap: () => context.read<PhoneCubit>().press('hook'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                hook,
                                style: const TextStyle(
                                  color: _enamel,
                                  fontSize: 20,
                                  fontFamily: 'Georgia',
                                ),
                              ),
                              if (signal.isNotEmpty)
                                Text(
                                  signal,
                                  style: const TextStyle(
                                    color: _enamel,
                                    fontFamily: 'Georgia',
                                  ),
                                ),
                              if (detail.isNotEmpty)
                                Text(
                                  detail,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _enamel,
                                    fontFamily: 'Georgia',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        key: const Key('keys'),
                        onPressed: () => setState(() => _open = true),
                        child: const Text(
                          'Keys',
                          style: TextStyle(
                            color: _enamel,
                            fontSize: 18,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_open)
                Positioned.fill(
                  child: Keypad(
                    onDigit: (digit) async {
                      try {
                        await context.read<PhoneCubit>().press('digit-$digit');
                      } on SwitchException {
                        // The switch refuses a digit it cannot take.
                      }
                    },
                    onClose: () => setState(() => _open = false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Digits 0 through 9. The handset opens this when a digit is needed.
class Keypad extends StatelessWidget {
  const Keypad({required this.onDigit, required this.onClose, super.key});

  final Future<void> Function(String digit) onDigit;
  final VoidCallback onClose;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xee1e3330),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('keys-close'),
                onPressed: onClose,
                child: const Text(
                  'Close',
                  style: TextStyle(color: _enamel, fontFamily: 'Georgia'),
                ),
              ),
            ),
            for (final row in _rows)
              Expanded(
                child: Row(
                  children: [
                    for (final digit in row) Expanded(child: _key(digit)),
                  ],
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  const Spacer(),
                  Expanded(child: _key('0')),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _key(String digit) {
    return TextButton(
      key: Key('digit-$digit'),
      onPressed: () => onDigit(digit),
      child: Text(
        digit,
        style: const TextStyle(
          color: _enamel,
          fontSize: 28,
          fontFamily: 'Georgia',
        ),
      ),
    );
  }
}

List<String> phoneText(LineSnapshot? snapshot) {
  if (snapshot == null) {
    return const ['Connecting'];
  }
  return [
    '${snapshot.number}',
    snapshot.hookOn ? 'Hook on' : 'Hook off',
    signalLabel(snapshot.signal),
    snapshot.detail,
    'Keys',
  ];
}
