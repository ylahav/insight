import 'package:flutter/material.dart';

import 'result.dart';

const enamel = Color(0xffd5ddd6);
const cord = Color(0xffe0a84a);
const bestTime = Color(0xff8fd0a8);
const worstTime = Color(0xffd24b3a);

class RunView extends StatelessWidget {
  const RunView({
    required this.run,
    required this.onExport,
    this.exportedPath,
    super.key,
  });

  final OpenedRun run;
  final VoidCallback? onExport;
  final String? exportedPath;

  @override
  Widget build(BuildContext context) {
    final result = run.result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        Text(
          recordingName(run.path),
          style: const TextStyle(
            color: cord,
            fontSize: 18,
            height: 1.35,
            fontFamily: 'Georgia',
          ),
        ),
        if (result.scenarioNote != null) ...[
          const SizedBox(height: 6),
          Text(
            result.scenarioNote!,
            key: const Key('scenario-note'),
            style: const TextStyle(
              color: enamel,
              fontSize: 16,
              height: 1.35,
              fontFamily: 'Georgia',
            ),
          ),
        ],
        if (result.heading.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            result.heading,
            style: const TextStyle(
              color: enamel,
              fontSize: 16,
              fontFamily: 'Georgia',
            ),
          ),
        ],
        if (result.gitLine != null) ...[
          const SizedBox(height: 8),
          Text(
            result.gitLine!,
            style: const TextStyle(
              color: enamel,
              fontSize: 16,
              fontFamily: 'Georgia',
            ),
          ),
        ],
        for (var i = 0; i < result.steps.length; i++) ...[
          const SizedBox(height: 18),
          Text(
            '${i + 1}.',
            style: const TextStyle(
              color: cord,
              fontSize: 16,
              fontFamily: 'Georgia',
            ),
          ),
          if (result.steps[i].action != null)
            Text(
              result.steps[i].action!,
              style: const TextStyle(
                color: cord,
                fontSize: 16,
                fontFamily: 'Georgia',
              ),
            ),
          const SizedBox(height: 6),
          Text(
            result.steps[i].title,
            style: const TextStyle(
              color: enamel,
              fontSize: 16,
              fontFamily: 'Georgia',
            ),
          ),
          if (result.steps[i].detail.isNotEmpty)
            Text(
              result.steps[i].detail,
              style: const TextStyle(
                color: enamel,
                fontSize: 15,
                fontFamily: 'Georgia',
              ),
            ),
          for (final name in result.steps[i].widgets)
            Text(
              name,
              style: const TextStyle(
                color: enamel,
                fontSize: 15,
                height: 1.3,
                fontFamily: 'Georgia',
              ),
            ),
          Text(
            rebuiltCount(result.steps[i].widgets.length),
            style: const TextStyle(
              color: cord,
              fontSize: 15,
              fontFamily: 'Georgia',
            ),
          ),
        ],
        if (result.taps != null) ...[
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('export-taps'),
              onPressed: onExport,
              style: OutlinedButton.styleFrom(
                foregroundColor: enamel,
                side: const BorderSide(color: cord),
              ),
              child: const Text('Export taps'),
            ),
          ),
        ],
        if (exportedPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Wrote $exportedPath',
              key: const Key('exported-path'),
              style: const TextStyle(
                color: cord,
                fontSize: 14,
                fontFamily: 'Georgia',
              ),
            ),
          ),
      ],
    );
  }
}
