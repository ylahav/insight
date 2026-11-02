# Roadmap

The public sequence after the alpha. The scope and the non-goals stay in [mvp.md](mvp.md).

## 0.1.0

This is the alpha. The wordmark is [brand/logo.png](../brand/logo.png). The app icon is [brand/icon.png](../brand/icon.png).

An app calls `Insight.attach()`. A Bloc or Cubit app sets `InsightBlocObserver`. A Riverpod app passes `InsightRiverpodObserver` to `ProviderScope`. The DevTools tab shows a frame, the user widgets that rebuilt, and a state change or a traced call on one timeline. `insight_cli` records a session from a VM Service URI.

Supported lines are Flutter 3.44.x and 3.47.x, in debug and profile. The session file is schema 1. `value` stays null unless the app sets `Insight.captureStateValues`.

The packages prepared for pub.dev are `insight`, `insight_bloc`, `insight_riverpod`, `insight_collector`, and `insight_cli`. Publish them after this repository is public. The examples and `insight_devtools` stay in the repository. The built panel already ships inside `insight`.

`tool/record.dart`, `tool/compare.dart`, `tool/play.dart`, `tool/parser_check.dart`, and `tool/analyzer` stay in the repository too. Record starts an example and writes a session. Compare prints two session files in columns. A widget that is in both files shares a row. Analyzer opens one recording, then another beside it. On Windows those programs, plus `insight_cli`, are built into one installer: [windows.md](windows.md). `play` and `record` still need Flutter and this checkout, because they launch the examples.

## Next check

Record the exchange twice, and read the files with `compare`. One ring with Bloc, the same ring with Riverpod. `tool/play.dart` plays the steps in `examples/exchange/scenarios/answered-call.txt`. The widget names should share rows. The state row is `ExchangeCubit` on one side and `exchange` on the other. The steps are in [running-example.md](running-example.md).

That pair is the use this alpha still owes. It comes before any new phase. The widget names should match, because both drivers paint the same board.

`examples/exchange2` is a separate example, already in the tree. The switch and each phone are their own processes, and an Insight server sends the scenario to the program that should run a step. It does not replace the pair above. The programs, the scripts, and the recordings are in [exchange2.md](exchange2.md).

## Same switch, two boards

After that pair, record the same ring on two boards. The state holder stays Bloc, so both files name `ExchangeCubit`. The board changes.

`tool/play.dart --board bloc` plays `examples/exchange/scenarios/answered-call.txt` on the enamel phones: `LinePhone`, `DialKey`, and `SwitchDesk`. `--board plinth` plays that same file on the circle drawn with `PlinthPaper`, `PlinthBadge`, and `PlinthButton`. The reducer does not change. The file does not change. Phone 1 dials phone 2, and the called phone answers.

`compare` then lines up one `ExchangeCubit` row. `LinePhone` sits across from `PlinthPaper`. `DialKey` sits across from `PlinthButton`. The state change is the same. The widget names are the difference. Both boards put the switch in the middle, give each phone its own color, and mix those two colors in the cord.

## Next phase

Compare two saved sessions by the state change, not only by the order the steps happened. The terminal today pairs step 1 with step 1. That hides a change of order.

Take one login recorded twice. In the first file the app leaves the login page, and the next page shows the loading. In the second file the loading stays on the login page, and the next page appears only when that page is ready. Walked in time order, the loading step of one file sits beside the navigation step of the other.

The comparison lines up the same state change, and the signal that belongs with it. The login change shares a row. The loading change shares a row. On one side the next page is already open when loading shows. On the other side the login page is still up, and the next page comes after the load. The widget names on that shared loading row are the finding.

The Insight tab shows that comparison. The tab today is one live session. The columns are the ones the terminal already uses for widget names inside a single step.

One phase at a time. A newer Flutter stable, when one exists, still needs the profile parser check on `examples/bloc_counter` before that line is supported. 3.44.9 and 3.47.8 have passed.

## On screen

`tool/play.dart` stores the scenario it played, and the git commit of that file, on each session. Analyzer opens that one recording with Select file. It shows the scenario, the steps, and the widgets that rebuilt. Add result opens another recording beside the first and prints the same reading as `tool/compare.dart`. Further recordings stay in that same row. On a step that has frame times, the shortest time is marked best and the longest is marked worst. Equal tenths of a millisecond stay unmarked. That mark is which recording was shorter. It is not a pass or a fail. Export writes the taps out so `tool/play.dart` can run them again.

## Off this roadmap

- A cause label on a row. A shared time window is the observation. The file has no cause field.
- A CI check that passes or fails on frame times.
- A desktop app that replaces the Insight tab.
- Release mode, and Flutter web.
- Full state values by default.
- An adapter besides Bloc, Cubit, and Riverpod.

## Suggest a change

Open an [issue](https://github.com/ylahav/insight/issues) for an improvement or a new feature. Name the action, the state change, and what the session did not make visible. A login that loads on one page in one build and on another page in the next build is the kind of note that fits.

An idea that sits in the list above can still be opened. It stays off this page until a session shows it belongs. Leave `Insight.captureStateValues` off, and keep the session file on your machine.
