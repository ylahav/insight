import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';
import 'package:insight_bloc/insight_bloc.dart';

void main() {
  Insight.attach();
  Bloc.observer = InsightBlocObserver();
  runApp(const CounterApp());
}

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

class CounterText extends StatelessWidget {
  const CounterText({required this.value, super.key});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Text('$value', style: Theme.of(context).textTheme.displayMedium);
  }
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Counter')),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FramePump(),
                _AutoIncrement(),
                _Count(),
                _TraceComplete(),
                _TraceThrow(),
              ],
            ),
          ),
          floatingActionButton: const _Increment(),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CounterCubit, int>(
      builder: (context, count) => CounterText(value: count),
    );
  }
}

class _AutoIncrement extends StatefulWidget {
  const _AutoIncrement();

  @override
  State<_AutoIncrement> createState() => _AutoIncrementState();
}

/// Profile captures attach after startup, so a one-shot at launch is missed.
/// A repeating increment makes `CounterText` show up in any two-second file.
class _AutoIncrementState extends State<_AutoIncrement> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!kProfileMode) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) {
        context.read<CounterCubit>().increment();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _TraceComplete extends StatelessWidget {
  const _TraceComplete();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Insight.traceFuture<void>(Future<void>.value(), name: 'complete');
      },
      child: const Text('Complete'),
    );
  }
}

class _TraceThrow extends StatelessWidget {
  const _TraceThrow();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Insight.traceFuture<void>(
          Future<void>.error(StateError('failed')),
          name: 'throw',
        ).ignore();
      },
      child: const Text('Throw'),
    );
  }
}

class _Increment extends StatelessWidget {
  const _Increment();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.read<CounterCubit>().increment(),
      child: const Icon(Icons.add),
    );
  }
}

/// Schedules frames for the whole session. An idle counter produces none
/// after the first build, and the CLI attaches after startup.
class _FramePump extends StatefulWidget {
  const _FramePump();

  @override
  State<_FramePump> createState() => _FramePumpState();
}

class _FramePumpState extends State<_FramePump>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.4, end: 1)),
      child: const SizedBox(width: 8, height: 8),
    );
  }
}
