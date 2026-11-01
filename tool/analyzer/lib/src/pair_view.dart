import 'package:flutter/material.dart';
import 'package:insight_collector/insight_collector.dart';

import 'performance_line.dart';
import 'result.dart';
import 'run_view.dart';

/// Every open recording in one row. Two recordings keep the paired rows in
/// [PairView]. A third recording stays on that same row.
class ResultsRow extends StatelessWidget {
  const ResultsRow({
    required this.runs,
    required this.onExport,
    required this.onRemove,
    this.exportedPath,
    super.key,
  });

  final List<OpenedRun> runs;
  final void Function(int index) onExport;
  final void Function(int index) onRemove;
  final String? exportedPath;

  @override
  Widget build(BuildContext context) {
    final steps = runs
        .map((run) => run.result.lines.length)
        .fold<int>(0, (longest, count) => count > longest ? count : longest);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < runs.length; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              Expanded(
                child: _Heading(
                  run: runs[i],
                  onRemove: i == 0 ? null : () => onRemove(i),
                  removeKey: i == 0 ? null : Key('remove-result-$i'),
                ),
              ),
            ],
          ],
        ),
        for (var step = 0; step < steps; step++) ...[
          const SizedBox(height: 18),
          Text(
            '${step + 1}.',
            style: const TextStyle(
              color: cord,
              fontSize: 16,
              fontFamily: 'Georgia',
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < runs.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                Expanded(
                  child: _LineColumn(
                    result: runs[i].result,
                    step: step,
                    lines: [
                      for (final run in runs)
                        step < run.result.lines.length
                            ? run.result.lines[step]
                            : null,
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
        if (runs.any((run) => run.result.taps != null)) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < runs.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                Expanded(
                  child: runs[i].result.taps == null
                      ? const SizedBox.shrink()
                      : _Export(
                          buttonKey: Key(i == 0 ? 'export-taps' : 'export-taps-$i'),
                          onPressed: () => onExport(i),
                        ),
                ),
              ],
            ],
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

class _LineColumn extends StatelessWidget {
  const _LineColumn({
    required this.result,
    required this.step,
    required this.lines,
  });

  final RunResult result;
  final int step;
  final List<BesideLine?> lines;

  @override
  Widget build(BuildContext context) {
    if (step >= result.lines.length) {
      return const SizedBox.shrink();
    }
    final line = result.lines[step];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (line.action != null)
          Text(
            line.action!,
            style: const TextStyle(
              color: cord,
              fontSize: 15,
              height: 1.3,
              fontFamily: 'Georgia',
            ),
          ),
        Text(
          line.title,
          style: const TextStyle(
            color: cord,
            fontSize: 15,
            height: 1.3,
            fontFamily: 'Georgia',
          ),
        ),
        if (line.detail.isNotEmpty)
          PerformanceLine(line: line, lines: lines),
        for (final name in line.widgets)
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
          rebuiltCount(line.widgets.length),
          style: const TextStyle(
            color: cord,
            fontSize: 15,
            fontFamily: 'Georgia',
          ),
        ),
      ],
    );
  }
}

class PairView extends StatelessWidget {
  const PairView({
    required this.left,
    required this.right,
    required this.rightIndex,
    required this.onExport,
    required this.onRemove,
    this.exportedPath,
    super.key,
  });

  final OpenedRun left;
  final OpenedRun right;
  final int rightIndex;
  final void Function(int index) onExport;
  final VoidCallback onRemove;
  final String? exportedPath;

  @override
  Widget build(BuildContext context) {
    final pair = readPair(left.result, right.result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pair.note,
          key: const Key('scenario-note'),
          style: const TextStyle(
            color: cord,
            fontSize: 18,
            height: 1.35,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Heading(run: left)),
            const SizedBox(width: 24),
            Expanded(
              child: _Heading(
                run: right,
                onRemove: onRemove,
                removeKey: Key('remove-result-$rightIndex'),
              ),
            ),
          ],
        ),
        for (var step = 0; step < pair.rows.length; step++) ...[
          const SizedBox(height: 18),
          Text(
            '${step + 1}.',
            style: const TextStyle(
              color: cord,
              fontSize: 16,
              fontFamily: 'Georgia',
            ),
          ),
          if (step < left.result.lines.length &&
                  left.result.lines[step].action != null ||
              step < right.result.lines.length &&
                  right.result.lines[step].action != null)
            _RowText(
              left: step < left.result.lines.length
                  ? left.result.lines[step].action
                  : null,
              right: step < right.result.lines.length
                  ? right.result.lines[step].action
                  : null,
              title: true,
            ),
          for (var row = 0; row < pair.rows[step].length; row++)
            if (row == 1)
              _PerformanceRow(
                left: step < left.result.lines.length
                    ? left.result.lines[step]
                    : null,
                right: step < right.result.lines.length
                    ? right.result.lines[step]
                    : null,
              )
            else
              _RowText(
                left: pair.rows[step][row].$1,
                right: pair.rows[step][row].$2,
                title: row == 0,
              ),
          _RowText(
            left: step < left.result.lines.length
                ? rebuiltCount(left.result.lines[step].widgets.length)
                : null,
            right: step < right.result.lines.length
                ? rebuiltCount(right.result.lines[step].widgets.length)
                : null,
            title: true,
          ),
        ],
        for (final line in pair.reading) ...[
          const SizedBox(height: 12),
          Text(
            line,
            style: const TextStyle(
              color: enamel,
              fontSize: 16,
              height: 1.35,
              fontFamily: 'Georgia',
            ),
          ),
        ],
        if (left.result.taps != null || right.result.taps != null) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: left.result.taps == null
                    ? const SizedBox.shrink()
                    : _Export(
                        buttonKey: const Key('export-taps'),
                        onPressed: () => onExport(0),
                      ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: right.result.taps == null
                    ? const SizedBox.shrink()
                    : _Export(
                        buttonKey: Key('export-taps-$rightIndex'),
                        onPressed: () => onExport(rightIndex),
                      ),
              ),
            ],
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
        const SizedBox(height: 28),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.run, this.onRemove, this.removeKey});

  final OpenedRun run;
  final VoidCallback? onRemove;
  final Key? removeKey;

  @override
  Widget build(BuildContext context) {
    final result = run.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recordingName(run.path),
          style: const TextStyle(
            color: cord,
            fontSize: 16,
            fontFamily: 'Georgia',
          ),
        ),
        if (result.heading.isNotEmpty)
          Text(
            result.heading,
            style: const TextStyle(
              color: enamel,
              fontSize: 15,
              fontFamily: 'Georgia',
            ),
          ),
        if (result.gitLine != null)
          Text(
            result.gitLine!,
            style: const TextStyle(
              color: enamel,
              fontSize: 15,
              height: 1.3,
              fontFamily: 'Georgia',
            ),
          ),
        if (onRemove != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: removeKey,
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: enamel,
                side: const BorderSide(color: cord),
              ),
              child: const Text('Remove'),
            ),
          ),
      ],
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.left, required this.right});

  final BesideLine? left;
  final BesideLine? right;

  @override
  Widget build(BuildContext context) {
    if ((left == null || left!.detail.isEmpty) &&
        (right == null || right!.detail.isEmpty)) {
      return const SizedBox.shrink();
    }
    final lines = [left, right];
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: left == null || left!.detail.isEmpty
                ? const SizedBox.shrink()
                : PerformanceLine(line: left!, lines: lines),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: right == null || right!.detail.isEmpty
                ? const SizedBox.shrink()
                : PerformanceLine(line: right!, lines: lines),
          ),
        ],
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({
    required this.left,
    required this.right,
    required this.title,
  });

  final String? left;
  final String? right;
  final bool title;

  @override
  Widget build(BuildContext context) {
    if ((left == null || left!.isEmpty) && (right == null || right!.isEmpty)) {
      return const SizedBox.shrink();
    }
    final style = TextStyle(
      color: title ? cord : enamel,
      fontSize: 15,
      height: 1.3,
      fontFamily: 'Georgia',
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(left ?? '', style: style)),
          const SizedBox(width: 24),
          Expanded(child: Text(right ?? '', style: style)),
        ],
      ),
    );
  }
}

class _Export extends StatelessWidget {
  const _Export({required this.buttonKey, required this.onPressed});

  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: enamel,
          side: const BorderSide(color: cord),
        ),
        child: const Text('Export taps'),
      ),
    );
  }
}
