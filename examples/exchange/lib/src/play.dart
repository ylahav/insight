import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Plays the steps in [script] on [board].
///
/// Each line is `tap <key>` or `see <text>`. A `#` line is a comment.
/// `tap open` presses the button for [board]: `bloc`, `riverpod`, `wide`, or
/// `plinth`.
/// Recording sends the file text through `ext.flutter.exchange.play` after the
/// collector is listening, so both runs follow the file and not a fixed ring.
Future<void> playScript(
  String script,
  String board, {
  Future<void> Function(String keyName)? tap,
  Future<void> Function()? settle,
}) async {
  final open = switch (board) {
    'bloc' => 'open-bloc',
    'riverpod' => 'open-riverpod',
    'wide' => 'open-wide',
    'plinth' => 'open-plinth',
    _ => throw ArgumentError(
      'Unknown board $board. Use bloc, riverpod, wide, or plinth.',
    ),
  };
  final steps = _readScenario(script);

  Future<void> frames([int count = 1]) async {
    for (var i = 0; i < count; i++) {
      if (settle != null) {
        await settle();
      } else {
        await _nextFrame();
      }
    }
  }

  Future<void> press(String name) async {
    final keyName = name == 'open' ? open : name;
    await _untilHit(keyName, frames);
    if (tap != null) {
      await tap(keyName);
    } else {
      _pointerTap(keyName);
    }
    await frames(2);
  }

  await frames();
  for (final step in steps) {
    switch (step) {
      case _Tap(:final key):
        await press(key);
      case _See(:final text):
        await _untilText(text, frames);
    }
  }
}

/// Registers the player on the VM service. The name the collector calls is
/// `ext.flutter.exchange.play`. The call carries the scenario file as `script`.
void registerExchangePlay(String board) {
  WidgetsBinding.instance.registerServiceExtension(
    name: 'exchange.play',
    callback: (parameters) async {
      final script = parameters['script'];
      if (script == null || script.isEmpty) {
        throw StateError('The play call did not include a script.');
      }
      await playScript(script, board);
      return {'result': 'called'};
    },
  );
}

sealed class _Step {}

class _Tap extends _Step {
  _Tap(this.key);

  final String key;
}

class _See extends _Step {
  _See(this.text);

  final String text;
}

List<_Step> _readScenario(String source) {
  final steps = <_Step>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final space = line.indexOf(' ');
    if (space <= 0) {
      throw FormatException('Line ${i + 1} needs a command and a target.');
    }
    final command = line.substring(0, space);
    final target = line.substring(space + 1).trim();
    if (target.isEmpty) {
      throw FormatException('Line ${i + 1} needs a target.');
    }
    switch (command) {
      case 'tap':
        steps.add(_Tap(target));
      case 'see':
        steps.add(_See(target));
      default:
        throw FormatException('Line ${i + 1} uses "$command". Use tap or see.');
    }
  }
  if (steps.isEmpty) {
    throw FormatException('The scenario has no steps.');
  }
  return steps;
}

Future<void> _nextFrame() {
  final done = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!done.isCompleted) {
      done.complete();
    }
  });
  WidgetsBinding.instance.scheduleFrame();
  return done.future;
}

Future<void> _untilHit(
  String name,
  Future<void> Function([int count]) frames,
) async {
  for (var i = 0; i < 90; i++) {
    if (_isHit(Key(name))) {
      return;
    }
    await frames();
  }
  throw StateError('The board never offered $name.');
}

Future<void> _untilText(
  String text,
  Future<void> Function([int count]) frames,
) async {
  for (var i = 0; i < 90; i++) {
    if (_hasText(text)) {
      return;
    }
    await frames();
  }
  throw StateError('The board never showed "$text".');
}

void _pointerTap(String name) {
  final element = _element(Key(name));
  if (element == null) {
    throw StateError('The board has no $name.');
  }
  final object = element.renderObject;
  if (object is! RenderBox || !object.hasSize) {
    throw StateError('$name is not on screen.');
  }
  final position = object.localToGlobal(object.size.center(Offset.zero));
  final viewId = View.of(element).viewId;
  final binding = WidgetsBinding.instance;
  binding.handlePointerEvent(
    PointerDownEvent(
      viewId: viewId,
      position: position,
      pointer: 1,
      kind: PointerDeviceKind.touch,
      buttons: kPrimaryButton,
    ),
  );
  binding.handlePointerEvent(
    PointerUpEvent(
      viewId: viewId,
      position: position,
      pointer: 1,
      kind: PointerDeviceKind.touch,
    ),
  );
}

bool _isHit(Key key) {
  final element = _element(key);
  if (element == null) {
    return false;
  }
  final object = element.renderObject;
  if (object is! RenderBox || !object.hasSize || !object.attached) {
    return false;
  }
  final position = object.localToGlobal(object.size.center(Offset.zero));
  final result = HitTestResult();
  GestureBinding.instance.hitTestInView(
    result,
    position,
    View.of(element).viewId,
  );
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderObject && _owns(object, target)) {
      return true;
    }
  }
  return false;
}

bool _owns(RenderObject keyed, RenderObject target) {
  RenderObject? current = target;
  while (current != null) {
    if (identical(current, keyed)) {
      return true;
    }
    final parent = current.parent;
    current = parent is RenderObject ? parent : null;
  }
  return false;
}

bool _hasText(String text) {
  var found = false;
  void visit(Element element) {
    if (found) {
      return;
    }
    final widget = element.widget;
    if (widget is Text && widget.data == text) {
      found = true;
      return;
    }
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) {
    visit(root);
  }
  return found;
}

Element? _element(Key key) {
  Element? match;
  void visit(Element element) {
    if (match != null) {
      return;
    }
    if (element.widget.key == key) {
      match = element;
      return;
    }
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) {
    visit(root);
  }
  return match;
}
