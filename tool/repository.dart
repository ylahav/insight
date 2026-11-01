import 'dart:io';

/// The Insight checkout that contains the examples and the packages.
///
/// Walks up from the working directory, then from this program. An installed
/// copy finds the checkout when the terminal is inside it. Returns null when
/// neither place is the checkout.
Directory? findRepository() {
  return _walk(Directory.current) ??
      _walk(File(Platform.script.toFilePath()).parent);
}

Directory? _walk(Directory start) {
  var dir = start.absolute;
  while (true) {
    final packages = Directory.fromUri(dir.uri.resolve('packages/insight_cli'));
    final exchange = Directory.fromUri(dir.uri.resolve('examples/exchange'));
    if (packages.existsSync() && exchange.existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return null;
    }
    dir = parent;
  }
}
