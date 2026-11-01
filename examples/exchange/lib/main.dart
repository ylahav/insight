import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';
import 'package:insight_bloc/insight_bloc.dart';

import 'src/exchange_app.dart';
import 'src/play.dart';

const _play = bool.fromEnvironment('EXCHANGE_PLAY');
const _board = String.fromEnvironment('EXCHANGE_BOARD', defaultValue: 'bloc');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Insight.attach();
  Bloc.observer = InsightBlocObserver();
  if (_play) {
    registerExchangePlay(_board);
  }
  runApp(const ExchangeApp());
}
