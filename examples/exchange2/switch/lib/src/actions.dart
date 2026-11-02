import 'dart:async';

import 'package:exchange2_agent/line_snapshot.dart';
import 'package:exchange2_rules/exchange.dart';
import 'package:flutter/foundation.dart';
import 'package:insight/insight.dart';

import 'store.dart';

/// A command the switch will not apply.
class SwitchFailure implements Exception {
  SwitchFailure(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

class _Wait {
  _Wait(this.after, this.done);

  final int after;
  final Completer<LineSnapshot> done;
}

/// Applies the call rules, writes the database, and wakes parked waits.
class SwitchActions extends ChangeNotifier {
  SwitchActions({required this.store});

  final SwitchStore store;

  /// The cubit or notifier assigns this so Insight sees the emit.
  void Function(Exchange value)? onChanged;

  Exchange exchange = Exchange.empty();
  var revision = 0;
  final log = <ActivityEntry>[];
  final _waiters = <int, List<_Wait>>{};

  Future<LineSnapshot> register(int number) {
    return _traced('POST register', () async {
      _knownNumber(number);
      if (exchange.has(number)) {
        return _snapshot(number);
      }
      exchange = exchange.register(number);
      revision += 1;
      await _writeLine(number);
      await _log(
        line: number,
        action: 'registered',
        detail: '$number registered',
      );
      _publish({number});
      return _snapshot(number);
    });
  }

  Future<LineSnapshot> hook(int number, {required bool off}) {
    return _traced('POST hook', () async {
      final phone = _require(number);
      if (phone.hookOn != off) {
        return _snapshot(number);
      }
      final before = exchange;
      exchange = off ? exchange.offHook(number) : exchange.onHook(number);
      if (exchange == before) {
        return _snapshot(number);
      }
      revision += 1;
      final changed = _changed(before);
      for (final line in changed) {
        await _writeLine(line);
      }
      final entry = _hookActivity(number, off: off, before: before);
      if (entry != null) {
        await _log(line: entry.line, action: entry.action, detail: entry.detail);
      }
      _publish(changed);
      return _snapshot(number);
    });
  }

  Future<LineSnapshot> digit(int number, int digit) {
    return _traced('POST digit', () async {
      final phone = _require(number);
      if (phone.hookOn) {
        throw SwitchFailure(409, 'Line $number is on hook.');
      }
      final before = exchange;
      exchange = exchange.dial(number, digit);
      if (exchange == before) {
        return _snapshot(number);
      }
      revision += 1;
      final changed = _changed(before);
      for (final line in changed) {
        await _writeLine(line);
      }
      final entry = _digitActivity(number, digit, before);
      await _log(line: entry.line, action: entry.action, detail: entry.detail);
      _publish(changed);
      return _snapshot(number);
    });
  }

  /// Completes when [number] changes, or after 25 seconds with the same revision.
  Future<LineSnapshot> wait(int number, {required int after}) async {
    _require(number);
    final current = _snapshot(number);
    if (current.revision > after) {
      return current;
    }
    final done = Completer<LineSnapshot>();
    final waiter = _Wait(after, done);
    _waiters.putIfAbsent(number, () => []).add(waiter);
    try {
      return await done.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          _waiters[number]?.remove(waiter);
          final held = _snapshot(number);
          return LineSnapshot(
            revision: after,
            number: held.number,
            hook: held.hook,
            signal: held.signal,
            detail: held.detail,
            digits: held.digits,
          );
        },
      );
    } on Object {
      _waiters[number]?.remove(waiter);
      rethrow;
    }
  }

  Future<T> _traced<T>(String name, Future<T> Function() body) {
    return Insight.traceFuture(body(), name: name);
  }

  void _knownNumber(int number) {
    if (number < 1 || number > exchange.lineCount) {
      throw SwitchFailure(404, 'Line $number is not a line.');
    }
  }

  Line _require(int number) {
    _knownNumber(number);
    if (!exchange.has(number)) {
      throw SwitchFailure(404, 'Line $number is not registered.');
    }
    return exchange.line(number);
  }

  Future<void> _writeLine(int number) {
    return Insight.traceFuture(
      store.replaceLine(StoredLine.from(exchange.line(number), revision)),
      name: 'update line',
    );
  }

  Future<void> _log({
    required int line,
    required String action,
    required String detail,
  }) async {
    final entry = ActivityEntry(
      id: 0,
      line: line,
      action: action,
      detail: detail,
      at: DateTime.now().toIso8601String(),
    );
    final id = await Insight.traceFuture(
      store.insertActivity(entry),
      name: 'insert activity',
    );
    log.add(
      ActivityEntry(
        id: id,
        line: entry.line,
        action: entry.action,
        detail: entry.detail,
        at: entry.at,
      ),
    );
  }

  Set<int> _changed(Exchange before) {
    final changed = <int>{};
    for (final line in exchange.lines) {
      if (!before.has(line.number) || before.line(line.number) != line) {
        changed.add(line.number);
      }
    }
    return changed;
  }

  void _publish(Set<int> changed) {
    onChanged?.call(exchange);
    notifyListeners();
    for (final number in changed) {
      final waiting = _waiters.remove(number);
      if (waiting == null) {
        continue;
      }
      final snapshot = _snapshot(number);
      for (final waiter in waiting) {
        if (!waiter.done.isCompleted && snapshot.revision > waiter.after) {
          waiter.done.complete(snapshot);
        }
      }
    }
  }

  LineSnapshot _snapshot(int number) {
    final line = exchange.line(number);
    final showDigits =
        line.status == LineStatus.dialing || line.status == LineStatus.busyTone;
    return LineSnapshot(
      revision: revision,
      number: number,
      hook: line.hookOn ? 'on' : 'off',
      signal: line.signal.name,
      detail: line.detail,
      digits: [
        if (showDigits) ...[
          for (final other in exchange.lines) '${other.number}',
          '0',
        ],
      ],
    );
  }

  ActivityEntry? _hookActivity(
    int number, {
    required bool off,
    required Exchange before,
  }) {
    final recall = _newRecall(before);
    if (recall != null) {
      return ActivityEntry(
        id: 0,
        line: recall,
        action: 'ringing',
        detail: '$recall ringing',
        at: '',
      );
    }
    return ActivityEntry(
      id: 0,
      line: number,
      action: off ? 'hook off' : 'hook on',
      detail: off ? '$number hook off' : '$number hook on',
      at: '',
    );
  }

  ActivityEntry _digitActivity(int number, int digit, Exchange before) {
    final recall = _newRecall(before);
    if (recall != null) {
      return ActivityEntry(
        id: 0,
        line: recall,
        action: 'ringing',
        detail: '$recall ringing',
        at: '',
      );
    }
    final acted = exchange.line(number);
    final wasWaiting =
        before.has(number) && before.line(number).status == LineStatus.waiting;
    if (acted.status == LineStatus.noSuchLine) {
      return ActivityEntry(
        id: 0,
        line: number,
        action: 'missing',
        detail: '$number line does not exist',
        at: '',
      );
    }
    if (acted.status == LineStatus.waiting && !wasWaiting) {
      return ActivityEntry(
        id: 0,
        line: number,
        action: 'waiting',
        detail: '$number waiting for ${acted.waitingFor}',
        at: '',
      );
    }
    return ActivityEntry(
      id: 0,
      line: number,
      action: 'digit',
      detail: '$number digit $digit',
      at: '',
    );
  }

  int? _newRecall(Exchange before) {
    for (final line in exchange.lines) {
      if (line.status != LineStatus.recall) {
        continue;
      }
      final previous = before.has(line.number)
          ? before.line(line.number)
          : null;
      if (previous == null || previous.status != LineStatus.recall) {
        return line.number;
      }
    }
    return null;
  }
}
