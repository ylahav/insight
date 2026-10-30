import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shelf.dart';

class ShelfApp extends StatelessWidget {
  const ShelfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff9a3412)),
        scaffoldBackgroundColor: const Color(0xfff3efe4),
      ),
      home: const ShelfPage(),
    );
  }
}

class ShelfPage extends ConsumerWidget {
  const ShelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(treeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tree is WideTree ? 'Wide' : 'Scoped')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShelfToolbar(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Tick once on Scoped, then switch to Wide and tick again. '
              'The second provider is the same. The widget names are not.',
            ),
          ),
          Expanded(
            child: tree is WideTree ? const WideShelf() : const ScopedShelf(),
          ),
        ],
      ),
    );
  }
}

class ShelfToolbar extends ConsumerWidget {
  const ShelfToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(treeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => ref.read(secondProvider.notifier).tick(),
            child: const Text('Tick'),
          ),
          TextButton(
            onPressed: tree is ScopedTree
                ? null
                : () =>
                      ref.read(treeProvider.notifier).show(const ScopedTree()),
            child: const Text('Scoped'),
          ),
          TextButton(
            onPressed: tree is WideTree
                ? null
                : () => ref.read(treeProvider.notifier).show(const WideTree()),
            child: const Text('Wide'),
          ),
        ],
      ),
    );
  }
}

/// Does not watch [secondProvider]. [SecondReadout] is the only widget that does.
class ScopedShelf extends StatelessWidget {
  const ScopedShelf({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SecondReadout(), MarkList()],
    );
  }
}

/// Watches [secondProvider] above the list, so one tick rebuilds every mark.
class WideShelf extends ConsumerWidget {
  const WideShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(secondProvider);
    // New instances, not const. A const child would keep the previous
    // element and the marks would not rebuild.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SecondReadout(),
        for (final title in marks) MarkCard(title: title),
      ],
    );
  }
}

class MarkList extends StatelessWidget {
  const MarkList({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkCard(title: 'Atlas'),
        MarkCard(title: 'Ledger'),
        MarkCard(title: 'Compass'),
      ],
    );
  }
}

class SecondReadout extends ConsumerWidget {
  const SecondReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ShelfBuilds.clock += 1;
    final count = ref.watch(secondProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        'Second $count',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class MarkCard extends StatelessWidget {
  const MarkCard({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    ShelfBuilds.cards += 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(title, style: const TextStyle(fontSize: 18)),
    );
  }
}
