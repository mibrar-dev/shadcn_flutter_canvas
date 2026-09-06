# Composition (Track C) — real nesting

Status: C0 design + core helpers. Renders, DnD, inspector, and codegen
recursion land in C1–C4 (see §8–§9).

Intent (verbatim): Flutter principle — everything is a widget and every
child can be a widget. A card must be able to contain a text field, a
button, anything; and vice versa for every other widget. No more
props-only boxes: real nesting.

## 1. Nesting model

`parentId` generalizes beyond rows: **any node may parent children**.
No schema change — `parentId` is already `String?` (`missing key → null`,
old behavior). `isRow` keeps exactly one meaning: horizontal layout.

Layout semantics (screen root stays an implicit vertical `Column`):

| Parent | Layout | Rule |
|---|---|---|
| Screen root (`parentId == null`) | Vertical `Column`, `kFlowScreenGap` separators | Unchanged |
| Row (`isRow == true`) | Horizontal `Row` of children, own `gap` separators | Unchanged, may nest under any node incl. other rows |
| Container (`isRow == false`, kind in §2) | Children stack **INSIDE** the parent's component chrome (its documented child slot), vertical, `kFlowScreenGap` separators | New |
| Leaf (`isRow == false`, kind NOT in §2) with children | Fallback `Column([ownWidget, ...children])` — children stack **BELOW** the parent's own widget | New |

Decision: containers nest inside chrome; non-container children stack
below rather than being dropped or refused. Justification: (a) Flutter
principle — any widget can parent any widget, so the model never forbids
an edge; (b) honesty — nodes are never silently dropped (same principle
as codegen treating dangling-`parentId` nodes as roots); (c) migration —
childless nodes (all existing docs) take none of the new branches, so
they render/export byte-identically; (d) UX gating stays out of the
model — DnD/inspector (C2) steer users toward containers while the model
accepts everything.

Rows under non-rows are allowed (a row inside a card is a horizontal
strip inside the card). Non-row children of rows are allowed (today's
only nesting). `expand`/`flex` keep working for row children at any
depth; container children ignore them (vertical stack, like root).

## 2. Container determination — explicit per-kind set

No name heuristics (never `kind.contains('card')`). A kind is a
container **iff** it is listed here. Initial list (10 kinds + the `row`
pseudo-kind), each with its child slot:

| Kind | Kit slot children splice into |
|---|---|
| `card` | Inner `Column` after description, before footer action |
| `outlined_container` | `OutlinedContainer.child` (`Column([label, ...children])`) |
| `scaffold` | Body `Padding` column under the body text |
| `dialog` | `ModalContainer` column after message, before action row |
| `alert_dialog` | Content area after message, before actions |
| `drawer` | Panel column after content text |
| `form` | Inner `Column` after the field layout, before submit |
| `hidden` | `Hidden.child` (`Column([label, ...children])`) |
| `clickable` | `Clickable.child` (`Column([label, ...children])`) |
| `scrollbar` | Box column under the label |
| `row` (pseudo-kind, `isRow == true`) | Structural `Row` (existing semantics) |

The other 58 catalog kinds are leaves: children use the §1 below-fallback.
Deliberately excluded for now (structured/ambiguous slots, no generic
single-`child`/body): `accordion`, `tabs`/`tab_container`/`tab_list`/
`tab_pane`, `steps`, `timeline`, `table`, `menu`/`menubar`/`popup`/
`popover`/`dropdown_menu`/`context_menu`/`hover_card`/`command`,
`collapsible`, `select`, `radio_group`, `tooltip` (trigger-vs-tip
ambiguity), `chat`, `toast`, `card_image`, `basic`, `form_field`,
`validated`, `formatted_input`, pickers, sliders, and all display kinds.

Rule for classifying future kinds — promote a kind only when ALL hold:

1. Its kit constructor exposes a generic single-`child` or body slot
   rendering arbitrary widgets (verified by reading the kit ctor +
   preview — never by kind-name substring).
2. The promotion names the exact child slot and the prop interplay
   (header/label stays vs. replaced, separator used).
3. Render + codegen goldens cover 0/1/2 children for the kind.

## 2.1 Layout-primitive container set (Track F)

The ten §7.1 layout primitives join the §2 container set. They are the
purest cases of the promotion rule above: each exposes a generic child
slot by construction (they ARE the Flutter layout widgets), and each
carries render + codegen goldens covering 0/1/2 children (see
`canvas_core/test/fixtures/primitives_screen.*` and the `f3_*` golden
tests).

KIT-FIRST EXEMPTION (BUILD_SPEC §7.1): primitives are raw Flutter
(`Container`, `Column`), not kit widgets. The `shadcn_ui.dart` kit-first
rule does NOT apply to them (also recorded on `SizeMode` in
`canvas_core/lib/src/screen_doc.dart`).

| Kind | Child slot children splice into |
|---|---|
| `container` | Single `child` (0 kids → omitted; 2+ kids → `Column` wrap) |
| `column` | Multi `children` (`gap` separators) |
| `row` | Multi `children` (`gap` separators; item-kind form — the `isRow` structural form keeps working unchanged) |
| `stack` | Multi `children` (plain stack children) |
| `padding` | Single `child` (same 0/1/2+ rule as `container`) |
| `center` | Single `child` |
| `align` | Single `child` |
| `expanded` | Single `child` (emits the `Expanded` wrapper itself) |
| `sized_box` | Single `child` (0 kids + no dims → `SizedBox.shrink()`) |
| `spacer` | Leaf — no slot (`Spacer`, takes no child) |

## 3. Builder contract change (app-side, documented — NOT a core type)

`canvas_core` stays Flutter-free, so this contract lives in
`canvas_app/lib/canvas/component_catalog.dart`:

```dart
typedef NodeBuilder = Widget Function(
  Map<String, dynamic> props, [
  List<Widget> children,
]);
```

Optional positional `children` (default `const []`): all 68 existing
builders keep compiling unmodified; C1 migrates the §2 container
builders to consume it. Builders that don't (yet) take children ignore
the arg — their nodes' children render via the §1 below-fallback, never
inside chrome. Component `props` stay stringly-typed; `children` are
already-built widgets (builders never look up nodes).

## 4. DnD-into-container UX + inspector affordances (SPEC ONLY — C2)

- Hit resolution generalizes `_flowHit`: the deepest container-or-row
  under the pointer wins (measured rects, smallest-area tiebreak —
  today's row logic with the `isRow` filter widened to
  containers-or-rows). Empty containers stay hit-testable via a min-64px
  `Drop here` placeholder (today's `_EmptyRowPlaceholder` idiom).
- Hover visuals: inner wash (`railActive` 0.25) on the target container +
  index line along the container's axis (reuse `flowInsertionIndex` /
  `_boundary`: vertical for containers, horizontal for rows).
- Drop lands in one commit: `parentId = target`, index within the
  target's child group. New-node drops cannot cycle (no descendants);
  reparent moves use `isAncestorOf` to refuse cycles and refuse
  cross-screen parents (same-screen only — `screenId` never changes on
  move, matching `reorderNode`).
- Inspector: breadcrumb chain (root › … › parent › node via `parentId`
  walk, cycle-safe); Parent picker listing same-screen
  container-or-row nodes minus self + descendants (`isAncestorOf`
  filter) plus `Screen root`; `Move to root` / `Move into` actions;
  container nodes show child count + child order list (up/down via the
  existing `reorderNode`, which already groups by equal `parentId`).
- Row-only fields (`gap`/`mainAxis`/`crossAxis`) stay on rows; `expand`/
  `flex` stay child-role fields.

## 5. Codegen recursion rule (C3)

Both exporters walk the tree recursively with identical structure:

- Container → parent widget expression with child expressions spliced
  into the §2 slot; row → `Row` (existing emitters, nested rows
  included); leaf-with-children → `Column([own, ...children])`.
- Same tier/action semantics applied recursively at every level: each
  node independently gets a `LayoutBuilder` tier wrapper when responsive
  (flex role stays outside the conditional, per
  `_writeResponsiveRowChild`); every item keeps its `// taps -> …`
  comment + `GestureDetector` navigation; hidden-on-all prunes the whole
  subtree to `SizedBox.shrink()`; unknown kinds keep the
  `TODO(canvas)` comment + placeholder — never a crash.
- Deterministic doc order everywhere; separators `SizedBox(width: gap)`
  in rows, `SizedBox(height: kFlowScreenGap)` in vertical stacks.
- Migration: childless docs emit today's output exactly (the recursion
  bottoms out to the current leaf/row paths).

## 6. Migration

- No schema change: `parentId` already expresses arbitrary nesting;
  container-ness is app-side knowledge (§2), not persisted state. Proven
  unnecessary: nothing new needs storing (layout role = `isRow` + kind,
  order = doc order, children = `parentId` edges).
- Existing docs (childless nodes, row-only nesting) render/export
  byte-identically: every new branch requires a non-row node WITH
  children, which old docs have none of.
- Row semantics preserved exactly: `isRow` still the sole horizontal
  flag; `gap`/`mainAxis`/`crossAxis`/`expand`/`flex` meanings unchanged.
- Store already generic: `deleteNode` cascades any depth,
  `duplicateNode` clones whole subtrees, `reorderNode` groups by equal
  `parentId` — all work for container children with no changes.

## 7. Test plan (implementation waves)

- C0 (this track): `canvas_core/test/composition_test.dart` — helpers,
  cycle `A→B→A` refused, self-parent, unknown parent, cross-screen,
  deep chains, empty docs, stable message strings.
- C1 render: card + 2 children renders inside `Card` chrome; leaf
  fallback stacks below; row-in-card horizontal; hidden container prunes
  subtree; childless widget goldens byte-identical.
- C2 DnD/inspector: drop into container sets `parentId` + index;
  reparent refuses cycles (`isAncestorOf`) and cross-screen; parent
  picker excludes self + descendants; reorder inside containers.
- C3 codegen: single + bundle goldens for nested card/dialog/form with
  depth-2 tap actions and a responsive node at depth; childless goldens
  byte-identical.
- C4 seed demo + matrix: seed doc `card{input,button}` + friends;
  matrix over container kinds × 0/1/2 children.

## 8. NON-GOALS (C0 does NOT do these — C1–C4 do)

- Render recursion in `phone_frame.dart` / preview player.
- Migrating builders to `children` params (only the typedef is
  documented here).
- DnD targeting, inspector UI, parent/move affordances.
- Codegen recursion in `codegen_single.dart` / `codegen_bundle.dart`.
- Seed demo docs, container matrix tests.
- Schema changes, store changes, AI contract changes.

## 9. C1–C4 work split (dispatchable allowlists)

- C1 render recursion — `canvas_app/lib/canvas/component_catalog.dart`
  (typedef + 10 container builders), `canvas_app/lib/ui/phone_frame.dart`
  (`ScreenSurface` flow/row/leaf builders), `canvas_app/lib/ui/
  preview_player.dart` (visible-subtree cascade),
  `canvas_app/test/*_test.dart` (new + touched render tests).
- C2 DnD + inspector — `canvas_app/lib/ui/phone_frame.dart` (hit test),
  `canvas_app/lib/ui/design_canvas.dart` (`onAccept` parent/index),
  `canvas_app/lib/canvas/canvas_store.dart` (reparent/move methods),
  `canvas_app/lib/ui/inspector_panel.dart` + `layers_panel.dart`
  (breadcrumb, parent picker, child order),
  `canvas_app/test/*_test.dart` (new + touched interaction tests).
- C3 codegen recursion — `canvas_core/lib/src/codegen_single.dart`,
  `canvas_core/lib/src/codegen_bundle.dart`,
  `canvas_core/test/codegen_*_test.dart` + fixtures (new + touched
  codegen tests). No model changes.
- C4 seed + matrix — seed/demo docs + fixtures, container matrix test,
  `canvas/COMPOSITION.md` conformance notes. No product-code changes
  except seeds.
