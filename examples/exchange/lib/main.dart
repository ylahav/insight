import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';
import 'package:insight_bloc/insight_bloc.dart';

import 'src/exchange_app.dart';

void main() {
  Insight.attach();
  Bloc.observer = InsightBlocObserver();
  runApp(const ExchangeApp());
}
