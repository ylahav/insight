# Roadmap

The public sequence after the alpha. The scope and the non-goals stay in [mvp.md](mvp.md).

## 0.1.0

This is the alpha.

An app calls `Insight.attach()`. A Bloc or Cubit app sets `InsightBlocObserver`. A Riverpod app passes `InsightRiverpodObserver` to `ProviderScope`. The DevTools tab shows a frame, the user widgets that rebuilt, and a state change or a traced call on one timeline. `insight_cli` records a session from a VM Service URI.

Supported lines are Flutter 3.44.x and 3.47.x, in debug and profile. The session file is schema 1. `value` stays null unless the app sets `Insight.captureStateValues`.

The packages prepared for pub.dev are `insight`, `insight_bloc`, `insight_riverpod`, `insight_collector`, and `insight_cli`. Publish them after this repository is public. The examples and `insight_devtools` stay in the repository. The built panel already ships inside `insight`.

`tool/record.dart` and `tool/beside.dart` stay in the repository too. One starts an example and records it. The other prints two session files in columns. A name that is in both files shares a row.

## Next check

Record the exchange twice, and read the files with `beside`. One ring with Bloc, the same ring with Riverpod. The widget names should share rows. The state row is `ExchangeCubit` on one side and `exchange` on the other. The steps are in [running-example.md](running-example.md).

That pair is the use this alpha still owes. It comes before any new phase.

## Next phase

The Insight tab shows two saved sessions in the same columns the terminal already prints. The tab today is one live session.

One phase at a time. A newer Flutter stable, when one exists, still needs the profile parser check on `examples/bloc_counter` before that line is supported. 3.44.9 and 3.47.8 have passed.

## Off this roadmap

- A cause label on a row. A shared time window is the observation. The file has no cause field.
- A CI check that passes or fails on frame times.
- A desktop companion app.
- Release mode, and Flutter web.
- Full state values by default.
- An adapter besides Bloc, Cubit, and Riverpod.
