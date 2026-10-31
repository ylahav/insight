# insight_bloc

Alpha. The Bloc and Cubit adapter for Flutter Insight.

Depend on `insight` and `insight_bloc`. Attach the agent, then set the observer.

```dart
void main() {
  Insight.attach();
  Bloc.observer = InsightBlocObserver();
  runApp(const MyApp());
}
```

A bloc event is recorded as its type name. A cubit record has a null event. `Insight.captureStateValues` stays off, so the record carries the state type and leaves the state value in the app.

The pinned line is `flutter_bloc` 9.1.x.

Suggestions and new features go to [the issues page](https://github.com/ylahav/insight/issues).
