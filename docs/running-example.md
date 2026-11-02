# Running example

A small private telephone switch, built once and driven twice. The widgets are shared. Bloc and Riverpod are two ways to hold the same switch. This is not a new phase. The phase list in [mvp.md](mvp.md) still ends at the side-by-side reader.

The screen is the example `examples/exchange`.

## The board

The switch has three to nine lines, numbered 1 through 9. The digit 0 is not a line. It starts a service code. The only service is `01`, camp-on.

At startup the user chooses how many lines, from 3 to 9, and chooses Bloc, Riverpod, or the Plinth board. That count and that face stay fixed until the board is closed. The switch sits in the middle. The phones stand on a circle around it. Each phone has its own color. A cord runs from one phone to the other through the switch, and the color at the switch is the mix of those two phones.

Each phone shows the hook, then at most one signal.

| Hook | Signal | What it is |
| --- | --- | --- |
| Hook on | none | Idle. |
| Hook on | Ringing signal | The called phone, while a cord is blinking. |
| Hook off | Line signal | Off hook and dialing, or waiting after `01`. |
| Hook off | Ringing signal | The caller, while this phone or the other phone is ringing. The phone names the other line. |
| Hook on | Ringing signal | Camp-on, after the caller has hooked on. The other phone is not ringing yet. |
| Hook off | Busy signal | The last dial did not connect. |
| Hook off | Voice | The call is up. The phone names the other line. |

A live call is a steady cord through the middle. A ring is a blinking cord through the middle, and the called line is named under it. The blink repaints that cord. It does not rebuild the switch. When animations are turned off, the ring cord stays lit. A camp-on request is a line of text under the cords, with no cord of its own. While the caller rings before the other phone, the switch names that caller and still draws no cord.

## A call

Click an idle phone. It goes off hook and shows the digits `1` through the last line, and `0`.

Dial one digit from 1 to the last line:

- That phone is idle. It rings. A blinking cord joins the two phones. The called phone stays on hook with Ringing signal. The caller is off hook with Ringing signal.
- That phone is waiting after `01`. It rings, and the camp-on stays. A blinking cord joins the two phones. When that call ends, the phone is waiting again.
- That phone is dialing, hearing busy, calling, ringing, or already in a call. The dialing phone shows Busy signal. No cord is drawn.
- The digit is the dialing phone’s own number, or it is higher than the line count. The dialing phone shows Busy signal, and there is no line to wait for.

The called phone answers by clicking its body. That hooks it off. Both phones show Voice, and the cord stays lit. **Hook on** under the ringing phone refuses the call. The caller can also click its own body to hook on and stop the ring.

Click the body of a phone that is calling, hearing busy, waiting, or in a call. That phone hooks on. If it was in a call or a ring, the other line clears too and the cord disappears.

## Busy and camp-on

A phone hearing busy can hook on, camp on, or dial a line.

Click its body. It returns to idle.

Dial a line number. That call is placed. If the line is idle now, it rings.

Dial `0`, then a line number other than `1`. That is the same call. `01` is camp-on. It records that this phone is waiting for the line that returned busy. The phone stays off hook, on Line signal, and names that line. Clicking its body before that line is idle cancels the request.

`01` with no line to wait for does not call line 1. That includes a phone that is only off hook, a phone that dialed its own number, and a phone that dialed a missing line. The phone stays on Busy signal and the switch records nothing.

When the waited line becomes idle, the caller rings first. The caller is still off hook and shows Ringing signal. No cord is drawn, and the other phone stays idle. That line is busy to every other caller until this recall is finished or refused. The caller hooks on. The phone stays on hook with Ringing signal. The caller then hooks off. Only then does the other phone ring, and the cord blinks. Later waiters stay on the list until that recall is finished or refused. **Hook on** under the caller's ring, after the caller has hooked on, refuses the recall. Any other off-hook phone is busy to callers, including a phone that is dialing, calling, ringing, or hearing busy. A phone that is waiting can still be called. The camp-on stays through that ring and that call. When the call ends, the phone is waiting again. If the waited line is already idle, the caller rings first.

## What one action should show

The phone widgets subscribe to one line each. The cord area subscribes to live calls, rings, caller rings, and the waiting list. An idle phone that was not part of the action does not rebuild. A blinking cord does not add rebuilds after that.

| Action | Widgets that rebuild | State row |
| --- | --- | --- |
| Phone 1 dials idle phone 2 | `LinePhone` for 1 and 2, `SwitchDesk`. The cord blinks | The whole switch |
| Phone 2 hooks off | `LinePhone` for 1 and 2, `SwitchDesk`. Both show Voice | The whole switch |
| Phone 2 hooks on while ringing | `LinePhone` for 1 and 2, `SwitchDesk`. The ring is gone | The whole switch |
| Phone 3 dials busy phone 1 | `LinePhone` for 3 | The whole switch |
| Phone 3 dials `01` | `LinePhone` for 3, `SwitchDesk` | The whole switch |
| A phone in that call hooks on, and 3 is waiting for it | The two phones leaving the call, and phone 3. Phone 3 rings. Phone 1 stays idle | The whole switch |
| Phone 3 hooks on, then hooks off | Phone 3, then phone 1 and `SwitchDesk`. The cord blinks only after the hook off | The whole switch |

`ExchangeHost` rebuilds on every change. It is the driver shell. The comparison that matters is the phone and the cords.

**Open the wide board** is the same enamel phones with every phone reading the whole switch. An idle phone then rebuilds with the phones that are in the call. The enamel board is each phone reading only its own line, so that idle phone stays off the row. The words on screen stay `Calling 2` and `2 is ringing`. The script is [third-phone.txt](../examples/exchange/scenarios/third-phone.txt). What one profile pair of those two boards showed is in [what-can-be-learned.md](what-can-be-learned.md).

```bash
dart run tool/play.dart --board wide --scenario examples/exchange/scenarios/third-phone.txt --out examples/exchange/1.json
dart run tool/play.dart --board bloc --scenario examples/exchange/scenarios/third-phone.txt --out examples/exchange/2.json
dart run tool/compare.dart --left examples/exchange/1.json --right examples/exchange/2.json
```

The installed `play` is the released program. It accepts `bloc`, `riverpod`, and `plinth`. `wide` is in this checkout, so that run uses `dart run tool/play.dart`.

Bloc records `ExchangeCubit`, adapter `bloc`, event null, summary `Exchange`, value null. Riverpod records `exchange`, adapter `riverpod`, event null, summary `Exchange`, value null. `Insight.captureStateValues` stays off. The same taps should list the same widget names. The state row is the part that differs.

## Run it

From `examples/exchange`:

```bash
flutter run -d windows
```

Choose a line count. Open with Bloc or Open with Riverpod. Tap a phone, then tap a digit.

To read the two drivers side by side, record one action per file from the repository root. The commands below are the installed programs. The Windows installer in [windows.md](windows.md) puts them on `PATH`. A developer who downloads the source runs the same tools from the repository root with `dart run tool/record.dart`, `dart run tool/play.dart`, and `dart run tool/compare.dart`. Those commands are listed after the installed ones. Leave the Insight tab closed. `1.json` and `2.json` under the example are ignored by git.

```bash
record --app examples/exchange --duration 25 --profile --out examples/exchange/1.json
```

Press Enter, choose 3, Open with Bloc, tap phone 1, tap 2.

```bash
record --app examples/exchange --duration 25 --profile --out examples/exchange/2.json
```

Press Enter, choose 3, Open with Riverpod, tap phone 1, tap 2.

```bash
compare --left examples/exchange/1.json --right examples/exchange/2.json
```

Compare the widget names on the row where the call is established. How that print is laid out is in [guide.md](guide.md). Bloc names `ExchangeCubit`. Riverpod names `exchange`. The process exits 0 when those rows differ. Those widget names should match. The state row is the part that differs.

The same ring can be played from a file. The scripts are in [examples/exchange/scenarios](../examples/exchange/scenarios). The script waits until the collector is listening, then runs every line in [answered-call.txt](../examples/exchange/scenarios/answered-call.txt). `tap` presses that control. `see` waits until that text is on screen. `tap open` follows `--board`. Pass `--scenario` with another file in that folder, and run that file once for each driver. Leave the Insight tab closed.

```bash
play --board bloc --out examples/exchange/1.json
play --board riverpod --out examples/exchange/2.json
compare --left examples/exchange/1.json --right examples/exchange/2.json --out examples/exchange/compare.json
```

What that pair shows is [what-can-be-learned.md](what-can-be-learned.md). When the two files stored different boards, the sentences name those boards. The columns in the file stay `left` and `right`, which is the order of `--left` and `--right`.

`--board` is `bloc`, `riverpod`, `wide`, or `plinth`. `wide` is the enamel board with every phone reading the whole switch. The default mode is profile. `--debug` records the order without frame times worth keeping. `--scenario` on `play` replaces `answered-call.txt`. [two-waiters.txt](../examples/exchange/scenarios/two-waiters.txt) has two phones waiting for the same line, then a `01` split by a hang-up. [camp-on-a-ring.txt](../examples/exchange/scenarios/camp-on-a-ring.txt) camps on a line that is still ringing. Each recording stores that file and the git commit. Compare reads the two stored scripts and says whether they are the same taps.

Downloading the source is enough to run those steps. From the repository root, the first `record` still waits for Enter, then Bloc, and the second waits for Enter, then Riverpod.

```bash
dart run tool/record.dart --app examples/exchange --duration 25 --profile --out examples/exchange/1.json
dart run tool/record.dart --app examples/exchange --duration 25 --profile --out examples/exchange/2.json
dart run tool/compare.dart --left examples/exchange/1.json --right examples/exchange/2.json
dart run tool/play.dart --board bloc --out examples/exchange/1.json
dart run tool/play.dart --board riverpod --out examples/exchange/2.json
dart run tool/compare.dart --left examples/exchange/1.json --right examples/exchange/2.json --out examples/exchange/compare.json
```

Analyzer reads one of those recordings, then another beside it. On each step, the shortest frame time is marked best and the longest is marked worst. Two times that print as the same tenth of a millisecond are left unmarked. The mark says which recording was shorter. It does not pass or fail the run.

The installer adds Analyzer to the Start menu. From a checkout:

```bash
cd tool/analyzer
flutter run -d windows
```

Press Select file and choose the session. Add result chooses the recording to compare with it. A tap recorded on the board, including a manual run, is printed above the step that follows it. Export taps writes the scenario that recording stored. A manual run has no scenario file, so Export taps writes the taps the session recorded.

## A second board

A later recording keeps Bloc and changes the board. `--board bloc` is the enamel phones. `--board plinth` is the same switch drawn with `PlinthPaper`, `PlinthBadge`, and `PlinthButton`. The taps stay phone 1 dials phone 2. The state row stays `ExchangeCubit`. The widget names are the difference. The sequence is in [roadmap.md](roadmap.md).

## A switch and its phones

`examples/exchange2` is the same call rules in two programs. The switch holds the lines and the log. Each phone is its own process. `play` does not start them. This example is under investigation and is not fully tested. The scripts, the scenario commands, and what one recording of each process contains are in [exchange2.md](exchange2.md).
