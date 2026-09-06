# Track H0 (hardening prep) — baseline, diff harness, gates, re-measure

Session scope: **H0 PREP ONLY** per the wave brief (BUILD_SPEC §§10, 11, 12).
No source fixes, no pinning, no CI required-check wiring. New files only:

- `canvas_app/tool/render_codegen_diff.dart` (NEW skeleton)
- `canvas_app/test/h0_diff_harness_test.dart` (NEW, 14 tests)
- this doc (NEW)

Repo: `canvas/` at HEAD `2316e8e1` (FF1-FF3 + F primitives + G1 scaffold).
`git status` was clean at session start. No `flutter pub get` was run.

## 1. Measured baseline (2026-09-06, Flutter 3.47.2 / Dart 3.13.2)

| Check | Command (workdir) | Result |
|---|---|---|
| analyze canvas_core | `flutter analyze --no-pub` in `canvas_core/` | **No issues found!** (0.6s) |
| analyze canvas_app | `flutter analyze --no-pub` in `canvas_app/` | **No issues found!** (3.5s) |
| tests canvas_core | `flutter test` in `canvas_core/` | **386 passed, 0 failed** |
| tests canvas_app | `flutter test` in `canvas_app/` | **1212 passed, 0 failed** (incl. 14 new H0) |
| new H0 tests | `flutter test test/h0_diff_harness_test.dart` in `canvas_app/` | **14 passed** |
| analyze after H0 adds | `flutter analyze --no-pub` in `canvas_app/` | **No issues found!** |

**Green confirmed with evidence above — no work invented.** Repo gates §11.1–2
PASS at HEAD.

Previously-failing tests from the spec audit (§3.2: `gen_registry_drift_test`
3 + `drop_preview_test` 1 + 13 more = 17): all pass now — verified both in the
full-suite run and by a targeted rerun
(`flutter test test/gen_registry_drift_test.dart test/drop_preview_test.dart`
→ 9 passed). The drift closure came from Tracks F/G1 (embed closure +
primitive bridge), not from H0. Owning tracks own any regression.

Flaky / order-dependent candidates: **none observed in this session**
(single full run per package + one targeted rerun, zero flakes). Single-run
evidence only — H-final should run each suite 3× (`--concurrency=1` once) and
record here before declaring "no flakes".

Read-only observations filed, NOT fixed (out of H0 allowlist):

1. **Source tree is not `dart format`-clean** (dry-run only, nothing modified):
   `dart format --output=none --set-exit-if-changed` reports **9 files in
   `canvas_core/lib`** (e.g. `canvas_core/lib/src/share_codec.dart`) and
   **30 files in `canvas_app/lib`** (e.g. `canvas_app/lib/ui/theme_bar.dart`)
   plus all 4 pre-existing `canvas_app/tool/*.dart`. This is NOT a gate
   failure — §11 gate 3 applies to *generated* output, and no format gate is
   wired for source — but H-final should decide: format the tree once (noisy
   diff) or record "source format intentionally unwired". Filed for the
   owning process track; H0 touched only its own 2 new files (formatted).
2. **10-kind placeholder gap (§4.3 → G3 scope)**: still open by design. H0 did
   not touch it. Gate 7 stays red until G3 lands via §8.2.

## 2. Render-vs-codegen screenshot-diff harness (§10 highest-value test)

Files:

- `canvas_app/tool/render_codegen_diff.dart` — CLI skeleton. **Implemented
  today** (pure, no browser): fixture discovery (`h0DiscoverFixtures`),
  golden-path resolution (`h0GoldenPaths`), raw-RGBA diff math
  (`h0PixelDiff`: per-pixel tolerance default 8/255, alpha compared, length
  mismatch counts extras as different, empty buffers yield diffFraction 1.0 so
  "no signal never reads as PASS"), verdict (`h0Verdict`, default max
  fraction 0.01), markdown report (`h0RenderReport`, byte-stable `| key |
  value |` rows for CI parsing), arg parsing, exit codes
  (0 pass / 1 diff-over-threshold / 2 infra-error / 3 stage-unimplemented).
  **Documented stubs** (need a browser, H-final scope): `h0StageAInstructions`
  (screenshot canvas render), `h0StageBInstructions` (build + screenshot
  generated project). Zero new dependencies (dart:* + package:canvas_core
  only, matching existing tool scripts).
- `canvas_app/test/h0_diff_harness_test.dart` — 14 tests over the pure pieces
  (imports the tool file relatively; no browser needed).

Manual runbook (works today, pure stages):

```
cd canvas/canvas_app
dart run tool/render_codegen_diff.dart --stage pure \
  --fixtures ../canvas_core/test/fixtures --out /tmp/h0diff
# → per fixture: prints stage A/B instructions, scaffolds <base>.report.md (NOT-RUN)
```

Full diff once stage PNGs exist (operator fills
`<base>.canvas.png` + `<base>.codegen.png` per the printed instructions, then):

```
dart run tool/render_codegen_diff.dart --stage all \
  --fixtures ../canvas_core/test/fixtures --out /tmp/h0diff
# → per fixture: <base>.diff.png + <base>.report.md, JSON verdict line on stdout,
#   exit 0 pass / 1 diff-over-threshold
```

Smoke-verified this session (`--stage pure` produced the NOT-RUN report
scaffold for `primitives_screen.json`).

Future CI wiring (AFTER FF7 cutover per §10 — do NOT add yet):

```yaml
# .github/workflows/canvas-h0-diff.yml (future)
- run: dart run tool/render_codegen_diff.dart --stage all
    --fixtures ../canvas_core/test/fixtures --out /tmp/h0diff
  working-directory: canvas/canvas_app
- uses: actions/upload-artifact@v4
  with: {name: h0-diff, path: /tmp/h0diff/}
```

H-final still to build: automated Stage A (integration_test + headless
Chrome capture of the gallery/seed view at a fixed device size), automated
Stage B (G-track project writer → `flutter build web` → headless-Chrome
capture at the same size), `.diff.png` rendering (needs an image codec —
`package:image` is pure Dart and keeps `canvas_core`-style purity; decide in
H-final, it adds a dependency so it needs a G-wave-style pubspec change).

## 3. Gates wiring check (§11 vs actual CI)

Workflows live at the **parent** repo root (`../.github/workflows/`), not in
`canvas/` — there is no `canvas/.github`, no `canvas/Makefile`. Parent has
`validate.yml` (registry-manifest + CLI tests only) and `canvas-deploy.yml`
(deploy-only). Per the "when in doubt, doc-only" rule, **zero CI edits made**.

| §11 gate | Wired? | Evidence |
|---|---|---|
| 1. `flutter analyze` (root + canvas_app), zero issues | ❌ MISSING | `validate.yml` runs `dart tool/validate_canvas.dart` + CLI tests only; no analyze step anywhere; `canvas-deploy.yml` is build-and-deploy with no gate steps |
| 2. `flutter test`, zero failures | ❌ MISSING (canvas) | `validate.yml` tests only `shadcn_flutter_cli`; no `canvas_core` / `canvas_app` test step |
| 3. `dart format --set-exit-if-changed` on generated output | ❌ MISSING | no step; no script |
| 4. `flutter analyze` on generated output | ❌ MISSING | no step; no script |
| 5. `flutter build web` on generated output | ❌ MISSING (as a gate) | `canvas-deploy.yml` builds the *editor* app for deploy, not generated output |
| 6. Byte-exact goldens per fixture | ⚠️ PARTIAL (repo-local only) | goldens enforced by in-repo tests (`primitives_f3_goldens_test`, `codegen_*_test`), but no CI job runs them |
| 7. Zero placeholder emissions | ⚠️ PARTIAL (repo-local only) | drift guard `gen_registry_drift_test` passes in-repo; unwired in CI; gap itself is G3 scope |
| 8. Human PR test | ❌ MANUAL by definition | no checklist template references it |

No trivial-additive edit was zero-risk here: the workflows are outside
`canvas/` (parent-repo blast radius, shared with other agents' tracks), so
even a "non-blocking" step addition violates "do not collide". H-final (with
exclusive CI ownership) should add one `canvas-gates.yml` covering gates 1–6
(non-blocking first, required after FF7), leaving gate 8 to a PR template
checkbox.

## 4. FF1 token re-measurement procedure + table (§10, measured-spec rule)

Source of truth: `canvas_app/lib/ui/editor_tokens.dart` (`EditorColors.light`
/ `.dark`, `EditorMetrics`). **H0 did not edit it.** FF1 values below are
APPROXIMATE per the file's own comments; `light_theme_test.dart` pins the
pre-existing hexes (must stay green — it does, §1).

Re-measurement procedure (for H-final, against the live FlutterFlow UI at
`app.flutterflow.io`):

1. Sample each surface with a color picker at 100% zoom, both FlutterFlow
   light and dark builder themes: (a) nav rail background → `railBg`;
   (b) rail active-destination indicator bar → `railActiveIndicator`;
   (c) side panel background → `panelBg`; (d) canvas backdrop (outside the
   device frame) → `canvasBackdrop`; (e) selected-widget outline on canvas →
   `selectionOutline`; (f) grouped-properties section header text →
   `groupHeaderFg`. Metrics: rail width → `ffRailWidth` (~48),
   top-bar height → `ffTopBarHeight` (~56), panel widths (~280/~300).
2. Verify: sample 3 distinct points per surface (gradient check — if they
   differ, the surface is not flat; record all stops, do not average into a
   fake flat); repeat in an incognito window (extensions shift colors);
   screenshot + attach the sampled PNG to the H-final commit.
3. Pin: replace the APPROXIMATE value, delete the APPROXIMATE comment per
   token, extend `test/ff_tokens_test.dart` (NEVER weaken
   `light_theme_test.dart`).

| token | current APPROXIMATE (light) | current APPROXIMATE (dark) | measured (H-final) | status |
|---|---|---|---|---|
| `railBg` | `#FFFFFFFF` | `#FF1E1D20` | — | APPROXIMATE |
| `railActiveIndicator` | `#FF2563EB` | `#FF60A5FA` | — | APPROXIMATE |
| `panelBg` | `#FFFFFFFF` | `#FF1C1B1F` | — | APPROXIMATE |
| `canvasBackdrop` | `#FFE8ECF1` | `#FF0F0E11` | — | APPROXIMATE |
| `selectionOutline` | `#FF2563EB` | `#FF60A5FA` | — | APPROXIMATE |
| `groupHeaderFg` | `#FF6B7280` | `#FF9CA3AF` | — | APPROXIMATE |
| metrics `ffRailWidth/ffTopBarHeight/panel widths` | ~48/56/280/300 | same | — | APPROXIMATE |

Note: dark `railActiveIndicator`/`selectionOutline`/`accent` share `#FF60A5FA`
and light `railActiveIndicator`/`selectionOutline`/`accent` share `#FF2563EB`
— re-measurement should confirm whether FlutterFlow actually uses one ramp
for all three or three distinct values (suspect: three distinct; filed for
H-final to check, not to assume).

## 5. Failures filed for owning tracks (nothing fixed by H0)

1. **G3 scope (§8.2 structural fix):** 10-kind placeholder gap still open
   (spec §4.3 list). No action — G3 owns. Harness `primitives_screen.json`
   fixture already covers the §7.5 tree for future diff runs.
2. **Process/track ownership:** source `dart format` drift (39 files, §1
   observation 1) + zero canvas gates wired in CI (§3 table) — H-final owns
   both; needs exclusive CI ownership since workflows live in the parent repo.
3. **No test/source defects found by H0.** `canvas_core/lib/*`,
   `canvas_app/lib/*`, existing tests, `main.dart`, pubspecs, COMPOSITION.md,
   FORGE.md untouched; no new dependencies; `git status` additions are exactly
   the 3 files listed at the top of this doc.
