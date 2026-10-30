/// One line on the switch.
enum LineStatus {
  idle,
  dialing,
  busyTone,
  waiting,
  recall,
  recallRing,
  calling,
  ringing,
  inCall,
}

/// What the phone lamp shows. Idle has none.
enum LineSignal { none, line, ringing, busy, voice }

/// A phone that is still off hook, waiting for [target] to become idle.
class CampOn {
  const CampOn({required this.waiter, required this.target});

  final int waiter;
  final int target;

  @override
  bool operator ==(Object other) {
    return other is CampOn && other.waiter == waiter && other.target == target;
  }

  @override
  int get hashCode => Object.hash(waiter, target);
}

/// The state of one phone.
class Line {
  const Line({
    required this.number,
    required this.status,
    this.digits = '',
    this.peer,
    this.attempt,
    this.waitingFor,
  });

  const Line.idle(this.number)
    : status = LineStatus.idle,
      digits = '',
      peer = null,
      attempt = null,
      waitingFor = null;

  final int number;
  final LineStatus status;
  final String digits;

  /// The other party of a live call.
  final int? peer;

  /// The line that returned busy. Camp-on waits for this line.
  final int? attempt;

  /// The line this phone is waiting for after `01`.
  final int? waitingFor;

  Line copy({
    LineStatus? status,
    String? digits,
    int? peer,
    int? attempt,
    int? waitingFor,
    bool clearPeer = false,
    bool clearAttempt = false,
    bool clearWaiting = false,
  }) {
    return Line(
      number: number,
      status: status ?? this.status,
      digits: digits ?? this.digits,
      peer: clearPeer ? null : peer ?? this.peer,
      attempt: clearAttempt ? null : attempt ?? this.attempt,
      waitingFor: clearWaiting ? null : waitingFor ?? this.waitingFor,
    );
  }

  Line cleared() => Line.idle(number);

  /// The handset is on the cradle.
  bool get hookOn =>
      status == LineStatus.idle ||
      status == LineStatus.recallRing ||
      status == LineStatus.ringing;

  String get hookLabel => hookOn ? 'Hook on' : 'Hook off';

  /// The one signal on this line, if the lamp is lit.
  LineSignal get signal {
    return switch (status) {
      LineStatus.idle => LineSignal.none,
      LineStatus.dialing || LineStatus.waiting => LineSignal.line,
      LineStatus.recall ||
      LineStatus.recallRing ||
      LineStatus.calling ||
      LineStatus.ringing => LineSignal.ringing,
      LineStatus.busyTone => LineSignal.busy,
      LineStatus.inCall => LineSignal.voice,
    };
  }

  String get signalLabel {
    return switch (signal) {
      LineSignal.none => '',
      LineSignal.line => 'Line signal',
      LineSignal.ringing => 'Ringing signal',
      LineSignal.busy => 'Busy signal',
      LineSignal.voice => 'Voice',
    };
  }

  /// Who this phone is reaching, when the signal alone does not say it.
  String get detail {
    return switch (status) {
      LineStatus.dialing || LineStatus.busyTone => digits,
      LineStatus.waiting => 'Waiting for $waitingFor',
      LineStatus.recall ||
      LineStatus.recallRing ||
      LineStatus.calling => 'Calling $peer',
      LineStatus.inCall => 'In call with $peer',
      _ => '',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Line &&
        other.number == number &&
        other.status == status &&
        other.digits == digits &&
        other.peer == peer &&
        other.attempt == attempt &&
        other.waitingFor == waitingFor;
  }

  @override
  int get hashCode =>
      Object.hash(number, status, digits, peer, attempt, waitingFor);
}

/// The whole switch. Actions return a new value and leave this one as it was.
class Exchange {
  Exchange({
    required this.lineCount,
    required List<Line> lines,
    required List<CampOn> waiting,
  }) : lines = List.unmodifiable(lines),
       waiting = List.unmodifiable(waiting);

  factory Exchange.opened(int lineCount) {
    if (lineCount < 3 || lineCount > 9) {
      throw ArgumentError.value(lineCount, 'lineCount', 'Use 3 to 9 lines.');
    }
    return Exchange(
      lineCount: lineCount,
      lines: [
        for (var number = 1; number <= lineCount; number++) Line.idle(number),
      ],
      waiting: const [],
    );
  }

  final int lineCount;
  final List<Line> lines;
  final List<CampOn> waiting;

  Line line(int number) => lines[number - 1];

  /// Camp-on callers who are ringing before the other phone does.
  /// Caller first, then the line they are waiting to call.
  List<(int, int)> get recalls {
    final pairs = <(int, int)>[];
    for (final line in lines) {
      final peer = line.peer;
      if (peer == null) {
        continue;
      }
      if (line.status != LineStatus.recall &&
          line.status != LineStatus.recallRing) {
        continue;
      }
      pairs.add((line.number, peer));
    }
    return pairs;
  }

  /// Rings that have not been answered. Caller first, then the called line.
  List<(int, int)> get rings {
    final pairs = <(int, int)>[];
    for (final line in lines) {
      final peer = line.peer;
      if (line.status != LineStatus.calling || peer == null) {
        continue;
      }
      pairs.add((line.number, peer));
    }
    return pairs;
  }

  /// Live calls, lower line number first, each pair once.
  List<(int, int)> get calls {
    final pairs = <(int, int)>[];
    for (final line in lines) {
      final peer = line.peer;
      if (line.status != LineStatus.inCall || peer == null) {
        continue;
      }
      if (line.number < peer) {
        pairs.add((line.number, peer));
      }
    }
    return pairs;
  }

  Exchange offHook(int number) {
    final phone = line(number);
    if (phone.status == LineStatus.recallRing) {
      final target = phone.peer!;
      if (line(target).status != LineStatus.idle) {
        return _replace(
          phone.copy(
            status: LineStatus.busyTone,
            attempt: target,
            clearPeer: true,
          ),
        );
      }
      return _ring(number, target);
    }
    if (phone.status == LineStatus.ringing) {
      return _connect(phone.peer!, number);
    }
    if (phone.status != LineStatus.idle) {
      return this;
    }
    return _replace(phone.copy(status: LineStatus.dialing));
  }

  Exchange dial(int number, int digit) {
    if (digit < 0 || digit > 9) {
      return this;
    }
    final phone = line(number);
    if (phone.status != LineStatus.dialing &&
        phone.status != LineStatus.busyTone) {
      return this;
    }
    if (phone.digits == '0') {
      return _serviceDigit(phone, digit);
    }
    if (digit == 0) {
      return _replace(phone.copy(digits: '0'));
    }
    return _place(phone, digit);
  }

  Exchange onHook(int number) {
    final phone = line(number);
    if (phone.status == LineStatus.idle) {
      return this;
    }
    if (phone.status == LineStatus.recall) {
      return _replace(
        phone.copy(status: LineStatus.recallRing, peer: phone.peer),
      );
    }
    if (phone.status == LineStatus.inCall ||
        phone.status == LineStatus.calling ||
        phone.status == LineStatus.ringing) {
      final peer = phone.peer!;
      return _replace(phone.cleared())._replace(line(peer).cleared())._grant();
    }
    return _replace(phone.cleared())._grant();
  }

  Exchange _place(Line phone, int digit) {
    if (digit < 1 || digit > lineCount || digit == phone.number) {
      return _replace(
        phone.copy(status: LineStatus.busyTone, digits: '', clearAttempt: true),
      );
    }
    if (line(digit).status != LineStatus.idle || _reserved(this, digit)) {
      return _replace(
        phone.copy(status: LineStatus.busyTone, digits: '', attempt: digit),
      );
    }
    return _ring(phone.number, digit);
  }

  Exchange _serviceDigit(Line phone, int digit) {
    if (digit == 1 && phone.status == LineStatus.busyTone) {
      final target = phone.attempt;
      if (target == null) {
        return _replace(phone.copy(digits: ''));
      }
      return _replace(
        phone.copy(
          status: LineStatus.waiting,
          digits: '',
          clearAttempt: true,
          waitingFor: target,
        ),
      )._withWaiting([
        ...waiting,
        CampOn(waiter: phone.number, target: target),
      ])._grant();
    }
    if (phone.status == LineStatus.busyTone) {
      final ready = _replace(phone.copy(digits: ''));
      return ready._place(ready.line(phone.number), digit);
    }
    return _replace(
      phone.copy(status: LineStatus.busyTone, digits: '', clearAttempt: true),
    );
  }

  Exchange _recall(int caller, int target) {
    final phone = line(caller).copy(
      status: LineStatus.recall,
      digits: '',
      peer: target,
      clearAttempt: true,
      clearWaiting: true,
    );
    return _replace(phone)._withoutWaiter(caller);
  }

  bool _reserved(Exchange exchange, int target) {
    for (final phone in exchange.lines) {
      if (phone.peer != target) {
        continue;
      }
      if (phone.status == LineStatus.recall ||
          phone.status == LineStatus.recallRing ||
          phone.status == LineStatus.calling) {
        return true;
      }
    }
    return false;
  }

  Exchange _ring(int caller, int called) {
    final from = line(caller).copy(
      status: LineStatus.calling,
      digits: '',
      peer: called,
      clearAttempt: true,
      clearWaiting: true,
    );
    final to = line(called).copy(
      status: LineStatus.ringing,
      digits: '',
      peer: caller,
      clearAttempt: true,
      clearWaiting: true,
    );
    return _replace(from)._replace(to);
  }

  Exchange _connect(int a, int b) {
    final left = line(a).copy(
      status: LineStatus.inCall,
      digits: '',
      peer: b,
      clearAttempt: true,
      clearWaiting: true,
    );
    final right = line(b).copy(
      status: LineStatus.inCall,
      digits: '',
      peer: a,
      clearAttempt: true,
      clearWaiting: true,
    );
    return _replace(left)._replace(right);
  }

  Exchange _grant() {
    var current = this;
    final keep = <CampOn>[];
    for (final request in waiting) {
      final waiter = current.line(request.waiter);
      final target = current.line(request.target);
      final stillWaiting =
          waiter.status == LineStatus.waiting &&
          waiter.waitingFor == request.target;
      if (!stillWaiting) {
        continue;
      }
      if (target.status == LineStatus.idle &&
          !_reserved(current, request.target)) {
        current = current._recall(request.waiter, request.target);
      } else {
        keep.add(request);
      }
    }
    return current._withWaiting(keep);
  }

  Exchange _replace(Line phone) {
    return Exchange(
      lineCount: lineCount,
      lines: [
        for (final current in lines)
          if (current.number == phone.number) phone else current,
      ],
      waiting: waiting,
    );
  }

  Exchange _withWaiting(List<CampOn> next) {
    return Exchange(lineCount: lineCount, lines: lines, waiting: next);
  }

  Exchange _withoutWaiter(int waiter) {
    return _withWaiting([
      for (final request in waiting)
        if (request.waiter != waiter) request,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Exchange ||
        other.lineCount != lineCount ||
        other.lines.length != lines.length ||
        other.waiting.length != waiting.length) {
      return false;
    }
    for (var i = 0; i < lines.length; i++) {
      if (other.lines[i] != lines[i]) {
        return false;
      }
    }
    for (var i = 0; i < waiting.length; i++) {
      if (other.waiting[i] != waiting[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(lineCount, Object.hashAll(lines), Object.hashAll(waiting));
}

/// True when the cords and the waiting list are the same.
bool sameSwitchView(Exchange left, Exchange right) {
  final leftCalls = left.calls;
  final rightCalls = right.calls;
  final leftRings = left.rings;
  final rightRings = right.rings;
  final leftRecalls = left.recalls;
  final rightRecalls = right.recalls;
  if (leftCalls.length != rightCalls.length ||
      leftRings.length != rightRings.length ||
      leftRecalls.length != rightRecalls.length ||
      left.waiting.length != right.waiting.length) {
    return false;
  }
  for (var i = 0; i < leftCalls.length; i++) {
    if (leftCalls[i] != rightCalls[i]) {
      return false;
    }
  }
  for (var i = 0; i < leftRings.length; i++) {
    if (leftRings[i] != rightRings[i]) {
      return false;
    }
  }
  for (var i = 0; i < leftRecalls.length; i++) {
    if (leftRecalls[i] != rightRecalls[i]) {
      return false;
    }
  }
  for (var i = 0; i < left.waiting.length; i++) {
    if (left.waiting[i] != right.waiting[i]) {
      return false;
    }
  }
  return true;
}
