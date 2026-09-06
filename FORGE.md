# Forge Redesign (Track Y0) — editor-chrome spec

Status: Y0 spec only. No code changes. Every number below is
eyeball-measured from the Forge reference description and marked
APPROXIMATE — the measured-spec rule in `editor_tokens.dart` (re-measure
against a live reference, never eyeball-promote) still applies at build
time; Y-waves re-measure and replace these with pinned values.

Intent: reskin the editor chrome to the Forge look (light, off-white
dotted canvas, white cards, blue accent, dark navy phone) while keeping
every behavior the current shell owns: store + undo, DnD + selection,
responsive tiers, split chrome/components themes, export/audit logic.
Chrome visuals/layout are REBUILT; document logic is KEPT.

Read first: `canvas/COMPOSITION.md` (nesting model — untouched by this
track), `canvas_app/lib/main.dart` (shell), `canvas_app/lib/ui/
editor_tokens.dart` (measured-spec rule + `EditorColors` dark/light).

## 1. Element-by-element mapping

`KEEP` = logic/behavior reused verbatim. `REBUILD` = visuals/layout
rewritten. Files are the current owners; §5 assigns each to one wave.

| # | Reference element | Our widget(s) / file(s) | Keep vs rebuild |
|---|---|---|---|
| 1a | Top bar (white): logo + "Forge" | NEW `ui/forge_topbar.dart` (Y2) | REBUILD (new chrome; no current topbar exists) |
| 1b | Project pill (green dot + title) | `forge_topbar.dart` reads `doc.meta.title` | KEEP data (meta), REBUILD pill |
| 1c | Screen tabs segmented (Home active dark pill, + add, × delete) | `forge_topbar.dart` over `store.screens`; ops `addScreen`/`renameScreen`/`deleteScreen` in `canvas/canvas_store.dart` | KEEP store ops (all exist, undoable); REBUILD tab UI |
| 1d | Undo/redo icon buttons | Same; `store.canUndo/canRedo/undo/redo` | KEEP logic; REBUILD placement (toolbar → topbar) |
| 1e | Black Preview button | Same; `PreviewPlayer` in `ui/preview_player.dart`, `DevicePicker` in `ui/device_picker.dart` | KEEP both files untouched; REBUILD button skin |
| 1f | Blue "Export Flutter" button | Same; `showExportDialog` in `ui/export_panel.dart` | KEEP dialog + builders untouched; REBUILD button skin |
| 1g | Open (folder) action | Same; `showOpenDialog` in `ui/open_dialog.dart` | KEEP file untouched; survives as a small topbar icon (deviation from reference — no data loss) |
| 2a | Library panel: eyebrow/title/helper/search | `ui/parts_palette.dart` (Y3 rewrite) | KEEP `Draggable<String>` kind payloads, `registryMatchesQuery`, collapse/search state; REBUILD tile cards |
| 2b | Tile cards (icon chip + name + desc + dashed "+ Add") | Same file; name = humanized kind, desc = `RegistryEntry.label` (the manifest description — there is no separate short-desc field; verified in `component_registry.dart`) | REBUILD card; tap-to-add is NEW (see §4) |
| 2c | LAYOUT / MATERIAL / DATA sections | Display-only mapping over `kRegistrySectionOrder` (8 registry sections) + search filter, inside `parts_palette.dart` | REBUILD grouping; KEEP registry source + order |
| 2d | Icon rail (52px) | `ui/icon_rail.dart` — DELETED at cutover (Y6) | REBUILD (remove). Rehost: Layers → "Library \| Layers" pills in the left column (Y3, imports `layers_panel.dart` untouched); Color/Shape/Type/Motion panels → "Theme" disclosure at the Library bottom (Y3 mounts `theme_panels.dart` untouched); AI/Lang placeholders dropped (AI = placeholder only today; Prompt lives in the right tabs) |
| 3a | Breadcrumb "Project › Home › Card · card_1" | NEW `ui/forge_canvas_header.dart` (Y4); trail = `meta.title` › screen name › `<Kind> · <id>` (the `<Kind> · <id>` idiom already exists in the inspector `_nodeShortLabel`) | REBUILD (new). Screen click → existing `onSelectScreen`; node click → existing `onSelectNode`. No store change |
| 3b | Zoom controls (- 100% +) + grid icon | `ui/zoom_controls.dart` (Y4 restyle, same API) embedded in the header; grid icon toggles snap guides (new `showGuides` param on `DesignCanvas`, defaults on — guides/`kSnapThreshold` logic KEPT) | KEEP zoom math (`clampZoom`, wheel/pinch in `design_canvas.dart`); REBUILD skin + position (bottom-right → header row) |
| 3c | Hint pill ("Drop widgets… · click a block… · drag the corner…") | Dismissible pill at the canvas top, inside `ui/design_canvas.dart` (Y4) | REBUILD (new; copy from reference verbatim) |
| 3d | Dotted canvas background | `design_canvas.dart` background → dot painter (CustomPainter, token color) | REBUILD background; KEEP pan/zoom/gesture code |
| 3e | iPhone frame (Dynamic Island, 9:41, home indicator) | `ui/phone_frame.dart` (Y4): geometry tokens KEPT verbatim; status bar (`_StatusBar`, 9:41 + glyphs) and home indicator already exist — VERIFIED, no Dynamic Island exists today | KEEP frame + status + indicator; ADD island overlay only (see §3) |
| 3f | Floating black toolbar (up/down/duplicate) | `ui/canvas_toolbar.dart` (Y4 rewrite): shows only when a node is selected; up/down = `reorderNode` ±1 within the node's group; duplicate = `duplicateNode` | KEEP store ops; REBUILD widget (today's always-visible toolbar is replaced; its actions move to the topbar/header) |
| 3g | Per-screen device buttons + screen label row | `ScreenLabel` in `phone_frame.dart`: device strip REUSED inside the Forge header (compact); name/dims text REPLACED by the breadcrumb trail | KEEP `specForScreenDevice`/`setScreenDevice`; REBUILD placement |
| 4a | Right tabs "Design \| Code" (+ kept Prompt, Audit) | `ui/right_aside.dart` (Y5): header becomes Design \| Code \| Prompt \| Audit pills. DEVIATION from the 2-pill reference, justified: Prompt/Audit have no other home and must not be lost. Auto-switch rule KEPT (selection → Design, else Prompt; Audit manual-only) | KEEP relay + auto-switch + `PromptPanel`/`AuditPanel` files; REBUILD header (2→4 pills) |
| 4b | Code tab (NEW, read-only code-peek) | NEW `ui/code_peek.dart` (Y5) calling `buildExportSingleFile(doc)` from `ui/export_panel.dart` (import only — that file is untouched) | NEW widget; KEEP generator. v1 = whole-doc code + selection header; selection-scoped emission is follow-up (§4) |
| 4c | SELECTED card ("card · card_1", TITLE, DESCRIPTION) | `ui/inspector_panel.dart` (Y5 restyle): kind·id header + existing `title`/`description` prop editors (verified: the only `card` content props in `props_schema.dart`) | KEEP editors/store paths (`patchItem`/`clearItemProps`); REBUILD card chrome |
| 4d | SURFACE Dark/Light, RADIUS / PADDING sliders | NO corresponding props exist (verified: `card` schema = `title`, `description`, `showFooter` only) → FOLLOW-UP, not Y2–Y6 (§4). Sliders reuse the `PropNumberEditor` ranged-slider pattern (kit `Slider`, verified in `property_editors.dart`) once props land | Spec as follow-up with exact diff |
| 4e | Duplicate (outline) + Delete (red) | Store `duplicateNode`/`deleteNode` + shell `_deleteSelection`/duplicate wiring all exist. `RightAside`/`InspectorPanel` gain `onDuplicate`/`onDelete` callbacks (Y5); shell passes them (Y6) | KEEP logic; REPOSITION into the SELECTED card |
| 5 | Demo content in phone (Wander app) | Track Y1 seed doc (other agent). Contract for Y1: screens named Home/Search/Saved; a `card` node id `card_1` with title "Kyoto in autumn"; light component theme. This spec does not design the seed | Referenced only |

## 2. Theme strategy — DECISION: extend `EditorColors`, do not replace

- **Extend, additively.** `canvas_app/test/light_theme_test.dart` pins the
  existing `EditorColors.light` hexes, and `theme_apply_test.dart` /
  `layers_multiselect_test.dart` assert against `light.surface` /
  `light.toolbarActive`. Changing any existing value breaks pinned tests
  for zero behavioral gain: the current light tokens are already
  near-white (`surface` 0xFFFEF7FF, `surfaceContainer` 0xFFF7F2FA), which
  IS the Forge white-card look. Y2 adds three fields with light+dark
  values and leaves every existing field/value untouched:
  `accent` (APPROXIMATE light `#2563EB`; dark a lighter blue
  APPROXIMATE `#60A5FA`), `onAccent` (white both modes), `danger`
  (APPROXIMATE `#DC2626` light / `#F87171` dark).
- **Dark mode keeps working.** Chrome selection (`effectiveChrome`,
  `theme.chrome`, `ColorPanel` follow/override) is untouched; new fields
  carry dark values so rebuilt chrome renders correctly under both. The
  empty-doc default (`dark: true` in `CanvasStore.emptyDoc`) is NOT
  flipped — flipping it would churn autosave/persistence tests. Forge
  light is experienced via light-themed docs: the Y1 seed ships light,
  and the Theme disclosure flips any doc. Consequence recorded in §6.
- **Bezel keeps its measured token** (`EditorColors.bezel`; likely pinned
  with the rest of light). Forge navy is approximated by restyling around
  it, not by changing it — deviation noted, revisit after re-measure.
- **Dotted canvas:** dots use `onSurfaceVariant` at low alpha
  (`withValues(alpha: …)`, the existing idiom) — no new token. Dot grid:
  spacing APPROXIMATE ~18px, radius APPROXIMATE ~1px, painted by a
  `CustomPainter` in `design_canvas.dart` (no kit dotted-box exists; same
  exception class as the existing `_DashedOutline`).
- **Dogfood rule for new chrome:** kit widgets via `shadcn_ui.dart` first
  — VERIFIED available: `Switch`, `Select` (+ popup idiom), `Slider`
  (renders inside `PropNumberEditor` when `min`+`max` are present),
  `OutlineButton`/`PrimaryButton`/`GhostButton`/`TextButton`, `Card`,
  badges, `TextField`, tooltips. Custom paint is allowed ONLY for the
  dots and the dashed "+ Add" border (documented exceptions, existing
  idioms). Screen content stays exempt per the rule in `phone_frame.dart`.

## 3. Layout numbers — ALL APPROXIMATE, re-measure in build

Shell at 1440×900. Parenthesized current measured values are for
traceability only; do not mix them into the new build.

- Topbar: height APPROXIMATE ~64px, white (`surface`), bottom hairline
  border. Left: black rounded-square logo APPROXIMATE ~28px, radius
  APPROXIMATE ~8px + "Forge" 15/600. Project pill: full-radius pill,
  green dot APPROXIMATE ~8px (`#22C55E` APPROXIMATE) + title 13/500.
  Screen tabs: segmented control, inactive = transparent, active = near-
  black pill (APPROXIMATE `#111827`) with white text; tab height
  APPROXIMATE ~32px, radius APPROXIMATE ~16px; "+" add-tab button and "×"
  on the active tab. Undo/redo 32px icon buttons. Preview = black pill
  button (white text + play icon). Export Flutter = accent-blue pill
  button (white text + download icon). Gaps APPROXIMATE 8–12px.
- Left Library: width APPROXIMATE ~300px (replaces measured 320), white,
  full height below topbar. Padding APPROXIMATE 16px. Eyebrow 11/700
  letterspaced ("WIDGETS · FLUTTER" — static text), title "Library"
  17/700, helper 13/400 muted, search field height APPROXIMATE ~36px.
  "Library | Layers" pills at top (see §1-2d). Section headers 12/700
  muted. Tile grid 2-col, gap APPROXIMATE 8px; tile APPROXIMATE
  ~130×~110px, white card, radius APPROXIMATE 12px, hairline border:
  icon chip APPROXIMATE ~32px rounded tinted square, name 13/600, desc
  12/400 muted 1-line ellipsis, dashed "+ Add" full-width button at the
  tile bottom. "Theme" disclosure pinned at the panel bottom.
- Canvas header row: height APPROXIMATE ~48px, transparent over the dots.
  Breadcrumb 13/400 muted with the screen name 13/600 dark ("Project ›
  **Home** › Card · card_1"). Zoom pill: white card, radius full, "-"
  label "100%" "+" + grid icon, each APPROXIMATE 32px.
- Hint pill: centered below header, dark pill (APPROXIMATE `#111827`,
  white 13/400 text), radius full, padding APPROXIMATE 8×16px,
  dismissible (×); reappears on restart (no persistence — deliberate).
- Phone: KEEP ALL geometry tokens verbatim (`phoneOuterWidth` 343,
  `phoneOuterHeight` 725, `phoneBezel` 7.5 budget, `_kFrameBezel` 4,
  radii 44/36, `_kStatusBarHeight` 28, home-indicator pill 134×5).
  ADD Dynamic Island only: black pill APPROXIMATE ~110×~28px, centered in
  the status strip (does not shift the status-bar reserve or any drop
  math — pure overlay, pointer-transparent like the status bar).
- Inspector: width KEEP 320 (`promptPanelWidth` — reference-likeness not
  worth the shell churn). SELECTED card: white, radius APPROXIMATE 12px,
  padding APPROXIMATE 12–16px, gaps APPROXIMATE 8px (existing
  `_kInspectorGap` rhythm kept). Header "card · card_1" 13/600. Field
  labels 11/700 muted caps (TITLE / DESCRIPTION / SURFACE / RADIUS /
  PADDING). Duplicate = outline button, Delete = red-text button, side
  by side at the card bottom. Design/Code/Prompt/Audit pills reuse the
  existing tab-segment tokens (outer 20 / inner 8 / gap 3).
- Selection toolbar: black pill (APPROXIMATE `#111827`, white icons),
  radius full, three 32px targets (up / down / duplicate); shell-centered
  horizontally near the canvas bottom (above zoom). Anchoring to the
  selection is follow-up (§6).

## 4. Feature deltas (redesign-introduced, over current behavior)

1. **Screen tabs in topbar** (Y2). Store already owns everything:
   `screens` (relay rebuilds tabs live), `addScreen()` (+ button),
   `renameScreen()` (inline double-click rename), `deleteScreen()`
   (× on active tab; the dangling-action refusal + SnackBar path is
   KEPT). Shell keeps owning the selected-screen id; tabs take
   `screens + selectedId + callbacks` (stateless vs the store → widget-
   testable without a shell).
2. **Breadcrumb selection trail** (Y4). Pure view over shell state:
   `meta.title › screen › kind·id`. Clicks reuse `onSelectScreen` /
   `onSelectNode`. The inspector's `_breadcrumbChain`/`_nodeShortLabel`
   logic is the reference implementation; the header takes prebuilt
   trail data (no import from `inspector_panel.dart`).
3. **Design/Code tabs + read-only code-peek** (Y5). Code tab mounts
   `code_peek.dart`: header shows the selection (`card · card_1`) or
   "No selection"; body = `buildExportSingleFile(doc)` in a read-only
   kit surface + Copy button (clipboard sink idiom from `export_panel`)
   + Refresh button. Regenerates on tab-open/selection-change ONLY
   (never per keystroke — full-file codegen on every inspector edit
   would jank). v1 is whole-doc; per-selection scoping is follow-up.
4. **RADIUS/PADDING/SURFACE editors → FOLLOW-UP (not Y2–Y6).** Verified
   absent: `card` has no radius/padding/surface props anywhere
   (`props_schema.dart`, catalog defaults, codegen). The follow-up diff
   is: add `PropSpec`s (number w/ min/max/step so the kit-Slider branch
   renders) + catalog builder support + single/bundle codegen emission +
   goldens. Y5 must NOT invent new props or hand-rolled sliders. The
   row-`gap` stepper+slider stays the in-tree pattern reference.
5. **Duplicate/Delete reposition** (Y5+Y6). No new ops: `duplicateNode`
   (subtree clone, +16 offset — keep) / `deleteNode` (cascade — keep)
   and the shell's whole-set delete + screen-delete-with-refusal stay
   the single implementations; the SELECTED card just calls them.
6. **Export Flutter → existing dialog; Preview → existing player** (Y2
   buttons, Y6 wiring). No changes to `export_panel.dart`,
   `preview_player.dart`, `device_picker.dart`, `open_dialog.dart`.
   The reference's bottom demo tab bar (Home/Search/Saved/You) is Y1
   seed content, not chrome.

## 5. Build plan — Y1 (seed) + Y2–Y6 (chrome), disjoint allowlists

Rules for every wave: no `flutter pub get`; chrome reads tokens/type
only (no hex literals — the analyzer/tests pin this idiom); kit-first
(§2); `flutter analyze` + `flutter test` green before handoff; new tests
in `canvas_app/test/` named per wave. A file appears in at most one
wave's allowlist. Shared untouched files (no wave may edit):
`canvas_store.dart`, `props_schema.dart`, `component_catalog.dart`,
`component_registry.dart`, `preview_player.dart`, `device_picker.dart`,
`open_dialog.dart`, `export_panel.dart`, `prompt_panel.dart`,
`layers_panel.dart`, `theme_panels.dart`, persistence, codegen.

- **Y1 — demo seed (OTHER AGENT, internals not spec'd here).** Contract:
  screens Home/Search/Saved; node `card_1` (`card`, title "Kyoto in
  autumn"); light component theme; includes a bottom tab bar in content.
  Must stay green: seed/template tests.
- **Y2 — topbar + tabs + Forge tokens.** ALLOWLIST:
  `canvas_app/lib/ui/editor_tokens.dart` (ADDITIVE fields only:
  `accent`/`onAccent`/`danger` + docs; no existing value touched),
  NEW `canvas_app/lib/ui/forge_topbar.dart` (logo, project pill, screen
  tabs w/ select+add+rename+delete, undo/redo, Open icon, Preview,
  Export Flutter; pure props, no store import),
  NEW `canvas_app/test/forge_topbar_test.dart`.
  Tests: tabs render from props; select/add/rename/delete callbacks;
  undo/redo disabled states; Preview/Export fire. Must stay green: full
   suite (esp. `light_theme_test.dart` — proves no token was disturbed).
- **Y3 — Library panel.** ALLOWLIST:
  `canvas_app/lib/ui/parts_palette.dart` (rewrite: header copy, search
  KEEP, Library|Layers pills mounting `LayersPanel`, Forge section
  mapping, new tile cards w/ desc + dashed +Add; optional `store`
  param for tap-to-add → `addNode` on the current screen root; DnD
  payloads unchanged),
  `canvas_app/test/parts_palette_test.dart` (+ any `*palette*` test —
  Y3 owns updating them to the new chrome).
  Tests: search filter still word-start; tiles draggable by kind; +Add
  inserts on the target screen; Layers pill swaps content; Theme
  disclosure mounts the four panels. Must stay green: DnD/drop-target
  tests (payload contract unchanged).
- **Y4 — canvas area.** ALLOWLIST:
  `canvas_app/lib/ui/design_canvas.dart` (dot background, hint pill,
  `showGuides` param, drop ScreenLabel row),
  `canvas_app/lib/ui/canvas_toolbar.dart` (rewrite → black selection
  toolbar: up/down/duplicate, `selectedNodeId`-gated),
  `canvas_app/lib/ui/zoom_controls.dart` (light-pill restyle, same API),
  `canvas_app/lib/ui/phone_frame.dart` (Dynamic Island overlay ONLY +
  keep `ScreenLabel` widget for header reuse; no geometry-token edits),
  NEW `canvas_app/lib/ui/forge_canvas_header.dart` (breadcrumb + zoom +
  grid + compact device strip),
  related `canvas_app/test/*` files for exactly these widgets.
  Tests: toolbar hidden without selection; up/down reorder via
  `reorderNode`; zoom API unchanged; island is pointer-transparent;
  guides toggle. Must stay green: hit-test/DnD/resize/responsive tests
  (geometry untouched by construction).
- **Y5 — inspector + code-peek.** ALLOWLIST:
  `canvas_app/lib/ui/right_aside.dart` (4-pill header, same auto-switch;
  new `onDuplicate`/`onDelete` pass-through),
  `canvas_app/lib/ui/inspector_panel.dart` (SELECTED card restyle,
  header kind·id, existing editors in order, Duplicate/Delete row),
  NEW `canvas_app/lib/ui/code_peek.dart` (read-only + Copy + Refresh),
  related `canvas_app/test/*` files for exactly these widgets.
  Tests: header pills switch; empty-selection hint; editors still hit
  `patchItem`; Duplicate/Delete callbacks fire with the node id;
  code-peek renders generator output + copies. Must stay green:
  inspector/audit/binding/step-editor tests (no editor logic changes).
- **Y6 — cutover (single flag day).** ALLOWLIST:
  `canvas_app/lib/main.dart` (mount topbar/header/library/toolbar/
  inspector; widths 300/canvas/320; remove rail + old toolbar/zoom
  mounts; wire duplicate/delete/screen-tab/selection callbacks),
  `canvas_app/lib/ui/icon_rail.dart` (DELETE), shell-level tests.
  DECISIONS (final): light is NOT forced — chrome follows the doc theme
  as today (seed ships light; toggle in Theme disclosure); old dark
  values are KEPT, never removed; no parallel chrome, no flag — one
  commit swaps it. Tests: full `flutter test` + `flutter analyze`
  (root + playground) + gallery smoke (`rsync` + `flutter run -d
  chrome` per AGENTS.md) + re-measure pass filing number corrections.

## 6. Risks

1. **Eyeball numbers.** Every §3 value is APPROXIMATE from a prose
   description. Mitigation: Y-waves treat them as starting points, then
   re-measure against the reference and update this file; layout tests
   assert structure/callbacks, not pixels.
2. **Kit coverage for new chrome.** Verified kit-first pieces: Switch,
   Select, Slider (ranged numbers), buttons, Card, TextField, tooltips.
   Known gaps: dashed "+ Add" border and dot background need custom
   paint (accepted exceptions, existing idioms). If the tile desc or
   pill styles need more, Y3/Y5 add tokens — never hardcode hex.
3. **Tile descriptions.** `RegistryEntry` has label-but-no-blurb; Forge
   tiles show `label` (manifest description) as the desc line. If any
   label is too long, Y3 truncates with ellipsis (no registry edits —
   that file is GENERATED).
4. **Code-peek cost.** Whole-doc single-file generation per keystroke
   would jank — Y5 regenerates on open/selection-change + manual
   Refresh (spec'd in §4). Selection-scoped emission is follow-up.
5. **Service-worker staleness for testers.** Canvas ships web; after Y6,
   testers must hard-refresh (or bump the SW cache) or they will review
   the OLD dark chrome against the new spec. Y6 notes the refresh step
   in its handoff.
6. **Fresh-start dark default.** `emptyDoc` stays `dark: true` (§2), so a
   brand-new user sees dark chrome until they pick a light doc/theme.
   Accepted: flipping the default churns persistence tests; revisit if
   user testing flags it.
7. **Selection-toolbar position.** Y4 centers it (no anchor math); it may
   overlap phone content on small viewports — anchoring to the selection
   is follow-up, not a Y4 stretch goal.
8. **No concurrent-agent conflicts.** This file is the coordination
   point: allowlists are disjoint by construction (§5); violating them
   (e.g. touching `main.dart` before Y6) is the top process risk.
