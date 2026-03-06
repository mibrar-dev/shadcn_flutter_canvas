# shadcn_flutter Micro Animations – Single Composable Library Plan (Chaining + Premium Motion)

This plan defines a **single, app-wide micro-animation library** that you can copy/paste install into your `shadcn_flutter_kit` ecosystem. It is **not split** into many separate “presence/pressable/collapse” components. Instead, it provides a **unified chaining/composition API** that can be used anywhere: overlays, inputs, buttons, toasts, list items, icons, etc.

> Goal: a **small set of motion primitives** + **composition (chain/parallel/stagger)** + **tokens** + **reduced motion** + **premium physics** that together cover ~95% of micro-motion needs.

---

## 1) Outcomes and Non-Goals

### Outcomes
- One installable package/group: `shared/micro_animations/…` (or a component named `micro_animations` that installs into shared).
- A **builder/chaining API** that can:
  - apply **multiple effects** (fade + slide + scale + shadow…)
  - run them **in parallel** or **sequence**
  - be **interruptible**
  - support **implicit** and **explicit** animation modes
  - support **springs / physics** options
- A **unified “MotionSpec” tokens system** so everything looks consistent.
- A **Reduce Motion policy** that automatically adapts durations/travel/blur/physics.

### Non-Goals
- Not a full timeline editor.
- Not a heavy dependency graph.
- Not enforcing one component style—this is an app-wide utility.

---

## 2) High-Level Architecture

### Single Library Modules (folders)
```
shared/micro_animations/
  micro_animations.dart        // the only public export surface
  _impl/
    tokens/
      motion_tokens.dart
      motion_curves.dart
      motion_durations.dart
      motion_springs.dart
      motion_reduce_policy.dart
    core/
      chain.dart               // chain DSL + composition graph
      effect.dart              // effect interface + common helpers
      driver.dart              // implicit vs explicit driver abstraction
      controller_pool.dart     // optional pooling for high-frequency
      tween_resolver.dart      // typed tween resolution per property
      lerp.dart                // lerp helpers for non-trivial values
      diagnostics.dart         // debug labels, introspection
    effects/
      opacity.dart
      translate.dart
      scale.dart
      rotate.dart
      size.dart
      shape.dart               // radius, border, clip
      color.dart               // color, border, text style
      elevation.dart           // shadow/elevation
      blur.dart
      path.dart                // icon stroke/path drawing hooks
      numeric.dart             // number tweening
      haptics_audio.dart       // optional adapters
    widgets/
      motion.dart              // Motion widget applying chain to a child
      motion_builder.dart      // builder to react to state changes
      motion_switcher.dart     // switch child keys with chain transitions
      motion_list.dart         // stagger support for list inserts/removes
      motion_overlay.dart      // optional overlay hook helpers (still uses same chain)
```

### Public API surface (single entry point)
`micro_animations.dart` exports **only**:
- `Motion` / `MicroMotion` widget (name your choice)
- `MotionChain` DSL for chaining effects
- `MotionTokens` defaults + customization
- `ReduceMotionPolicy` hooks
- Optional helpers: `MotionSwitcher`, `MotionList`, `MotionBuilder`

Everything else is internal under `_impl/`.

---

## 3) The Core Concept: A Composable Motion Graph

### Why a motion graph?
Micro animations are rarely one property. The *good stuff* is: **fade + scale + shadow** or **slide + fade + blur** etc. You want a consistent way to combine them without re-writing controllers and tweens.

### Your composition model
Represent an animation as a graph of “tracks”:
- Each **track** animates one or more properties (opacity, offset, scale…).
- Tracks can be combined:
  - `parallel([…])`
  - `sequence([…])`
  - `stagger(list, delayStep)`
- Each track can have:
  - duration / curve or spring
  - delay
  - begin/end values
  - “reduced motion” behavior overrides

This graph compiles to either:
- **Implicit**: TweenAnimationBuilder-style evaluation (simple + lightweight)
- **Explicit**: AnimationController (needed for sequencing/stagger and precise control)

Your driver abstraction hides the difference.

---

## 4) Chaining DSL (Developer Experience)

### Design goals for the DSL
- Readable, short, fluent.
- Works for both *state transitions* (show/hide, enabled/disabled) and *event pulses* (press, shake, success pop).
- Chain should be **portable**:
  - can be stored as a const-ish config object
  - can be reused across components
  - can be theme-driven

### Example DSL shape (conceptual)
You don’t need this exact syntax, but the plan assumes something like:

- `MotionChain()` creates an empty chain.
- `.fadeIn()` `.fadeOut()` `.slideY()` `.scale()` `.rotate()` `.elevate()` etc add effects.
- `.then(...)` appends sequentially.
- `.with(...)` merges in parallel.
- `.stagger(...)` for lists.
- `.spec(tokens.micro)` picks timing defaults.
- `.spring(tokens.spring.standard)` uses physics.

> Key point: every “specialized animation” becomes just a chain recipe, not a separate component folder.

---

## 5) Tokens: How to Keep Motion Consistent

### Token categories
- **Durations**
  - micro (press/hover)
  - short (state changes)
  - medium (small overlays)
  - long (large transitions)
- **Curves**
  - interactiveIn (ease-out)
  - interactiveOut (ease-in)
  - standard (ease-in-out)
  - emphasized (rare)
- **Springs**
  - standard
  - bouncy
  - tight
  - overshoot-safe (no crazy bounce)
- **Distances**
  - nudge (2–4px)
  - microSlide (6–12px)
  - overlaySlide (12–24px)
- **Scale**
  - pressDown (0.98–0.99)
  - hoverUp (1.01–1.02)
- **Elevation**
  - base, hover, pressed, overlay

### Theming approach
Create a `MotionTokens` object similar to how shadcn has theme tokens. It should be:
- globally accessible (e.g., inherited widget or via your theme)
- overrideable per subtree

---

## 6) Reduced Motion and Accessibility Strategy

### Inputs to check
- `MediaQueryData.disableAnimations`
- `AccessibilityFeatures.disableAnimations`
- `AccessibilityFeatures.reduceMotion`

### Policy: “reduce motion” isn’t “no animation”
Define `ReduceMotionPolicy` that decides:
- duration scaling (e.g., 0.4x or 0x)
- travel scaling (e.g., offset * 0.2)
- disable blur by default (expensive + motion heavy)
- clamp spring bounciness to near-critical damping
- keep fades very short (or instant) for continuity

Expose policies:
- `ReduceMotionPolicy.off()`
- `ReduceMotionPolicy.system()` (default)
- `ReduceMotionPolicy.custom(...)`

This lets your entire app behave responsibly without rewriting each animation.

---

## 7) The 12 Primitive Effects (Coverage Plan)

Each primitive is implemented as an **Effect**:
- defines which property/properties it animates
- defines default begin/end values
- defines how it composes with other effects
- defines reduced-motion fallback

### 1) Opacity (Fade)
- properties: `opacity`
- supports: fade in/out, crossfade, emphasis/disabled transitions

### 2) Translation (Slide / Nudge)
- properties: `offset` (x, y)
- modes:
  - slide in/out (overlay origins)
  - nudge (errors, attention)
  - parallax (advanced optional)

### 3) Scale (Grow / Shrink)
- properties: `scale`
- modes:
  - press down/up
  - pop in
  - subtle emphasis

### 4) Rotation
- properties: `rotation`
- modes:
  - chevron rotate
  - subtle wobble (advanced)
  - spinner (loop mode)

### 5) Size (Expand / Collapse)
- properties: `sizeFactor` or `heightFactor` (with clip)
- implement with:
  - clip + alignment control
  - optional opacity for content legibility

### 6) Shape morph (Radius, stroke, clip)
- properties: border radius, stroke width, clip shape
- strategies:
  - animate `BorderRadius`
  - animate stroke width
  - clip morph (advanced: custom clipper + lerp)

### 7) Color / Fill / Border / Text style
- properties: background color, border color/width, text style color/weight
- use typed tweens (ColorTween, TextStyleTween, custom for border)

### 8) Elevation / Shadow (Depth)
- properties: shadow blur/spread/offset or “elevation token” mapped to shadows
- pair with micro-translation for realism

### 9) Blur / Filter (sparingly)
- properties: sigmaX/Y or image filter config
- reduced-motion: default to disabled

### 10) Path / Stroke drawing (icons)
- properties: path progress 0..1
- approach options:
  - animated painter + `PathMetric.extractPath`
  - vector icon pipeline (if you standardize)
- treat as “delight” effect with a safe default

### 11) Numeric interpolation
- properties: value double/int
- output widgets:
  - number ticker text
  - progress counters
- support formatting callback

### 12) Non-visual feedback (haptic/audio)
- adapters:
  - `HapticFeedback.*`
  - optional audio callback injection
- reduced-motion: unaffected (but user might want disable)
- keep optional behind an interface (no forced dependency)

---

## 8) Premium / Advanced Motion (Physics + Choreography)

### A) Spring / Physics layer
Offer spring as a **spec type**:
- `MotionSpec.curve(duration, curve)`
- `MotionSpec.spring(springSpec)`

SpringSpec should include:
- response (duration-ish)
- damping
- mass/stiffness (or simplified “bouncy/tight” presets)
- clamp overshoot option

### B) Stagger and choreography
Provide these as **composition operators**:
- `chain.then(...)`
- `chain.with(...)` (parallel)
- `chain.stagger(...)`
- `chain.delay(...)`

### C) Gesture-driven progress (scrubbing)
Advanced but powerful:
- allow the chain to be driven by a `progress` (0..1), not only time.
- useful for drag-to-dismiss, interactive sheets, slider-based animations.

### D) State machine support (optional)
For complex components, allow:
- named states: `idle`, `hover`, `pressed`, `disabled`, `loading`, `success`, `error`
- each state chooses a chain recipe
- transitions resolved automatically (like a mini motion state machine)

Keep this optional to avoid bloat.

---

## 9) Driver Layer: Implicit vs Explicit Without Pain

### Why a driver abstraction?
- Implicit is easiest and covers many cases.
- Explicit is needed for:
  - sequencing
  - interrupts
  - staggering
  - interactive progress
  - loops (loading)

### Plan
Create:
- `MotionDriver` interface
- `ImplicitDriver`: evaluates chain at time t with tween math
- `ControllerDriver`: uses AnimationController + CurvedAnimation / simulation

The `Motion` widget picks the driver automatically:
- If chain contains only parallel simple tracks → implicit
- If chain contains sequence/stagger/loop/physics → explicit

Expose an override for power users.

---

## 10) Interrupts, Reversals, and “Don’t Jank” Rules

### Requirements
- If the target state changes mid-animation:
  - continue smoothly from current value (no jump)
  - optionally reverse direction
- For chained sequences, decide behavior:
  - **cut-to-new** (cancel current, animate to new)
  - **queue** (finish current, then new) — rarely desired for micro
  - **blend** (preferred)

### Implementation strategy
- Keep a snapshot of current animated values when a new chain starts.
- Use “begin = current” and “end = target” for each track.
- If spring: create simulation with current velocity if available.

Also include:
- a global “max duration” clamp for micro interactions
- a “skip animation on first build” option (avoids initial pop)

---

## 11) Debuggability (Critical for a Library)

Add diagnostics tools:
- `MotionDebugOverlay` (optional) shows:
  - current chain name
  - progress, active tracks
  - reduced motion state
- `toStringDeep()` for chain graph
- `assertValid()` rules:
  - no negative durations
  - non-null begin/end
  - clip required when size collapse used
  - blur disabled unless explicitly enabled

---

## 12) Integration Patterns (How Users Will Actually Use It)

### Pattern 1: State-driven wrappers
- Wrap any widget:
  - `show/hide`, `enabled/disabled`, `selected/unselected`
- You pass `state` and `chain` recipe resolver.

### Pattern 2: Event pulses
- Trigger animations from events:
  - press pulse
  - error shake
  - success pop
- Provide a `MotionControllerHandle` to “ping” effects without rebuilding.

### Pattern 3: Overlays, menus, tooltips, toasts (still same library)
Even though you don’t want separate components, you still need “recipes”:
- Provide a `MicroRecipes` file with named chains:
  - `recipes.toastInTopRight`
  - `recipes.menuEnterFromTop`
  - `recipes.tooltipPop`
These are **just chain presets**, not separate modules.

### Pattern 4: Lists
- Provide `MotionList` helper that:
  - animates insert/remove with stagger
  - supports keyed items
  - still uses MotionChain recipes

---

## 13) Build Phases (Step-by-Step Roadmap)

### Phase 0 – Design + API freeze (1–2 days)
- Pick public names:
  - `Motion`, `MotionChain`, `MotionSpec`, `MotionTokens`, `ReduceMotionPolicy`
- Decide the DSL style (fluent vs builder functions).
- Decide how you represent “properties” internally (typed channels).

### Phase 1 – Tokens + Reduce Motion (foundation)
- Implement tokens files.
- Implement reduce-motion policy resolution:
  - system detection
  - scaling rules
- Add test coverage for policy behaviors.

### Phase 2 – Core chain graph + implicit driver
- Implement effect interface and composition operators.
- Implement `Motion` widget with implicit driver.
- Implement 3 basic effects: fade, translate, scale.
- Provide sample recipes (fade+scale, fade+slide).

### Phase 3 – Explicit driver + sequencing
- Add explicit driver that compiles chain to controller timeline.
- Add `then/sequence`, `delay`, `with/parallel` behaviors.
- Add interrupt blending rules.

### Phase 4 – Implement remaining primitives (12-set)
- rotation, size+clip, shape, color, elevation/shadow, blur, numeric
- path drawing as advanced optional
- haptics/audio adapters behind interfaces
- Add validation asserts and docs.

### Phase 5 – Springs/physics premium layer
- Add spring spec presets.
- Provide safe defaults (no wild overshoot).
- Reduced-motion should clamp springs.

### Phase 6 – Helpers (switcher/list/builder)
- `MotionSwitcher` for child transitions
- `MotionBuilder` for state resolution
- `MotionList` for stagger insert/remove
- Still all under the same library export.

### Phase 7 – Documentation + Examples
- One README with:
  - primitives and recipes
  - “How to chain effects”
  - state-driven + event-driven examples
  - reduced motion behavior
- A demo page in your widget catalog.

### Phase 8 – Registry integration
- Add a single registry entry (component or shared group).
- Ensure install copies only under shared path.
- Ensure pubspec additions are minimal (ideally none).

---

## 14) Registry Strategy (shadcn_flutter_kit friendly)

### Recommended install shape
- Treat it as a **shared group** because it’s broadly reusable:
  - `shared: ["micro_animations"]`
- Or as one component `utility/micro_animations` that installs into shared path.

### File rules compliance
- Only one public class per Dart file:
  - `micro_animations.dart` exports the public API types, each in its own file
  - internal helpers in `_impl/`
- Keep taxonomy stable and deterministic.

---

## 15) Testing Matrix (What to Validate)

### Unit tests
- chain graph construction (sequence/parallel)
- token resolution
- reduced motion scaling and disabling
- tween resolution for complex types (BorderRadius, TextStyle)

### Golden tests (optional but recommended)
- fade+scale overlay
- press pulse
- collapse with clip
- list stagger

### Performance checks
- no rebuild loops
- blur behind a feature flag
- path drawing limited to small sizes

---

## 16) Documentation Deliverables (What you’ll ship)

1. **README.md**
   - Quick start
   - Concepts: chain, spec, tokens, reduced motion
   - Recipes catalog
   - Patterns: state-driven, event-driven, interactive progress
2. **API dartdocs**
   - Field-level docs (per your doc rules)
   - Parameter behavior, clamping, reduced-motion behavior
3. **Widget catalog examples**
   - “Motion Playground” (interactive knobs for tokens, curves, spring presets)

---

## 17) Suggested “Recipe Packs” (Still Single Library)

Keep “recipes” as pure data/config:
- `MicroRecipes.interactive`
  - press, hover, focus, disabled
- `MicroRecipes.overlay`
  - menu, tooltip, dialog
- `MicroRecipes.feedback`
  - success pop, error nudge, loading pulse
- `MicroRecipes.list`
  - insert/remove, reorder hint

All recipes resolve down to `MotionChain` + `MotionSpec` + token lookups.

---

## 18) Final Checklist Before You Implement

- [ ] Single export surface (`micro_animations.dart`)
- [ ] Tokens + reduce-motion policy in place first
- [ ] Chain graph supports parallel + sequence + stagger
- [ ] Driver abstraction hides implicit vs explicit
- [ ] 12 primitives implemented as Effects
- [ ] Premium: spring specs + interactive progress option
- [ ] Named recipes for common patterns (but no separate components)
- [ ] Debug overlay + validation asserts
- [ ] Registry entry added and deterministic file layout

---

## 19) What to Build First (Minimal Viable “Feels Like Shadcn”)

Start with:
- tokens
- reduce-motion policy
- chain core
- fade/translate/scale
- `Motion` widget
- recipe: `fade+scale pop`
- recipe: `fade+slide in`

Then ship it into your catalog as “Motion Playground”. Once that feels good, expand to the remaining primitives and springs.

---

### If you want, next step
I can convert this plan into **your registry files** structure (component entry + meta.json + README + stub file list) so you can drop it into `registry/` and install via CLI as one unit.
