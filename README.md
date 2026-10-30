# Flutter Insight

**Status: alpha.** A session shows frames, the user widgets that rebuilt during them, bloc and cubit transitions, and futures or streams the app traces. The desk checks passed on Flutter 3.47.8. The bloc_counter parser check also passed on Flutter 3.44.9. The shelf profile check also passed on Flutter 3.47.8: a scoped tick groups `second` with `SecondReadout` and without `MarkCard`, and a wide tick groups the same provider with `MarkCard`.

Flutter Insight is a debugging aid for Flutter apps. The first version groups four observations on one timeline: a frame, the user widgets that rebuilt during it, a bloc transition, and an async span the app opted to trace.

Flutter DevTools already charts frames. Insight lines a frame up with the bloc transition and the widgets that rebuilt. How to use a session, and how to read one, is [docs/guide.md](docs/guide.md). `examples/desk` is the Bloc reference. `examples/bloc_counter` is the small parser fixture. CaptureGuide is the reference with no state library. They are described in [docs/mvp.md](docs/mvp.md).

## Design of record

| Doc | What it decides |
| --- | --- |
| [docs/runtime.md](docs/runtime.md) | In-app agent versus collector, build modes, Flutter 3.44.x and 3.47.x |
| [docs/events.md](docs/events.md) | Schema version 1, the session file, and the agent wire format |
| [docs/mvp.md](docs/mvp.md) | Three-month scope, acceptance checks, and non-goals |

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

## Read two files

`tool/beside.dart` prints two schema-1 sessions, earliest change first. Wrapper widgets stay hidden. The process exits 0 when the widget names differ. That difference is the reading.

```bash
dart run tool/beside.dart --left scoped.json --right wide.json
```

## License

[MIT](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
