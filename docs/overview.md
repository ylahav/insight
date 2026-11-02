# Why Insight for Flutter

<img src="../brand/logo.png" alt="Insight for Flutter" width="560">

Insight is an independent project and is not affiliated with, sponsored by, or endorsed by Google LLC. Flutter and the related logo are trademarks of Google LLC.

The wordmark is [brand/logo.png](../brand/logo.png) and the app icon is [brand/icon.png](../brand/icon.png). Both are cut from [brand/sheet.jpg](../brand/sheet.jpg). Analyzer and the Windows installer use that icon.

Insight for Flutter is a debugging aid. One row shows a state change, the frame that followed it, and the user widgets that rebuilt in that frame.

DevTools already charts how long a frame took. A bloc log already says a cubit changed. The widget inspector can show what rebuilt. Those are three places. The question that sits between them is one question: when this state changed, which frame followed, and which of your widgets rebuilt.

That question is what a session is for.

## Why that question needs its own tool

A screen that feels busy is usually a list of names. The clock ticked, and every card on the board rebuilt. A load finished, and the tickets appeared on a later frame than the event that started the load. Two ways of holding the same screen rebuilt different widgets for the same tap.

Frame time alone does not name those widgets. A state log alone does not name the frame. Insight records both on one clock, in debug and in profile, for Bloc, Cubit, and Riverpod.

The alpha has been checked on Flutter 3.47.8. The small parser fixture has also been checked on Flutter 3.44.9.

## What you get

**One row for one change.** The title is the state change, such as `ClockCubit → ClockTick` or `second → int`. Under it is the frame time, then the app widget names.

**The names are the finding.** On the desk, a scoped tick lists `ClockReadout` and leaves `TicketCard` off the row. The same tick on the wide tree lists `ClockReadout` and every `TicketCard`. The cubit record is the same. The extra names are the issue: the board is watching the clock above the list.

**A file you can keep.** One action, one session file. `tool/compare.dart` prints two files in step order. It exits 0 when the widgets differ. That difference is the reading. `tool/analyzer` opens one recording, and Add result compares another with it. On Windows the tools are one installer, as [windows.md](windows.md) describes.

**A span for a call you already care about.** `Insight.traceFuture` records one `async.span`. On the desk, `loadBoard` stays open until the frame that paints the tickets, so the span and the `TicketCard` rebuilds share a row. Fail load is the same name with status `error`.

**Types, not payloads.** A record carries the bloc or provider name, the event type when there is one, and the state type. `value` stays null unless the app sets `Insight.captureStateValues`. Event fields stay in the app. A session file stays on the machine that recorded it.

**Rebuilds with no state library.** Frames and user-widget rebuilds come from the VM. An app that never calls the Insight API still shows those. CaptureGuide's Sunny 16 screen is that case: `Sunny16View` rebuilds, and the session has no state row.

## What a row is allowed to say

The label on the panel is **Time grouping**. Records on one row share a time window of 32 ms. A state change belongs to the earliest frame at or after its time when the gap is inside that window. A larger gap leaves the state on its own row.

Two records on one row happened close together. The file has no cause field and no pass or fail. A widget name on the row is a widget that rebuilt in that window. The list is what you take back to the code.

Debug is for the order of events. Profile is for frame times you might compare later. `buildUs` and `rasterUs` from a debug run are not numbers to keep.

Flutter web and release builds produce no session. Another Flutter version stays unsupported until the same parser check has passed on it.

## See it on the desk

From `examples/desk`:

```bash
flutter run -d windows
```

Open the DevTools link that command prints, and open the Insight tab. Leave any CLI recorder disconnected while the tab is open. The tab and the CLI are two clients on one VM.

Press **Tick**. On Scoped, the row is `ClockCubit` with `ClockReadout`, and `TicketCard` is absent. Press **Wide**, then **Tick** again. The same cubit now lists `TicketCard`.

That second list is the issue. The wide tree reads the clock in the widget that builds the cards. The scoped tree lets `ClockReadout` read it alone. The two lists are the same kind of row, so the extra names are easy to see.

The shelf is the same comparison for Riverpod. From `examples/riverpod_shelf`, press **Tick**, then **Wide**, then **Tick**. Scoped lists `SecondReadout`. Wide also lists `MarkCard`. The provider name is `second`.

## Read one action

Use one action per look. A long run is mostly the frame pump.

**Live.** Run the app in debug or profile. Open the Insight tab from the DevTools link `flutter run` prints. Do the action. The flow is earliest first. The title is the state change or the traced call. The frame time is the line under it. The names under that are your widgets. Flutter wrappers such as `Text` and `Padding` stay hidden until **Show all widgets**. Frames that only rebuilt stay hidden until **Show all frames**. **Pause** holds the list while the session continues.

**A file.** Record with the CLI and leave the tab closed. From the repository root:

```bash
dart run tool/record.dart --app examples/desk --duration 15
```

Press Enter when the window is up, then do the one action. The file is `insight-session.json` in the app directory. `--profile` is the mode for frame times.

**Two files.**

```bash
dart run tool/compare.dart --left scoped.json --right wide.json
```

Each step is one change, in two columns. How to read that print is in [guide.md](guide.md).

Before you compare, check the envelope. `schemaVersion` is `1`. `flutter` is `3.44.x` or `3.47.x`. `mode` is `debug` or `profile`. `rejected` is `0`. A higher `rejected` means some records were dropped. Record again before you treat the names as complete.

## Where an issue shows up

**A widget you did not expect.** The title is the change you made. A name under it rebuilt in the following frame. On the exchange, dialing an idle line lists `LinePhone` for the caller and the called phone, and `SwitchDesk`. An idle phone is absent. A third `LinePhone` on that row rebuilt for a call it is not in. The wide board is that row, and the reading is in [what-can-be-learned.md](what-can-be-learned.md).

**The same change, a longer list.** Record the action twice, once in each arrangement, and read them with `compare`. The state title matches. The extra names are the widgets the wider tree rebuilt. The desk's `TicketCard` rows and the shelf's `MarkCard` rows are that finding.

**A call and the frame that painted it.** Trace the call you already care about:

```dart
await Insight.traceFuture(loadBoard(), name: 'loadBoard');
```

The panel shows that span once, on the earliest frame it overlapped, with a frame count. On the desk, `loadBoard` overlaps the frame that contains `TicketCard`. `BoardLoadRequested` is stamped when the handler starts, about a third of a second earlier, so that state change can sit on its own row. The span is the record that meets the paint. **Fail load** is the same name with status `error`, a short error string, and no stack trace.

**Two drivers, one screen.** The exchange is one board. Open with Bloc or Open with Riverpod chooses who holds the switch. Record the same ring both ways. The widget names should match. The state row is `ExchangeCubit` or `exchange`. A widget name that appears for only one driver is the difference to open. The script is in [running-example.md](running-example.md). The same rules with the switch and each phone in its own process are in [exchange2.md](exchange2.md). That example is under investigation and is not fully tested.

**No state library.** Frames and rebuilds still record. A session of CaptureGuide's Sunny 16 screen has `Sunny16View` and has no `state.changed` row. The finding there is which of your widgets rebuilt.

## Put it on an app

The packages live in this repository. They are not on pub.dev yet. An app enables the tab by depending on `insight`, calling `Insight.attach()`, and turning the extension on.

A Bloc or Cubit app also sets the observer:

```dart
void main() {
  Insight.attach();
  Bloc.observer = InsightBlocObserver();
  runApp(const MyApp());
}
```

A Riverpod app passes its observer to `ProviderScope`:

```dart
void main() {
  Insight.attach();
  runApp(
    const ProviderScope(
      observers: [InsightRiverpodObserver()],
      child: MyApp(),
    ),
  );
}
```

`devtools_options.yaml` at the app root:

```yaml
extensions:
  - insight: true
```

Leave `Insight.captureStateValues` off. Trace a future or a stream only when that call should appear on the timeline. The first time the Insight tab opens, DevTools asks you to allow the extension.

The field-by-field rules for a saved file are in [guide.md](guide.md).
