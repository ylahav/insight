# Tools on Windows

<img src="../brand/icon.png" alt="Insight icon" width="96">

The Windows programs are Analyzer, `compare`, `play`, `record`, `parser_check`, and `insight_cli`. One installer puts them on the machine. The five pub.dev packages are a separate publish. They wait until this repository is public. That list is in [roadmap.md](roadmap.md).

## What the installer contains

| Program | What it does | What else it needs |
| --- | --- | --- |
| Analyzer | Opens one session file, then another beside it | Nothing else |
| `compare` | Prints two session files, and can write `compare.json` | Nothing else. A git stamp on `--out` is stored when the terminal is inside this checkout |
| `parser_check` | Checks a profile session from `examples/bloc_counter` for one Flutter line | Nothing else. This is the support check, not a recording |
| `insight_cli` | Records a session from a VM Service URI you already have | The app has to be running in debug or profile |
| `play` | Plays one exchange scenario and writes the session | Flutter on `PATH`, and this checkout. It runs `examples/exchange` |
| `record` | Starts an example and writes the session | Flutter on `PATH`, and this checkout |

`play` and `record` do not carry the Flutter SDK or the examples. The checkout is where those apps live. Run them from a terminal inside the checkout and they find it. Flutter has to be the `flutter` command, or the `--flutter` path.

The machine that runs Analyzer, or any of the compiled programs, needs the [Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist) for the x64 architecture. Flutter's Windows build and the compiled Dart programs both use it.

## Build the installer

From the repository root:

```powershell
.\tool\package_windows.ps1
```

That builds Analyzer, compiles the other programs, and copies them to `dist/windows/stage`. When Inno Setup 6 is installed, the same command compiles `dist/windows/Insight-Setup.exe` from [tool/windows/insight.iss](../tool/windows/insight.iss). Without Inno Setup the stage folder is still complete, and the script says so.

The installer adds Analyzer to the Start menu and adds `bin` to the system `PATH`. Analyzer's window icon, and the installer icon, are [brand/icon.png](../brand/icon.png). After it finishes, a new terminal can run:

```text
compare --left a.json --right b.json
play --board bloc --out examples/exchange/1.json
record --app examples/desk --duration 15
parser_check --file path --flutter 3.44
insight_cli --uri http://127.0.0.1:8181/token=/ --duration 15 --out insight-session.json
```

`play` and `record` in that list still run from the checkout. Analyzer opens from the Start menu and reads any session file.

## From a checkout, without the installer

```bash
cd tool/analyzer
flutter run -d windows
```

```bash
dart run tool/compare.dart --left a.json --right b.json
dart run tool/play.dart --board bloc --out examples/exchange/1.json
dart run tool/record.dart --app examples/desk --duration 15
dart run tool/parser_check.dart --file path --flutter 3.44
```

`record` writes the session itself. It does not start `insight_cli`.
