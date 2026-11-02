import 'dart:io';

import 'package:exchange2_rules/exchange.dart';
import 'package:sqlite3/sqlite3.dart';

/// One row in the activity log.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.line,
    required this.action,
    required this.detail,
    required this.at,
  });

  final int id;
  final int line;
  final String action;
  final String detail;
  final String at;
}

/// The current state of one line, as stored.
class StoredLine {
  const StoredLine({
    required this.number,
    required this.hook,
    required this.signal,
    required this.detail,
    required this.status,
    required this.peer,
    required this.waitingFor,
    required this.revision,
  });

  factory StoredLine.from(Line line, int revision) {
    return StoredLine(
      number: line.number,
      hook: line.hookOn ? 'on' : 'off',
      signal: line.signal.name,
      detail: line.detail,
      status: line.status.name,
      peer: line.peer,
      waitingFor: line.waitingFor,
      revision: revision,
    );
  }

  final int number;
  final String hook;
  final String signal;
  final String detail;
  final String status;
  final int? peer;
  final int? waitingFor;
  final int revision;
}

abstract class SwitchStore {
  Future<void> open();

  Future<void> replaceLine(StoredLine line);

  Future<int> insertActivity(ActivityEntry entry);

  Future<void> close();
}

/// Keeps the rows in memory. Tests use this.
class MemorySwitchStore implements SwitchStore {
  final lines = <int, StoredLine>{};
  final activity = <ActivityEntry>[];
  var _next = 0;

  @override
  Future<void> open() async {}

  @override
  Future<void> replaceLine(StoredLine line) async {
    lines[line.number] = line;
  }

  @override
  Future<int> insertActivity(ActivityEntry entry) async {
    final saved = ActivityEntry(
      id: ++_next,
      line: entry.line,
      action: entry.action,
      detail: entry.detail,
      at: entry.at,
    );
    activity.add(saved);
    return saved.id;
  }

  @override
  Future<void> close() async {}
}

/// `exchange2.db` beside the process. Opening deletes the previous file.
class SqliteSwitchStore implements SwitchStore {
  SqliteSwitchStore(this.path);

  final String path;
  Database? _db;

  Database get _database => _db!;

  @override
  Future<void> open() async {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
    for (final suffix in ['-wal', '-shm']) {
      final extra = File('$path$suffix');
      if (extra.existsSync()) {
        extra.deleteSync();
      }
    }
    final db = sqlite3.open(path);
    db.execute('''
      CREATE TABLE lines (
        number INTEGER PRIMARY KEY,
        hook TEXT NOT NULL,
        signal TEXT NOT NULL,
        detail TEXT NOT NULL,
        status TEXT NOT NULL,
        peer INTEGER,
        waiting_for INTEGER,
        revision INTEGER NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE activity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at TEXT NOT NULL,
        line INTEGER NOT NULL,
        action TEXT NOT NULL,
        detail TEXT NOT NULL
      )
    ''');
    _db = db;
  }

  @override
  Future<void> replaceLine(StoredLine line) async {
    _database.execute(
      '''
      INSERT INTO lines (
        number, hook, signal, detail, status, peer, waiting_for, revision
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(number) DO UPDATE SET
        hook = excluded.hook,
        signal = excluded.signal,
        detail = excluded.detail,
        status = excluded.status,
        peer = excluded.peer,
        waiting_for = excluded.waiting_for,
        revision = excluded.revision
      ''',
      [
        line.number,
        line.hook,
        line.signal,
        line.detail,
        line.status,
        line.peer,
        line.waitingFor,
        line.revision,
      ],
    );
  }

  @override
  Future<int> insertActivity(ActivityEntry entry) async {
    _database.execute(
      '''
      INSERT INTO activity (at, line, action, detail) VALUES (?, ?, ?, ?)
      ''',
      [entry.at, entry.line, entry.action, entry.detail],
    );
    return _database.lastInsertRowId;
  }

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }
}
