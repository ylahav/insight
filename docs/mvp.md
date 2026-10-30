# MVP

One schedule for a single developer. v1 is a profile-mode and debug-mode session that shows a frame, the user widgets that rebuilt during it, a bloc transition, and a traced async span on one timeline.

[runtime.md](runtime.md) is the process split. [events.md](events.md) is the file the timeline reads. This file is the scope.

The alpha is the phase 3 acceptance checks passing on `examples/desk`, plus the parser checks on `examples/bloc_counter`. It is not a pub.dev publish requirement and not a CI gate.

## Non-goals

These are out of v1 even if a prototype of one of them would be easy.

- A Flutter engine change, or a fork of Flutter or DevTools
- A general performance view: flame chart, CPU profiler, memory, network, or a second frame heatmap. Flutter DevTools already has those. Insight lists frames so the other records have something to sit next to
- Inferred rebuild causes
- Provider, GetX, or any adapter besides Bloc, Cubit, and Riverpod
- Passing or failing a pull request on frame times
- A desktop companion app
- Multi-device sessions
- Architecture graphs, test-fragility analysis, offline replay
- Platform-channel or FFI logging
- Release mode and Flutter web
- Full state values, unless the sample or the app sets `Insight.captureStateValues`

## Schedule

Each phase ends with something a sample app can demonstrate. Later phases depend on the previous acceptance check.

### Phase 1 — Frames on disk

Create the pub workspace, `insight`, `insight_collector`, and `insight_cli`.

- `insight` attaches and posts `agent.ready`.
- The CLI takes a VM Service URI, records a profile-mode run, and writes `insight-session.json`.
- The collector parses `Flutter.Frame` into `frame` records on Flutter 3.47.x. That parser test is the support claim.
- Build profiling stays off. The file has no `widget.rebuild` records yet.

**Acceptance.** Profile-mode `bloc_counter` fixture, CLI attached for at least one second of frames. The session file has `schemaVersion` 1, `mode` `profile`, `rejected` 0, and at least one `frame` whose `buildUs`, `rasterUs`, and `elapsedUs` are integers `>= 0`. `agent.ready` is present.

### Phase 2 — Rebuilds in DevTools

- The collector enables `ext.flutter.profileUserWidgetBuilds` for the session and emits `widget.rebuild` records.
- `insight_devtools` renders the live session through `serviceManager`. The extension does not open its own VM URI.
- The panel lists frames and, under each frame, the user widgets that rebuilt. Counts are computed in the UI.

**Acceptance.** Debug-mode `bloc_counter` fixture, extension connected.

1. With the session active, one tap increases the number of `CounterText` rebuild records by at least 1, and the new row shows up within one second.
2. A second capture with build profiling left off still writes `frame` records and writes zero `widget.rebuild` records.
3. After disconnect, `ext.flutter.profileUserWidgetBuilds` is off.
4. CaptureGuide, unmodified, debug mode. Open Sunny 16 and change the aperture once. The session contains a `widget.rebuild` named `Sunny16View`, at least one `frame`, and zero `state.changed` or `agent.ready` records.

### Phase 3 — Bloc, async, alpha

- `insight_bloc` emits `state.changed` through `Bloc.observer`. Cubit changes are included, with `event` set to `null`. The apps do not set `Insight.captureStateValues`, so `value` is `null`.
- `Insight.traceFuture` and `Insight.traceStream` emit `async.span` from the public fixture.
- The panel groups records with the version-1 window in [events.md](events.md). It draws those moments as a flow in time order. The change is the title of each step, and the frame time sits under it. A step is shown for a frame that has a state change or an async span. Rebuild-only frames and Flutter wrapper widgets stay behind controls. A span is shown on its earliest frame, with the number of frames it overlapped. Pause holds the rows while the session continues. Grouping is labeled as time grouping.
- The CLI writes a session file from the desk. There is no baseline, no threshold, and no GitHub check. A scoped tick and a wide tick are read side by side.

**Acceptance.** Flutter 3.47.x. `examples/desk`.

1. Debug, Scoped tree. Press Tick. The session contains a `state.changed` for `ClockCubit` with `event` null, `summary` `ClockTick`, and `value` null, grouped with the following frame. That frame's `widget.rebuild` names include `ClockReadout` and do not include `TicketCard`.
2. Switch to Wide and press Tick. The same `ClockCubit` record is present. That frame's names include `TicketCard`. The widget names are the comparison.
3. Press Load. The session contains an `async.span` named `loadBoard` with `status` `completed` and a non-null `endUs`, overlapping a frame that contains `TicketCard`. Press Fail load. That span's `status` is `error`, `error` is non-null and at most 200 characters, and there is no stack trace field.
4. A profile session of one of these actions, written by the CLI, uses schema version 1. Byte-identical output across the two ticks is not required.

Phase 3 is the alpha. The README's status line changes from design to alpha only after these checks pass on Flutter 3.47.x.

## Apps under test

Phases 1 and 2 use a public fixture so the parser test can run without a larger app. The desk is the phase 3 reference. CaptureGuide is the app with no state-library adapter. `examples/exchange` is the running example after those phases. It is specified in [running-example.md](running-example.md). stayAble is not in v1.

### Public fixture

`examples/bloc_counter`, added in phase 1 and extended in place:

- Flutter 3.44.x and 3.47.x, profile and debug
- A `CounterCubit` and a `CounterText` widget that builds its state
- A button that completes a future and a button that throws
- `devtools_options.yaml` with the Insight extension enabled, once the extension exists in phase 2

This fixture is the parser test. It is not a gallery, and it is not the product Insight is being built to explain. Complete and Throw remain on it. The desk's Load and Fail load are the async script for phase 3.

### Desk

`examples/desk` is the reference application. It lives in this repository. It is one package, with two trees, so the comparison does not depend on a private app.

| Piece | What a session shows |
| --- | --- |
| `ClockCubit` | A tick. `event` is null. `summary` is `ClockTick`. |
| Scoped tree | That tick rebuilds `ClockReadout` and leaves `TicketCard` alone. |
| Wide tree | The same tick rebuilds `ClockReadout` and every `TicketCard`, because the board widget reads the clock. |
| `FilterCubit` | All, Open, or Done. `summary` is `FilterAll`, `FilterOpen`, or `FilterDone`. |
| `BoardBloc` | `BoardLoadRequested`, `BoardFailRequested`, and `TicketSelected`. `summary` is `BoardIdle`, `BoardReady`, or `BoardFailed`. |
| `loadBoard` | `Insight.traceFuture`. The span stays open until the frame that paints the result. |

`captureStateValues` stays off. The recorded names are types. A ticket id stays on the event object.

The useful difference between the two tick files is which widgets rebuilt around that same cubit change. The wide tree is the one that reads the clock above the list. The scoped tree lets `ClockReadout` read it alone.

### Shelf

`examples/riverpod_shelf` is the Riverpod reference. It is the same comparison as the desk, with a provider instead of a cubit. It ships in this repository so the check does not depend on stayAble.

| Piece | What a session shows |
| --- | --- |
| `second` | A tick. `adapter` is `riverpod`. `event` is null. `summary` is `int`. |
| Scoped tree | That tick rebuilds `SecondReadout` and leaves `MarkCard` alone. |
| Wide tree | The same tick rebuilds `SecondReadout` and every `MarkCard`, because the shelf watches `second` above the list. |
| `tree` | Scoped or Wide. `summary` is `ScopedTree` or `WideTree`. |

`captureStateValues` stays off. The recorded name is the provider's `name`.

### Exchange

`examples/exchange` is one board driven twice. The phones and cords are shared. Open with Bloc or Open with Riverpod chooses who holds the switch. Hook, signal, ringing, and camp-on are specified in [running-example.md](running-example.md). This is not a phase.

| Piece | What a session shows |
| --- | --- |
| `ExchangeCubit` | A change. `adapter` is `bloc`. `event` is null. `summary` is `Exchange`. |
| `exchange` | The same change under Riverpod. `adapter` is `riverpod`. `event` is null. `summary` is `Exchange`. |
| A ring | `LinePhone` for the caller and the called phone, and `SwitchDesk`. An idle phone is absent. The cord blinks without further rebuilds. |
| An answer | Those same widgets. The called phone was on hook with Ringing signal and is now off hook with Voice. |

`captureStateValues` stays off.

### CaptureGuide

CaptureGuide is the no-adapter reference. It has no Bloc and no Riverpod. Screen-local state is `setState`. `Sunny16View` is one of those screens: changing the aperture rebuilds that widget and nothing else has to be instrumented.

The app also has `AppModel`, a `ChangeNotifier` shared through `AppScope`. That is app state, and v1 does not read it. The Sunny 16 script stays on the calculator so the session is rebuilds and frames only. Favorites, locale, and gear go through `AppModel` and are not the script.

The check runs against the tree as it is today. Do not add `insight` or `insight_bloc` for it. The CLI attaches from outside. A passing session has `Sunny16View` rebuilds and has no `state.changed` and no `agent.ready`. That is the proof the collector still works when the in-app agent is absent.

CaptureGuide's SDK constraint is `^3.13.2`, which is the Dart line paired with Flutter 3.47. It stays outside this repository (`publish_to: none`). The recorded screen is a camera calculator, and the session file still stays on the machine that recorded it.

stayAble is the wrong app for the CaptureGuide slot. It depends on `flutter_riverpod` 3.4.x, Drift, and `payload_flutter`. It is the dogfood app for `insight_riverpod`.

## Public API in v1

```dart
Insight.traceFuture<T>(Future<T> Function() body, {String? name});
Insight.traceStream<T>(Stream<T> source, {String? name});
Insight.captureStateValues = false;
```

`insight_bloc` exposes `InsightBlocObserver`. The app assigns it with `Bloc.observer = InsightBlocObserver()`. The `flutter_bloc` types it implements are the 9.1.x line. That pin lives in `insight_bloc`, not in `insight`.

Names default to `future` and `stream` when omitted. `traceFuture` forwards the value and the error after recording the span.

## Risks owned by this schedule

| Risk | What v1 does about it |
| --- | --- |
| Rebuild timeline events are not a stable API | Two supported Flutter lines, named in [runtime.md](runtime.md), each backed by a profile-mode parser test on `examples/bloc_counter` |
| Build profiling distorts timings | Rebuild records carry names and times of occurrence. Frame `buildUs` / `rasterUs` come from `Flutter.Frame`, which does not depend on that flag |
| CI numbers move between machines | The recorder writes a file. `tool/beside.dart` prints two files. Neither one passes or fails a run |
| State payloads can leak secrets | `value` defaults to `null`. Opt-in strings are truncated |
| `flutter_bloc` major versions | The adapter is its own package, first pinned to 9.1.x |
| `flutter_riverpod` major versions | `insight_riverpod` is its own package, first pinned to 3.4.x |
| A private app has secrets in its events | The reference app is `examples/desk`, which has none. `value` still defaults to null. Session files from any other app stay on the machine that recorded them |
| Two VM clients | The extension uses `serviceManager`. The CLI is the only other client, and not at the same time |

## After v1

Only after the phase 3 checks pass, and only one of these at a time:

1. A second supported Flutter stable. Done: the `examples/bloc_counter` profile check passed on Flutter 3.44.9. A newer stable still needs its own check.
2. Riverpod, as `insight_riverpod`, speaking the same `state.changed` record. Done: the `examples/riverpod_shelf` profile check passed on Flutter 3.47.8. A wide tick groups `second` → `int` with `WideShelf`, `SecondReadout`, and `MarkCard` (`frame_69` and `frame_239`). A scoped tick groups the same provider with `SecondReadout` and without `MarkCard` (`frame_159`). `adapter` is `riverpod`, `event` and `value` are null, and `rejected` is 0. stayAble remains the dogfood app. That session was not this check.
3. A side-by-side reader for two session files, such as the desk's scoped tick and wide tick, without a pass/fail exit code. Done: `dart run tool/beside.dart --left a.json --right b.json` prints both flows. It exits 0 when both files are schema 1, including when the widget names differ.

Cause labels, a CI threshold, and a desktop app wait until those three exist and the alpha has been used on the desk. They are not scheduled here. The public sequence is [roadmap.md](roadmap.md).
