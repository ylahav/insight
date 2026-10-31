# Contributing

Suggestions and new features are welcome. Open an [issue](https://github.com/ylahav/insight/issues). Name the action you recorded, the state change, and what the session did not make visible. The current sequence is [docs/roadmap.md](docs/roadmap.md). Leave `Insight.captureStateValues` off, and keep the session file on your machine.

The design of record is:

- [docs/runtime.md](docs/runtime.md)
- [docs/events.md](docs/events.md)
- [docs/mvp.md](docs/mvp.md)
- [docs/running-example.md](docs/running-example.md)
- [docs/roadmap.md](docs/roadmap.md)

Phase 1 is a pub workspace with `insight`, `insight_collector`, `insight_cli`, and `examples/bloc_counter`. Phase 2 adds the DevTools panel in `packages/insight_devtools`. Phase 3 adds `packages/insight_bloc` and `examples/desk`. `packages/insight_riverpod` is the Riverpod adapter. The repository is [ylahav/insight](https://github.com/ylahav/insight). The extension config uses its issues page for the DevTools report-an-issue link.

## Commands that work

From the repository root:

```bash
dart pub get
dart test packages/insight_collector
flutter test packages/insight packages/insight_bloc packages/insight_riverpod packages/insight_devtools examples/bloc_counter examples/desk examples/exchange examples/riverpod_shelf
```

After changing the panel, rebuild the extension from `packages/insight_devtools`. DevTools loads the files copied into `packages/insight/extension/devtools/`:

```bash
dart run devtools_extensions build_and_copy --source=. --dest=../insight/extension/devtools
```

To record a session, run the fixture in profile mode and pass its VM Service URI to the CLI. The steps are in the [README](README.md).

## When you edit the docs

Keep [runtime.md](docs/runtime.md), [events.md](docs/events.md), and [mvp.md](docs/mvp.md) consistent with each other. A new event field is a schema change: bump the version in `events.md` and name the Flutter line it was tested on.

The license is [MIT](LICENSE). Contributions are under that license.
