# Track G1 — Codegen Rewrite Scaffold + Design

Session scope: **G1 SCAFFOLD + DESIGN only** (BUILD_SPEC §§0, 4.2, 4.3, 5, 6,
8, 11, 12, 13, 15). No edits to existing emitters — Track F owns additive
bundle changes this session. Full emitter migration is G2; goldens are NOT
written in G1 (Track F must land first per §13, or goldens get written twice).

Repo: `canvas/` at HEAD `07f28e21` (P20). Spec audited at `0c15e1a6` (P19).

## 1. Audit (measured at HEAD)

### 1.1 Write-site counts

| File | Lines (spec → HEAD) | `StringBuffer`/`write(`/`writeln(` lines (measured) |
|---|---|---|
| `canvas_core/lib/src/codegen_single.dart` | 7,771 → **8,113** | **264** (spec said 262) |
| `canvas_core/lib/src/codegen_bundle.dart` | 5,252 → **5,252** | **27** |

`codegen_single` keeps the hand-rolled linker (directive stripping, export
dedupe, import-graph fixpoint, `duplicate_ignore` merging, `as`-prefix
preservation, `on Widget` keeper election, type-twins homing) — verdict per
§5 stands: **DEMOTE to optional "inline sources (experimental)" mode in G4,
do not delete.**

### 1.2 Bundle emitter inventory

`_bundleBody` has **97 unique kind cases → 97 per-kind `_bundleX(props)`
functions** (109 `List<String> _bundle*` declarations minus 12 helpers:
`HiddenTiers`, `OverrideTiers`, `ItemExpr`, `WrapTap`, `ContainerBody`,
`Body`, `ShortcutKeys`, `BasicWithSlots`, `CardImageWithSlots`,
`ScaffoldWithSlots`, `SubtreeLines`, `FallbackLines`). Container pseudo-kinds
(14: card, outlined_container, scaffold, dialog, alert_dialog, drawer, form,
hidden, clickable, scrollbar, chat, toast, validated, refresh_trigger) route
through `_bundleContainerBody` into the same per-kind functions. Each maps 1:1
onto a G2 `WidgetEmitter` (registry type key + `EmitContext` needs below) —
mechanical, not a redesign.

EmitContext needs per emitter class (verified against current `_bundleX`
behavior):

| Need | Carried by | Used by |
|---|---|---|
| Import collector (barrel per kind + extras, e.g. `tabs.` prefix) | `EmitContext.imports` | every emitter; tab-family, menu→popup, card/dialog→button extras |
| Theme accessor (token-bound values) | `EmitContext.themeExpr` (`Theme.of(context)`) | **currently NONE — zero `Theme.of` in bundle output** (biggest G2 gap; see §2) |
| Responsive tier (hiddenOn/breakpointValues) | `EmitContext.tier` + `_bundleHiddenTiers/_bundleOverrideTiers` logic | row/leaf wrappers; leaf-value rule only |
| Name allocator (controllers/keys) | `EmitContext.names` | text_field/text_area (controllers), switch/checkbox/tabs (state fields) |
| Recursion | `ctx.emitChild(node)` | all container emitters |

### 1.3 Per-widget correctness rules (verified sample — G2 extracts the rest per emitter)

1. **Switch/Checkbox disabled rule** (`_bundleSwitch`, `_bundleCheckbox`):
   `disabled → onChanged: null`, else no-op callback. `null` renders the
   *disabled* state — a naive `onChanged: (_) {}` mapping gets semantics wrong.
2. **Divider empty-label branch** (`_bundleDivider`): the empty/non-empty
   branch is chosen *at export time*; emitting the runtime `if` would be
   dead code in output.
3. **Tabs barrel prefix** (`_bundleTabs`): tab-family names emit as
   `tabs.Tabs`/`tabs.TabItem` (the `tabs` barrel re-declares names homed
   elsewhere). Bare `Tabs` would collide after import merge.
4. **Placeholder-as-Widget, not String** (`_bundleInput`,
   `_bundleTextFieldKind`, `_bundleFormField`, et al.): kit `placeholder:`
   takes a `Widget` → always `Text('…')`, never a raw string.
5. **Container color-vs-decoration** (§6.2 archetype): **no container kind
   exists yet** — `container`/`column`/`padding`/etc. arrive with Track F
   (§7.1). The rule (`color` XOR `decoration:`, merge into `BoxDecoration`
   when radius/border/gradient/shadow set) is specified in
   `tagged_value.dart`/`widget_emitter.dart` docs and binds F3/G2 emitters.
6. **Static snapshots of stateful cells**: stateful kinds render initial
   value + no-op callback (never a dangling controller reference) until the
   `{Page}Model` split (§8.4) gives them a home in G2.
7. **Zero token resolution today**: `grep Theme.of codegen_bundle.dart` →
   empty. Every color/radius/spacing emits a literal. G2's highest-value
   single change is routing tagged color props through `themeExpr` (§6.1
   rule: never emit a raw hex for a token-bound value).

## 2. Tagged values (§6.1) — implemented in `lib/src/emit/tagged_value.dart`

Sealed `TaggedValue` + `parse({$: tag, v: …})` (lenient: unknown → null,
never throws) + `toDart(themeExpr)`. Tags: double/int/bool/string
(literals, single-quoted+escaped), enum (`Owner.name`), color token
(`Theme.of(context).colorScheme.<token>`) / literal (`Color(0xFF…)`,
uppercase ARGB), edgeInsets (collapse `.zero`/`.all`/`.symmetric`/
`.fromLTRB`), borderRadius (uniform→`.circular`, else `.only`),
alignment (9 named constants else `Alignment(x, y)`), size
(`fixed|expand|hug` — shapes parent, no literal form), icon
(`Icons.<name>`), asset (quoted path + pubspec entry via project writer),
textStyle (`theme.textTheme.<token>`, cf. §6.3). Flutter-free, no deps —
G2 keeps these types verbatim.

Current gap this exposes: doc props are still raw JSON (`_bStr/_bBool/
_bDouble/_bInt` lenient readers); the tagged envelope has no producer yet.
Track F's style PropSpecs (§7.3) should author tagged values directly so G2
emitters consume them without a lossy raw→tagged inference pass.

## 3. Output shape (§8.4) — implemented in `lib/src/emit/project_writer.dart`

`scaffoldProject` emits: `pubspec.yaml` (kit always, `go_router` only when
>1 screen, sorted `assets/` when used), `analysis_options.yaml`
(`flutter_lints`), `lib/main.dart` (`MaterialApp.router` iff router exists,
else plain `MaterialApp`), `lib/theme/app_theme.dart` (structure pinned;
token binding in G2 from `CanvasTheme`), `lib/routes/app_router.dart`
(only multi-screen; one `GoRoute` per screen). Page shells:
`pages/<slug>/<slug>_page.dart` + `<slug>_model.dart` **only when**
`needsModel` (any of `kStatefulKinds`: text_field, text_area, switch,
checkbox, tabs + provisional page-controller set carousel/swiper/
tab_container — G2 verifies each against its migrated emitter before
pinning; the contract test pins only the spec-certain four). Stateless →
`StatelessWidget`, no model file, no empty-model ceremony. Responsive:
`responsiveLeaf(base:, md:)` is the single constructor — values branch,
subtrees never duplicate.

## 4. §8.2 structural fix (specified, NOT implemented — G3)

`EmitterRegistry` + `KindBinding` (in `lib/src/emit/widget_emitter.dart`):
one entry declares render path + emit path + `correctnessRules` +
`needsModel`. A kind that cannot do both does not enter. `driftKinds`
(bound kinds without a real emitter) is the machine-readable drift set;
the drift guard asserts it empty. G3 populates bindings for all kinds
after F lands — explicitly not 28/10 more hand functions.

## 5. Drift status (§4.3): spec's 28-kind gap is CLOSED; a new 10-kind gap is open

- Spec's 28 (`phone_input` … `repeated_animation_builder`): **all 28 now
  have real `case` + `_bundleX` bodies** (added by Track FF2 commit
  `4490a587`). Verified by enumeration: 97 unique `_bundleBody` cases
  include every one of the 28. The drift the spec measured at `0c15e1a6`
  no longer exists in that form.
- **New gap (G3 scope): 10 registry-only canvas-ready kinds render on
  canvas but export as `Text` placeholders** (`_bundlePlaceholderKinds`):
  chip, alert, circular_progress_indicator, linear_progress_indicator,
  triple_dots, dot_indicator, empty_state, code_snippet, number_ticker,
  text_area. They render via the U1 registry fallback
  (`_buildRegistryFallback` in `component_catalog.dart`) with real
  `build<Kind>Entry` builders — the same two-lists drift shape as §4.3,
  smaller (28→10) and relocated to the registry seam. G3 closes it via §8.2.
- `canvas_app/test/gen_registry_drift_test.dart`: **4/4 PASS at HEAD**
  (guards registry↔generator drift, 96 bridges + 10 bare + row + 1
  `navigation_bar` frozen-track exemption = 108 ready; the exemption still
  needs its one-line `_bridgeKinds` fix before the next regen).

## 6. New files (G1 allowlist only — zero edits to existing emitters)

- `canvas_core/lib/src/emit/emit_context.dart` — `EmitContext`,
  `ImportCollector`, `NameAllocator`, `ResponsiveTier`, `EmitNodeFn`
- `canvas_core/lib/src/emit/tagged_value.dart` — sealed `TaggedValue` + 12
  subtypes + collapse rules
- `canvas_core/lib/src/emit/widget_emitter.dart` — `WidgetEmitter`,
  `EmitterRegistry`, `KindBinding` (§8.2 shape), `placeholderFor`
- `canvas_core/lib/src/emit/project_writer.dart` — `out/` shells,
  `needsModel`/`kStatefulKinds`, `responsiveLeaf`, slug/class/path helpers
- `canvas_core/test/g1_contract_test.dart` — 26 tests, all passing
- `canvas/docs/BUILD_G1_DESIGN.md` — this file
- `canvas_core/pubspec.yaml` — deps only (see §7). Barrel exports for
  `src/emit/` deferred to G4 (file outside G1 allowlist); G1 test imports
  `src/` paths directly.

## 7. Pubspec decision: ADDED (low-risk, verified)

`code_builder: ^4.10.0` + `dart_style: ^2.3.6` added; `flutter pub get`
succeeded (network OK, cache held both). Resolved: **code_builder 4.12.0,
dart_style 2.3.6**. Risk was nil by construction: no G1 file imports either
package (G2 does), so resolution cannot break compilation; `flutter analyze`
re-verified after.

## 8. Golden-first constraint (§6.5) — binding on G2/G3

No `.expected.dart` in G1 is generated from any emitter (G1 has no kind
emitters). When G2 migrates `_bundleX` → `WidgetEmitter`, each golden MUST
be hand-written first (starting point: the §7.5 primitives tree → §15
`primitives_screen.json` / `.expected.dart`, owned by Track F), then the
emitter made to match. Byte-exactness is meaningful only because output
passes through `dart_style` (= `dart format`), so goldens are stored
post-format. Any golden produced by running the emitter is void.

## 9. Handoff plan

- **G2 — code_builder migration** (after F lands): retype
  `WidgetEmitter.emit` → `Expression`, migrate 97 `_bundleX` 1:1, route
  tagged colors through `themeExpr` (rule 7 above), page bodies via
  registry, goldens hand-written-first per §6.5 covering F's 10 primitives
  (0/1/2 children each). Needs: `flutter pub get` already done — no new deps.
- **G3 — close the 10-kind gap structurally**: populate `KindBinding` for
  all kinds (incl. the 10 in §5 + F's primitives), assert
  `driftKinds.isEmpty` in the drift guard, remove `_bundlePlaceholderKinds`.
  `text_area` model/controller wiring verified here.
- **G4 — demote `codegen_single`**: optional "inline sources
  (experimental)" export mode, barrel-export `src/emit/` from
  `canvas_core.dart`, full gates (§11.3–7 incl. `dart format
  --set-exit-if-changed` + `flutter build web` on generated output).
