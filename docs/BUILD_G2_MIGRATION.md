# Track G2 — `code_builder` Migration Notes

Session scope: **G2 MIGRATION only** (BUILD_SPEC §§4.2, 6, 8.2–8.4, 11, 12).
Baseline: `2316e8e1` (G1 scaffold), green at 386 core + clean analyze.
Result: **420 core tests pass (386 + 34 new), analyze clean both sides,
127 consumer tests pass.** No legacy output byte changed (full F-suite green
unmodified).

## 1. Approach (and why the bundle file barely changed)

The brief said "behind the existing `_bundleX` signatures where feasible."
Feasibility was tested, not assumed, and one attempt FAILED instructively:
routing a `_bundleX` body through `DartFormatter` collapses short widgets to
one line (`Container(child: …)` fits in 80 cols), breaking hundreds of
F-pinned multi-line goldens. So the migration is a **parallel AST path with
parity proofs**, not an in-place rewrite:

* NEW `lib/src/emit/expr_emitter.dart`: `AstEmitter` (§6.4 shape, named to
  avoid clashing with `code_builder`'s own `ExpressionEmitter` mixin), the
  `TaggedValue → Expression` bridge, `formatExpression` (one `dart_style`
  pass), `importDirectives`, and **10/97** kind emitters (the Track F
  primitives) + `emitPrimitivePageFiles` walker.
* MOVED (verbatim) `lib/src/emit/value_codecs.dart`: the 17 Track F
  `_bundlePrim*` value codecs. `codegen_bundle.dart` keeps thin delegating
  wrappers (call sites untouched); the AST path composes the same codecs.
  §6.1 collapse rules now have exactly ONE implementation shared by the
  string path, the AST path, and (via `tagged_value.dart`, untouched) the
  single-file exporter.
* WIRED `lib/src/emit/project_writer.dart` (additive only): `pageKindsFor`
  (whole-screen, nested-aware detection), `planModelFields` (controller/bool
  allocation), `responsiveLeafValue` (tablet→`md:`, desktop fallback),
  `emitPage` (needsModel split + collector-driven imports + model shell).
  G1 shells (`buildPageFile`, `buildModelFile`, …) verbatim.

## 2. Migrated vs wrapped ledger (honest)

* **Migrated 10/97**: `container column row stack padding center align
  expanded sized_box spacer`. AST owns: constructor choice, named-arg
  presence/order, child composition (`child:` vs `children:` + gap
  separators), the §6.2 color-XOR-decoration branch, responsive-leaf
  wrapping, const placement. Proven by 15 format-normalized parity tests
  (legacy `_bundleX` vs AST, both through `dart_style`, comments stripped —
  same program, two mechanisms).
* **Wrapped (opaque `Code` leaves)**: `const` constructor calls, hex
  literals, gap separators, the `responsiveValue` call template —
  `code_builder` has no `const` model and its trailing-comma emission would
  fight hand layout. All wrap SINGLE-SOURCED codec strings, never hand text.
* **Untouched 87/97**: kit-widget emitters stay pure-string until G3 (their
  goldens pin hand-shaped multi-line blocks; cutover re-bases goldens
  post-format in G4 per G1 §8).

## 3. Token resolution + collapse (the zero-`Theme.of` closure)

* Token colors → `Theme.of(context).colorScheme.<token>` (real property
  chain in `toExpression`; single-sourced codec strings in adapters) — never
  a hex. Literals → `Color(0xFF…)`. `ColorValue.token` with a null token is
  impossible by construction (sealed subtypes).
* Collapse: `.all` / `.symmetric` / `.fromLTRB` / `.zero`,
  `BorderRadius.circular` / `.only`, 9 alignment constants + custom pairs,
  `const` insertion with themed-ness tracking (a token anywhere kills the
  enclosing `const` — incl. the `unnecessary_const` trap that const lives on
  the SHADOW LIST, never its entries).
* Fixtures (all hand-written FIRST, `.json` + `.expected.dart` pairs):
  `test/fixtures/g2_token_container` (token vs literal),
  `g2_collapse` (symmetric/fromLTRB/named+custom alignment),
  `g2_responsive_leaf` (leaf rule + const elision),
  `g2_model_split` (+ `_model`, Stateful+Model vs Stateless).
  Byte-exact + whole-file reformat idempotence (gate-3 direction).

## 4. Two formatter findings (measured — G3/G4 must know)

1. **Trailing commas are load-bearing.** `code_builder` emits them after
   every arg of a multi-arg invocation; the formatter treats them as hard
   splits (full-split, +2 block indent — stable fixpoint). Stripping them
   before formatting looks prettier (minimal splits, short multis stay one
   line) but the output is NOT a fixpoint (reformat re-splits +2), failing
   gate 3. **Policy: never strip; multi-arg widgets always full-split.**
   (`formatExpression` documents this; do not "simplify".)
2. **Comments inside formatted lists need B-shape raw**: each comment
   pre-indented at list-item level (`[\n  // kind 'id'.\n  SRC,\n…]`); the
   formatter then keeps every comment with its item, stably. Column-0
   comments misplace (first at +2, rest at +0 — a formatter quirk, verified
   by experiment). Nested composites stay comment-free (trace comments live
   at root level only).

## 5. Files modified / created

* Modified: `canvas_core/lib/src/codegen_bundle.dart` (codecs→wrappers,
  ~300 lines deleted, zero output change), `canvas_core/lib/src/emit/
  project_writer.dart` (4 additive helpers, shells verbatim).
* Created: `canvas_core/lib/src/emit/{value_codecs,expr_emitter}.dart`,
  `canvas_core/test/g2_migration_test.dart` (34 tests),
  `canvas_core/test/fixtures/g2_*.{json,expected.dart}` (4+1),
  this doc.
* Untouched per allowlist: `codegen_single.dart`, `screen_doc.dart`,
  `canvas_app/*`, `pubspec.yaml`, `main.dart`, `.github/`,
  `tagged_value.dart` (public API verbatim — F's emitters unaffected).

## 6. Handoff

* **G3 (10-kind gap)**: `chip alert circular/linear_progress triple_dots
  dot_indicator empty_state code_snippet number_ticker text_area` still
  placeholder (`_bundlePlaceholderKinds` untouched). Migrate kit emitters to
  `AstEmitter`, reusing `toExpression`/`withTabletLeaf`/collector; register
  `KindBinding`s so `driftKinds` empties structurally. Open v1 gaps to
  close: `hiddenOn` (trace comment only), non-leaf `breakpointValues`
  (inert except wired padding/margin/width/height), `isRow` structural rows
  (transparent in v1), `tabs`/`carousel`/`swiper`/`tab_container` model
  fields (force a model today, no fields yet), leaf-children fallback
  (siblings, never dropped).
* **G4 (single demote)**: re-base goldens post-format, cut the legacy string
  path over to adapters, demote `codegen_single` to experimental inline
  mode, barrel-export `src/emit/`, run gates 3–7 (generated-project
  `dart format` check + `flutter analyze` + `build web` + zero placeholders
  + human review).
* Net: `codegen_bundle.dart` −~300 lines (codecs single-sourced);
  `code_builder 4.12.0` + `dart_style 2.3.6` now imported by shipping code
  (previously resolved-but-unused). `canvas_core` still Flutter-free.
