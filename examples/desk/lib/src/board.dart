import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';

/// How long [BoardBloc] waits before it paints the result.
///
/// The span stays open until the frame after that wait, so the panel can
/// show the tickets on the span. The bloc event itself is stamped when the
/// handler starts, which is outside the 32 ms grouping window.
const boardPause = Duration(milliseconds: 350);

class Ticket {
  const Ticket({required this.id, required this.title, required this.done});

  final String id;
  final String title;
  final bool done;

  @override
  bool operator ==(Object other) {
    return other is Ticket &&
        other.id == id &&
        other.title == title &&
        other.done == done;
  }

  @override
  int get hashCode => Object.hash(id, title, done);
}

const sampleTickets = <Ticket>[
  Ticket(id: 'north', title: 'North window', done: false),
  Ticket(id: 'south', title: 'South door', done: false),
  Ticket(id: 'roof', title: 'Roof leak', done: true),
  Ticket(id: 'boiler', title: 'Boiler', done: false),
  Ticket(id: 'keys', title: 'Keys', done: true),
  Ticket(id: 'lobby', title: 'Lobby light', done: false),
];

sealed class BoardState {
  const BoardState();
}

class BoardIdle extends BoardState {
  const BoardIdle();
}

class BoardFailed extends BoardState {
  const BoardFailed();
}

class BoardReady extends BoardState {
  BoardReady(this.tickets, {this.openId});

  final List<Ticket> tickets;
  final String? openId;

  @override
  bool operator ==(Object other) {
    return other is BoardReady &&
        other.openId == openId &&
        _sameTickets(other.tickets, tickets);
  }

  @override
  int get hashCode => Object.hash(openId, Object.hashAll(tickets));
}

bool _sameTickets(List<Ticket> a, List<Ticket> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

sealed class BoardEvent {}

class BoardLoadRequested extends BoardEvent {}

class BoardFailRequested extends BoardEvent {}

class TicketSelected extends BoardEvent {
  TicketSelected(this.id);

  final String id;
}

class BoardBloc extends Bloc<BoardEvent, BoardState> {
  BoardBloc() : super(const BoardIdle()) {
    on<BoardLoadRequested>(_onLoad);
    on<BoardFailRequested>(_onFail);
    on<TicketSelected>(_onSelect);
  }

  Future<void> _onLoad(
    BoardLoadRequested event,
    Emitter<BoardState> emit,
  ) async {
    await Insight.traceFuture(() async {
      await Future<void>.delayed(boardPause);
      emit(BoardReady(List<Ticket>.of(sampleTickets)));
      await SchedulerBinding.instance.endOfFrame;
    }(), name: 'loadBoard');
  }

  Future<void> _onFail(
    BoardFailRequested event,
    Emitter<BoardState> emit,
  ) async {
    try {
      await Insight.traceFuture(() async {
        await Future<void>.delayed(boardPause);
        emit(const BoardFailed());
        await SchedulerBinding.instance.endOfFrame;
        throw StateError('failed');
      }(), name: 'loadBoard');
    } on StateError {
      // The span is already closed with this error.
    }
  }

  void _onSelect(TicketSelected event, Emitter<BoardState> emit) {
    final current = state;
    if (current is! BoardReady || current.openId == event.id) {
      return;
    }
    emit(BoardReady(current.tickets, openId: event.id));
  }
}

class ClockTick {
  const ClockTick(this.count);

  final int count;

  @override
  bool operator ==(Object other) => other is ClockTick && other.count == count;

  @override
  int get hashCode => count.hashCode;
}

class ClockCubit extends Cubit<ClockTick> {
  ClockCubit() : super(const ClockTick(0));

  void tick() => emit(ClockTick(state.count + 1));
}

sealed class DeskFilter {
  const DeskFilter();
}

class FilterAll extends DeskFilter {
  const FilterAll();
}

class FilterOpen extends DeskFilter {
  const FilterOpen();
}

class FilterDone extends DeskFilter {
  const FilterDone();
}

class FilterCubit extends Cubit<DeskFilter> {
  FilterCubit() : super(const FilterAll());

  void show(DeskFilter filter) => emit(filter);
}

bool ticketMatches(Ticket ticket, DeskFilter filter) {
  return switch (filter) {
    FilterAll() => true,
    FilterOpen() => !ticket.done,
    FilterDone() => ticket.done,
  };
}

sealed class DeskTree {
  const DeskTree();
}

class ScopedTree extends DeskTree {
  const ScopedTree();
}

class WideTree extends DeskTree {
  const WideTree();
}

class TreeCubit extends Cubit<DeskTree> {
  TreeCubit() : super(const ScopedTree());

  void show(DeskTree tree) => emit(tree);
}

/// Rebuild counters for the widget tests. Insight is what records this in a
/// real session; the counters only check that the two trees differ.
class DeskBuilds {
  static var clock = 0;
  static var cards = 0;

  static void reset() {
    clock = 0;
    cards = 0;
  }
}
