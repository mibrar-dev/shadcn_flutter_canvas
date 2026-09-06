# Track G3 — Close the 10-Kind Gap, Structurally (§8.2)

Session scope: **G3 GAP CLOSEOUT only** (BUILD_SPEC §§4.3, 6.5, 8.2, 11, 12).
Baseline: `02df67f2` (G2 migration), green at 420 core + clean analyze.

Result: **463 core tests pass (420 + 43 new), analyze clean.** The 10
registry-only kinds that rendered on canvas but exported as `Text`
placeholders (`chip`, `alert`, `circular_progress_indicator`,
`linear_progress_indicator`, `triple_dots`, `dot_indicator`,
`empty_state`, `code_snippet`, `number_ticker`, `text_area`) now emit real
bodies behind both export paths from ONE implementation each.

## 1. Golden-first (§6.5) — how it was honored

`canvas_core/test/fixtures/g3_<kind>.json` + `.expected.dart` (10 pairs +
1 model file) were **hand-written from the canvas registry builders
BEFORE any emitter existed** — no expected byte here was produced by
running an emitter. Oracle per kind: the verified `buildXEntry`
function in `canvas_app/lib/canvas/component_registry.dart`
(prop-for-prop, same defaults, same `num`-parse + clamp edge handling).

Two mechanical steps, both neutral ground (neither is the emitter):

- Layout canonicalization: the hand-written `.expected.dart` files were
  checked with `dart format --set-exit-if-changed` — **0 changed**.
  (G1 §8: goldens are stored post-format.)
- One premise correction on the emitter side: the labeled-`text_area`
  golden pins the trailing comma after the last `children:` element
  (canonical multi-element list form, the G2 trailing-comma policy);
  the first emitter draft omitted it and was fixed to match the golden.
  The golden's program never moved toward the emitter.

## 2. One registry, both paths (§8.2)

NEW `canvas_core/lib/src/emit/g3_emitters.dart` — one `AstEmitter` per
kind, consumed twice:

- **Page walker** (new project path): `emitPrimitivePageFiles(...,
  extraEmitters: g3Emitters)` — the walker gained an ADDITIVE optional
  parameter (G2 callers pass nothing, byte-identical). G3
  `collectImports` declares the `flutter_shadcn_kit` umbrella (the §8.1
  package-dep contract); the shell still owns the material import.
- **Bundle string path** (shipping exporter): `codegen_bundle.dart`
  gains ten thin `_bundleX(item)` wrappers over `g3BundleLines`
  (canonical `formatExpression` output, line-split + trailing comma —
  same program, adapted shape). The wrappers own NO props logic.

`g3Registry()` registers all ten as `ExprAdapter` + `KindBinding`
(render builder + correctness rules + `needsModel`, true only for
`text_area`). `driftKinds` is empty by construction; the drift guard in
`test/g3_gap_test.dart` asserts it.

Construction ledger (cf. G2's honest ledger): `alert`,
`dot_indicator`, `empty_state`, `number_ticker`, `text_area` are
structured AST (constructor choice + arg presence/order are real
decisions); `chip`, `circular_progress_indicator`,
`linear_progress_indicator`, `triple_dots`, `code_snippet` are opaque
single-line leaves (one short arg — no layout decision to own), built
from the same single-sourced value helpers. String escaping mirrors
`_bundleStr` exactly.

`_bundlePlaceholderKinds` is DELETED (no uses remain). Unknown kinds
keep the honest `Text` placeholder via the `_bundleBody` default branch.

## 3. Per-kind summary

| Kind | Emitter | Constructor | Notes |
|---|---|---|---|
| `chip` | ChipEmitter (leaf) | `Chip(child: Text(label))` | default `'Chip'` |
| `alert` | AlertEmitter (AST) | `Alert(title:, content:, destructive:)` | Texts; bool passthrough |
| `circular_progress_indicator` | CircularProgressEmitter (leaf) | `CircularProgressIndicator(value:)` | `num`-parse, clamp 0..1, default 0.6 |
| `linear_progress_indicator` | LinearProgressEmitter (leaf) | `LinearProgressIndicator(value:)` | same |
| `triple_dots` | TripleDotsEmitter (leaf) | `MoreDots(count:)` | kit name differs from kind; int clamp 1..9, default 3 |
| `dot_indicator` | DotIndicatorEmitter (AST) | `DotIndicator(index:, length:)` | index clamped into length range |
| `empty_state` | EmptyStateEmitter (AST) | `EmptyState(title:, description:)` | Texts |
| `code_snippet` | CodeSnippetEmitter (leaf) | `CodeSnippet(code: Text)` | default `'const x = 1;'` |
| `number_ticker` | NumberTickerEmitter (AST) | `NumberTicker(number:, formatter:)` | plain integer formatter pinned; value unclamped (mirrors builder) |
| `text_area` | TextAreaEmitter (AST) | `TextArea(placeholder:, enabled:)` + label caption `Column` | static snapshot, no controller ref; `needsModel: true` (the `{Page}Model` shell owns the controller — `planModelFields` already allocated it; G1 contract confirmed) |

V1 gap (documented in-file): `=var` bindings inside G3 text props emit
the quoted literal (legacy unknown-var fallback behavior) — live
interpolation for these ten kinds is future work.

## 4. Files modified / created

- Created: `canvas_core/lib/src/emit/g3_emitters.dart`,
  `canvas_core/test/g3_gap_test.dart` (43 tests),
  `canvas_core/test/fixtures/g3_*.{json,expected.dart}` (10+1),
  this doc.
- Modified (G3 emitters + delegation only):
  `canvas_core/lib/src/codegen_bundle.dart` (import, 10 `_bundleBody`
  cases, 10 thin wrappers, placeholder-set deletion, doc updates),
  `canvas_core/lib/src/emit/expr_emitter.dart` (additive
  `extraEmitters` parameter), `canvas_core/lib/src/emit/widget_emitter.dart`
  (additive `bindingFor` accessor).
- Mandated test updates (the spec-required behavior change —
  `codegen_bundle_test.dart` pinned the exact drift G3 closes):
  the placeholder golden retargeted from `chip` to a genuinely unknown
  kind (test renamed to `unknown kinds keep the comment plus
  placeholder…`; the unknown-kind honesty rule still holds), and the
  barrel-wiring test now asserts `chip`'s real import + body (gate-7
  evidence in-suite). No other existing test was touched.

## 5. Handoff to G4

- `text_area` model/controller wiring: confirmed (Stateful + model
  shell, static body — see `g3_text_area*.expected.dart`).
- Open v1 gaps carried forward: `=var` interpolation in G3 text props;
  non-leaf `breakpointValues` still inert for G3 kinds (leaves wire no
  responsive overrides yet).
- G4: demote `codegen_single`, barrel-export `src/emit`, gates 3–7
  evidence (format check + placeholder scan + byte-exact goldens).
