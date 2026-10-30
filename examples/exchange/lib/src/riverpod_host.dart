import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board.dart';
import 'exchange.dart';
import 'exchange_scope.dart';

final lineCountProvider = Provider<int>((ref) => 3);

class ExchangeNotifier extends Notifier<Exchange> {
  @override
  Exchange build() => Exchange.opened(ref.watch(lineCountProvider));

  void offHook(int number) => state = state.offHook(number);

  void onHook(int number) => state = state.onHook(number);

  void dial(int number, int digit) => state = state.dial(number, digit);
}

final exchangeProvider = NotifierProvider<ExchangeNotifier, Exchange>(
  ExchangeNotifier.new,
  name: 'exchange',
);

class ExchangeHost extends ConsumerStatefulWidget {
  const ExchangeHost({super.key});

  @override
  ConsumerState<ExchangeHost> createState() => _ExchangeHostState();
}

class _ExchangeHostState extends ConsumerState<ExchangeHost> {
  void _offHook(int number) =>
      ref.read(exchangeProvider.notifier).offHook(number);

  void _onHook(int number) =>
      ref.read(exchangeProvider.notifier).onHook(number);

  void _dial(int number, int digit) =>
      ref.read(exchangeProvider.notifier).dial(number, digit);

  @override
  Widget build(BuildContext context) {
    final exchange = ref.watch(exchangeProvider);
    return ExchangeActions(
      offHook: _offHook,
      onHook: _onHook,
      dial: _dial,
      child: ExchangeScope(exchange: exchange, child: const ExchangeBoard()),
    );
  }
}
