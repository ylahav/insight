import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'src/pair_view.dart';
import 'src/result.dart';
import 'src/run_view.dart';

const _panel = Color(0xff1e3330);

/// Where Export taps writes the scenario, next to the opened result.
File tapsFileFor(String opened, String? scenarioPath) {
  final name = scenarioPath == null
      ? 'scenario.txt'
      : scenarioPath.split(RegExp(r'[\\/]')).last;
  return File('${File(opened).parent.path}${Platform.pathSeparator}$name');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnalyzerApp());
}

class AnalyzerApp extends StatefulWidget {
  const AnalyzerApp({super.key});

  @override
  State<AnalyzerApp> createState() => _AnalyzerAppState();
}

class _AnalyzerAppState extends State<AnalyzerApp> {
  final List<OpenedRun> _runs = [];
  Object? _error;
  String? _exported;

  Future<void> _select() async {
    final chosen = await _choose();
    if (chosen == null) {
      return;
    }
    try {
      final run = await _open(chosen.path);
      setState(() {
        _runs
          ..clear()
          ..add(run);
        _error = null;
        _exported = null;
      });
    } on Object catch (error) {
      setState(() {
        _runs.clear();
        _error = error;
        _exported = null;
      });
    }
  }

  Future<void> _add() async {
    final chosen = await _choose();
    if (chosen == null) {
      return;
    }
    try {
      final run = await _open(chosen.path);
      setState(() {
        _runs.add(run);
        _error = null;
        _exported = null;
      });
    } on Object catch (error) {
      setState(() => _error = error);
    }
  }

  Future<XFile?> _choose() {
    return openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
  }

  Future<OpenedRun> _open(String path) async {
    final decoded = jsonDecode(await File(path).readAsString());
    return OpenedRun(path: path, result: readRunResult(decoded));
  }

  Future<void> _export(int index) async {
    final run = _runs[index];
    final taps = run.result.taps;
    if (taps == null) {
      return;
    }
    final out = tapsFileFor(run.path, run.result.scenarioPath);
    await out.writeAsString(taps);
    setState(() => _exported = out.path);
  }

  void _remove(int index) {
    setState(() {
      _runs.removeAt(index);
      _error = null;
      _exported = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Analyzer',
      home: AnalyzerHome(
        runs: _runs,
        error: _error,
        exportedPath: _exported,
        onSelect: _select,
        onAdd: _add,
        onExport: _export,
        onRemove: _remove,
      ),
    );
  }
}

class AnalyzerHome extends StatelessWidget {
  const AnalyzerHome({
    required this.runs,
    required this.onSelect,
    required this.onAdd,
    required this.onExport,
    required this.onRemove,
    this.error,
    this.exportedPath,
    super.key,
  });

  final List<OpenedRun> runs;
  final Object? error;
  final String? exportedPath;
  final VoidCallback onSelect;
  final VoidCallback onAdd;
  final void Function(int index) onExport;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final first = runs.isEmpty ? null : runs.first;
    return Scaffold(
      backgroundColor: _panel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('select-file'),
                  onPressed: onSelect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: enamel,
                    side: const BorderSide(color: cord),
                  ),
                  child: const Text('Select file'),
                ),
                if (first != null)
                  OutlinedButton(
                    key: const Key('add-result'),
                    onPressed: onAdd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: enamel,
                      side: const BorderSide(color: cord),
                    ),
                    child: const Text('Add result'),
                  ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Text(
                '$error',
                key: const Key('open-error'),
                style: const TextStyle(
                  color: Color(0xffd24b3a),
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          Expanded(
            child: first == null
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(28, 24, 28, 0),
                    child: Text(
                      'Select a recording.',
                      style: TextStyle(
                        color: enamel,
                        fontSize: 18,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  )
                : runs.length == 1
                ? RunView(
                    run: first,
                    onExport: () => onExport(0),
                    exportedPath: exportedPath,
                  )
                : runs.length == 2
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                    children: [
                      PairView(
                        left: first,
                        right: runs[1],
                        rightIndex: 1,
                        onExport: onExport,
                        onRemove: () => onRemove(1),
                        exportedPath: exportedPath,
                      ),
                    ],
                  )
                : ResultsRow(
                    runs: runs,
                    onExport: onExport,
                    onRemove: onRemove,
                    exportedPath: exportedPath,
                  ),
          ),
        ],
      ),
    );
  }
}
