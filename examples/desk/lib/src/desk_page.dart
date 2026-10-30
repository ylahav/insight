import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'board.dart';
import 'widgets.dart';

const _ink = Color(0xff1c1915);
const _paper = Color(0xfff3efe4);
const _rust = Color(0xff9a3412);

class DeskApp extends StatelessWidget {
  const DeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => BoardBloc()),
        BlocProvider(create: (_) => ClockCubit()),
        BlocProvider(create: (_) => FilterCubit()),
        BlocProvider(create: (_) => TreeCubit()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _paper,
          colorScheme: ColorScheme.fromSeed(seedColor: _rust, surface: _paper),
          appBarTheme: const AppBarTheme(
            backgroundColor: _paper,
            foregroundColor: _ink,
            elevation: 0,
          ),
        ),
        home: const DeskPage(),
      ),
    );
  }
}

class DeskPage extends StatelessWidget {
  const DeskPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Desk')),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeskToolbar(),
          Expanded(child: DeskBody()),
          DeskNote(),
        ],
      ),
    );
  }
}

class DeskBody extends StatelessWidget {
  const DeskBody({super.key});

  @override
  Widget build(BuildContext context) {
    final tree = context.watch<TreeCubit>().state;
    return tree is WideTree ? const WideBoard() : const ScopedBoard();
  }
}

/// Reads the clock, the filter, and the board, so one of them rebuilds
/// every ticket.
class WideBoard extends StatelessWidget {
  const WideBoard({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ClockCubit>();
    context.watch<FilterCubit>();
    context.watch<BoardBloc>();
    // New instances, not const. A const child would keep the previous
    // element and the tickets would not rebuild.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClockReadout(),
        FilterBar(),
        BoardStatus(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: TicketList()),
              SizedBox(width: 320, child: TicketDetail()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Does not read the clock. [ClockReadout] is the only widget that does.
class ScopedBoard extends StatelessWidget {
  const ScopedBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return const BoardColumn();
  }
}

class BoardColumn extends StatelessWidget {
  const BoardColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClockReadout(),
        FilterBar(),
        BoardStatus(),
        Expanded(child: TicketPane()),
      ],
    );
  }
}

class TicketPane extends StatelessWidget {
  const TicketPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: TicketList()),
        SizedBox(width: 320, child: TicketDetail()),
      ],
    );
  }
}

class DeskToolbar extends StatelessWidget {
  const DeskToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          LoadButton(),
          FailButton(),
          TickButton(),
          Spacer(),
          TreeSwitch(),
        ],
      ),
    );
  }
}

class LoadButton extends StatelessWidget {
  const LoadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.read<BoardBloc>().add(BoardLoadRequested()),
      child: const Text('Load'),
    );
  }
}

class FailButton extends StatelessWidget {
  const FailButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.read<BoardBloc>().add(BoardFailRequested()),
      child: const Text('Fail load'),
    );
  }
}

class TickButton extends StatelessWidget {
  const TickButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.read<ClockCubit>().tick(),
      child: const Text('Tick'),
    );
  }
}

class TreeSwitch extends StatelessWidget {
  const TreeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = context.watch<TreeCubit>().state is WideTree;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: wide
              ? () => context.read<TreeCubit>().show(const ScopedTree())
              : null,
          child: const Text('Scoped'),
        ),
        TextButton(
          onPressed: wide
              ? null
              : () => context.read<TreeCubit>().show(const WideTree()),
          child: const Text('Wide'),
        ),
      ],
    );
  }
}

class DeskNote extends StatelessWidget {
  const DeskNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        'Tick once on Scoped, then switch to Wide and tick again. '
        'The clock cubit is the same. The widget names are not. '
        'Load traces loadBoard.',
        style: TextStyle(color: _ink, fontSize: 13),
      ),
    );
  }
}
