# shadcn_flutter_canvas

Visual canvas editor that renders **real shadcn widgets** — what you see on
the canvas is literally the source the user installs.

## Layout

- `canvas_app/` — the Flutter editor shell (palette + phone canvas + inspector
  + theme bar + preview player). See `canvas_app/HANDOFF.md` for the
  work-in-progress visual spec.
- `canvas_core/` — pure-Dart document model, exporters, and AI contract shared
  by the app (and the CLI). Flutter-free by design.

## Dependencies

`flutter_shadcn_kit` (the parts library) is **not vendored here** — it resolves
from GitHub (`mibrar-dev/shadcn_flutter_kit`, `main`) via the `git:` entry in
`canvas_app/pubspec.yaml`. `canvas_core` resolves via a relative `path:` entry
since it lives in this repo.

## Run

```bash
cd canvas_app
flutter pub get
flutter run -d chrome        # web (primary target)
flutter analyze              # must be zero issues
flutter test
flutter build web --release
```

## Regenerating embedded kit sources

`canvas_app/lib/canvas/_impl/embedded_sources.dart` is generated from the
kit's `components.json` and committed, so normal builds need no kit checkout.
To regenerate after a kit change, clone the kit as a sibling of this repo
(or pass its root explicitly):

```bash
git clone --depth 1 https://github.com/mibrar-dev/shadcn_flutter_kit.git ../shadcn_flutter_kit
cd canvas_app
dart run tool/embed_sources.dart            # uses ../shadcn_flutter_kit
dart run tool/embed_sources.dart /path/to/kit   # explicit kit root
```
