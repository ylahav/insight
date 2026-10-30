import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'board.dart';

class ClockReadout extends StatelessWidget {
  const ClockReadout({super.key});

  @override
  Widget build(BuildContext context) {
    DeskBuilds.clock += 1;
    final count = context.watch<ClockCubit>().state.count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        'Second $count',
        style: const TextStyle(
          color: _ink,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<FilterCubit>().state;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _FilterButton(
            label: 'All',
            filter: const FilterAll(),
            current: current,
          ),
          _FilterButton(
            label: 'Open',
            filter: const FilterOpen(),
            current: current,
          ),
          _FilterButton(
            label: 'Done',
            filter: const FilterDone(),
            current: current,
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.filter,
    required this.current,
  });

  final String label;
  final DeskFilter filter;
  final DeskFilter current;

  @override
  Widget build(BuildContext context) {
    final selected = current.runtimeType == filter.runtimeType;
    return TextButton(
      onPressed: selected
          ? null
          : () => context.read<FilterCubit>().show(filter),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _rust : _ink,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class BoardStatus extends StatelessWidget {
  const BoardStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final kind = context.select<BoardBloc, Type>(
      (bloc) => bloc.state.runtimeType,
    );
    final text = switch (kind) {
      BoardFailed => 'The load failed.',
      BoardIdle => 'Load the board.',
      _ => null,
    };
    if (text == null) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: const TextStyle(color: _ink)),
    );
  }
}

class TicketList extends StatelessWidget {
  const TicketList({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<FilterCubit>().state;
    final tickets = context.select<BoardBloc, List<Ticket>>((bloc) {
      final state = bloc.state;
      return state is BoardReady ? state.tickets : const <Ticket>[];
    });
    final visible = [
      for (final ticket in tickets)
        if (ticketMatches(ticket, filter)) ticket,
    ];
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView(
      children: [
        for (final ticket in visible)
          TicketCard(key: ValueKey(ticket.id), ticket: ticket),
      ],
    );
  }
}

class TicketCard extends StatelessWidget {
  const TicketCard({required this.ticket, super.key});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    DeskBuilds.cards += 1;
    final selected = context.select<BoardBloc, bool>((bloc) {
      final state = bloc.state;
      return state is BoardReady && state.openId == ticket.id;
    });
    return GestureDetector(
      onTap: () => context.read<BoardBloc>().add(TicketSelected(ticket.id)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? _selectedFill : _card,
          border: Border(
            left: BorderSide(
              color: selected ? _rust : _line,
              width: selected ? 4 : 1,
            ),
            bottom: const BorderSide(color: _line),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                ticket.done ? 'Done' : 'Open',
                style: TextStyle(color: ticket.done ? _moss : _rust),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketDetail extends StatelessWidget {
  const TicketDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final ticket = context.select<BoardBloc, Ticket?>((bloc) {
      final state = bloc.state;
      if (state is! BoardReady || state.openId == null) {
        return null;
      }
      for (final ticket in state.tickets) {
        if (ticket.id == state.openId) {
          return ticket;
        }
      }
      return null;
    });
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _line)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ticket == null
            ? const Text(
                'Select a ticket.',
                style: TextStyle(color: _ink, fontSize: 16),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.done ? 'Done' : 'Open',
                    style: TextStyle(color: ticket.done ? _moss : _rust),
                  ),
                ],
              ),
      ),
    );
  }
}

const _ink = Color(0xff1c1915);
const _card = Color(0xfffffdf8);
const _rust = Color(0xff9a3412);
const _moss = Color(0xff3f6212);
const _line = Color(0xffd6d0c4);
const _selectedFill = Color(0xfffff7ed);
