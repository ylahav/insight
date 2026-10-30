# Contributing

The design of record is:

- [docs/runtime.md](docs/runtime.md)
- [docs/events.md](docs/events.md)
- [docs/mvp.md](docs/mvp.md)

Month 1 is a pub workspace with `insight`, `insight_collector`, `insight_cli`, and `examples/bloc_counter`. Month 2 adds the DevTools panel in `packages/insight_devtools`. Month 3 adds `packages/insight_bloc` and `examples/desk`. `packages/insight_riverpod` is the Riverpod adapter. The private repository is [ylahav/flutter_insigth](https://github.com/ylahav/flutter_insigth). The extension config uses its issues page for the DevTools report-an-issue link.

## Commands that work

From the repository root:

```bash
dart pub get
dart test packages/insight_collector
flutter test packages/insight packages/insight_bloc packages/insight_riverpod packages/insight_devtools examples/bloc_counter examples/desk examples/riverpod_shelf
```

After changing the panel, rebuild the extension from `packages/insight_devtools`. DevTools loads the files copied into `packages/insight/extension/devtools/`:

```bash
dart run devtools_extensions build_and_copy --source=. --dest=../insight/extension/devtools
```

To record a session, run the fixture in profile mode and pass its VM Service URI to the CLI. The steps are in the [README](README.md).

## When you edit the docs

Keep [runtime.md](docs/runtime.md), [events.md](docs/events.md), and [mvp.md](docs/mvp.md) consistent with each other. A new event field is a schema change: bump the version in `events.md` and name the Flutter line it was tested on.

The license is [MIT](LICENSE). Contributions are under that license.
