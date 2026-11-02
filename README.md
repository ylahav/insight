# Insight for Flutter

<img src="brand/logo.png" alt="Insight for Flutter" width="640">

Insight is an independent project and is not affiliated with, sponsored by, or endorsed by Google LLC. Flutter and the related logo are trademarks of Google LLC.

**Status: alpha.** A session shows frames, the user widgets that rebuilt during them, bloc and cubit transitions, and futures or streams the app traces. The desk checks passed on Flutter 3.47.8. The bloc_counter parser check also passed on Flutter 3.44.9. The shelf profile check also passed on Flutter 3.47.8: a scoped tick groups `second` with `SecondReadout` and without `MarkCard`, and a wide tick groups the same provider with `MarkCard`.

The Windows installer and the Linux archive are on the [latest release](https://github.com/ylahav/insight/releases/latest). What each program needs is in [docs/windows.md](docs/windows.md).

Insight for Flutter is a debugging aid for Flutter apps. The first version groups four observations on one timeline: a frame, the user widgets that rebuilt during it, a bloc transition, and an async span the app opted to trace. Why that timeline is worth opening, and how to read a row for a problem in the widget list, is [docs/overview.md](docs/overview.md). What comes after this alpha is [docs/roadmap.md](docs/roadmap.md).

Flutter DevTools already charts frames. Insight lines a frame up with the bloc transition and the widgets that rebuilt. How to use a session, and how to read one, is [docs/guide.md](docs/guide.md). `examples/desk` is the Bloc reference. `examples/bloc_counter` is the small parser fixture. CaptureGuide is the reference with no state library. They are described in [docs/mvp.md](docs/mvp.md).

## Design of record

| Doc | What it decides |
| --- | --- |
| [docs/runtime.md](docs/runtime.md) | In-app agent versus collector, build modes, Flutter 3.44.x and 3.47.x |
| [docs/events.md](docs/events.md) | Schema version 1, the session file, and the agent wire format |
| [docs/mvp.md](docs/mvp.md) | Three-phase scope, acceptance checks, and non-goals |
| [docs/running-example.md](docs/running-example.md) | The switch example, with Bloc and Riverpod on one board |
| [docs/what-can-be-learned.md](docs/what-can-be-learned.md) | Two profile readings: bloc beside riverpod, and the wide board beside enamel |
| [docs/exchange2.md](docs/exchange2.md) | The same rules across a switch and its phones |
| [docs/roadmap.md](docs/roadmap.md) | What comes after the alpha |
| [docs/windows.md](docs/windows.md) | The Windows installer, and the programs it contains |
| [brand/logo.png](brand/logo.png) | The wordmark. The icon is [brand/icon.png](brand/icon.png) |

## Record a session

From the repository root, this starts the app, reads the VM Service address `flutter run` prints, and records one session. Leave the Insight tab closed.

```bash
dart run tool/record.dart --app examples/desk --duration 15
```

The app window opens. Press Enter in that terminal, then do one action in the window while the recording runs. The file is `examples/desk/insight-session.json`. `--profile` uses profile mode. `--device` chooses the target. On `windows` the script turns Impeller off, because that backend closes the view and `flutter run` prints `Lost connection to device.`

`examples/bloc_counter` increments on its own in profile mode, so `CounterText` shows up without a tap. It sets `Bloc.observer` to `InsightBlocObserver`, so those increments are `state.changed` records with a null event. Complete and Throw trace a future: one span finishes, and one ends with `status` `error`. User-widget rebuilds are on by default. `--no-rebuilds` leaves them off.

## Open the panel

Run `examples/bloc_counter` in debug or profile, and open the DevTools link `flutter run` prints. The Insight tab is enabled for that example. It uses the VM client DevTools already has. It does not open a second one, so leave the CLI disconnected while the tab is open.

The tab draws those changes as a flow, earliest first. The title of a step is the bloc or cubit change. The frame time is the small line under it. The label "Time grouping" means the records share a time window. It does not mean one caused the other. Show all frames includes rebuild-only frames. Show all widgets includes Flutter wrappers such as `Text` and `Padding`. Pause holds the list while the session continues. A traced call appears once, on the earliest frame, with a frame count. Flutter web is unsupported and the panel says so.

## Run the desk

`examples/desk` is the app that shows the comparison. It is a dispatch board with a clock cubit, a filter cubit, a board bloc, and a traced load. The Scoped tree and the Wide tree handle the same clock tick.

From `examples/desk`:

```bash
flutter run -d windows
```

Open the DevTools link that command prints, and open the Insight tab. Leave the CLI disconnected while the tab is open.

Press **Tick**. On Scoped, the row is `ClockCubit` with `ClockReadout`, and `TicketCard` is absent. Press **Wide**, then **Tick** again. The same cubit now lists `TicketCard`. That difference is the comparison.

Press **Load**. The session gains an `async.span` named `loadBoard`. The tickets are on the frame that span overlaps. Press **Fail load** for a span with `status` `error`. Press a ticket for `BoardBloc`, event `TicketSelected`, and `TicketDetail` on the following frame.

`examples/bloc_counter` stays the unattended profile fixture. In profile it increments on its own, so `CounterText` shows up without a tap. Complete and Throw still trace a future.

## Run the shelf

`examples/riverpod_shelf` is the same comparison for Riverpod. Scoped and Wide share one `second` provider.

From `examples/riverpod_shelf`:

```bash
flutter run -d windows
```

Press **Tick**. On Scoped, the row is `second` with `SecondReadout`, and `MarkCard` is absent. Press **Wide**, then **Tick** again. The same provider now lists `MarkCard`. That difference is the comparison.

## Run the exchange

`examples/exchange` is a private switch. The phones and cords are shared. Open with Bloc or Open with Riverpod chooses who holds the switch. The behavior is specified in [docs/running-example.md](docs/running-example.md).

From `examples/exchange`:

```bash
flutter run -d windows
```

Choose a line count, open one driver, tap a phone, and dial another line. The called phone stays on hook with Ringing signal, and a cord blinks until that phone is clicked. Both phones then show Voice and the cord stays lit. An idle phone stays as it was. `01` waits for a busy line. When that line is free, the caller rings and hooks on, then hooks off, and only then the other phone rings. `01` after dialing your own number stays on Busy signal.

## Run the switch and the phones

`examples/exchange2` splits that board into two programs. The switch decides the call and keeps the log. Each phone is its own window. How to start them, and how a scenario drives them, is [docs/exchange2.md](docs/exchange2.md).

From the repository root, on Windows:

```powershell
.\examples\exchange2\start.ps1 bloc
.\examples\exchange2\test.ps1 bloc .\examples\exchange2\scenarios\answered-call.txt
```

The first argument is `bloc`, `riverpod`, or `plinth`. `start` takes a line count after that. The default is 3. From a checkout the same commands are `dart run examples/exchange2/start.dart` and `dart run examples/exchange2/test.dart`.

## Read two files

`tool/compare.dart` prints two schema-1 sessions, earliest change first, in two columns. How to read that print is in [docs/guide.md](docs/guide.md). The process exits 0 when the widgets differ. That difference is the reading. `tool/analyzer` opens one recording with Select file, and Add result puts another recording beside it. The shortest time on a step is marked best and the longest is marked worst. The Windows installer for Analyzer and the other tools is in [docs/windows.md](docs/windows.md).

```bash
dart run tool/compare.dart --left scoped.json --right wide.json
```

## License

[MIT](LICENSE)

## Contributing

Suggestions and new features go to [the issues page](https://github.com/ylahav/insight/issues). The current sequence is [docs/roadmap.md](docs/roadmap.md). Code changes follow [CONTRIBUTING.md](CONTRIBUTING.md).
