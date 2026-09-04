# Handoff: make `canvas_app` look like m3e-canvas

You are picking up a Flutter web design tool and making its **editor shell**
pixel-match a React reference app. This document is self-contained — you should
not need the prior conversation.

---

## 1. The two apps

| | Reference | This project |
|---|---|---|
| Name | **m3e-canvas** | **canvas_app** ("Shadcn Canvas") |
| Live | https://lnkiai.github.io/m3e-canvas/ | local only |
| Source | https://github.com/lnkiai/m3e-canvas | `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/canvas_app` |
| Stack | Next.js 16 + React 19 + Tailwind | Flutter web |
| Size | ~14,970 lines TS/TSX | ~2,600 lines Dart |
| Parts library | Material 3 Expressive | shadcn (`flutter_shadcn_kit`) |

Clone the reference for study — reading its source beats guessing from
screenshots:

```bash
git clone --depth 1 https://github.com/lnkiai/m3e-canvas.git /tmp/m3e-canvas
```

Key reference files: `app/page.tsx` (3,433 lines — the shell and all state),
`components/PartsPalette.tsx`, `components/Toolbar.tsx`,
`components/Inspector.tsx`, `app/globals.css` (the `.m3-press` / `.m3-tile`
interaction classes).

### ⚠️ Scope boundary — read this before you start

**Replicate the editor chrome, not the parts library.** m3e-canvas is a
Material 3 Expressive tool; canvas_app is a shadcn tool. Its palette contains
shadcn components and its canvas renders real `flutter_shadcn_kit` widgets —
that fidelity is the entire product thesis (see
`lib/canvas/component_catalog.dart` and `tool/embed_sources.dart`: what you see
on canvas is literally the source the user installs).

So "look exactly like the reference" means: **the rail, panels, toolbar, zoom
controls, phone frame, spacing, colors, and interaction feel are identical.**
The tiles inside the palette and the widgets on the canvas stay shadcn. Do not
port Material 3 components in to chase a screenshot — that would break the
export contract.

---

## 2. The measured spec — already captured, do not re-guess

`lib/ui/editor_tokens.dart` holds **every** color, size, radius, gap and text
style, each measured from the live reference at a 1440x900 viewport via
`getComputedStyle`. It is the single source of truth.

**Rule: never hardcode a hex color or a magic number in chrome code.** Read
colors with `EditorTheme.of(context)` and sizes from `EditorMetrics`.

Summary of what is in there:

```
Layout @1440x900   left aside 320 (rail 52 + panel 268) | canvas 800 | right aside 320
Backgrounds        surface #141317 — all three columns share it, NO dividers
Containers         surfaceContainer #1C1B1F (tiles) · surfaceContainerHigh #2B292D (fields)
Text/icons         onSurface #E4E1E7 · onSurfaceVariant #C9C4D1 · disabled #494550
Rail active        bg #4B425D / icon #E9DDFD
Toolbar active     bg #D2BCFC / icon #32226F
Rail buttons       44x44 r22, x=4, first y=68, step 50, +10 between groups
Search field       244x40 r20 at x=64 y=58
Palette tiles      114x72 r16, gap 6, 2 columns
Toolbar            y=20 h40; buttons 40x40 r20; segment gap 3, group gap 22, button gap 4
Segmented pair     outer corners r20, touching corners r8
Zoom row           40 tall, 28 from bottom-right; readout 56 wide
Phone frame        outer 343x725 r44, bezel 7.5, inner 328x709 r36
```

### Re-measuring anything

Open the live reference in a browser tool at a **1440x900** viewport and run
JS against it. This is how every number above was obtained:

```js
const pick = el => { const r = el.getBoundingClientRect(), cs = getComputedStyle(el);
  return {x:Math.round(r.x), y:Math.round(r.y), w:Math.round(r.width), h:Math.round(r.height),
          bg:cs.backgroundColor, radius:cs.borderRadius, color:cs.color,
          fs:cs.fontSize, fw:cs.fontWeight}; };
[...document.querySelectorAll('button')].map(pick);
```

⚠️ At a narrow viewport the reference switches to a **phone-only editor** (one
screen, buttons only, bottom sheet). If you see a stripped-down UI you are
measuring the mobile variant. Always resize to 1440x900 first.

---

## 3. Current state

### Done
- `lib/ui/editor_tokens.dart` — the measured token set (above).
- `lib/ui/editor_buttons.dart` — `EditorIconButton` (hover fill, 0.94 press
  scale over 120ms, disabled state) and `EditorSegmented` (fused-corner pair).
- `lib/ui/canvas_toolbar.dart` — `CanvasToolbar`, the floating top row.
- `lib/ui/zoom_controls.dart` — `ZoomControls`, bottom-right.
- `lib/ui/phone_frame.dart` — rewritten: `PhoneFrame` (bezel geometry),
  `ScreenLabel` (phone/desktop pair + name), `ScreenSurface` (nodes + drop
  target).
- `lib/ui/design_canvas.dart` — rewritten as a pan/zoom viewport only; the
  palette moved out to the shell.
- `lib/main.dart` — rewritten as the 3-column shell.
- `web/index.html` — removed a dead `<script src="standard.js">` that 404'd.

### In flight / not done
- `lib/ui/icon_rail.dart` (`EditorIconRail`) and `lib/ui/parts_palette.dart`
  (`PartsPalette`) — **may not exist yet.** `main.dart` imports both, so the
  project will not compile until they do. Their contracts are in §5.
- `lib/ui/palette_panel.dart` — the old flat-list palette. Delete it once
  `PartsPalette` lands and nothing imports it.

### Contracts `main.dart` depends on

```dart
// lib/ui/icon_rail.dart
const String kRailParts = 'parts';   // also: kRailLayers, kRailColor,
const String kRailColor = 'color';   // kRailShape, kRailType, kRailMotion,
const String kRailShape = 'shape';   // kRailAi, kRailLang
const String kRailMotion = 'motion';
class EditorIconRail extends StatelessWidget {
  const EditorIconRail({super.key, required this.activeId, required this.onSelect});
  final String activeId;
  final ValueChanged<String> onSelect;
}

// lib/ui/parts_palette.dart
class PartsPalette extends StatefulWidget { const PartsPalette({super.key}); }
```

If you change either signature, update `lib/main.dart` in the same commit.

---

## 4. Build, run, verify

```bash
cd /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/canvas_app
flutter analyze          # must be zero issues
flutter build web --release
```

Serve the built bundle and screenshot it at 1440x900:

```bash
cd build/web && python3 -m http.server 8900 --bind 127.0.0.1
```

⚠️ **Do not verify against `flutter run -d web-server`.** The DDC debug server
loads all 1,171 scripts and then renders a blank page in a headless browser —
you will chase a phantom bug. Always verify the release bundle over a static
server.

### Visual diff loop
1. Reference at http://localhost:… vs. live site, both at exactly 1440x900.
2. Screenshot both.
3. For each element in §2, measure the Flutter build the same way you measured
   the reference (Flutter web renders to canvas, so `getComputedStyle` will not
   work on it — compare screenshots and count pixels, or add temporary debug
   paint).
4. Fix, rebuild, repeat.

---

## 5. Remaining work, in priority order

### P0 — unblock the build
1. **`lib/ui/icon_rail.dart`** — 52px column. Buttons 44x44 r22, inset 4.
   First at y=68, step 50 within a group, +10 between groups.
   Groups: `[add_box]` · `[layers]` · `[palette, rounded_corner, text_fields,
   animation]` · `[auto_awesome]`, then bottom-anchored `[translate]` and a
   GitHub mark. Active = `railActive`/`onRailActive`; inactive = transparent
   with `onSurfaceVariant`. Hover feedback + `Tooltip` per item. Icon size 22.
   Use the nearest `Icons.*` constants (the reference uses Material Symbols
   Rounded).
2. **`lib/ui/parts_palette.dart`** — "Parts" title + collapse button at top,
   then the search field, then collapsible sections of a 2-column tile grid.
   - StatefulWidget owning the query and the collapsed-section set.
   - Tiles come from `kCatalog` (`lib/canvas/component_catalog.dart`) — today
     `button, card, input, badge, switch`. Declare
     `const Map<String, List<String>> kPartSections` (section → kinds) and
     render from it, skipping kinds absent from `kCatalog`, so sections can
     grow without touching layout code.
   - Tile = icon (20, `onSurfaceVariant`) over label (`EditorType.tileLabel`,
     `onSurface`), 4px apart, centered.
   - **Each tile must be a `Draggable<String>` with `data: entry.kind`** — this
     is what makes drop-to-canvas work. Feedback: the tile at 0.9 opacity
     wrapped in a transparent `Material` (without the `Material` ancestor the
     drag feedback renders with yellow underlined text).
   - Search filters kind + label case-insensitively and auto-expands matching
     sections. Empty result → centered "No parts match" in `onSurfaceVariant`.
   - Hover lifts the tile 1px; press scales to 0.96 (140ms `easeOutCubic`).

### P1 — make the chrome real
3. **Right aside.** The reference's right column is a **Prompt panel**: a
   settings icon, a "Prompt" pill, and the generated brief. `canvas_core` already
   has `buildPrompt` in `lib/src/prompt_builder.dart` — wire it up. Today
   `main.dart` puts `InspectorPanel` there instead. Decide: either a two-tab
   right panel (Inspector | Prompt), or Inspector on selection and Prompt
   otherwise. The reference shows the inspector as an overlay near the selected
   part, not in the aside.
4. **Layers panel** for the `layers` rail item (`kRailLayers`) — z-order list
   per screen with reorder. Currently a placeholder.
5. **Theme panels.** `color` / `shape` / `motion` all currently render the same
   `ThemeBar`. The reference has four distinct panels (color with seed +
   contrast + dark toggle, shape, type, motion). Split them.
6. **Add-screen is inert.** `_addScreen()` in `main.dart` is deliberately a
   no-op with a comment, because `CanvasStore` has no `addScreen`. Add
   `addScreen`/`renameScreen`/`deleteScreen` to `lib/canvas/canvas_store.dart`
   (mirror `addNode`: build the new `ScreenDoc`, call `_commit`, so undo works),
   then make multiple screens render side by side on the canvas.
7. **Open (`folder_open`) is inert** — wire to file import via
   `share_codec.dart` / a file picker.

### P2 — parity polish
8. Keyboard shortcuts (the reference README lists them).
9. Alignment guides while dragging.
10. Magnetic connection of adjacent parts.
11. Light theme pass — `EditorColors.light` exists but is unverified against the
    reference's light mode. Measure it the same way and correct it.
12. Grow `kCatalog` beyond 5 kinds. The kit has **134 components, 20 already
    marked canvas-ready** in
    `../shadcn_flutter_kit/flutter_shadcn_kit/lib/registry/manifests/components.json`
    (`Button, Card, Accordion, Badge, Avatar, Select, Checkbox, Divider,
    Progress, Skeleton, Breadcrumb, Input, Form, Radio Group, Switch, Dialog,
    Tooltip, Toast, Drawer, Tabs`). Each new kind needs: a `CatalogEntry` in
    `component_catalog.dart`, an entry in `kPartSections`, an icon in
    `_iconFor`, and a `_KindSpec` in
    `../canvas_core/lib/src/codegen_bundle.dart` or the bundle export will warn
    on it.

---

## 6. Edge cases and traps

**Widget names are not guessable.** `flutter_shadcn_kit` has no `Shad*`
classes. Discover before writing:
`grep -rn "^class .* extends .*Widget" <component>/_impl/ | head`. Verified
mappings: button → `PrimaryButton`/`SecondaryButton`/`OutlineButton`/
`GhostButton`/`DestructiveButton`/`LinkButton`/`TextButton`; card → `Card`;
input → `TextField`; badge → `*Badge`; switch → `Switch`.

**Known `components.json` vs. constructor mismatches** (documented at the top
of `component_catalog.dart`, deliberately not patched): button `size` enum
lists `icon` but `ButtonSize` has no icon member; button `variant` omits `text`
though `TextButton` exists; switch schema has a `label` prop but `Switch` takes
only `leading`/`trailing`.

**Never embed a component's `preview.dart`.** Previews render full `Scaffold`s;
nesting those inside canvas frames breaks `ScaffoldMessenger` and safe-area
behavior. Catalog builders construct bare widgets.

**JSON doubles.** `jsonDecode` yields `int` for whole numbers, so `as double`
crashes. Every numeric parse in `canvas_core` uses `(v as num).toDouble()` —
keep that pattern.

**`canvas_core` must stay Flutter-free.** No `package:flutter` and no
`dart:io` imports — the CLI shares it, and `share_codec.dart` must compile for
web. That is why share links are uncompressed (`dart:convert` has no zlib);
`kShareMaxUrlLength` (6000) is the guard instead. Do not "optimize" this by
adding a compression dependency without checking both targets.

**Drag feedback needs a `Material` ancestor** or text renders yellow and
underlined.

**Zoom vs. hit testing.** `design_canvas.dart` scales with `Transform.scale`.
Pointer coordinates inside the scaled subtree are handled by Flutter, but the
**drop offset is not**: `ScreenSurface.onAcceptWithDetails` converts the global
drop point with `globalToLocal` and subtracts the bezel. At a zoom other than
1.0 the resulting offset is in *scaled* pixels and parts will land off-target.
Divide by the current zoom before calling `onAccept`. **This is an open bug —
fix it when you touch drop handling.**

**`store.undo()` / `redo()` return `bool`, not `void`.** Passing them directly
where a `VoidCallback` is expected is a type error — wrap them:
`() => store.undo()`.

**Default zoom is 0.79**, matching the reference's default fit. `onFit`
currently resets to that constant rather than computing a real fit; compute it
from the viewport once multiple screens exist.

**The reference has no dividers between columns.** If you find yourself adding
a `VerticalDivider` or a border, you are drifting.

---

## 7. Running sub-agents (opencode CLI)

Two verified models:

```bash
opencode run -m opencode-go/muse-spark-1.3-contributor  --variant xhigh --auto -- "prompt"
opencode run -m opencode/muse-spark-1.3-contributor-free --variant xhigh --auto -- "prompt"
```

**Gotchas learned the hard way:**
- `--variant xhigh` is the reasoning-effort flag (not `--reasoning`).
- `--auto` auto-approves permissions. This version has **no**
  `--dangerously-skip-permissions`.
- **`-f` is a greedy array flag: it swallows the positional prompt as another
  filename.** Always put `--` between the last `-f` and the prompt, or the run
  fails with `Error: File not found: <your entire prompt>`.
- `--dir <path>` sets the working directory.
- The go-contributor model can run for many minutes at `xhigh` with **zero
  streamed output** — an empty log does not mean it is stuck. Check
  `ps aux | grep opencode` before killing it.

**Parallelism rule:** give each agent a strict, disjoint **file allowlist** and
say so in the prompt ("another agent is editing other files right now"). Write
any file both agents need (like `editor_tokens.dart`) yourself, first. Two
agents editing one Flutter file will clobber each other silently.

Always attach the spec and the token file, and require `flutter analyze` to be
clean before the agent reports done.
