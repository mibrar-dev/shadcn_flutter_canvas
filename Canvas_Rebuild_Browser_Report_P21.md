# Canvas Rebuild — Browser Verification Report (P21)

Date: 2026-09-07. Branch: `feat/canvas-p3` (13 commits on top of `07f28e21`).
Spec: `BUILD_SPEC.md` (Canvas → FlutterFlow-class visual builder).

Method: release builds (`flutter build web --release`, both trees compile
clean) served over plain HTTP, driven with coordinate mouse control because
the app paints to a single `<canvas>` (the accessibility tree exposes only
one button, so ref-based automation cannot reach Flutter widgets).
Screenshots in `rebuild_browser_shots/` (1440×900).

- BEFORE = base `07f28e21` (pre-rebuild): `before_home.png`
- AFTER = rebuild HEAD `4bebc4f2`: `after_home.png`, `after_palette.png`,
  `after_drop.png`, `after_inspector.png`, `after_deploy.png`

Pre-test cleanup: killed all stale project servers — `flutter run -d
web-server` on :8907 (Saturday, serving pre-rebuild code), plus `http.server`
instances on :8900/:8911/:8913/:8100. All ports verified closed before
re-testing.

## 1. Browser pass (AFTER) — all green

| # | Action | Result |
|---|---|---|
| 1 | Load release build | ✅ Shell renders first paint, all fonts load (Geist, Lucide, Radix, Bootstrap, Material — 200s in network log) |
| 2 | Rail → Palette | ✅ Panel switches to list rows, search field present |
| 3 | Layout Primitives section | ✅ Ordered FIRST, count badge **10**: Row, Align, Center, Column, Container, Expanded, Padding, Sized Box, Spacer, Stack |
| 4 | Drag Container → phone frame | ✅ Drop lands, block renders labelled `container`, prompt panel lists the new node with position |
| 5 | Tree panel | ✅ Shows `Screen 1 › Container…` with up/down/lock/duplicate/delete affordances, `1 selected` multi-select header |
| 6 | Select node (tree row) | ✅ Canvas draws accent outline + floating `Container` kind label + resize handles; breadcrumb `Screen 1 › Container · u2`; inspector switches to grouped panel |
| 7 | Grouped inspector (FF6+F4) | ✅ `Container · u2` header, collapsible **Layout** (width/height steppers) and **Style** (padding L/T/R/B + **All** row with `All sides equal` readout, margin) groups |
| 8 | Deploy pill | ✅ Export dialog opens: `Project` / `Inline sources (experimental)` segmented modes, `Download project ZIP`, single-file + share + doc-JSON actions |

No console-blocking errors; no placeholder/fallback rendering anywhere.

## 2. Before → after

### 2.1 Chrome (reskin: Forge → FlutterFlow model)

| Surface | BEFORE (`before_home.png`) | AFTER (`after_home.png`) |
|---|---|---|
| Top bar | `Forge · Untitled · Screen 1` tab + `+`; **Preview** / **Export Flutter** pills | Page **dropdown** (`Select page` → `Screen 1`); device + zoom embeds; **Run** / **Deploy** pills |
| Nav rail | Old Forge icon rail (no panel switching) | 48px `FfNavRail`: Tree / Palette / Theme / Assets / Settings, switches the 280px panel host (deliberate Y6 reversal, committed as such) |
| Palette | 2-column **tile grid** (Accordion, Alert, App, Basic, Card…) | Full-width **list rows** (28px tile + label + drag hint), search unchanged, DnD payloads unchanged |
| Canvas backdrop | Dotted (`ForgeDotsPainter`) | Neutral `canvasBackdrop` (painter deleted) |
| Device frame | Shadowed bezel | Plain bezel, shadow removed (paint-only; every geometry token verbatim, pinned by `ff5` test) |
| Selection | Toolbar-anchored highlight | Accent outline + floating kind label + handles |
| Inspector | Flat prop list | Collapsible Layout / Style / Content / State groups + visual box-model editor |
| Export | Single-mode dialog | Mode switch: supported Project ZIP vs experimental inline-sources |

### 2.2 Capability (the two blockers from §4)

| | BEFORE | AFTER |
|---|---|---|
| Layout primitives | **1 of 10** (`Row` only; section header existed but empty) — screens unbuildable beyond an implicit `Column` | **10 of 10** with model fields (`SizeMode` derived getters, zero JSON churn), catalog builders, PropSpecs, sizing selector, paint/radius/border/gradient/shadow editors |
| Codegen contract | `doc → inline kit sources → hand-rolled linker` (7,771-line `codegen_single`, 264 write-sites) | `doc → widget tree → package-dep Dart` (AST path for primitives + G3 kinds, `code_builder` + `dart_style`); single-file demoted to experimental export mode |
| Registry↔codegen drift | 28 kinds rendered but exported as placeholders (spec audit) | **0 placeholders** (placeholder scan 0/38; `driftKinds` empty; scanner wired into CI) |
| Generated-output gates | No evidence | Gate 3 format-clean, **gate 4 `flutter analyze` exit 0**, **gate 5 `flutter build web` exit 0** on a real generated project (`/tmp` proof, local-kit path dep) |

### 2.3 Health

| | BEFORE (audit/base) | AFTER |
|---|---|---|
| `flutter analyze` | clean | clean (core + app) |
| Tests | 1138 app (+17 failing at audit) | **1282 app + 486 core, 0 failures** |
| CI | validate.yml (registry manifests + CLI only) | `canvas/.github/workflows/canvas-gates.yml`: analyze / test / drift+goldens / format-check |
| Harness | — | render-vs-codegen diff skeleton + exit-code-correct CLI + placeholder scanner |

## 3. What was rewritten (13 commits)

- `6df2db46` FF1–FF3: additive tokens (6 colors + 8 metrics, all APPROXIMATE per measured-spec rule), `ff_nav_rail.dart`, `ff_panel_host.dart`, dense topbar with device/zoom embeds.
- `cd8310d9` Track F: 10 primitives end-to-end (model, catalog, PropSpecs, registry regen with section first, bundle+single emitters, hand-written `primitives_screen` fixture + 0/1/2 goldens).
- `2316e8e1` G1: `emit/` scaffolds (tagged values, `EmitContext`, `WidgetEmitter`, project writer) + audit + `BUILD_G1_DESIGN.md`.
- `649920d9` F4: sizing segmented control, alignment grid, editable paint/radius/border/gradient/shadow editors.
- `02df67f2` G2: parallel AST path (10 primitives migrated, 87 kit emitters wrapped with parity, no output change).
- `d8be435a` FF4–FF5: tree/palette panels, neutral backdrop, bezel skin, selection outline + label.
- `6caaf775` + `552d0a3e` H0/H: diff harness, `canvas-gates.yml`, placeholder scanner, gates evidence, re-measure procedure (tokens stay APPROXIMATE — no live sampling in-sandbox, nothing eyeball-promoted).
- `83ddc6a3` + `3c0bda54` FF6–FF7: grouped inspector + box-model All-row, cutover mount at 48/280/flex/300.
- `12cfe9af` G3–G4: 10-kind gap closed via `KindBinding`s, single-file demote with panel wiring.
- `7b6fa03c` + `9fbe16a9` fix-ups: shell-test migration, Run/Deploy rename, harness exit codes, emit barrel, manifest roots.
- `89c2cade` H-FINAL-2: legacy emitter indentation → generated output is `dart format`-clean; unknown-component warnings zero.
- `511edf45` hygiene: SDK format migration (86 files, whitespace-only), dead `icon_rail.dart` deleted.
- `f5e5805b` + `4bebc4f2` gates 4–5: sample-project driver + evidence, then `ImportCollector` hide/prefix, const-canonical emission, format-clean `main.dart`, emitted `web/` scaffold.

Kept verbatim throughout: `canvas_store.dart` (undo/redo, screens,
multi-select), `app_state.dart`, `COMPOSITION.md` nesting model (extended,
not rewritten), `prompt_builder` / `share_codec`, all store callbacks and
DnD payload contracts.

## 4. Issues found in the browser (minor, filed)

1. Phone status-bar time (`9:41`) sits slightly under the bezel curve —
   **pre-existing** (visible in BEFORE shot too), cosmetic only.
2. Device + zoom controls appear in BOTH the top bar and the canvas header
   (known duplication, deferred product call; both drive the same state).
3. `manifest.json` / `favicon.png` 404s under plain `http.server` —
   static-server noise, not app defects.
4. Build warns about Lucide/Radix font families in `IconData` vs pubspec —
   fonts demonstrably load at runtime (network log); non-blocking.

## 5. Gate status (§11)

1 analyze ✅ · 2 tests ✅ (1282 + 486) · 3 format-on-generated ✅ ·
4 analyze-generated ✅ · 5 build-web-generated ✅ · 6 byte-exact goldens ✅ ·
7 zero placeholders ✅ · 8 human PR test — this report + the shots above are
the evidence; the remaining judgment call is yours.
