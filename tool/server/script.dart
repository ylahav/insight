import 'dart:io';

/// One line of a multi-process scenario.
sealed class Step {
  const Step();
}

class Start extends Step {
  const Start(this.name, this.instance);

  final String name;
  final String instance;
}

class Record extends Step {
  const Record(this.name, this.instance);

  final String name;
  final String instance;
}

class Target extends Step {
  const Target(this.name, this.instance);

  final String name;
  final String instance;
}

class Tap extends Step {
  const Tap(this.target);

  final String target;
}

class See extends Step {
  const See(this.text);

  final String text;
}

class Delay extends Step {
  const Delay(this.milliseconds);

  final int milliseconds;
}

/// The scenario file, whether [scenario] is absolute, relative to the
/// working directory, or relative to [root].
File scenarioFile(Directory root, String scenario) {
  final given = File(scenario);
  if (given.isAbsolute) {
    if (given.existsSync()) {
      return given;
    }
    throw FormatException('No scenario at ${given.path}.');
  }
  if (given.existsSync()) {
    return given.absolute;
  }
  final fromRoot = File.fromUri(
    root.uri.resolve(scenario.replaceAll('\\', '/')),
  );
  if (fromRoot.existsSync()) {
    return fromRoot;
  }
  throw FormatException('No scenario at $scenario.');
}

/// Reads `start`, `record`, `on`, `tap`, `see`, and `delay`.
List<Step> parseScenario(String source) {
  final steps = <Step>[];
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
      case 'start' || 'record' || 'on':
        steps.add(_named(command, target, i + 1));
      case 'tap':
        steps.add(Tap(target));
      case 'see':
        steps.add(See(target));
      case 'delay':
        final milliseconds = int.tryParse(target);
        if (milliseconds == null || milliseconds < 0) {
          throw FormatException(
            'Line ${i + 1} delay needs a whole number of milliseconds.',
          );
        }
        steps.add(Delay(milliseconds));
      default:
        throw FormatException(
          'Line ${i + 1} uses "$command". '
          'Use start, record, on, tap, see, or delay.',
        );
    }
  }
  if (steps.isEmpty) {
    throw const FormatException('The scenario has no steps.');
  }
  return steps;
}

Step _named(String command, String target, int line) {
  final parts = target.split(RegExp(r'\s+'));
  final String name;
  final String instance;
  if (parts.length == 1 && parts.single == 'switch') {
    name = 'switch';
    instance = '1';
  } else if (parts.length == 2) {
    name = parts[0];
    instance = parts[1];
  } else {
    throw FormatException('Line $line names a program as "switch" or "phone 1".');
  }
  return switch (command) {
    'start' => Start(name, instance),
    'record' => Record(name, instance),
    _ => Target(name, instance),
  };
}
