# insight_cli

Alpha. Records one Insight session from a Flutter VM Service URI.

```bash
dart pub global activate insight_cli
insight_cli --uri http://127.0.0.1:8181/example --duration 15 --out insight-session.json
```

Copy the VM Service URI from `flutter run`. Leave the Insight DevTools tab closed while this runs. The tab and this command are two clients on one VM.

`--no-rebuilds` leaves user-widget rebuilds off. The default duration is 2 seconds.

Suggestions and new features go to [the issues page](https://github.com/ylahav/flutter_insigth/issues).
