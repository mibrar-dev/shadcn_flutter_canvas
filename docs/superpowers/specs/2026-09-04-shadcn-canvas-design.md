# Shadcn Canvas — Design Spec

Date: 2026-09-04
Status: draft (pending user review)
Decisions locked: standalone web app · real Flutter widgets (Flutter web, not Next.js) · triple export (prompt-only + single `screen.dart` + clean-folders bundle) + CLI install

## 1. Context

The repo is a copy/paste component system (shadcn-style) for Flutter:

- `registry-directory/registries/registries.json` indexes registries; `entries/official.json` (`shadcn → lib/ui/shadcn`) and `entries/ai-chat.json` (`ai → lib/ui/ai`) describe install namespaces/roots and init actions.
- `shadcn_flutter_kit/flutter_shadcn_kit/lib/registry/manifests/components.json` holds 134 official components: per-component `id/name/description/category/tags/files[{source,destination}]/shared[]/dependsOn[]/pubspec/assets/postInstall/version/tier`, plus top-level `defaults{installPath,sharedPath}` and 61 shared items.
- Install flow (`shadcn_flutter_cli/lib/src/application/services/installer/installer.dart`): resolve → dependency-graph validation → shared-closure install → guarded file write → pubspec merge → alias/manifest update → `.shadcn/state.json`.
- Existing web precedent: `shadcn_flutter_kit/docs/` is a Flutter web app deployed to GitHub Pages; `ARCHITECTURE.md` describes the `.shadcn/studio` preview-registry pattern (phases 3–5 map to catalog/canvas/inspector/export).

Reference studied (read-only clone at `/var/folders/dt/p77q2g1j7190pw1cc_h07hg80000gn/T/opencode/m3e-canvas`, upstream `lnkiai/m3e-canvas`, MIT): a zero-backend Next.js static-export sketch tool (`next@16.3.4`, `react@19`, `motion`, `html-to-image`, Tailwind v4). Key files: `app/page.tsx` (~3433 lines, whole editor), `lib/tokens.ts` (1614, part registry + `Doc/Frame/Group/Item`), `lib/prompt.ts` (1151, `buildPrompt`/`effectivePrompt`), `components/M3Node.tsx` (renderer), `components/Preview.tsx` (tap-through player). It has **no code download** — only prompt copy (whole-design + single-screen), PNG via `toPng`, and raw `Doc` JSON save/load; persistence is `localStorage` (`m3e:doc/ui/ai`); AI helper (BYO key, raw fetch, `lib/ai.ts`) writes prose fields only. We borrow its UX patterns, not its code (loading-shape port would require keeping its `NOTICE` attribution).

## 2. Goals / non-goals

Goals: visual canvas where users drag shadcn components onto phone frames, arrange screens, switch themes, tap-through preview, then get (a) a paste-into-AI prompt, (b) a single `screen.dart`, (c) a clean-folders bundle installable via CLI, (d) a shareable link. Later: prompt-to-screen AI that emits `ScreenDoc` JSON through the same codegen path.

Non-goals for v1: backend accounts/DB, multi-user collaboration, desktop-frame editing, free-form Dart generation by LLM, visual regression testing.

## 3. Decisions (user-confirmed)

1. **Standalone web app**, Flutter web (not Next.js). Rationale: rendering must be real Flutter widgets; a React mirror would re-implement 134 components and drift permanently. Copy the `shadcn_flutter_kit/docs/` build/deploy pattern (`flutter-gh-pages`, own `baseHref`, CanvasKit, tree-shaken icons, stripped font list).
2. **Triple export, build order: prompt → single file → bundle → CLI.** Prompt is zero-dependency and freezes the `ScreenDoc` schema; single-file proves shared-closure import resolution; bundle proves multi-namespace paths; CLI reuses the tested graph.
3. **Real-widget rendering** via a generated `component_catalog`: prop defaults are generated from `components.json` canvas blocks by a build-time embedder; widget builders are hand-mapped to real classes (`Button`, `Card`, `TextField`, … — discovered per component, never assumed) using each component's `preview.dart` as the construction reference. Web codegen inlines component bodies from sources embedded at build time; the CLI reads them from disk.

## 4. Architecture

```
canvas_app/                       # new standalone Flutter app (own pubspec, web/index.html)
  lib/canvas/
    screen_doc.dart               # ScreenDoc/Screen/Node/Item/Action/Theme (json_serializable)
    component_catalog.dart        # generated: kind -> props schema + builder (from components.json + canvas{})
    canvas_store.dart             # ChangeNotifier, immutable snapshots, HISTORY_MAX=100 undo
    codegen_single.dart           # ScreenDoc -> screen.dart string
    codegen_bundle.dart           # ScreenDoc -> {dest path -> content} + pubspec patch
    prompt_builder.dart           # ScreenDoc -> natural-language brief (port of m3e buildPrompt)
    share_codec.dart              # ScreenDoc <-> LZ-compressed URL hash
  lib/ui/
    palette.dart  phone_frame.dart  inspector.dart
    theme_panel.dart  preview_player.dart  layers.dart
```

Layout mirrors m3e and the studio plan: left catalog (search, favorites row), center infinite canvas with phone frames (412×892; desktop later), right inspector + theme panel, toolbar (prompt copy, export, undo/redo, preview toggle `P`).

Interaction v1: `Draggable`/`DragTarget` palette→frame drops + select/move/nudge (`arrows`, `Shift`=10) + duplicate (`Ctrl+D`) + delete + layers z-order + group/ungroup (one-level nesting only: connected run `axis x/y` or free group — same constraint as m3e). Custom pointer+snap engine (m3e `SNAP_MAIN=44/SNAP_CROSS=24`, guides, springs) deferred to v2. Autosave debounced to `SharedPreferences` (web localStorage) under `canvas:doc` / `canvas:ui`.

State model (Dart port of m3e `Doc`, JSON-serializable):

```json
{
  "screens": [{"id": "s1", "name": "Home", "x": 0, "y": 0, "bg": "surface"}],
  "nodes": [{"id": "n1", "screenId": "s1", "x": 16, "y": 96,
             "items": [{"id": "i1", "kind": "button", "label": "Checkout",
                        "variant": "primary", "action": {"to": "s2", "transition": "slide"}}]}],
  "theme": {"paletteKey": "indigo", "dark": false, "shape": "rounded", "motion": "expressive"},
  "meta": {"title": "Checkout flow", "brief": "2-screen purchase flow"}
}
```

`Transition = slide|slideLeft|slideUp|slideDown|fade|expand|none`. Pure-Dart ports of `layoutOf/groupBounds/frameOfGroup/explodeGroup` for rows/zones/overlap text.

## 5. Canvas-ready component metadata

Extend `components.schema.json` with an **optional** `canvas{}` block (optional so all 134 components keep validating during rollout):

```json
"canvas": {
  "icon": "mouse-pointer-click", "resizable": true, "defaultSize": {"w": 160, "h": 44},
  "propsSchema": [
    {"name": "label", "type": "string", "default": "Button", "group": "content"},
    {"name": "variant", "type": "enum", "enum": ["primary","secondary","outline","ghost","destructive","link"], "default": "primary", "group": "style"},
    {"name": "size", "type": "enum", "enum": ["sm","md","lg","icon"], "default": "md", "group": "style"},
    {"name": "disabled", "type": "bool", "default": false, "group": "state"}
  ]
}
```

Prop types: `string|bool|double|enum|color|icon|slot`; groups: `content|style|state|layout|behavior|advanced`. Non-canvas params (gesture callbacks, controllers, focus nodes — e.g. `button_widget.dart`'s callbacks) stay excluded via constructor allowlist mapping (e.g. `label→child:Text`, `variant/size→style`, `disabled→enabled` inverted). Validator (CI, static JSON only — no analyzer in P0): shape + type/group allowlists + `default ∈ enum` + default-type match. Constructor cross-check (required Dart params ⊆ `propsSchema` ∪ denylist, enums vs variant source files) is a P1 follow-up; precedent for analyzer tooling is `tool/generate_schemas_convention.dart` which already depends on `package:analyzer`. Note: `components.schema.json` is hand-maintained (no generator emits it — verified), while `components.json` IS rewritten by `tool/registry/registry_components_manifest.dart`; that tool copies entries whole (`Map.from`), so `canvas` blocks survive regen, and the plan gates on this. First 20 components cover 7 categories: button, checkbox, switch, input, select, radio_group, form, card, badge, avatar, skeleton, dialog, sheet, toast, tabs, breadcrumb, accordion, separator, tooltip, progress.

## 6. Export / share / CLI

- **(a) Prompt-only** (`prompt_builder.dart`): deterministic sections — intro + viewport + Flutter target + palette hex rows + theme lines + per-screen layout rows/zones + behavior notes (tap/swipe/toggle) + per-kind style notes + general rules (no hard-coded colors, `Theme.of`, real data, validation, empty states). Editable override (`promptEdit` wins, mirroring m3e `effectivePrompt`).
- **(b) Single `screen.dart`**: `usedComponents[]` → `shared[]` closure via existing `RegistryDependencyGraph`; imports rewritten from `RegistryFile{source,destination}`; one widget file with `package:<app>/ui/shadcn/…` + `ui/ai/…` imports.
- **(c) Clean-folders bundle**: manifest `{screen: lib/ui/screens/<name>.dart, deps: [{dest: lib/ui/shadcn/…}, {dest: lib/ui/ai/…}], pubspec: {dependencies…}}` + patch notes; namespaces mirror `install{namespace,root}`.
- **Share v1**: LZ-compressed `ScreenDoc` JSON in URL hash (`#d=…`), `isProject`-style validation on decode; short-ID/DB links later. PNG via `RepaintBoundary.toImage` (preview artifact, not source of truth).
- **CLI**: `shadcn screen add <url|file> --into lib/ui/screens` (decode/fetch → validate → `ComponentManifestResolver.resolve` → graph validate → shared closure → `InstallTargetPolicy` + `ProjectPathGuard` write → pubspec merge → manifest + `.shadcn/state.json` `screens[]` entry) and `shadcn screen prompt <file>`.
- **AI v2**: LLM constrained to output `ScreenDoc` JSON only (fixed schema, `parseJsonObject`-style guard), then the same codegen path; BYO-key direct-to-provider like m3e, no server.

## 7. Theming

Reuse `tokens.json` + `ThemeExtension`s from `registry/shared`; canvas theme panel edits palette key/custom seed, dark/both-modes, contrast, global shape scaler, font, motion — same four axes as m3e `ColorPanel/ThemePanel`. Preview player honors motion (spring vs standard) and font.

## 8. Risks

- Flutter web bundle (CanvasKit + fonts): strip font groups, defer catalog imports, tree-shake icons.
- Text measurement (m3e `MeasuredContent/widths` has no DOM equivalent): pre-measure with `TextPainter` before `layoutOf` or rows mis-wrap.
- Canvas pan/zoom vs in-phone scroll gesture fight: mode toggle + gesture arena gating.
- Schema drift (Dart constructors vs `propsSchema`): CI validator is load-bearing; keep `canvas{}` optional until coverage passes.

## 9. Phased delivery

- P0 metadata schema + validator + 20 components.
- P1 canvas MVP (palette/frames/inspector/theme/undo/autosave/preview).
- P2a prompt export → P2b single-file → P2c bundle zip.
- P3 share links + PNG.
- P4 CLI `screen add/prompt`.
- P5 AI `ScreenDoc` generation.

Success criteria: 20 canvas-ready components; prompt/single/bundle outputs for a 2-screen flow verified by `flutter analyze` + widget test render; CLI installs bundle into a fixture app with zero manual import fixes; share link round-trips.
