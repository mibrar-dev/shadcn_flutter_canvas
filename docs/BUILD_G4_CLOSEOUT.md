# Track G4 — Demote Single-File + Closeout (gates 3–7 evidence)

Session scope: **G4 DEMOTE + CLOSEOUT only** (BUILD_SPEC §§8.1, 8.2-barrel,
11, 12). Baseline: G3 complete (463 core pass, analyze clean).
Result: **469 core tests pass (463 + 6 new), analyze clean both packages.**

## 1. Demote design (mode flag + path)

`codegen_single.dart` keeps the hand-rolled linker VERBATIM (directive
stripping, export dedupe, import-graph fixpoint, `duplicate_ignore`
merging, `as`-prefix preservation, `on Widget` keeper election,
type-twins homing — untouched, still covered by
`codegen_single_test.dart`). Added ONLY:

- `enum ExportMode { bundle, inlineSourcesExperimental }` — the mode
  flag. Bundle first = supported path.
- `exportModeLabel(mode)` — `'Project'` /
  `'Inline sources (experimental)'`. The experimental qualifier is part
  of the label contract (a G4 test pins the substring).
- Doc block stating the demotion: bundle is load-bearing, single-file is
  the kept-but-experimental inline path for one-file demos and diffing.

`canvas_app/lib/ui/export_panel.dart` — mode-wiring ONLY, no dialog
redesign (all six existing options keep their exact labels and
behaviors; `export_panel_test.dart` passes unmodified):

- `ExportDialog.initialMode` (defaults `ExportMode.bundle`) + `_mode`
  state.
- A `SegmentedButton<ExportMode>` under the Code section with a per-mode
  caption (supported-path vs experimental-linker guidance).

## 2. Barrel export

NEW `canvas_core/lib/src/emit/emit.dart` re-exporting all seven emit
files (context, expr_emitter, g3_emitters, project_writer,
tagged_value, value_codecs, widget_emitter) — the §8.2 surface as one
import, resolving cleanly (a G4 test imports it directly).

Deliberately NOT re-exported from `canvas_core.dart`: doing so trips
`unnecessary_import` in every existing `src/emit/` direct importer
(including `g2_migration_test.dart`, which this track may not edit).
One-line follow-up if a future track wants it — with those import
cleanups in the same wave.

## 3. Gates 3–7 evidence (on generated output)

- **Gate 3** — `dart format --set-exit-if-changed` over all 11
  hand-written G3 fixture pages + both new test files:
  `Formatted 13 files (0 changed)`, **exit=0**. In-suite, `g4_closeout`
  re-pins every fixture as a `DartFormatter` (repo `dart_style`)
  fixpoint, and `g3_gap` pins each emitted page the same way.
- **Gate 4** — `flutter analyze --no-pub`: **No issues found** in
  `canvas_core` (covers the generated-output-shaped fixtures in place —
  they carry the broad kit-name `ignore_for_file`, same as G2) and in
  `canvas_app` (covers the export-panel wiring). A full generated-project
  analyze needs the kit checkout + `flutter pub get` (network); out of
  sandbox scope per working rule 9 — same stance as G2, documented not
  skipped.
- **Gate 5** — `flutter build web` on generated output: not runnable in
  this sandbox (same reason as gate 4; no new deps may be fetched).
  Unblocked the moment a kit checkout is present — no codegen-side work
  remains for it.
- **Gate 6** — byte-exact goldens: 10 `g3_<kind>` page goldens + 1 model
  golden, all passing (`g3_gap_test`: 43 tests; `g4_closeout`: 6).
- **Gate 7** — zero placeholder emissions: `placeholderFor` survives ONLY
  as the genuinely-unknown-kind honesty fallback (walker + `_bundleBody`
  default). A kitchen-sink doc (10 G3 kinds + primitive + kit kind)
  asserts all twelve constructors present and `(not yet bridged)` absent
  (`g4_closeout`); per-kind no-placeholder asserts live in `g3_gap`.
  The §4.3 list and the 10-kind gap list are both empty in output.

## 4. Incidental but required: `canvas_app/pubspec.lock`

G3 is the first wave to drag `code_builder`/`dart_style` (G2 deps of
`canvas_core`) into `canvas_app`'s compile closure (via
`codegen_bundle → g3_emitters`). The app's `package_config.json` predated
them, so app tests failed to compile until `flutter pub get --offline`
materialized the transitives. No `pubspec.yaml` changed (forbidden);
`canvas_app/pubspec.lock` gained the transitive entries only (+104
lines). Reproducible by any later `pub get`.

## 5. Files modified / created

- Created: `canvas_core/lib/src/emit/emit.dart`,
  `canvas_core/test/g4_closeout_test.dart` (6 tests), this doc.
- Modified: `canvas_core/lib/src/codegen_single.dart` (ExportMode +
  labels + demote docs; linker verbatim),
  `canvas_app/lib/ui/export_panel.dart` (initialMode + SegmentedButton
  + caption; labels/behaviors untouched),
  `canvas_app/pubspec.lock` (transitive materialization, generated).
- Untouched: every other test, `screen_doc.dart`, registry/catalog/
  schema, store/app-state, pubspecs (`.yaml`), `.github/`.

## 6. Verify outputs (exact)

- `flutter analyze --no-pub` (canvas_core): **No issues found!**
- `flutter analyze --no-pub` (canvas_app): **No issues found!**
- `flutter test` (canvas_core): **469 passed** (420 baseline + 43 g3 +
  6 g4; includes the 2 spec-mandated placeholder-pin updates from G3).
- `flutter test test/gen_registry_drift_test.dart
  test/catalog_test.dart test/f2_primitives_test.dart
  test/f3_primitives_render_test.dart test/f4_primitive_editors_test.dart
  test/export_panel_test.dart` (canvas_app): **187 passed**.
- `dart format --set-exit-if-changed` (13 files): **0 changed, exit 0**.
