# Track H FINAL (hardening + gates) — evidence, CI, re-measure, decisions

Session scope: **H FINAL hardening prep, SOURCE-TOUCH-FREE** per the wave
brief (BUILD_SPEC §§10, 11, 12). Continues `docs/BUILD_H0_HARDENING_PREP.md`
(H0) — does not redo it. New files only (allowlist): `canvas/.github/…`,
`canvas_app/tool/placeholder_scan.dart`, `canvas_app/test/h_final_gates_test.dart`,
this doc. Read-only execution everywhere else.

Heads observed during the session (parallel tracks active):

- Session start: HEAD `6caaf775`, tree clean except FF6/G3 in-flight edits.
- Session end: HEAD `83ddc6a3` (`feat(ff): FF6 grouped properties…`).
  FF6 (`inspector_panel.dart`, `property_editors.dart`, `right_aside.dart`,
  `main.dart`) and G3 (`codegen_bundle.dart`, NEW `emit/g3_emitters.dart` +
  `test/fixtures/g3_*.json` / `g3_*.expected.dart`) landed **mid-flight**.
  Gap/status statements below are timestamped to the HEAD they were measured
  at — nothing is assumed.

Toolchain (measured): Flutter 3.47.2 / Dart 3.13.2 (`flutter --version`).
No `flutter pub get` run. No `dart format` writes on any repo path
(dry-runs only; the one format-write in §3 touched a `/tmp` copy).

## 1. CI wiring (main deliverable)

**File:** `canvas/.github/workflows/canvas-gates.yml` (NEW — `canvas/` had no
`.github`; parent `../.github` untouched: `validate.yml` + `canvas-deploy.yml`
re-read this session and confirmed to contain no canvas gates).

| Job | §11 gate | Steps (exact) |
|---|---|---|
| `analyze` | 1 — `flutter analyze`, zero issues | `flutter analyze --no-pub` in `canvas_core/`, then `canvas_app/` |
| `test` | 2 — `flutter test`, zero failures | `flutter test` in `canvas_core/`, then `canvas_app/` |
| `drift` | 6 goldens + 7 placeholders, repo-local guards | `flutter test test/gen_registry_drift_test.dart` (app); `flutter test test/primitives_f3_goldens_test.dart test/g2_migration_test.dart` (core); H0 harness smoke `dart run tool/render_codegen_diff.dart --stage pure --fixtures ../canvas_core/test/fixtures --out /tmp/h0diff` (app) |
| `format-check` | 3 direction, **NON-BLOCKING first** (`continue-on-error: true`) | `dart format --output=none --set-exit-if-changed` on DEFINED harness paths only: `tool/placeholder_scan.dart tool/render_codegen_diff.dart test/h_final_gates_test.dart test/h0_diff_harness_test.dart` (app) |

Standard `subosito/flutter-action@v2` pinned to `3.47.2` (the measured
baseline SDK). Triggers: `push`/`pull_request` limited to
`canvas_core/**`, `canvas_app/**`, `docs/**`, `.github/**`, plus
`workflow_dispatch`. Timeouts: 10/25/15/10 min.

Deliberately NOT in CI yet (filed, not silently dropped): gates 4–5 on
generated output need `flutter_shadcn_kit: ^1.0.0` resolvable at CI time
(hosted publish or path override — G4 scope, §6 H-FINAL-4); gate-3 on
generated output graduates from `format-check` once G4 lands a checked-in
generate-to-dir script (§5). Gate 8 is manual by definition.

Verify: `python3 -c yaml.safe_load` → `YAML_OK jobs= ['analyze',
'drift', 'format-check', 'test']`, on = push/pull_request/workflow_dispatch.
Contract-pinned by `test/h_final_gates_test.dart` (workflow presence + job
ids + key commands).

## 2. Gates evidence table (§11, gates 1–8)

| # | Gate | Status | Exact evidence (command → output) |
|---|---|---|---|
| 1 | `flutter analyze`, zero issues | ✅ PASS | `flutter analyze --no-pub` in `canvas_core/` → `No issues found! (ran in 1.1s)`; in `canvas_app/` (after H adds) → `No issues found!` |
| 2 | `flutter test`, zero failures | ✅ PASS | `flutter test` in `canvas_core/` → `00:02 +420: All tests passed!` (exit 0); in `canvas_app/` → `01:37 +1274: All tests passed!` (exit 0; = 1256 baseline + 12 new H + 6 FF6/G3 landed mid-flight) |
| 3 | `dart format --set-exit-if-changed` on generated output | ❌ FAIL (legacy path) / ✅ PASS (G1 scaffold path) | Probe `/tmp/genout_probe.dart` materialized `buildCleanBundle` (§7.5 `primitives_screen.json`) + `scaffoldProject` to `/tmp/genout`; `dart format --output=none --set-exit-if-changed /tmp/genout` → exit **1**, `Changed …/lib/ui/screens/primitives_screen.dart` (whole body under-indented 2sp vs canonical; diff recorded in-session). Scaffold `main.dart` + `app_theme.dart` format-clean. Filed H-FINAL-2 (G-track owns; G2 `code_builder` migration is the structural fix) |
| 4 | `flutter analyze` on generated output | ⬜ CI-COVERED (not run in sandbox) | Blocked: no checked-in generate-to-runnable-dir script and kit dep unresolvable (§1). CI step filed for G4 (H-FINAL-4) |
| 5 | `flutter build web` on generated output | ⬜ CI-COVERED (not run in sandbox) | Infeasible in-sandbox: emitted pubspec needs `flutter_shadcn_kit: ^1.0.0` hosted; pub cache holds `go_router-*`, `shadcn-0.0.0`, `flutter_shadcn_cli-*` but NO `flutter_shadcn_kit`. Same G4 filing as gate 4 |
| 6 | Byte-exact goldens per fixture | ✅ PASS (repo-local) | Full suites green (§2 rows 1–2) incl. `primitives_f3_goldens_test`, `g2_migration_test`, `codegen_*_test`; drift job re-runs the subset in CI |
| 7 | Zero placeholder emissions | ✅ PASS **at HEAD `83ddc6a3`** (was red at session start) | Black-box scan over real `buildCleanBundle` output, §4 below. G3 closed the gap mid-flight; G3's own goldens (`g3_*.expected.dart`) + green suite corroborate |
| 8 | Human PR test | ⬜ MANUAL | Cannot automate. Note for the reviewer: the §6.3 worked-example bar + gate-3 indent finding (§3) are the two things to eyeball on G3's new emitters |

## 3. H0 harness smoke (read-only execution)

`dart run tool/render_codegen_diff.dart --stage pure --fixtures
../canvas_core/test/fixtures --out /tmp/h0diff-final` → printed Stage A/B
instructions for all 5 fixtures (`g2_collapse`, `g2_model_split`,
`g2_responsive_leaf`, `g2_token_container`, `primitives_screen`) and
scaffolded 5 × `<base>.report.md` (`Verdict: NOT-RUN …`). Tool file unchanged
since H0 (`git log` shows only the H0 commit touching it).

**Finding filed as H-FINAL-1:** the process exit code does NOT propagate —
`--stage pure` and even `--bogus x` both exit **0** (verified: minimal
`Future<int> main() async => 3` run via `dart` and `dart run` on Dart 3.13.2
also exits 0; the VM ignores `main`'s return, `exit()` from `dart:io` is
required). So the H0 `H0Exit` int-return contract (0/1/2/3) is currently
advisory only, and the CI `drift` smoke step is presence-only until fixed.
Fix is one line in `tool/render_codegen_diff.dart` (`exit(await …)` /
`exitCode = …`) — NOT applied (existing file, out of allowlist). The NEW
`tool/placeholder_scan.dart` uses `exit()` throughout and its 0/1/2 codes
were verified end-to-end (§4).

## 4. Placeholder scan (§4.3 list + G1 10-kind list)

Method: `/tmp/placeholder_scan_run.dart` (read-only probe, NOT in repo) —
single-kind docs through the real `buildCleanBundle(doc, const {})`,
black-box classification over OUTPUT text only: `Text('<kind>'),` =
legacy default branch (`codegen_bundle.dart:1690-1691`), `(not yet bridged)`
= AST path (`widget_emitter.dart:48`), `TODO(canvas): no source for kind` =
single-file path (`codegen_single.dart:289,4091`).

- **Run 1 @ HEAD `6caaf775` (pre-G3-land): 10/38 PLACEHOLDER** — all 28
  §4.3 kinds REAL (spec gap stays closed); all 10 G1 kinds
  (`chip`, `alert`, `circular_progress_indicator`,
  `linear_progress_indicator`, `triple_dots`, `dot_indicator`,
  `empty_state`, `code_snippet`, `number_ticker`, `text_area`) legacy
  `Text('<kind>'),` placeholders. G3 gap open, as briefed.
- **Run 2 @ HEAD `83ddc6a3` (G3 landing): 0/38, `PLACEHOLDER_COUNT=0 / 38`**
  (full log `/tmp/phscan_final.log`; `grep -c REAL` = 38). **Gate 7 is
  green at session end.** G3 owns keeping it green via §8.2 + its goldens.

Durable scanner: NEW `canvas_app/tool/placeholder_scan.dart` (pure
`hScanContent`/`hScanFiles` + `exit()`-correct CLI `--dir/--kinds/--ext`).
Verified: `--dir /tmp/genout` → `0 hit(s) in 3 file(s)`, exit 0;
synthetic 3-marker file → 3 hits (`ast-not-bridged`, `single-no-source`,
`legacy-text`), exit 1; missing dir → exit 2. 12/12 tests in
`canvas_app/test/h_final_gates_test.dart` pass (scanner core + CI-workflow
contract).

## 5. Re-measure (H0 §4 procedure — outcome: stays APPROXIMATE)

Followed as far as the sandbox allows. No live-browser sampling is available
in-sandbox (no operator browser against `app.flutterflow.io`), and per the
measured-spec rule numbers are NEVER eyeball-promoted. Result, exactly as
H0 predicted:

- `editor_tokens.dart` untouched (read-only grep): all six FF1 tokens
  (`railBg`, `railActiveIndicator`, `panelBg`, `canvasBackdrop`,
  `selectionOutline`, `groupHeaderFg`) + `ffRailWidth`/`ffTopBarHeight`/panel
  widths still carry APPROXIMATE markers with H0's values
  (`#FFFFFFFF`/`#FF1E1D20`, `#FF2563EB`/`#FF60A5FA`, `#FFFFFFFF`/`#FF1C1B1F`,
  `#FFE8ECF1`/`#FF0F0E11`, `#FF6B7280`/`#FF9CA3AF`, ~48/56/280/300).
- **No measured values invented; measured column stays blank for the human
  pass.** Procedure (§4 steps 1–3: 3-point sampling, incognito repeat,
  screenshot attach, APPROXIMATE-comment removal + `ff_tokens_test`
  extension, never weakening `light_theme_test`) is intact and quoted in §1
  of the H0 doc — hand to the operator with a live browser.
- Corroboration available without a browser: none found in repo
  PDFs/screenshots that pins FlutterFlow-side hexes (repo PDFs are
  self-reports of this builder, not FlutterFlow samples), so nothing is
  cited and nothing is promoted.

## 6. Format decision: intentionally-unwired now, format-once after FF/G land

Re-measured (dry-run only, zero writes):
`dart format --output=none --set-exit-if-changed canvas_core/lib
canvas_app/lib` → **36 changed of 57** (core 11: `app_state`,
`codegen_bundle`, `codegen_single`, `prompt_builder`, `screen_doc`,
`share_codec`, + 5 `emit/` files; app 25 incl. `editor_tokens.dart`,
`inspector_panel.dart`, `main.dart`, `component_registry.dart`,
`_impl/embedded_sources.dart`). Drift grew in core (H0: 9 → 11, G2's new
`emit/` files) and shrank in app (H0: 30 → 25). SDK is still 3.47.2 vs
whatever formatted the tree originally — the delta is whitespace-only
(style version), not a defect.

**Decision: intentionally-unwired.** Rationale: (a) formatting now would
dirty FF6/G3's in-flight diffs and collide with their waves (§12.1); (b)
§11 gate 3 binds *generated* output, and no source-format gate exists —
wiring one now would flip the new CI red on 36 files owned by other tracks.
The two GENERATED files in the drift set (`component_registry.dart`,
`_impl/embedded_sources.dart`) must converge via their generators, not via
a manual format.

**Exact deferred command — run SEQUENTIALLY, once, AFTER FF/G land**
(precondition: owning tracks re-run the registry + embedded-sources
generators so GENERATED files converge first):

```
cd /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/canvas
dart format canvas_core/lib canvas_app/lib canvas_app/tool canvas_core/test canvas_app/test
(cd canvas_core && flutter analyze --no-pub && flutter test)
(cd canvas_app && flutter analyze --no-pub && flutter test)
```

Acceptance for that run: `analyze` zero issues both packages, `test` zero
failures both packages, and the commit message names the style-version
normalization so `git blame` stays interpretable. `editor_tokens.dart`
whitespace changes are values-safe (`light_theme_test` pins hexes, suite
must stay green), but keep its hunk reviewable.

## 7. Failures filed for owning tracks (NOTHING fixed by H-FINAL)

- **H-FINAL-1 — harness exit codes don't propagate (H scope, next H batch
  or tool owner).** `canvas_app/tool/render_codegen_diff.dart:284`
  `Future<int> main` return value is ignored by the Dart 3.13.2 VM
  (measured §3); `H0Exit` 0/1/2/3 contract is advisory. Fix (one line,
  existing file — needs a batch with tool ownership):
  `exit(await h0.main(args))` wrapper or set `exitCode`. Until then the CI
  `drift` smoke step is presence-only.
- **H-FINAL-2 — legacy bundle screen output not canonically formatted
  (G track, G2/G4).** `canvas_core/lib/src/codegen_bundle.dart`
  `_screenFile`/`_bundleFallbackLines` region: emitted
  `primitives_screen.dart` body is under-indented 2sp vs `dart format`
  (gate-3 probe exit 1, §2 row 3). G2's `code_builder`+`dart_style` path is
  the structural fix; G4's generated-output format gate will pin it. Do
  NOT hand-tweak emitter whitespace — migrate the path.
- **H-FINAL-3 — manifest warning noise for `select`/`object_input`
  (G track, triage).** `canvas_core/lib/src/codegen_bundle.dart:199`
  (`select` dependsOn lists `'async'`, no `_kinds` entry) and `:418`
  (`object_input` dependsOn lists `'locale_utils'`, no `_kinds` entry) →
  every export containing those kinds carries `unknown component 'async'
  required by 'select': skipped` / `unknown component 'locale_utils'
  required by 'object_input': skipped` in `manifestJson.warnings`
  (measured in both scan runs, sources-independent). Likely benign (pub
  package / non-kind library resolved outside `requireKind`, cf. the
  `_screenExtraTemplates` mechanism at `:766`) but user-visible noise;
  either register the entries or silence precisely. Severity: minor.
- **H-FINAL-4 — gates 4–5 CI wiring needs a resolvable kit dep + a
  generate-to-dir script (G4).** Emitted pubspec
  (`project_writer.dart:250`) needs `flutter_shadcn_kit: ^1.0.0`; CI must
  add a path-override (kit checkout) or publish step, plus a checked-in
  script that writes `scaffoldProject` + page files to a dir for
  `flutter analyze` / `flutter build web` / gate-3 promotion. Not
  attempted in-sandbox beyond the cache check (§2 rows 4–5).
- **G3 gap status (G3 owns):** 10-kind placeholder gap CLOSED mid-flight
  (§4 run 2, suite 1274 green). No action — recorded so a stale "gap open"
  reading of run 1 doesn't spawn duplicate work. Re-scan any time with
  `dart run tool/placeholder_scan.dart --dir <generated-dir>`.

## 8. Files created + verification

| File | Status |
|---|---|
| `canvas/.github/workflows/canvas-gates.yml` | NEW, 4 jobs, YAML-parsed (§1) |
| `canvas_app/tool/placeholder_scan.dart` | NEW, `dart format` clean (0 changed), CLI 0/1/2 verified (§4) |
| `canvas_app/test/h_final_gates_test.dart` | NEW, 12/12 pass |
| `docs/BUILD_H_FINAL.md` | NEW, this file |

Verification (exact): `flutter analyze --no-pub` → `No issues found!`
both packages (post-adds); `flutter test` → core `+420 All tests passed!`
(exit 0), app `+1274 All tests passed!` (exit 0, includes the 12 new H
tests); `git status` shows ONLY the 4 new files as mine (FF6/G3 in-flight
edits to `lib/*`, `main.dart`, `g3_*` fixtures observed but never touched —
no `lib/`, test, pubspec, `main.dart`, `COMPOSITION.md`, or `../.github`
writes; no `pub get`; no source `dart format` writes).
