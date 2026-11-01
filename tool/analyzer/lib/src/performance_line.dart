import 'package:flutter/material.dart';
import 'package:insight_collector/insight_collector.dart';

import 'run_view.dart';
import 'times.dart';

/// The frame line, with the shortest time marked best and the longest worst.
class PerformanceLine extends StatelessWidget {
  const PerformanceLine({
    required this.line,
    required this.lines,
    super.key,
  });

  final BesideLine line;
  final List<BesideLine?> lines;

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(
      fontSize: 15,
      height: 1.3,
      fontFamily: 'Georgia',
      color: enamel,
    );
    if (line.elapsedUs == null) {
      return Text(line.detail, style: style);
    }
    final frame = _frameId(line.detail);
    final build = timeMark(line.buildUs, lines.map((item) => item?.buildUs));
    final raster = timeMark(line.rasterUs, lines.map((item) => item?.rasterUs));
    final elapsed = timeMark(
      line.elapsedUs,
      lines.map((item) => item?.elapsedUs),
    );
    final hasParts = line.buildUs != null && line.rasterUs != null;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (hasParts) ...[
            _part('build ', line.buildUs!, build),
            const TextSpan(text: ' · '),
            _part('raster ', line.rasterUs!, raster),
            const TextSpan(text: ' · '),
            _part('elapsed ', line.elapsedUs!, elapsed),
          ] else
            _part('', line.elapsedUs!, elapsed),
          if (frame != null) TextSpan(text: ' · $frame'),
        ],
      ),
    );
  }

  TextSpan _part(String label, int microseconds, TimeMark mark) {
    return TextSpan(
      text: '$label${timeText(microseconds, mark)}',
      style: TextStyle(color: _color(mark)),
    );
  }

  Color _color(TimeMark mark) {
    return switch (mark) {
      TimeMark.best => bestTime,
      TimeMark.worst => worstTime,
      TimeMark.none => enamel,
    };
  }
}

String? _frameId(String detail) {
  final match = RegExp(r'frame_\w+').firstMatch(detail);
  return match?.group(0);
}
