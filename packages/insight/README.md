# insight

Alpha. The in-app agent for Flutter Insight.

Call `Insight.attach()` before `runApp`. The DevTools extension in this package then shows a frame, the user widgets that rebuilt during it, and a state change or a traced call on one timeline.

Supported Flutter lines are 3.44.x and 3.47.x. Use a debug or profile run. Release mode has no VM service, and Flutter web is unsupported.

```dart
void main() {
  Insight.attach();
  runApp(const MyApp());
}
```

`devtools_options.yaml` at the app root:

```yaml
extensions:
  - insight: true
```

Trace a call you already care about:

```dart
await Insight.traceFuture(loadBoard(), name: 'loadBoard');
```

Leave `Insight.captureStateValues` off. A record then carries type names. Event fields stay in the app.

A Bloc or Cubit app also depends on `insight_bloc`. A Riverpod app also depends on `insight_riverpod`.

The repository is [flutter_insigth](https://github.com/ylahav/flutter_insigth). Suggestions and new features go to [the issues page](https://github.com/ylahav/flutter_insigth/issues).
