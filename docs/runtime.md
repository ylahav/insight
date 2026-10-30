# Runtime

How Flutter Insight is split across processes, which build modes produce data, and which Flutter versions the collector claims to understand.

This file, [events.md](events.md), and [mvp.md](mvp.md) are the design of record.

The first implementation targets **Flutter 3.47.x stable / Dart 3.13.x**, which was the stable line on 28 Oct 2026 (3.47.8, Dart 3.13.7). Another Flutter version is unsupported until a collector parser test passes on it.

## Two processes

State and traced async work exist only inside the app isolate. Frame timings and rebuild timeline events exist on the Dart VM Service. One package cannot sit on only one side of that boundary and see both.

```
App isolate                          DevTools or CLI
┌─────────────────────────┐          ┌──────────────────────────┐
│ insight                 │          │ insight_collector        │
│   posts Insight.Event   │          │   one VM Service client  │
│ insight_bloc            │ ───────► │ insight_devtools (UI)    │
│   BlocObserver          │   VM     │   or insight_cli (file)  │
└─────────────────────────┘ Service  └──────────────────────────┘
```

The in-app agent publishes. The collector translates VM traffic into the session file described in [events.md](events.md). The UI and the CLI are two consumers of that same model. They are not two collectors running at once against one app.

### In the app

| Package | Role |
| --- | --- |
| `insight` | Public API. Posts agent events. Ships the DevTools extension assets under `extension/devtools/`. Depends on Flutter, not on `flutter_bloc`. |
| `insight_bloc` | Bloc adapter. Depends on `insight` and `flutter_bloc`. This is the only state adapter in v1. The first pinned line is `flutter_bloc` 9.1.x. |

`insight` posts on the VM Service `Extension` stream with `developer.postEvent('Insight.Event', payload)`. Each payload includes `timeUs` from `Timeline.now`. That is the same clock as `Flutter.Frame`'s `startTime`. The Extension event's own timestamp is wall-clock microseconds and is not used for ordering.

`postEvent` is discarded when the Extension stream has no listener. `Insight.attach()` still posts once at startup, and it registers `ext.insight.agent`. The collector subscribes first, then calls that extension, which posts `agent.ready` again. There is no periodic heartbeat. An app that depends on `insight` and never calls the API still emits only `agent.ready`, and only after a collector asks. Frame data does not require the agent. If the collector never sees `agent.ready`, the UI says the in-app package is absent and continues to show frames.

`Insight.captureStateValues` defaults to `false`. With the default, a state event carries the bloc or cubit type, the bloc event's type name when there is one, and a short state-type summary. Event fields are never posted. `LoginButtonPressed` holds an email and a password, and those stay in the app even when the flag is on. Previous and next state strings are sent only after the app sets the flag, truncated as specified in [events.md](events.md). Opt-in values can contain tokens and personal data. v1 does not try to detect secrets. Truncation is the only automatic limit.

Rebuild profiling stays off until the collector enables it. The agent never turns it on by itself.

### Outside the app

| Package | Role |
| --- | --- |
| `insight_collector` | Pure Dart. Parses VM streams into the session model. No Flutter dependency. |
| `insight_devtools` | Flutter web source for the extension. Depends on `insight_collector`, `package:devtools_extensions`, and `package:devtools_app_shared`. Its release build is copied into `insight/extension/devtools/`. Apps do not depend on this package. |
| `insight_cli` | Pure Dart executable. Depends on `insight_collector`. Opens a VM Service URI itself and writes a session file. |

The repo uses a Dart pub workspace at the root once these packages exist. `flutter pub get` at the root does nothing useful until that workspace `pubspec.yaml` is in the tree.

### The DevTools connection

Users enable the tool by depending on `insight` and `insight_bloc`. The app sets `Bloc.observer` to the observer `insight_bloc` provides. That assignment is the whole install. `examples/desk` does it in `main`. DevTools loads the extension from `insight/extension/devtools/` after the app's `devtools_options.yaml` enables it. The first open asks the user to allow the extension. That is the DevTools extension flow, documented at <https://docs.flutter.dev/tools/devtools/extensions>.

`flutter pub global activate` is the install path for `insight_cli` only. It does not add a DevTools tab.

The extension reads the VM through the `serviceManager` global provided under the `DevToolsExtension` widget. DevTools passes the connected app's VM Service URI, and `serviceManager` owns that client. The extension does not look up a VM URI on its own and does not open a second client beside `serviceManager`.

The CLI is the consumer that opens a URI itself, from `flutter run` or `flutter attach`. A debugging session uses the extension or the CLI, not both. Two clients subscribed to the same timeline streams double the observation traffic.

Widget-build profiling is enabled by the collector through the framework service extension `ext.flutter.profileUserWidgetBuilds` (`WidgetsServiceExtensions.profileUserWidgetBuilds`). That flag corresponds to `debugProfileBuildsEnabledUserWidgets`. It records user-created widgets and costs less than `ext.flutter.profileWidgetBuilds`. The collector turns it on when a session starts and turns it off when the session ends.

## What the collector reads

| Session record | VM source | Who turns it on |
| --- | --- | --- |
| `frame` | Flutter's `Flutter.Frame` events on the `Extension` stream | Always available in debug and profile |
| `widget.rebuild` | Timeline events emitted while user-widget build profiling is on | Collector, via `ext.flutter.profileUserWidgetBuilds` |
| `state.changed`, `async.span`, `agent.ready` | `Insight.Event` on the `Extension` stream | In-app agent |

`Flutter.Frame` and the build-profiling timeline names are framework internals. They are not the public contract. [events.md](events.md) is the public contract. A Flutter upgrade that changes a timeline name is a collector parser change. Apps do not migrate.

The parser is covered by a test that runs a fixed sample in profile mode on each supported Flutter stable and checks the emitted session records. A green unit test with hand-written JSON does not count as support for a new Flutter version.

## Build modes

| | Debug | Profile | Release |
| --- | --- | --- | --- |
| VM Service | Yes | Yes | No |
| `frame` records | Yes. Durations are not representative. | Yes. These are the durations worth keeping. | No |
| `widget.rebuild` | Yes, after the collector enables build profiling. The timeline overhead is large relative to a widget build. | Yes, after the collector enables build profiling. Use the names and counts. Treat the build durations on those events as distorted. | No |
| State and async events | Yes, when the app calls the API | Yes, when the app calls the API | The agent can run, and nothing is listening |
| Session `mode` | `debug` | `profile` | Not a valid session |

Release builds are unsupported. The CLI exits with an error if it attaches to a release isolate.

Profile mode is the mode for any number someone might compare later. Debug mode is for the live panel, where seeing the sequence matters more than the microseconds. v1 does not fail a build on either number. See [mvp.md](mvp.md).

## Platforms

v1 is mobile and desktop, debug and profile.

Flutter web is unsupported until the same parser test passes on web. The CLI and the extension should refuse a web isolate with a clear message rather than emit a partial session that looks successful.

## Session lifetime

A session starts when the collector connects and ends when the connection closes, the CLI hits its duration, or the isolate exits.

Hot restart and hot reload start a new session. v1 does not stitch events across reloads. The UI shows the session boundary.

Build profiling is a session setting. Leaving it on after the tool disconnects would keep taxing the app, so the collector clears `ext.flutter.profileUserWidgetBuilds` on the way out. If the process dies first, the flag dies with the isolate.

## Package boundaries that stay intact

- `insight` does not depend on `flutter_bloc`.
- `insight_bloc` does not depend on `insight_collector` or the VM Service client.
- `insight_collector` does not depend on Flutter.
- Adapter authors depend on `insight`, implement the small observer hook, and post `state.changed` events. They do not link the collector.

Riverpod, a desktop app, and a CI pass/fail gate are outside v1. The schedule and the non-goals are in [mvp.md](mvp.md).
