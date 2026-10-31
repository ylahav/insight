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

Compare two saved sessions by the state change, not only by the order the steps happened. The terminal today pairs step 1 with step 1. That hides a change of order.

Take one login recorded twice. In the first file the app leaves the login page, and the next page shows the loading. In the second file the loading stays on the login page, and the next page appears only when that page is ready. Walked in time order, the loading step of one file sits beside the navigation step of the other.

The comparison lines up the same state change, and the signal that belongs with it. The login change shares a row. The loading change shares a row. On one side the next page is already open when loading shows. On the other side the login page is still up, and the next page comes after the load. The widget names on that shared loading row are the finding.

The Insight tab shows that comparison. The tab today is one live session. The columns are the ones the terminal already uses for widget names inside a single step.

One phase at a time. A newer Flutter stable, when one exists, still needs the profile parser check on `examples/bloc_counter` before that line is supported. 3.44.9 and 3.47.8 have passed.

## Off this roadmap

- A cause label on a row. A shared time window is the observation. The file has no cause field.
- A CI check that passes or fails on frame times.
- A desktop companion app.
- Release mode, and Flutter web.
- Full state values by default.
- An adapter besides Bloc, Cubit, and Riverpod.

## Suggest a change

Open an [issue](https://github.com/ylahav/insight/issues) for an improvement or a new feature. Name the action, the state change, and what the session did not make visible. A login that loads on one page in one build and on another page in the next build is the kind of note that fits.

An idea that sits in the list above can still be opened. It stays off this page until a session shows it belongs. Leave `Insight.captureStateValues` off, and keep the session file on your machine.
