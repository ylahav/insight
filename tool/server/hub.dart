import 'dart:async';

import 'script.dart';

/// One program that registered with the Insight server.
class Registration {
  const Registration({
    required this.role,
    required this.name,
    required this.instance,
    required this.vmServiceUri,
  });

  final String role;
  final String name;
  final String instance;
  final String vmServiceUri;

  String get id => '$name/$instance';
}

/// A tap or a see sent to one registered program.
class StepCommand {
  const StepCommand({
    required this.id,
    required this.command,
    this.target,
    this.text,
  });

  final String id;
  final String command;
  final String? target;
  final String? text;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'command': command,
      if (target != null) 'target': target,
      if (text != null) 'text': text,
    };
  }
}

class _Agent {
  _Agent(this.registration);

  Registration registration;
  StepCommand? pending;
  String? outstanding;
  Completer<StepCommand?>? poll;
  Completer<void>? done;
}

/// Registrations and the one command each program is running.
class Hub {
  final _agents = <String, _Agent>{};
  final _arrived = <String, List<Completer<void>>>{};
  var _ids = 0;

  bool isRegistered(String name, String instance) {
    return _agents.containsKey('$name/$instance');
  }

  Registration? lookup(String name, String instance) {
    return _agents['$name/$instance']?.registration;
  }

  void register(Registration registration) {
    final agent = _agents[registration.id];
    if (agent == null) {
      _agents[registration.id] = _Agent(registration);
    } else {
      agent.registration = registration;
    }
    final waiters = _arrived.remove(registration.id);
    if (waiters == null) {
      return;
    }
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
  }

  Future<void> waitUntil(
    String name,
    String instance, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final id = '$name/$instance';
    if (_agents.containsKey(id)) {
      return;
    }
    final waiter = Completer<void>();
    _arrived.putIfAbsent(id, () => []).add(waiter);
    try {
      await waiter.future.timeout(timeout);
    } on TimeoutException {
      throw StateError('$name $instance did not register.');
    }
  }

  /// The next command, or null when [wait] passes with nothing to do.
  Future<StepCommand?> poll(
    String name,
    String instance, {
    Duration wait = const Duration(seconds: 25),
  }) async {
    final agent = _agents['$name/$instance'];
    if (agent == null) {
      throw StateError('$name $instance is not registered.');
    }
    final pending = agent.pending;
    if (pending != null) {
      agent.pending = null;
      return pending;
    }
    final waiter = Completer<StepCommand?>();
    agent.poll = waiter;
    try {
      return await waiter.future.timeout(
        wait,
        onTimeout: () {
          if (identical(agent.poll, waiter)) {
            agent.poll = null;
          }
          return null;
        },
      );
    } on Object {
      if (identical(agent.poll, waiter)) {
        agent.poll = null;
      }
      rethrow;
    }
  }

  void complete(
    String name,
    String instance,
    String id, {
    required bool ok,
    String? error,
  }) {
    final agent = _agents['$name/$instance'];
    if (agent == null || agent.outstanding != id) {
      throw StateError('$name $instance is not running step $id.');
    }
    agent.outstanding = null;
    final done = agent.done;
    agent.done = null;
    if (done == null || done.isCompleted) {
      return;
    }
    if (ok) {
      done.complete();
    } else {
      done.completeError(
        StateError(error ?? '$name $instance failed step $id.'),
      );
    }
  }

  Future<void> send(Target target, {String? tap, String? see}) async {
    await waitUntil(target.name, target.instance);
    final agent = _agents['${target.name}/${target.instance}']!;
    final command = StepCommand(
      id: '${++_ids}',
      command: tap != null ? 'tap' : 'see',
      target: tap,
      text: see,
    );
    final done = Completer<void>();
    agent.done = done;
    agent.outstanding = command.id;
    final poll = agent.poll;
    if (poll != null && !poll.isCompleted) {
      agent.poll = null;
      poll.complete(command);
    } else {
      agent.pending = command;
    }
    try {
      await done.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw StateError(
        '${target.name} ${target.instance} did not finish step ${command.id}.',
      );
    }
  }
}
