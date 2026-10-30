import 'dart:convert';
import 'dart:io';

import 'package:insight_collector/insight_collector.dart';

/// Prints two session files side by side.
///
/// The widget names can differ. That is the reading. The process exits 0
/// for any two schema-1 files.
///
/// ```text
/// dart run tool/beside.dart --left scoped.json --right wide.json
/// ```
Future<void> main(List<String> arguments) async {
  final options = _parse(arguments);
  if (options == null) {
    exitCode = 64;
    return;
  }
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }
  final left = await _load(options.left!);
  final right = await _load(options.right!);
  if (left == null || right == null) {
    exitCode = 1;
    return;
  }
  _print(options.left!, left, options.right!, right);
}

Future<List<BesideLine>?> _load(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No session file at $path.');
    return null;
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map || decoded['schemaVersion'] != 1) {
    stderr.writeln('$path is not a schema-1 session.');
    return null;
  }
  final events = decoded['events'];
  if (events is! List) {
    stderr.writeln('$path has no events list.');
    return null;
  }
  return besideLines(
    events.whereType<Map>().map((event) {
      return event.cast<String, Object?>();
    }),
  );
}

void _print(
  String leftPath,
  List<BesideLine> left,
  String rightPath,
  List<BesideLine> right,
) {
  stdout.writeln('Time grouping, not a cause.');
  stdout.writeln('left   $leftPath');
  stdout.writeln('right  $rightPath');
  final count = left.length > right.length ? left.length : right.length;
  if (count == 0) {
    stdout.writeln('');
    stdout.writeln('Neither file has a state change or an async span.');
    return;
  }
  final width = _columnWidth(left);
  for (var i = 0; i < count; i++) {
    stdout.writeln('');
    stdout.writeln('${i + 1}.');
    final rows = besideStepRows(
      i < left.length ? left[i] : null,
      i < right.length ? right[i] : null,
    );
    for (final row in rows) {
      stdout.writeln(_format(row.$1, row.$2, width));
    }
  }
}

int _columnWidth(List<BesideLine> left) {
  var width = '—'.length;
  for (final line in left) {
    if (line.title.length > width) {
      width = line.title.length;
    }
    if (line.detail.length > width) {
      width = line.detail.length;
    }
    for (final name in line.widgets) {
      if (name.length > width) {
        width = name.length;
      }
    }
  }
  return width;
}

String _format(String? left, String? right, int width) {
  final leftText = left ?? '';
  final rightText = right ?? '';
  if (rightText.isEmpty) {
    return leftText;
  }
  return '${leftText.padRight(width)}  $rightText';
}

class _Options {
  _Options({this.left, this.right, this.help = false});

  final String? left;
  final String? right;
  final bool help;
}

_Options? _parse(List<String> arguments) {
  String? left;
  String? right;
  for (var i = 0; i < arguments.length; i++) {
    String? next() {
      if (i + 1 >= arguments.length) {
        return null;
      }
      return arguments[++i];
    }

    switch (arguments[i]) {
      case '--left':
        left = next();
      case '--right':
        right = next();
      case '--help' || '-h':
        return _Options(help: true);
      default:
        stderr.writeln('Unknown argument ${arguments[i]}.');
        stderr.writeln(_usage);
        return null;
    }
  }
  if (left == null || right == null) {
    stderr.writeln(_usage);
    return null;
  }
  return _Options(left: left, right: right);
}

const _usage = '''
Prints two schema-1 sessions in two columns. A shared widget name is one row.
The exit code is 0 either way.

dart run tool/beside.dart --left path --right path
''';
