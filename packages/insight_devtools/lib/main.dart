import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/panel.dart';

void main() {
  runApp(const InsightDevToolsExtension());
}

class InsightDevToolsExtension extends StatelessWidget {
  const InsightDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: InsightPanel());
  }
}
