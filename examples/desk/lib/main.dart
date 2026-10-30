import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';
import 'package:insight_bloc/insight_bloc.dart';

import 'src/desk_page.dart';

void main() {
  Insight.attach();
  Bloc.observer = InsightBlocObserver();
  runApp(const DeskApp());
}
