import 'dart:async';

import 'hub.dart';
import 'script.dart';

/// Opens a recording and closes it when the scenario stops.
abstract class ScenarioRecording {
  Future<void> stop();
}

/// Runs a scenario against programs that have registered on [hub].
Future<void> runScenario(
  List<Step> steps,
  Hub hub, {
  Future<void> Function(Start step)? launch,
  Future<ScenarioRecording> Function(Registration registration)? record,
}) async {
  for (final step in steps) {
    if (step is Start && !hub.isRegistered(step.name, step.instance)) {
      final start = launch;
      if (start == null) {
        throw StateError('No launcher for ${step.name} ${step.instance}.');
      }
      await start(step);
    }
  }
  for (final step in steps) {
    final named = switch (step) {
      Start(:final name, :final instance) => (name, instance),
      Record(:final name, :final instance) => (name, instance),
      Target(:final name, :final instance) => (name, instance),
      _ => null,
    };
    if (named != null) {
      await hub.waitUntil(named.$1, named.$2);
    }
  }

  Target? current;
  ScenarioRecording? recording;
  try {
    for (final step in steps) {
      switch (step) {
        case Start():
          break;
        case Record():
          if (recording != null) {
            throw StateError('The scenario records one program.');
          }
          final registration = hub.lookup(step.name, step.instance);
          if (registration == null) {
            throw StateError('${step.name} ${step.instance} is not registered.');
          }
          final start = record;
          if (start == null) {
            throw StateError('This run cannot record.');
          }
          recording = await start(registration);
        case Target():
          current = step;
        case Delay():
          await Future<void>.delayed(Duration(milliseconds: step.milliseconds));
        case Tap():
          final target = current;
          if (target == null) {
            throw StateError('tap ${step.target} needs an on line.');
          }
          await hub.send(target, tap: step.target);
        case See():
          final target = current;
          if (target == null) {
            throw StateError('see ${step.text} needs an on line.');
          }
          await hub.send(target, see: step.text);
      }
    }
  } finally {
    await recording?.stop();
  }
}
