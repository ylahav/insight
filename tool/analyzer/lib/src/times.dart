/// How one time sits among the other recordings on the same step.
///
/// The mark uses the milliseconds the screen prints, to a tenth. Two times
/// that print the same tenth are the same. A single recording has no mark.
enum TimeMark { best, worst, none }

TimeMark timeMark(int? microseconds, Iterable<int?> others) {
  if (microseconds == null) {
    return TimeMark.none;
  }
  final shown = [
    for (final value in others)
      if (value != null) _tenth(value),
  ];
  if (shown.length < 2) {
    return TimeMark.none;
  }
  final mine = _tenth(microseconds);
  final low = shown.reduce((a, b) => a <= b ? a : b);
  final high = shown.reduce((a, b) => a >= b ? a : b);
  if (low == high) {
    return TimeMark.none;
  }
  if (mine == low) {
    return TimeMark.best;
  }
  if (mine == high) {
    return TimeMark.worst;
  }
  return TimeMark.none;
}

String timeText(int microseconds, TimeMark mark) {
  final ms = '${_tenth(microseconds).toStringAsFixed(1)} ms';
  return switch (mark) {
    TimeMark.best => '$ms best',
    TimeMark.worst => '$ms worst',
    TimeMark.none => ms,
  };
}

double _tenth(int microseconds) =>
    double.parse((microseconds / 1000).toStringAsFixed(1));
