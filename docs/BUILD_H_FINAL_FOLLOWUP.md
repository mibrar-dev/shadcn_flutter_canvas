# H-FINAL-2 follow-up: legacy bundle screen indent (DEFERRED, not fixed)

Status: **deferred by the H-final closeout batch** — output left untouched,
no goldens changed. Owner: G-track (the G2 `code_builder` migration is the
structural fix, as filed in `docs/BUILD_H_FINAL.md` §7 H-FINAL-2).

## Verdict

The gate-3 probe still fails on the legacy bundle path after the FF/G waves
landed, and a small emitter tweak does NOT close it. Per the closeout
brief's blast-radius rule (>~3 goldens → defer, don't chase), the fix is
deferred to the G2 migration; this doc records the evidence so the owning
track can reproduce in minutes.

## Reproduction (exact, repo-clean — all writes go to /tmp)

```sh
cd canvas/canvas_core
cat > /tmp/genprobe.dart <<'EOF'
import 'dart:convert';
import 'dart:io';
import 'package:canvas_core/canvas_core.dart';
Future<void> main() async {
  final doc = ScreenDoc.fromJson(jsonDecode(
      File('test/fixtures/primitives_screen.json').readAsStringSync())
      as Map<String, dynamic>);
  final bundle = buildCleanBundle(doc, const {});
  final out = Directory('/tmp/genout_probe/lib/ui/screens');
  await out.create(recursive: true);
  for (final e in bundle.files.entries) {
    if (!e.key.startsWith('lib/ui/screens/')) continue;
    await File('${out.path}/${e.key.split('/').last}').writeAsString(e.value);
  }
}
EOF
dart --packages=.dart_tool/package_config.json /tmp/genprobe.dart
dart format --output=none --set-exit-if-changed /tmp/genout_probe
# => exit 1, `Changed .../primitives_screen.dart` (measured 2026-09-06,
# Dart 3.13.2). The G1 scaffold path (`main.dart`, `app_theme.dart`) stays
# clean — legacy `_screenFile` screens only.
```

## Hand-verification (golden-first discipline)

The formatter's proposed shape was hand-checked (before/after diff of the
probe output) and **is correct Dart, not just formatter-happy**:

1. Import grouping: a blank line between the `package:flutter/…` import
   (plus `package:http`, when present) and the relative `../shadcn/…`
   barrel imports — canonical Dart import-group separation.
2. Body base indent: rows move from 6sp to 8sp under `children: [` —
   the canonical block indent for `return Column(` at 4sp.
3. Nested continuation indents: legacy hand-shaped blocks (e.g. a
   `child: Row(` whose args the emitter lays out at a +6sp continuation)
   reflow to the canonical block indent.

No semantic change anywhere in the reformatted output (pure whitespace
plus the one import-group blank line).

## Why a small fix is insufficient (measured, not assumed)

Applying ONLY (2) + (1) — uniform +2sp on the body block plus the import
blank line — to the probe output and re-running the gate-3 check **still
exits 1**: the formatter additionally reflows nested arg indentation (3)
inside `Row`/`Column` bodies built by the legacy `_bundle*Body` emitters.
Closing gate 3 emitter-side therefore means reworking indentation logic
across the whole legacy string-emitter family, not touching two lines in
`_screenFile`.

## Blast radius (why this batch stopped)

Any screen-output change invalidates expectations across the core suite:
`test/codegen_bundle_test.dart` alone has ~2500 lines carrying 6sp
indent-sensitive screen expectations, plus byte-exact fixtures and the
g2/g3/g4 suites that pin screen bodies. That is far beyond the ~3-golden
budget — so per the brief, output is untouched and no golden was updated.

## Pointers for the owning track

- Root base indent: `codegen_bundle.dart` `_screenFile` — `_writeBundleNode`
  call with `'      '` (6sp) base plus the `'      // (empty screen).'`
  literal.
- Import-group blank line: the `_screenFile` return template
  (`$flutterLine` / `${extraImports}${kitImports}` run the `package:` and
  relative groups together with no blank line).
- Nested continuation indents: the legacy `_bundleContainerBody` /
  `_bundleFallbackLines` / per-kind `_bundleX` string emitters (compare the
  G2 AST path, which is already canonical post-format).
- Suggested acceptance: re-run the reproduction above (exit 0) plus the
  full `canvas_core` suite green with goldens re-based to the verified
  shape — ideally as part of the G2 `code_builder` cutover, which replaces
  the hand-shaped blocks structurally.

---

## Resolution (H-FINAL-2 closeout, 2026-09-06)

Status: **fixed emitter-side in `canvas_core/lib/src/codegen_bundle.dart`**
(no `emit/` or `codegen_single.dart` changes; G2/G3 logic frozen). All
shapes below were verified by reading the `dart format` diff of probe
output, confirming correct Dart, then changing the emitter.

### Emitter hunks (`canvas_core/lib/src/codegen_bundle.dart`)

Base + header (the two lines this doc pointed at):

- `_screenFile` (~:1085, ~:1086): body base `'      '` → `'        '`
  (8sp canonical under `children: [`), same for the empty-screen literal.
- `_screenFile` import template (~:1194): blank line between the
  `package:`/`dart:` group and the relative kit imports when kit imports
  exist (`${extraImports}${kitImports.isEmpty ? '' : '\n'}${kitImports}` —
  byte-identical when the kit group is empty).

Nested continuation / structural indentation (found by probing every
writer path, not just the primitives screen):

- `_bundlePrimChildLines` (~:4301): `child:` continuations `'    '` → `'  '`
  (args sit at +2 from the `child:` statement, not +4).
- `_writeBundleSizedBox` (~:4850): `Expanded(` child splice keeps its
  trailing comma (branch expressions arrive comma-stripped).
- `_writeBundleResponsiveNode` (~:5008): `final tier = …` ternary is now
  emitted pre-split in the canonical 5-line hanging form.
- `_writeBundleBranch` (~:5520): guarded multi-line branches split the
  guard first, `return <block>` rides at +2 (single-line branches keep
  the historical joined form).
- `_writeBundleResponsiveRowChild` (~:5883): bare-`child:` block indent
  `+4` → `+6` (dart_style hangs a split value at +4 from the arg).
- `_bundleSingleParam` (~:5186): slot-param continuations lose the extra
  `+2` (expression lines already carry relative indent).
- `_bundleActionMethods` (~:1348): step lines emitted verbatim —
  `emitStepStatements` already carries the 4sp method-body base; the
  extra `'  '` prefix double-indented to 6sp.
- `_bundleWrapTap` (~:1427): legacy `onTap: () => Navigator… // transition`
  always overflows 80 columns, so the arrow value rides the hanging indent
  (`onTap: () =>` + value at +4 from `onTap:`).
- Childless primitives go single-line when the joined call fits
  (`_bundleFittedCall`, 72-col budget): `_bundleColumn` / `_bundleRowKind` /
  `_bundleStack` (props preserved), `_bundlePadding`, `_bundleAlign`,
  `_bundleExpanded`, scalar-only `_bundleContainer`, `_bundleKeyboardShortcut`
  inner, `_bundleForm` submit.
- G3 wrappers (`_bundleChip` … `_bundleTextArea`): `_bundleJoinedCall` /
  `_bundleJoinGroup` join fittable call groups bottom-up (flat groups
  only; nested blocks and comments stay split). Same program, whitespace
  only; `emit/g3_emitters.dart` untouched.

`_KindSpec` rows (same one-row treatment as `async`/`locale_utils`, specs
derived from the shipped bodies in
`canvas_app/lib/canvas/_impl/embedded_sources.dart` — all parts verified
import-free; `dependsOn` verbatim): `alpha`, `color`, `eye_dropper`
(`shared ['color_extensions','text','theme']`, `data_widget ^0.0.2`,
`dependsOn ['history']`), `formatter` (`expressions ^0.2.5+2`),
`sortable` (`shared ['constants','util']`, `data_widget ^0.0.2`).

### Gate-3 evidence (exact commands, `canvas/canvas_core`)

```sh
dart --packages=.dart_tool/package_config.json /tmp/genprobe.dart
dart format --output=none --set-exit-if-changed /tmp/genout_probe
# Formatted 1 file (0 changed) — exit 0 (the probe above now passes)

dart format --output=none --set-exit-if-changed test/fixtures
# Formatted 18 files (0 changed) — exit 0 (all hand-written .expected.dart)

# legacy screens rebuilt from every test/fixtures/*.json (15 files):
dart format --output=none --set-exit-if-changed /tmp/gate3_fixtures
# Formatted 15 files (0 changed) — exit 0
```

Regenerated golden screens (`kBundleNestedCardGolden`,
`kBundleThreeDeepGolden`, `kBundleScreenGolden`, `kBundleNonCatalogGolden`):
`dart format` exit 0. `kBundleNestedExportGolden` keeps exactly 3
residual lines (below) — its tests still pass byte-exact.

Test churn (all updated expectations eyeballed as correct Dart via
old-vs-new diff: whitespace + canonical splits only, no token changes):
`canvas_core/test/codegen_bundle_test.dart` (5 golden constants + 2
`contains`), `g2_migration_test.dart` + `g3_gap_test.dart` +
`primitives_f3_goldens_test.dart` (8sp harness strip + 9 hand-verified
shape updates). No fixture-file content changed (g2/g3 `.expected.dart`
are AST-path outputs; the F1 hand golden is aspirational, not emission).

### Residuals (need G2 `code_builder` / `app_state` structural work, not more tweaks)

1. Deep tap wraps: `onTap` + route + `// transition` trailer cannot fit
   past ~indent 16 in any static shape (formatter chain-splits per depth).
   Shallow/mid taps are canonical; the 3 depth-20/30 taps in the nested
   export golden re-split under `dart format`. Owner: G2 cutover (width-
   aware layout) — static emitters cannot be fixpoints at two depths.
2. `emitStepStatements` (`app_state.dart`, frozen): `showSnackBar` /
   `showDialog` / `http.get` step lines overflow or mis-indent
   continuations. Method bodies now compose at the canonical 4sp base
   (fixed on the bundle side); the step shapes themselves are untouched.
   No fixture carries stepped actions, so the gate corpus is unaffected.
3. Near-budget (65–80 col) single-line bodies (`NavigationItem`,
   `tooltip:` arrows, `MenuButton` rows, long-label `TextField`s) and
   multi-hide import lines (>80 cols) are depth-/content-sensitive by
   construction; left in the historical shape. No fixture or pinned
   golden hits them.
4. Unknown-component warnings: full kind-universe probe reports **zero**
   warnings after the 5 rows above (was 11 lines over alpha/color/
   eye_dropper/formatter/sortable).

### Verify results

- `flutter analyze --no-pub` (canvas_core): No issues found.
- `flutter test` (canvas_core): 469 passed, 0 failed (baseline 469 pass).
- Consumer (canvas_app): `gen_registry_drift_test` + `catalog_test` +
  `f3_primitives_render_test` + `export_panel_test` (152 tests) green;
  `h_final_gates_test` (12) green; `f4_primitive_editors_test`,
  `registry_builders_test` + `registry_test` green.
