/// A widget runtime type, which is how Flutter labels a user-widget build.
///
/// Framework phases on the same `Dart` timeline (`BUILD`, `POST_FRAME`,
/// `LAYOUT (root)`) do not match. Embedder and GC events are a different
/// `cat` and never reach this check.
bool isWidgetBuildName(String name) {
  return RegExp(r'^_?[A-Z][A-Za-z0-9]*(?:<(?:[^<>]|<[^<>]*>)*>)?$')
          .hasMatch(name) &&
      RegExp(r'[a-z]').hasMatch(name);
}

/// Reads one Chrome-trace timeline event. Returns null when it is not a
/// user-widget build. Durations are discarded.
({int timeUs, String name})? widgetRebuildFromTimeline(
  Map<String, Object?> event,
) {
  if (event['cat'] != 'Dart') {
    return null;
  }
  if (event['ph'] != 'B' && event['ph'] != 'X') {
    return null;
  }
  final name = event['name'];
  final timeUs = event['ts'];
  if (name is! String || timeUs is! int || timeUs < 0) {
    return null;
  }
  if (!isWidgetBuildName(name)) {
    return null;
  }
  return (timeUs: timeUs, name: name);
}
