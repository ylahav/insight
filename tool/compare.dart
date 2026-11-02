import 'dart:convert';
import 'dart:io';

import 'package:insight_collector/insight_collector.dart';

import 'repository.dart';

/// Prints two session files in two columns, and can write one results file.
///
/// Each recording stores the scenario `tool/play.dart` ran. This tool reads
/// those stamps. The results file says whether the taps were the same.
/// `tool/analyzer` opens each recording, then another beside the first.
///
/// ```text
/// dart run tool/compare.dart --left a.json --right b.json --out compare.json
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
  final played = scenarioReading(left: left.play, right: right.play);
  stdout.writeln(played.note);
  stdout.writeln('');
  _print(
    options.left!,
    left.lines,
    options.right!,
    right.lines,
    leftBoard: left.play?.board,
    rightBoard: right.play?.board,
  );
  final out = options.out;
  if (out == null) {
    return;
  }
  final root = findRepository();
  final scenarioPath = played.same == true ? left.play?.path : null;
  final document = compareDocument(
    left: left.lines,
    right: right.lines,
    leftPath: options.left!,
    rightPath: options.right!,
    leftMode: left.mode,
    rightMode: right.mode,
    leftStartedAt: left.startedAt,
    rightStartedAt: right.startedAt,
    leftPlay: left.play,
    rightPlay: right.play,
    git: root == null ? null : await _git(root, scenarioPath),
  );
  final file = File(out);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(document)}\n',
  );
  stdout.writeln('');
  stdout.writeln('Wrote ${file.path}.');
}

Future<
  ({
    List<BesideLine> lines,
    String? mode,
    String? startedAt,
    PlayedScenario? play,
  })?
>
_load(String path) async {
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
  final mode = decoded['mode'];
  final startedAt = decoded['startedAt'];
  return (
    lines: besideLines(
      events.whereType<Map>().map((event) {
        return event.cast<String, Object?>();
      }),
    ),
    mode: mode is String ? mode : null,
    startedAt: startedAt is String ? startedAt : null,
    play: PlayedScenario.fromSession(decoded),
  );
}

void _print(
  String leftPath,
  List<BesideLine> left,
  String rightPath,
  List<BesideLine> right, {
  String? leftBoard,
  String? rightBoard,
}) {
  stdout.writeln('Time grouping, not a cause.');
  stdout.writeln(
    'Steps pair by order. A recorded tap is the line above the change. '
    'The change is the next line. '
    'The second line is that frame. Profile frames list build, raster, and elapsed. '
    'Elapsed is the whole frame. The rows under that are the widgets that rebuilt. '
    'A widget in both files shares a row. The widgets do not divide the frame time.',
  );
  stdout.writeln(_fileLine('left', leftPath, leftBoard));
  stdout.writeln(_fileLine('right', rightPath, rightBoard));
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
    final leftLine = i < left.length ? left[i] : null;
    final rightLine = i < right.length ? right[i] : null;
    if (leftLine?.action != null || rightLine?.action != null) {
      stdout.writeln(_format(leftLine?.action, rightLine?.action, width));
    }
    final rows = besideStepRows(
      i < left.length ? left[i] : null,
      i < right.length ? right[i] : null,
    );
    for (final row in rows) {
      stdout.writeln(_format(row.$1, row.$2, width));
    }
  }
  final reading = besideReading(
    left,
    right,
    leftName: leftBoard,
    rightName: rightBoard,
  );
  if (reading.isNotEmpty) {
    stdout.writeln('');
    for (final line in reading) {
      stdout.writeln(line);
    }
  }
}

String _fileLine(String side, String path, String? board) {
  final label = side == 'left' ? 'left   ' : 'right  ';
  if (board == null || board.isEmpty) {
    return '$label$path';
  }
  return '$label$path  $board';
}

int _columnWidth(List<BesideLine> left) {
  var width = '—'.length;
  for (final line in left) {
    final action = line.action;
    if (action != null && action.length > width) {
      width = action.length;
    }
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

Future<Map<String, Object?>> _git(Directory root, String? scenarioPath) async {
  Future<String> read(List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: root.path,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      return '';
    }
    return (result.stdout as String).trim();
  }

  final commit = await read(['rev-parse', 'HEAD']);
  final branch = await read(['rev-parse', '--abbrev-ref', 'HEAD']);
  final subject = await read(['log', '-1', '--format=%s']);
  var scenarioDirty = false;
  if (scenarioPath != null) {
    final status = await read(['status', '--porcelain', '--', scenarioPath]);
    scenarioDirty = status.isNotEmpty;
  }
  return {
    if (commit.isNotEmpty) 'commit': commit,
    if (branch.isNotEmpty) 'branch': branch,
    if (subject.isNotEmpty) 'subject': subject,
    if (scenarioPath != null) 'scenarioDirty': scenarioDirty,
  };
}

class _Options {
  _Options({this.left, this.right, this.out, this.help = false});

  final String? left;
  final String? right;
  final String? out;
  final bool help;
}

_Options? _parse(List<String> arguments) {
  String? left;
  String? right;
  String? out;
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
      case '--out':
        out = next();
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
  return _Options(left: left, right: right, out: out);
}

const _usage = '''
Prints two schema-1 sessions in two columns. A shared widget is one row.
The exit code is 0 either way.

Each session must carry the scenario tool/play.dart stored. The first line
says whether those taps are the same. --out writes that same reading
to one file. `tool/analyzer` opens the recordings themselves.

compare --left path --right path [--out compare.json]

From a checkout: dart run tool/compare.dart --left path --right path [--out compare.json]
''';
