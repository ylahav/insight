import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The clock. `name` is `second`, so the session does not use the provider's
/// runtime type. `summary` is `int`.
class Second extends Notifier<int> {
  @override
  int build() => 0;

  void tick() => state = state + 1;
}

final secondProvider = NotifierProvider<Second, int>(
  Second.new,
  name: 'second',
);

sealed class ShelfTree {
  const ShelfTree();
}

class ScopedTree extends ShelfTree {
  const ScopedTree();
}

class WideTree extends ShelfTree {
  const WideTree();
}

class Tree extends Notifier<ShelfTree> {
  @override
  ShelfTree build() => const ScopedTree();

  void show(ShelfTree tree) => state = tree;
}

final treeProvider = NotifierProvider<Tree, ShelfTree>(Tree.new, name: 'tree');

const marks = ['Atlas', 'Ledger', 'Compass'];

/// Rebuild counters for the widget tests. Insight records the same split in
/// a session; the counters only check that the two trees differ.
class ShelfBuilds {
  static var clock = 0;
  static var cards = 0;

  static void reset() {
    clock = 0;
    cards = 0;
  }
}
