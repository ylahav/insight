/// The switch's answer for one line.
class LineSnapshot {
  const LineSnapshot({
    required this.revision,
    required this.number,
    required this.hook,
    required this.signal,
    required this.detail,
    required this.digits,
  });

  factory LineSnapshot.fromJson(Map<String, Object?> json) {
    final digits = json['digits'];
    return LineSnapshot(
      revision: _int(json['revision'], 'revision'),
      number: _int(json['number'], 'number'),
      hook: _text(json['hook'], 'hook'),
      signal: _text(json['signal'], 'signal'),
      detail: _text(json['detail'], 'detail'),
      digits: [
        if (digits is List)
          for (final digit in digits) '$digit',
      ],
    );
  }

  final int revision;
  final int number;

  /// `on` or `off`.
  final String hook;

  /// `none`, `line`, `ringing`, `busy`, `missing`, or `voice`.
  final String signal;
  final String detail;
  final List<String> digits;

  bool get hookOn => hook == 'on';

  Map<String, Object?> toJson() {
    return {
      'revision': revision,
      'number': number,
      'hook': hook,
      'signal': signal,
      'detail': detail,
      'digits': digits,
    };
  }
}

int _int(Object? value, String name) {
  if (value is int) {
    return value;
  }
  throw FormatException('$name is not a whole number.');
}

String _text(Object? value, String name) {
  if (value is String) {
    return value;
  }
  throw FormatException('$name is not text.');
}

/// Words the handset and the desk print for a signal.
String signalLabel(String signal) {
  return switch (signal) {
    'line' => 'Line',
    'ringing' => 'Ringing',
    'busy' => 'Busy',
    'missing' => 'Line does not exist',
    'voice' => 'Voice',
    _ => '',
  };
}
