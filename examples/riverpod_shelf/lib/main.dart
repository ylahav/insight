import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insight/insight.dart';
import 'package:insight_riverpod/insight_riverpod.dart';

import 'src/shelf_page.dart';

void main() {
  Insight.attach();
  runApp(
    const ProviderScope(
      observers: [InsightRiverpodObserver()],
      child: ShelfApp(),
    ),
  );
}
