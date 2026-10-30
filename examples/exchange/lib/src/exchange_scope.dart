import 'package:flutter/widgets.dart';

import 'exchange.dart';

/// The line count chosen before the board opened. It does not change.
class LineCountScope extends InheritedWidget {
  const LineCountScope({
    required this.lineCount,
    required super.child,
    super.key,
  });

  final int lineCount;

  static int of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LineCountScope>();
    return scope!.lineCount;
  }

  @override
  bool updateShouldNotify(LineCountScope oldWidget) =>
      lineCount != oldWidget.lineCount;
}

/// Stable actions. The host keeps the same function identities across rebuilds
/// so a phone does not rebuild just because the switch emitted.
class ExchangeActions extends InheritedWidget {
  const ExchangeActions({
    required this.offHook,
    required this.onHook,
    required this.dial,
    required super.child,
    super.key,
  });

  final void Function(int number) offHook;
  final void Function(int number) onHook;
  final void Function(int number, int digit) dial;

  static ExchangeActions of(BuildContext context) {
    final actions = context
        .dependOnInheritedWidgetOfExactType<ExchangeActions>();
    return actions!;
  }

  @override
  bool updateShouldNotify(ExchangeActions oldWidget) {
    return offHook != oldWidget.offHook ||
        onHook != oldWidget.onHook ||
        dial != oldWidget.dial;
  }
}

/// Notifies a phone when its own line changes, and the cords when a call or
/// a camp-on request changes.
class ExchangeScope extends InheritedModel<int> {
  const ExchangeScope({
    required this.exchange,
    required super.child,
    super.key,
  });

  final Exchange exchange;

  /// Aspect for [SwitchDesk]. Line numbers start at 1.
  static const switchAspect = 0;

  static Line lineOf(BuildContext context, int number) {
    final scope = InheritedModel.inheritFrom<ExchangeScope>(
      context,
      aspect: number,
    );
    return scope!.exchange.line(number);
  }

  static Exchange switchOf(BuildContext context) {
    final scope = InheritedModel.inheritFrom<ExchangeScope>(
      context,
      aspect: switchAspect,
    );
    return scope!.exchange;
  }

  @override
  bool updateShouldNotify(ExchangeScope oldWidget) =>
      exchange != oldWidget.exchange;

  @override
  bool updateShouldNotifyDependent(
    ExchangeScope oldWidget,
    Set<int> dependencies,
  ) {
    for (final aspect in dependencies) {
      if (aspect == switchAspect) {
        if (!sameSwitchView(exchange, oldWidget.exchange)) {
          return true;
        }
      } else if (exchange.line(aspect) != oldWidget.exchange.line(aspect)) {
        return true;
      }
    }
    return false;
  }
}
