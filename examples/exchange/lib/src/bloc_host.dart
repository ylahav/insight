import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'board.dart';
import 'exchange.dart';
import 'exchange_scope.dart';
import 'plinth_board.dart';

class ExchangeCubit extends Cubit<Exchange> {
  ExchangeCubit(int lineCount) : super(Exchange.opened(lineCount));

  void offHook(int number) => emit(state.offHook(number));

  void onHook(int number) => emit(state.onHook(number));

  void dial(int number, int digit) => emit(state.dial(number, digit));
}

class ExchangeHost extends StatefulWidget {
  const ExchangeHost({this.plinth = false, super.key});

  final bool plinth;

  @override
  State<ExchangeHost> createState() => _ExchangeHostState();
}

class _ExchangeHostState extends State<ExchangeHost> {
  void _offHook(int number) => context.read<ExchangeCubit>().offHook(number);

  void _onHook(int number) => context.read<ExchangeCubit>().onHook(number);

  void _dial(int number, int digit) =>
      context.read<ExchangeCubit>().dial(number, digit);

  @override
  Widget build(BuildContext context) {
    final exchange = context.watch<ExchangeCubit>().state;
    return ExchangeActions(
      offHook: _offHook,
      onHook: _onHook,
      dial: _dial,
      child: ExchangeScope(
        exchange: exchange,
        child: widget.plinth ? const PlinthBoard() : const ExchangeBoard(),
      ),
    );
  }
}
