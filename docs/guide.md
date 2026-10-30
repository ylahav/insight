# Using Insight

Who this is for: someone opening a session to see what an app did, not someone changing the collector.

The field rules are in [events.md](events.md). This page is the benefit, and the way to read a file.

## What you get

DevTools already charts frame time. Insight puts four observations on one clock:

- a frame
- the user widgets that rebuilt during that frame
- a bloc or cubit transition
- an async span the app chose to trace

The question it answers is: when this bloc event happened, which frame followed it, and which of your widgets rebuilt in that frame.

That is the whole product. A shared time window is the observation. The file has no cause field, no confidence score, and no pass or fail. Two records sitting together means they happened close together.

The comparison that matters is the widget names. `examples/desk` has two trees and one clock cubit. A tick on the scoped tree is followed by `ClockReadout`. The same tick on the wide tree is followed by `ClockReadout` and every `TicketCard`. The cubit is the same. The names are the difference.

## What to record

Use a debug or profile run on a phone, emulator, or desktop. Flutter web is unsupported. Release mode has no VM service.

Debug is for the order of events. Profile is for the frame times you might compare later. `buildUs` and `rasterUs` from a debug run are not numbers to keep.

Leave `Insight.captureStateValues` off. A record then carries the bloc type, the event type, and the state type. An event object can hold a password or a token. Those fields stay on the object in the app.

Trace only a call you already care about. The desk does this for its load:

```dart
await Insight.traceFuture(loadBoard(), name: 'loadBoard');
```

The session then has one `async.span` named `loadBoard`. The desk keeps that span open until the frame that paints the tickets, so the span and the `TicketCard` rebuilds share a row. The `BoardLoadRequested` record is stamped when the handler starts, a third of a second earlier, so that state change can sit outside the 32 ms window.

## Two ways to look

The Insight tab draws a flow of changes, earliest at the top. The title of each step is the bloc or cubit change, such as `ClockCubit → ClockTick`, or a traced call, such as `loadBoard → completed`. The frame time is the small line under that title, then the app widget names. A step appears when a frame has a bloc or cubit change, or a traced call. Flutter wrappers such as `Text`, `Padding`, and `Row` stay hidden until you press **Show all widgets**. Frames that only contain rebuilds stay hidden until you press **Show all frames**. A traced call is shown once, on the earliest frame it overlapped, with that frame count beside the name. **Pause** holds the rows on screen while the session keeps recording. The label **Time grouping** means those records share a time window. It does not mean one caused the other.

Use a file when you want to study one action. The tab is still a live session, and a long run is still mostly the frame pump.

Record with the CLI while that action happens, and leave the Insight tab closed. The tab and the CLI are two clients on one VM. One session at a time.

From the repository root, this starts the app and fills in the VM Service address for you:

```bash
dart run tool/record.dart --app examples/desk --duration 15
```

Press Enter when the window is up, then do the action during the recording. The file is written in the app directory. Keep the duration short. A long file is mostly the frame pump.

Open DevTools from the link `flutter run` prints. That link already contains the VM address. A DevTools page opened on its own asks you to connect. Copy the `http://127.0.0.1:...` line from that same terminal.

## How to read a file

Open `insight-session.json`. Check the envelope first.

| Field | What to check |
| --- | --- |
| `schemaVersion` | `1` |
| `flutter` | `3.44.x` or `3.47.x`. Another line is not a supported capture |
| `mode` | `debug` or `profile` |
| `rejected` | `0`. A higher count means some agent or timeline records were dropped. The rest of the file is still there |

Then find the one record that is your action. Ignore the rest until that record is in hand.

**A bloc, cubit, or Riverpod change** is `type` `state.changed`. Read `adapter`, `name`, `event`, and `summary`. `adapter` is `bloc` or `riverpod`. For a cubit, and for a Riverpod update with no mutation, `event` is null. `value` is null unless the app opted in. A Riverpod `name` is the provider's label when one was set, and otherwise the provider's runtime type.

The frame that followed it is the earliest `frame` whose `timeUs` is at or after the state time, when the gap is at most 32 ms. In the desk example, `TicketSelected` is at `500000` and the frame starts at `500800`. The gap is 0.8 ms, so they group. A gap larger than 32 ms leaves the state ungrouped. The panel shows that row as ungrouped.

**Widgets** are `type` `widget.rebuild`. A rebuild belongs to the frame whose interval `[timeUs, timeUs + elapsedUs]` contains the rebuild's `timeUs`. In the example, `TicketDetail` at `501200` falls inside the frame that starts at `500800` and lasts `4200` microseconds. Those names are the list to write down. Framework phases such as `BUILD` and `LAYOUT` are already discarded. What remains is user-widget types, including widgets from libraries the screen uses. The panel hides Flutter wrappers such as `Text` and `TextButton` until you ask for them.

**An async span** is one record, merged from a start and an end. Read `name`, `status`, `startUs`, and `endUs`. `completed` and `error` have an `endUs`. `error` is at most 200 characters and there is no stack trace. `unfinished` means the session ended before the call finished, so `endUs` is null. The span groups with every frame that overlaps `[startUs, endUs]`.

The file itself stores no links between records. The tab computes the same windows for display, and it can hide wrappers, rebuild-only frames, and repeated span rows. The file still has one record per rebuild, not a running total.

## A session worth keeping

One action, one file. For the desk, three files are worth keeping:

- **Scoped tick.** `state.changed` for `ClockCubit`, `event` null, `summary` `ClockTick`, `value` null, grouped with the following frame. That frame has `ClockReadout` and does not have `TicketCard`.
- **Wide tick.** The same cubit record. That frame does have `TicketCard`.
- **Load.** `async.span` named `loadBoard`, `status` `completed`, a non-null `endUs`, overlapping a frame that contains `TicketCard`. **Fail load** is the same name with `status` `error`, a non-null `error` of at most 200 characters, and no stack trace.

Compare the widget names in the two tick frames. Byte-identical files are not the goal.

The exchange is the same kind of reading with two drivers. Record one ring with Bloc and the same ring with Riverpod, as [running-example.md](running-example.md) describes. The widget names should match. The state row is `ExchangeCubit` or `exchange`.

From the repository root, two schema-1 files can be printed together:

```bash
dart run tool/beside.dart --left scoped.json --right wide.json
```

Each numbered step is one change, earliest first. The left file is the first column and the right file is the second. A shelf tick prints like this:

```text
Time grouping, not a cause.
left   scoped.json
right  wide.json

1.
second → int        second → int
1.7 ms · frame_159  1.7 ms · frame_69
                    WideShelf
SecondReadout       SecondReadout
                    MarkCard
```

The first row of the step is the change. The second row is the frame time. The rows after that are widget names. `SecondReadout` shares a row because both files rebuilt it. `WideShelf` and `MarkCard` sit only in the right column. Flutter wrappers such as `Text` and `Padding` stay hidden. The process exits 0 when those names differ. A missing file, or a file that is not schema 1, exits 1.

If `rejected` is greater than zero, or `flutter` is outside 3.44.x and 3.47.x, record again before comparing.
