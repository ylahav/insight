# insight_riverpod

Alpha. The Riverpod adapter for Insight for Flutter.

Depend on `insight` and `insight_riverpod`. Attach the agent, then pass the observer to `ProviderScope`.

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

The record name is the provider's `name` when one is set, and otherwise the provider's runtime type. A mutation supplies the event type. The first value of a provider is not recorded as a change.

The pinned line is `flutter_riverpod` 3.4.x.

Suggestions and new features go to [the issues page](https://github.com/ylahav/insight/issues).

Insight is an independent project and is not affiliated with, sponsored by, or endorsed by Google LLC. Flutter and the related logo are trademarks of Google LLC.
