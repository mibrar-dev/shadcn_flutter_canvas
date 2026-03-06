<!-- You are documenting a Dart/Flutter API. Write behavioral Dartdoc comments at FIELD and PARAMETER level.

Hard requirements:
1) Add docs above every public `final` field in the class (field-level docs are mandatory).
2) Add docs above each public constructor/factory/copyWith parameter.
3) Do NOT write generic constructor-level comments like “Creates a ...” unless strictly necessary.
4) Explain runtime behavior, not restating type names.
5) For numeric controls, define:
   - what `0` means
   - what positive values do
   - what negative values do (if applicable)
6) For bounds/ranges, state validation or clamping behavior.
7) For callbacks, state exactly when they fire and what transformed value is passed.
8) For nullable theme/override fields, describe fallback behavior and how to clear values.
9) Keep each doc concise (2–5 lines), specific, and non-repetitive.
10) Do not change logic or signatures; documentation-only edits.

Output:
- Return only updated Dart code.
- Preserve formatting and API order. -->



You are documenting a Dart/Flutter API in the flutter_shadcn registry (copy/paste installable components).

Write behavioral Dartdoc for:

Public final fields (mandatory)

All public constructor/factory/copyWith parameters (mandatory)

All public methods (mandatory)

Your docs must explain runtime behavior, fallback rules, and value transformations precisely.

🔒 Hard Requirements (Must Follow)

Field-level docs are mandatory
Add /// above every public final field in the class.

Parameter docs are mandatory
Add /// above each public constructor/factory/copyWith parameter (inline in parameter lists).

Method docs are mandatory
Add /// above each public method (including getters/setters), explaining:

When it should be called / when it is called

Side-effects (state changes, notifications, rebuilds)

Return value meaning

Errors / assertions / clamping / no-op conditions

Avoid generic constructor-level comments
Do not write “Creates a …” unless it provides essential context not obvious from the signature.

Explain behavior, not types
Never restate type names or obvious info (avoid “A double that…”). Describe what it does at runtime.

Numeric controls must define 0 / positive / negative
For any numeric parameter/field:

What 0 means

What positive values do

What negative values do (or explicitly disallowed)

Units (logical px, ms, degrees, normalized 0–1, etc.)

Default value

Ranges/bounds must state enforcement
If there’s a range:

State valid range

State whether values are clamped, asserted, or ignored

State behavior at bounds (inclusive/exclusive)

Callbacks must specify timing + value transformation
For each callback:

Exactly when it fires (gesture phase, animation tick, layout, frame, after setState, etc.)

Whether it fires continuously or once

Whether repeated equal values may emit

What value is passed (raw/clamped/normalized/snapped/transformed)

Whether it fires during programmatic updates vs user interaction

Nullable overrides must specify fallback & clearing
For nullable theme/override fields:

Fallback order: explicit override → theme → defaults

How to clear: passing null resets to fallback

Whether override merges or replaces (if it’s a style object)

Layout/painting properties must state when they have no effect
Explain:

Constraint interactions

Parent-driven behaviors

When the field is ignored (e.g., no extra space, single run, disabled state)

Animation behavior must be explicit (common in shadcn)
If a field affects animation:

What triggers animation (value changes, hover, focus, press, mount)

Duration curve default

Whether animations are interrupted, restarted, or smoothly retargeted

State/control rules must be explicit
For controlled/uncontrolled patterns:

Which value wins (external vs internal)

When internal state updates happen

How to keep in sync (e.g., pass controller/value)

Docs must be concise (2–5 lines each)
No fluff. No repetition. No “Used to…”.

Documentation-only edits
Do NOT change:

Logic

Signatures

Names

Ordering

Formatting (except inserting docs)

🧩 Special Rules for Methods (Very Important)

For each public method/getter/setter:

Describe contract: what it guarantees, what it expects.

Describe no-op cases: when calling does nothing.

Describe performance notes only if user-visible (e.g., “triggers a repaint”).

If method returns bool/int/double: define meaning of each possible return.

If method may throw/assert: state conditions.

If method mutates state: state whether it triggers listeners/rebuilds and when.

🧠 Style Rules

Prefer: “Controls…”, “Determines…”, “Fires when…”, “Clamped to…”.

Always mention defaults explicitly when present.

Mention units (px/ms/0–1).

Mention precedence rules (override/theme/default).

Mention interaction with disabled/readOnly/dragging/hover states if relevant.

📤 Output Rules

Return only the updated Dart code.

Preserve formatting and API order.

No commentary outside code.

Insert docs exactly where needed:

Above fields

Inline above params

Above methods/getters/setters