# Exchange 2

A proposal for a second example. The switch and the phones are separate programs. The phones talk to the switch over HTTP. The switch keeps each phone's current state, and a log of what happened, in a database. An Insight server reads the scenario and sends each step to the program that should run it.

This does not replace `examples/exchange`. That board stays the short pair: one process, Bloc beside Riverpod. The call rules stay the ones in [running-example.md](running-example.md). This file is how those rules sit across processes, and what a recording of each process shows.

## What a recording can show

Insight records one VM Service client. The switch and each phone are their own processes, so each recording is one of them.

A tap on a phone is a `user.action` in that phone's session. The same tap arrives at the switch as an HTTP command. The switch session has the `async.span` for that command, the `async.span` for the database write, a `state.changed` for the whole switch, and the rebuilds of the line row and the log. The phone session has the tap, the span for its own request, a `state.changed` for that one line, and the rebuild of that phone.

The two files do not share a clock. `timeUs` is `Timeline.now` inside one isolate. The scenario is what puts a phone step next to the switch step it caused. Compare still reads two recordings of the same role, played from the same scenario text. A switch recording beside a phone recording is two views of one run. It is not the Bloc-beside-Riverpod pair.

`Insight.captureStateValues` stays off. The line text is on the screen, so the recording shows the widget that painted it.

## The two programs

`examples/exchange2/switch` is the operator desk and the HTTP server. It is the only place that decides a call. One instance listens on `127.0.0.1:8765`.

`examples/exchange2/phone` is one handset. The line number comes from the `LINE` environment variable, or from `--dart-define=LINE=2` when that variable is unset. A second phone is a second process with another `LINE`. Every phone runs the same built program. The phone sends hook and digit. It draws the snapshot the switch returns. It does not decide busy, camp-on, or recall.

On Windows the switch window opens in the middle of the work area. Its icon is a switchboard. Each phone is a smaller window seated around that desk, clockwise from the top, and its icon is a handset. `LINES` is how many seats are on that ring. The start script sets it from the line count, and a scenario sets it from the highest phone it starts.

Both programs call `Insight.attach()`. On startup each one also registers with the Insight server. The switch is the program that has the three profiles, because that is the state row Compare already knows how to line up. `bloc` draws `LineRow` and `ActivityLog` from `ExchangeCubit`. `riverpod` names the state row `exchange`. `plinth` keeps `ExchangeCubit` and draws `PlinthLine`, `PlinthPaper`, `PlinthBadge`, and `PlinthLog`. The phone is a single `PhoneCubit`.

## Functions

### Switch

- Listen on port 8765. Refuse to start when that port is taken.
- Delete `exchange2.db` on startup, so a scenario begins with no lines and an empty log.
- Accept a phone registering its line number. Create that line as idle.
- Accept hook off, hook on, and one digit from a registered line.
- Apply the call rules. Update that line, and any other line the rule names.
- Write the current row for each changed line, and append one activity row.
- Show one row per registered line: number, hook, signal, and detail.
- Show the activity log under the rows, oldest at the top.
- The desk does not take taps. Calls are made on the phones.

### Phone

- Register its line when the window opens.
- Show the line number, the hook, at most one signal, and the detail text, using the same words as the board in [running-example.md](running-example.md).
- A Keys button opens a keypad. The keypad also opens when `digits` is not empty. It always offers 0 through 9. Close hides it until the next time a digit is needed, or until Keys is pressed again.
- A tap on the hook hooks an idle, ringing, or recall phone off, and hooks any other phone on. A digit key sends that digit.
- Wait on one long-poll for the next snapshot. When it arrives, draw it and wait again.

### Calls

The rules are unchanged: dial, answer, refuse, hook on, busy, `01`, two waiters for one line, and `01` split by a hang-up between the `0` and the `1`. Dialing a number that has not registered is the exception. That phone's signal is "Line does not exist", and there is no line to camp on. The switch owns the rules. A phone cannot camp on by itself. It sends `0`, then later `1`, and the switch decides.

## HTTP

The phone is the client. Every response that names a line is one snapshot.

```json
{
  "revision": 4,
  "number": 1,
  "hook": "off",
  "signal": "ringing",
  "detail": "Calling 2",
  "digits": ["1", "2", "3", "0"]
}
```

`revision` increases by one each time the switch emits. `digits` lists the registered lines and `0` while this line is dialing or hearing busy, and is empty otherwise. The keypad uses that list only as the signal to open. The keys themselves are always 0 through 9. `hook` is `on` or `off`. `signal` is `none`, `line`, `ringing`, `busy`, `missing`, or `voice`. `missing` is shown as "Line does not exist".

| Request | Who traces it | Result |
| --- | --- | --- |
| `POST /lines/{n}/register` | Switch, span `POST register` | Creates the idle line. A second register from the same number returns the current snapshot. |
| `POST /lines/{n}/hook` with `{ "off": true }` or `{ "off": false }` | Switch, span `POST hook`. Phone, span `POST hook` | The switch applies the hook rule and returns that phone's snapshot. |
| `POST /lines/{n}/digit` with `{ "digit": "2" }` | Switch, span `POST digit`. Phone, span `POST digit` | One digit. The switch returns that phone's snapshot. |
| `GET /lines/{n}/wait?after={revision}` | Phone, span `GET wait` | Held open until `revision` is greater than `after`, or for 25 seconds. The 25 second reply carries the same revision. The phone starts another wait and does not treat it as a change. |

The switch does not trace the parked `GET`. A span belongs to every frame it overlaps, and a wait can sit open for seconds. The command spans are the ones that belong on the switch timeline. The wait span belongs on the phone that is waiting.

An unknown line is HTTP 404. A digit while the phone is on hook is HTTP 409. The span for that request ends with `status` `error`.

## Database

One SQLite file, `exchange2.db`, beside the switch process. The cubit holds the same facts in memory and emits them. The file is what survives a look at the desk after the command has returned. Insight never reads the file. The insert and the update are spans, and the desk widgets rebuild from the emit.

`lines` is the current state, one row per registered number. A change replaces that row.

| Column | Meaning |
| --- | --- |
| `number` | Primary key. The line. |
| `hook` | `on` or `off` |
| `signal` | `none`, `line`, `ringing`, `busy`, `missing`, `voice` |
| `detail` | The phone text, such as `Calling 2` or `Waiting for 1` |
| `status` | The rule status: idle, dialing, busyTone, noSuchLine, waiting, recall, recallRing, calling, ringing, inCall |
| `peer` | The other line, when there is one |
| `waiting_for` | The camp-on target, when this line is waiting |
| `revision` | The switch revision that wrote this row |

`activity` is append-only. The desk shows these lines in order.

| Column | Meaning |
| --- | --- |
| `id` | Primary key |
| `line` | The phone the row is about |
| `action` | `registered`, `hook off`, `hook on`, `digit`, `ringing`, `answered`, `in call`, `cleared`, `waiting` |
| `detail` | Short text the desk can show, such as `1 digit 2` or `3 waiting for 1` |

Inside `POST hook` and `POST digit`, the switch also traces `update line` and `insert activity`. Those spans overlap the command span and the frame that rebuilds the desk.

## Shape

```
Insight server :8790
reads the scenario, sends one step to one program
        │ register          │ register         │ register
        ▼                   ▼                  ▼
┌──────────────┐   HTTP   ┌──────────────────┐   HTTP   ┌──────────────┐
│ phone 1      │ ───────► │ switch :8765     │ ◄─────── │ phone 2      │
│ PhoneCubit   │ ◄─────── │ ExchangeCubit    │ ───────► │ PhoneCubit   │
└──────────────┘ snapshot │ lines + activity │ snapshot └──────────────┘
                          │        │         │
                          │        ▼         │
                          │  exchange2.db    │
                          │  LineRow, log    │
                          └──────────────────┘
```

The pure call rules live in `examples/exchange2/rules`, with no Flutter and no HTTP. The switch is the only caller. The phone never imports them.

On a command, the switch does five steps in order:

1. Apply the rule in memory.
2. Replace each changed `lines` row.
3. Append one `activity` row.
4. Emit. The desk rebuilds the changed line rows and the log.
5. Complete any parked `GET` whose line revision moved, with that phone's snapshot.

A phone does three steps when the user taps, and the same three when the Insight server sends that tap:

1. Post `user.action` (`hook` or `digit-2`).
2. Send `POST hook` or `POST digit`, traced as that span.
3. Store the snapshot and rebuild. The open `GET wait` stays up until a later revision, including a ring caused by someone else.

## Insight server

The Insight server is a tool in this repository, beside `play`. It is not the telephone switch. The switch on port 8765 decides calls. The Insight server on `127.0.0.1:8790` decides which program runs the next scenario step. `play` stays the runner for one process. This server is the runner for a scenario that names more than one.

Each program registers once, when its window opens.

```json
{
  "role": "phone",
  "name": "phone",
  "instance": "1",
  "vmServiceUri": "http://127.0.0.1:12345/token=/"
}
```

`role` is `switch` or `phone`. `name` is the word the scenario uses, `switch` or `phone`. `instance` is which copy. Phone 2 sends `"instance": "2"`. The one switch sends `"instance": "1"`. `vmServiceUri` is how `record` finds that process. A second register from the same name and instance replaces the first.

The server reads the scenario file. It does not send the file to the programs. It waits until every instance the file names has registered, then walks the lines. A line is sent only to the program selected by the current `on` line. That program asks for the next command and replies when it has finished.

| Line | Who acts | What happens |
| --- | --- | --- |
| `start switch` or `start phone 1` | Server | Launches that process, then waits until it registers. An instance that is already registered satisfies `start`. |
| `record switch` or `record phone 1` | Server | Attaches the collector to that registration's VM Service URI. One recording per run. |
| `on phone 1` or `on switch` | Server | The following `tap` and `see` lines go to that name and instance. |
| `tap hook` | That program | Presses the control, posts `user.action`, and replies. |
| `see Calling 2` | That program | Replies when that text is on screen. The wait is the same 90 frames `play` uses. |
| `delay 200` | Server | Waits 200 milliseconds, then reads the next line. Nothing is sent. |

`delay` takes a whole number of milliseconds. It sits between two steps when the next tap or `see` should wait a known time, such as a ring crossing the network before the next digit. `see` is still how the script checks the screen. A delay does not check anything.

The border case uses both. Phone 5 sends `0`, the server tells phone 1 to hook on, `delay` gives that hang-up time to reach phone 5, and only then phone 5 is told to send `1`.

```text
on phone 5
tap digit-0
on phone 1
tap hook
delay 200
on phone 5
tap digit-1
see Calling 1
```

## What each recording contains

Answered call: phone 1 dials phone 2, phone 2 hooks off. Recorded on the switch, profile, Bloc:

| After | Spans | State row | Widgets |
| --- | --- | --- | --- |
| Phone 1 hooks off | `POST hook`, `update line`, `insert activity` | `ExchangeCubit`, event null, summary `Exchange` | `LineRow` 1, `ActivityLog` |
| Phone 1 dials 2 | `POST digit`, `update line`, `insert activity` | `ExchangeCubit` | `LineRow` 1, `LineRow` 2, `ActivityLog` |
| Phone 2 hooks off | `POST hook`, `update line`, `insert activity` | `ExchangeCubit` | `LineRow` 1, `LineRow` 2, `ActivityLog` |

The same run recorded on phone 1:

| After | Tap | Spans | State row | Widgets |
| --- | --- | --- | --- | --- |
| Hook off | `hook` | `POST hook` | `PhoneCubit` | `Handset` |
| Dial 2 | `digit-2` | `POST digit` | `PhoneCubit` | `Handset`, `Keypad` |
| Phone 2 answers | none | `GET wait` ends | `PhoneCubit` | `Handset` shows Voice |

Riverpod on the switch names the state row `exchange`. The spans and the widget names stay. That is the pair Compare is for.

An idle phone's recording stays on its open `GET wait`. It does not rebuild because another line changed.

## Start it by hand

From the repository, on Windows:

```powershell
.\examples\exchange2\start.ps1
.\examples\exchange2\start.ps1 riverpod 5
.\examples\exchange2\start.ps1 plinth
```

The same commands from a checkout:

```bash
dart run examples/exchange2/start.dart
dart run examples/exchange2/start.dart riverpod 5
dart run examples/exchange2/start.dart plinth
```

The first argument is the profile: `bloc`, `riverpod`, or `plinth`. The default is `bloc`. The line count is how many phones open. It is a whole number from 1 to 9. The default is 3. The switch opens first, in the middle. Then one smaller phone for each line, around the desk. Click the phones. Keys opens the keypad, and the keypad also opens on its own while that line is dialing or hearing busy. The desk only watches. Press Enter in that terminal to stop them.

A recording of one of those windows uses the VM Service address `flutter run` prints. Leave the Insight tab closed.

```bash
dart run packages/insight_cli/bin/insight_cli.dart --uri http://127.0.0.1:50849/token=/ --duration 60 --out examples/exchange2/switch-session.json
```

The switch address records every line. A phone address records that handset. Recording starts immediately and lasts `--duration` seconds.

## Scenarios

[test.ps1](../examples/exchange2/test.ps1) reads one scenario file, starts the programs it names, plays the steps, and stops them. `play` stays the one-process runner it is today.

```powershell
.\examples\exchange2\test.ps1 bloc .\examples\exchange2\scenarios\answered-call.txt
.\examples\exchange2\test.ps1 riverpod .\examples\exchange2\scenarios\answered-call.txt
```

```bash
dart run examples/exchange2/test.dart plinth examples/exchange2/scenarios/answered-call.txt
```

The first argument is the profile: `bloc`, `riverpod`, or `plinth`. `--debug` records the order without frame times worth keeping. The default mode is profile.

`examples/exchange2/scenarios/answered-call.txt`

```text
start switch
start phone 1
start phone 2
record switch

on phone 1
tap hook
delay 150
tap digit-2
see Calling 2

on phone 2
see Ringing
tap hook
see In call with 1

on switch
see 1 and 2
see 1 digit 2
```

`examples/exchange2/scenarios/two-waiters.txt` starts phones 1 through 5, records the switch, and follows the same taps as [two-waiters.txt](../examples/exchange/scenarios/two-waiters.txt). The switch log then contains both `3 waiting for 1` and `4 waiting for 1`. After phone 1 hooks on, the log gains `3 ringing`, and `4 waiting for 1` is still the last waiting line.

A second pass of the same file with `record phone 5` is how the split `01` shows up on a handset. The server sends `digit-0`, then tells the phone that holds the call to hook on, waits with `delay`, then sends `digit-1`. The snapshot comes back `Calling 1` with the other line still idle.

## Left out

One switch. Phones on this machine only. No login, and no second hop between phones. The database file is deleted on startup. Sessions stay schema 1. Two recordings are not merged into one timeline. The Insight server sends steps. It does not become a second collector, and it does not record two processes into one file.
