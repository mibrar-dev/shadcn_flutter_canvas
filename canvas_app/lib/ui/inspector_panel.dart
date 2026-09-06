/// Right-rail inspector: edits the selected item's props per [kPropSchemas].
///
/// Every editor row is driven by one [PropSpec] (Storybook `argTypes` style):
/// string → [PropTextEditor], number → [PropNumberEditor] (slider when the
/// spec carries min/max), bool → [PropSwitchEditor], enum → dropdown
/// ([PropSelectEditor]) or segmented control ([PropSegmentedEditor] when the
/// spec has <= 3 options), color → [PropColorEditor], child → [PropSlotEditor]
/// (read-only chip). Every edit goes through `store.patchItem` (leaf props)
/// or `store.patchNode` (container props), so undo/redo keep working.
///
/// OVERRIDE MODEL (Figma-style): the inspector shows the resolved value
/// (`schema default <- kind defaults <- node.props`) plus, when `node.props`
/// carries an override differing from the default, a `modified` badge and a
/// `reset` affordance. `reset` performs a true sparse delete via
/// `store.clearItemProps` (removes the key from `node.props` so the value
/// falls back to the schema/catalog default); normal edits keep going
/// through `store.patchItem`, which merges `{...old, ...new}`.
///
/// DICTATED APIs (W3 — landed in the working tree at integration time):
/// `CanvasNode.mainAxis`/`crossAxis` + per-child `expand`/`flex`, written via
/// `store.patchNode(nodeId, gap:/mainAxis:/crossAxis:/expand:/flex:)`.
/// `patchNode` treats null params as "leave unchanged", so alignment editors
/// offer no reset-to-null affordance (documented on the specs).
///
/// Widget APIs verified in kit sources, never assumed:
/// `TextField(controller, onChanged, placeholder: Widget)`,
/// `Switch(required value, required onChanged)`,
/// `Select(value, enabled, onChanged, placeholder, itemBuilder, popup)` +
/// `SelectPopup(items: SelectItemList(...)).call`,
/// `Slider(value, onChanged, min, max)`,
/// `OutlineButton(size, onPressed, child)` / `PrimaryButton(...)`,
/// `Card(padding, child)`, `*Badge(child)`.
///
/// Dogfooding rule: chrome uses registry widgets via `lib/shadcn_ui.dart` —
/// no raw Material or Cupertino widgets in here.
///
/// TRACK R1 (app state + action flows):
/// * [_stateCard] manages the doc's [AppStateVar]s (add with sane defaults,
///   rename with `=old` binding rewrites, delete with raw-clearing) — the
///   only var UI this track; it lives on the item inspector so bindings are
///   made where vars are visible. The add affordance is a single button
///   (zero extra editors when the doc has no vars, so legacy widget counts
///   hold); rename rides a per-row text field.
/// * String prop rows gain a binding affordance ([_bindingRow]): pick a var
///   to write `=name`, or unlink back to the literal. Unbound rows with no
///   vars render nothing extra.
/// * [_actionCard] keeps the Track K single-nav editors verbatim for legacy
///   actions (same keys/behavior) and grows a step-list editor: the legacy
///   nav materializes as step 1 on first edit, all writes go through the
///   undoable `store.setItemSteps`, and clearing all steps restores legacy.
///   Navigation-last execution is documented in `app_state.dart`.
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/props_schema.dart';
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/property_editors.dart';
import 'package:canvas_app/ui/state_scope.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;

/// Inspector vertical rhythm: every intra-card gap and row separation is one
/// [_kInspectorGap]. NOTE: [EditorMetrics] carries no 8px token (its steps
/// are 3/4/6/12) and that file is owned by another batch, so the rhythm
/// lives here as a single named constant rather than scattered literals.
/// Outer card padding and inter-card separation reuse
/// [EditorMetrics.panelInset].
const double _kInspectorGap = 8.0;

/// Legal `NodeAction.transition` values for the "On tap" editor: the exact
/// set the AI contract validator enforces ([kAiAllowedTransitions] in
/// canvas_core's `screen_doc_schema.dart` — also referenced by
/// `prompt_builder.dart`'s behavior section and `validateRefs`), sorted for
/// a deterministic dropdown order. Never invent transitions here.
final List<String> _kActionTransitions =
    kAiAllowedTransitions.toList()..sort();

/// Fixed width of the row-gap stepper readout (fits two digits plus padding;
/// mirrors the zoom readout role — see [EditorMetrics.zoomLabelWidth]).
const double _kGapValueWidth = 48.0;

/// Starter size applied when stepping a dimension that is currently auto
/// (Track U2): half the 328 phone stage — big enough to see, small enough to
/// stay inside every device. Documented so tests and users can rely on it.
const double _kSizeFallback = 160.0;

/// Display title for a spec [group] id (`content` → `Content`). Group ids
/// stay lowercase in [PropSpec]; only the header paint capitalizes.
String _groupTitle(String group) {
  if (group.isEmpty) return group;
  return group[0].toUpperCase() + group.substring(1);
}

/// Short node label for the nesting breadcrumb/picker (`Row · u3`,
/// `Card · card1`, `Empty · u9` — the same `<Kind> · <id>` idiom as the
/// layers panel rows).
String _nodeShortLabel(CanvasNode node) {
  if (node.isRow) return 'Row · ${node.id}';
  if (node.items.isEmpty) return 'Empty · ${node.id}';
  final kind = node.items.first.kind;
  if (kind.isEmpty) return 'Empty · ${node.id}';
  return '${kind[0].toUpperCase()}${kind.substring(1)} · ${node.id}';
}

/// Ancestor chain of [node] root-first via `parentId` hops, cycle-safe
/// (visited guard, so corrupt cyclic docs terminate; a dangling edge stops
/// the walk, mirroring [isAncestorOf]).
List<CanvasNode> _breadcrumbChain(ScreenDoc doc, CanvasNode node) {
  final byId = {for (final n in doc.nodes) n.id: n};
  final chain = <CanvasNode>[];
  final seen = <String>{node.id};
  var cursor = node.parentId == null ? null : byId[node.parentId];
  while (cursor != null && seen.add(cursor.id)) {
    chain.insert(0, cursor);
    final nextId = cursor.parentId;
    cursor = nextId == null ? null : byId[nextId];
  }
  return chain;
}

/// Screen display name for the breadcrumb head; falls back to the id when
/// the node's screen is missing (imported docs).
String _screenName(ScreenDoc doc, String screenId) {
  for (final s in doc.screens) {
    if (s.id == screenId) return s.name;
  }
  return screenId;
}

/// Whether [node] is a legal parent target for the nesting picker: a row or
/// a container (first item's kind in [kContainerKinds] — the catalog rule
/// from COMPOSITION.md §2, reused here and in `phone_frame.dart`, never
/// re-derived). Leaves are steered away (their children would render with
/// the below-fallback, never inside chrome).
bool _isParentTarget(CanvasNode node) =>
    node.isRow ||
    (node.items.isNotEmpty &&
        kContainerKinds.contains(node.items.first.kind));

/// Disabled reason for a picker [target] relative to [node], or null when
/// the move is legal. Self and descendants stay visible-but-disabled (with
/// the reason) instead of vanishing, so the refusal is discoverable;
/// cross-screen nodes are excluded from the picker outright (a move never
/// changes screens — see [CanvasStore.reparentNode]).
String? _parentDisabledReason(
  CanvasNode node,
  CanvasNode target,
  Set<String> descendantIds,
) {
  if (target.id == node.parentId) return 'current parent';
  if (target.id == node.id) return 'cannot contain itself';
  if (descendantIds.contains(target.id)) return 'would create a cycle';
  return null;
}

/// Disabled reason for a slot [target] relative to [node]'s [slot], or null
/// when the assignment is legal (Track DD — mirrors [_parentDisabledReason]:
/// illegal targets stay visible-but-disabled with the reason so the refusal
/// is discoverable; cross-screen nodes are excluded from the picker outright
/// — a slot child never changes screens, see [CanvasStore.setSlotChild]).
String? _slotDisabledReason(
  CanvasNode node,
  String slot,
  CanvasNode target,
  Set<String> descendantIds,
) {
  if (target.id == node.slotNodes[slot]) return 'current slot child';
  if (target.id == node.id) return 'cannot slot itself';
  if (descendantIds.contains(target.id)) return 'would create a cycle';
  return null;
}

/// Primary composition kind of [node] for the slot table: rows declare no
/// slots, item-less nodes have no kind, otherwise the first item's kind
/// (the same `<Kind>` the headers and layers rows display).
String _slotHostKind(CanvasNode node) {
  if (node.isRow) return 'row';
  if (node.items.isEmpty) return '';
  return node.items.first.kind;
}

/// One editable prop (pre-W2 shape; legacy compatibility shim).
///
/// Kept for source compatibility (`inspector_row_test.dart` reads
/// [kInspectorSchemas]). New code should use [PropSpec] / [kPropSchemas];
/// this view is derived from it (see [kInspectorSchemas]).
class PropDef {
  /// Prop key inside [CanvasItem.props].
  final String name;

  /// One of `'string'`, `'bool'`, `'enum'` (plus `'double'`/`'int'` for
  /// read-only-then numeric props).
  final String type;

  /// Allowed values when [type] is `'enum'`.
  final List<String> enumValues;

  /// Group label (`content`/`style`/`state`/…) for section headers.
  final String group;

  const PropDef({
    required this.name,
    required this.type,
    this.enumValues = const [],
    required this.group,
  });
}

/// Legacy per-kind schema view, derived from [kPropSchemas] (container kinds
/// such as `row` are excluded — a row was never a legacy leaf kind).
/// The `tabs` entry additionally carries the `index` spec, which exists in
/// the catalog defaults but predates the pre-W2 map.
/// W1 appends the canvas-ready registry kinds below (defaults mirror the
/// `k*EntryDefaults` in `component_registry.dart`; invented, documented
/// there). They have no [kPropSchemas] entry yet — that map's length is
/// pinned by `props_schema_test.dart` (another agent's file), so promotion
/// there is an integration step, not part of this batch.
final Map<String, List<PropDef>> kInspectorSchemas = {
  for (final entry in kPropSchemas.entries)
    if (entry.key != 'row')
      entry.key: [
        for (final spec in entry.value)
          PropDef(
            name: spec.name,
            type: spec.type == 'number'
                ? (spec.isInt ? 'int' : 'double')
                : spec.type,
            enumValues: spec.options,
            group: spec.group,
          ),
      ],
  // W1 registry kinds with string/bool/double props (PropDef idiom).
  'chip': const [
    PropDef(name: 'label', type: 'string', group: 'content'),
  ],
  'alert': const [
    PropDef(name: 'title', type: 'string', group: 'content'),
    PropDef(name: 'content', type: 'string', group: 'content'),
    PropDef(name: 'destructive', type: 'bool', group: 'state'),
  ],
  // Doubles render read-only here, same as the progress kind.
  'circular_progress_indicator': const [
    PropDef(name: 'value', type: 'double', group: 'state'),
  ],
  'linear_progress_indicator': const [
    PropDef(name: 'value', type: 'double', group: 'state'),
  ],
  'empty_state': const [
    PropDef(name: 'title', type: 'string', group: 'content'),
    PropDef(name: 'description', type: 'string', group: 'content'),
  ],
  'code_snippet': const [
    PropDef(name: 'code', type: 'string', group: 'content'),
  ],
  'text_area': const [
    PropDef(name: 'placeholder', type: 'string', group: 'content'),
    PropDef(name: 'label', type: 'string', group: 'content'),
    PropDef(name: 'disabled', type: 'bool', group: 'state'),
  ],
};

/// Forwards pure-Dart store notifications to Flutter listeners.
/// Same sanctioned `Listenable` adapter pattern as `design_canvas.dart`.
class _StoreRelay extends foundation.ChangeNotifier {  _StoreRelay(this._store) {
    _store.addListener(_forward);
  }

  final CanvasStore _store;

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_forward);
    super.dispose();
  }
}

/// Inspector bound to one item. Null [nodeId]/[itemId] (or a deleted item)
/// renders the empty hint; unknown kinds render a fallback note.
class InspectorPanel extends StatefulWidget {
  final CanvasStore store;
  final String? nodeId;
  final String? itemId;

  /// Forge SELECTED-card actions (FORGE.md §1-4e, Y5 pass-through): the
  /// Duplicate/Delete row calls these with the selected node id. The shell
  /// wires them to `store.duplicateNode`/`store.deleteNode` (Y6); null
  /// renders the row's buttons disabled.
  final ValueChanged<String>? onDuplicate;
  final ValueChanged<String>? onDelete;

  /// Pre-W2 per-kind schemas. Retained for source compatibility only; editors
  /// are driven by [kPropSchemas] from `props_schema.dart`.
  final Map<String, List<PropDef>>? schemas;

  const InspectorPanel({
    super.key,
    required this.store,
    this.nodeId,
    this.itemId,
    this.onDuplicate,
    this.onDelete,
    this.schemas,
  });

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel> {
  late final _StoreRelay _relay = _StoreRelay(widget.store);

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  CanvasItem? _selectedItem(ScreenDoc doc) {
    final nodeId = widget.nodeId;
    final itemId = widget.itemId;
    if (nodeId == null || itemId == null) return null;
    for (final node in doc.nodes) {
      if (node.id != nodeId) continue;
      for (final item in node.items) {
        if (item.id == itemId) return item;
      }
    }
    return null;
  }

  void _patch(String name, Object? value) {
    widget.store.patchItem(widget.nodeId!, widget.itemId!, props: {name: value});
  }

  /// Row container matching [InspectorPanel.nodeId], or null. Row nodes carry
  /// no items, so they never resolve through [_selectedItem].
  CanvasNode? _selectedRow(ScreenDoc doc) {
    final nodeId = widget.nodeId;
    if (nodeId == null) return null;
    for (final node in doc.nodes) {
      if (node.id == nodeId && node.isRow) return node;
    }
    return null;
  }

  /// Any node matching [InspectorPanel.nodeId], or null. Drives the
  /// node-level Visibility section (shown for leaves and rows alike).
  CanvasNode? _selectedNode(ScreenDoc doc) {
    final nodeId = widget.nodeId;
    if (nodeId == null) return null;
    for (final node in doc.nodes) {
      if (node.id == nodeId) return node;
    }
    return null;
  }

  /// Toggles one tier in the node's `hiddenOn` set through the undoable
  /// `store.setNodeResponsive` path. [visible] is the post-toggle switch
  /// value (true = shown on that tier). Clearing the last hidden tier uses
  /// the `clearHiddenOn` sparse-delete path so the field resets to empty.
  void _toggleVisibility(CanvasNode node, String tier, bool visible) {
    final next = Set<String>.from(node.hiddenOn);
    if (visible) {
      next.remove(tier);
    } else {
      next.add(tier);
    }
    if (next.isEmpty) {
      widget.store.setNodeResponsive(node.id, clearHiddenOn: true);
    } else {
      widget.store.setNodeResponsive(node.id, hiddenOn: next);
    }
  }

  /// Node-level Visibility section: one visible-vs-hidden toggle per
  /// responsive tier plus a small `hidden on: …` summary. Reads
  /// `node.hiddenOn` and writes through [setNodeResponsive] (see
  /// [_toggleVisibility]), so undo/redo keep working.
  ///
  /// Toggles are registry buttons (not [shadcn.Switch]) so the leaf prop
  /// editors keep their exact widget counts (`inspector_test.dart` pins the
  /// single bool [shadcn.Switch] for the selected item).
  Widget _visibilityCard(CanvasNode node) {
    final hidden = node.hiddenOn;
    final sorted = hidden.toList()..sort();
    final summary = hidden.isEmpty
        ? 'hidden on: none (always visible)'
        : 'hidden on: ${sorted.join(', ')}';
    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Visibility', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
          for (final tier in const ['mobile', 'tablet', 'desktop'])
            Padding(
              padding: const EdgeInsets.only(bottom: _kInspectorGap),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tier[0].toUpperCase() + tier.substring(1),
                      style: EditorType.tileLabel,
                    ),
                  ),
                  _visibilityToggle(node, tier, !hidden.contains(tier)),
                ],
              ),
            ),
          Text(summary, style: EditorType.tileLabel),
        ],
      ),
    );
  }

  /// One tier toggle: filled while visible, outlined while hidden. Tapping
  /// flips the tier through [_toggleVisibility].
  Widget _visibilityToggle(CanvasNode node, String tier, bool visible) {    final label = visible ? 'Visible' : 'Hidden';
    if (visible) {
      return shadcn.PrimaryButton(
        key: ValueKey('visibility-$tier'),
        size: shadcn.ButtonSize.small,
        onPressed: () => _toggleVisibility(node, tier, false),
        child: Text(label),
      );
    }
    return shadcn.OutlineButton(
      key: ValueKey('visibility-$tier'),
      size: shadcn.ButtonSize.small,
      onPressed: () => _toggleVisibility(node, tier, true),
      child: Text(label),
    );
  }

  /// Per-item "On tap" action editor: legacy single-nav pickers plus the
  /// Track R1 step-list editor.
  ///
  /// LEGACY (unchanged Track K behavior, same keys): a screen picker
  /// (`action-target`; fresh picks default the transition to `'slide'`
  /// while keeping an existing one), a transition select
  /// (`action-transition`, disabled until a target exists), and a Clear
  /// button (`action-clear`). Every write goes through the undoable
  /// `store.setItemAction` path. Deleting a screen needs no handling here:
  /// `store.deleteScreen` already refuses while an action points at it, so a
  /// target can never dangle through the UI — a stale `to` from an imported
  /// doc shows a missing-target note instead of a value.
  ///
  /// STEPS (Track R1): the `step-add-*` buttons append a step of that kind;
  /// the first append materializes the legacy nav (when any) as step 1, so
  /// no behavior is lost. Steps render in order with per-step editors and
  /// up/down/delete controls; conditions nest one full editor level per
  /// `then` branch. All step writes go through the undoable
  /// `store.setItemSteps` (equal writes are no-ops, so history stays
  /// clean); deleting every step restores pure legacy behavior. While steps
  /// exist the legacy pickers hide (they would desync — `setItemAction`
  /// replaces the whole action); the navigate steps carry their own target
  /// pickers instead.
  Widget _actionCard(CanvasItem item) {
    final doc = widget.store.doc;
    final screens = doc.screens;
    final action = item.action;
    final stepped = action != null && action.steps.isNotEmpty;
    final steps = stepped ? action.steps : const <ActionStep>[];

    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('On tap', style: EditorType.sectionHeader),
              if (stepped) ...[
                const SizedBox(width: _kInspectorGap),
                Text(
                  '${steps.length} step(s)',
                  style: EditorType.tileLabel,
                ),
              ],
            ],
          ),
          const SizedBox(height: _kInspectorGap),
          if (!stepped) ..._legacyActionRows(item, screens, action),
          if (stepped) ...[
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: _kInspectorGap),
              _stepCard(
                steps,
                i,
                'step',
                (next) => widget.store.setItemSteps(
                  widget.nodeId!,
                  widget.itemId!,
                  next,
                ),
              ),
            ],
            const SizedBox(height: _kInspectorGap),
          ],
          _addStepRow(
            (step) => widget.store.setItemSteps(
              widget.nodeId!,
              widget.itemId!,
              [...effectiveActionSteps(action), step],
            ),
            'step-add',
          ),
          const SizedBox(height: _kInspectorGap),
          shadcn.OutlineButton(
            key: const ValueKey('action-clear'),
            size: shadcn.ButtonSize.small,
            onPressed: action == null
                ? null
                : () => widget.store.setItemAction(
                      widget.nodeId!,
                      widget.itemId!,
                      null,
                    ),
            child: const Text('Clear action'),
          ),
          if (!stepped &&
              action != null &&
              !screens.any((s) => s.id == action.to)) ...[
            const SizedBox(height: _kInspectorGap),
            Text(
              'Target screen “${action.to}” is missing.',
              style: EditorType.tileLabel,
            ),
          ],
          if (stepped)
            for (final note in _missingStepTargets(doc, steps, ''))
              Padding(
                padding: const EdgeInsets.only(top: _kInspectorGap),
                child: Text(note, style: EditorType.tileLabel),
              ),
        ],
      ),
    );
  }

  /// The verbatim Track K legacy rows (screen picker + transition select),
  /// shown only while the item has no steps.
  List<Widget> _legacyActionRows(
    CanvasItem item,
    List<CanvasScreen> screens,
    NodeAction? action,
  ) {
    final targetValue =
        (action != null && screens.any((s) => s.id == action.to))
            ? action.to
            : null;
    final transitionValue =
        action != null && _kActionTransitions.contains(action.transition)
            ? action.transition
            : null;

    String screenName(String id) {
      for (final s in screens) {
        if (s.id == id) return s.name;
      }
      return id;
    }

    return [
      shadcn.Select<String>(
        key: const ValueKey('action-target'),
        value: targetValue,
        placeholder: const Text('No action'),
        itemBuilder: (context, option) => Text(screenName(option)),
        onChanged: (to) {
          if (to == null) return;
          widget.store.setItemAction(
            widget.nodeId!,
            widget.itemId!,
            NodeAction(to: to, transition: action?.transition ?? 'slide'),
          );
        },
        popup: shadcn.SelectPopup(
          items: shadcn.SelectItemList(
            children: [
              for (final s in screens)
                shadcn.SelectItemButton(
                  value: s.id,
                  child: Text(s.name),
                ),
            ],
          ),
        ).call,
      ),
      const SizedBox(height: _kInspectorGap),
      PropSelectEditor(
        key: const ValueKey('action-transition'),
        value: transitionValue,
        options: _kActionTransitions,
        placeholderLabel: 'Pick transition',
        enabled: action != null,
        onChanged: (v) {
          if (v != null && action != null) {
            widget.store.setItemAction(
              widget.nodeId!,
              widget.itemId!,
              NodeAction(to: action.to, transition: v),
            );
          }
        },
      ),
      const SizedBox(height: _kInspectorGap),
    ];
  }

  /// One step row: order label + up/down/delete plus the per-kind editor;
  /// conditions additionally nest a full editor for their `then` branch.
  /// [commit] replaces the whole edited list (top-level or nested).
  Widget _stepCard(
    List<ActionStep> steps,
    int index,
    String prefix,
    ValueChanged<List<ActionStep>> commit,
  ) {
    final doc = widget.store.doc;
    final step = steps[index];

    void update(ActionStep next) {
      final copy = List.of(steps)..[index] = next;
      commit(copy);
    }

    void move(int delta) {
      final other = index + delta;
      if (other < 0 || other >= steps.length) return;
      final copy = List.of(steps);
      final tmp = copy[index];
      copy[index] = copy[other];
      copy[other] = tmp;
      commit(copy);
    }

    void remove() {
      final copy = List.of(steps)..removeAt(index);
      commit(copy);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${index + 1}. ${_stepTitle(step, doc)}',
                key: ValueKey('$prefix-$index-title'),
                style: EditorType.tileLabel,
              ),
            ),
            shadcn.OutlineButton(
              key: ValueKey('$prefix-up-$index'),
              size: shadcn.ButtonSize.small,
              onPressed: index > 0 ? () => move(-1) : null,
              child: const Text('↑'),
            ),
            const SizedBox(width: _kInspectorGap),
            shadcn.OutlineButton(
              key: ValueKey('$prefix-down-$index'),
              size: shadcn.ButtonSize.small,
              onPressed:
                  index < steps.length - 1 ? () => move(1) : null,
              child: const Text('↓'),
            ),
            const SizedBox(width: _kInspectorGap),
            shadcn.OutlineButton(
              key: ValueKey('$prefix-delete-$index'),
              size: shadcn.ButtonSize.small,
              onPressed: remove,
              child: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: _kInspectorGap),
        _stepEditor(step, doc, prefix, index, update),
        if (step.kind == 'condition') ...[
          const SizedBox(height: _kInspectorGap),
          const Text('Then', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
          for (var j = 0; j < step.thenSteps.length; j++) ...[
            if (j > 0) const SizedBox(height: _kInspectorGap),
            _stepCard(
              step.thenSteps,
              j,
              '$prefix-$index-then',
              (next) => update(
                ActionStep.condition(
                  variable: step.variable,
                  equals: step.equals,
                  then: next,
                ),
              ),
            ),
          ],
          if (step.thenSteps.isNotEmpty)
            const SizedBox(height: _kInspectorGap),
          _addStepRow(
            (added) => update(
              ActionStep.condition(
                variable: step.variable,
                equals: step.equals,
                then: [...step.thenSteps, added],
              ),
            ),
            '$prefix-$index-then-add',
          ),
        ],
      ],
    );
  }

  /// Short step summary for the order label.
  String _stepTitle(ActionStep step, ScreenDoc doc) {
    switch (step.kind) {
      case 'navigate':
        return 'Navigate to ${_screenName(doc, step.to)}';
      case 'setState':
        final value = step.value.isEmpty ? '(empty)' : step.value;
        return 'Set ${step.variable.isEmpty ? '(pick var)' : step.variable} = $value';
      case 'showSnackBar':
        return 'Snackbar';
      case 'showDialog':
        return 'Dialog';
      case 'condition':
        return 'If ${step.variable} == ${step.equals}';
      case 'apiCall':
        if (step.url.isEmpty) return 'API call';
        return 'API ${step.method} ${step.url}';
    }
    return step.kind;
  }

  /// Per-kind step editor. Keys are `$prefix-$index-<field>` (nested `then`
  /// editors extend the prefix), so tests can drive every field.
  Widget _stepEditor(
    ActionStep step,
    ScreenDoc doc,
    String prefix,
    int index,
    ValueChanged<ActionStep> update,
  ) {
    final screens = doc.screens;
    final vars = doc.states;
    switch (step.kind) {
      case 'navigate':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shadcn.Select<String>(
              key: ValueKey('$prefix-$index-target'),
              value: screens.any((s) => s.id == step.to) ? step.to : null,
              placeholder: const Text('Pick screen'),
              itemBuilder: (context, option) =>
                  Text(_screenName(doc, option)),
              onChanged: (to) {
                if (to == null) return;
                update(
                  ActionStep.navigate(
                    to: to,
                    transition: step.transition,
                  ),
                );
              },
              popup: shadcn.SelectPopup(
                items: shadcn.SelectItemList(
                  children: [
                    for (final s in screens)
                      shadcn.SelectItemButton(
                        value: s.id,
                        child: Text(s.name),
                      ),
                  ],
                ),
              ).call,
            ),
            const SizedBox(height: _kInspectorGap),
            PropSelectEditor(
              key: ValueKey('$prefix-$index-transition'),
              value: _kActionTransitions.contains(step.transition)
                  ? step.transition
                  : null,
              options: _kActionTransitions,
              placeholderLabel: 'Pick transition',
              onChanged: (v) {
                if (v != null) {
                  update(
                    ActionStep.navigate(to: step.to, transition: v),
                  );
                }
              },
            ),
          ],
        );
      case 'setState':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _varPicker(
              key: ValueKey('$prefix-$index-var'),
              value: step.variable,
              placeholder:
                  vars.isEmpty ? 'No state vars' : 'Pick variable',
              onChanged: (v) => update(
                ActionStep.setState(variable: v, value: step.value),
              ),
            ),
            const SizedBox(height: _kInspectorGap),
            PropTextEditor(
              key: ValueKey('$prefix-$index-value'),
              initial: step.value,
              placeholderLabel: 'value or =other',
              onChanged: (s) => update(
                ActionStep.setState(variable: step.variable, value: s),
              ),
            ),
          ],
        );
      case 'showSnackBar':
        return PropTextEditor(
          key: ValueKey('$prefix-$index-message'),
          initial: step.message,
          placeholderLabel: 'message',
          onChanged: (s) =>
              update(ActionStep.snackBar(message: s)),
        );
      case 'showDialog':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PropTextEditor(
              key: ValueKey('$prefix-$index-title'),
              initial: step.title,
              placeholderLabel: 'title',
              onChanged: (s) => update(
                ActionStep.dialog(title: s, message: step.message),
              ),
            ),
            const SizedBox(height: _kInspectorGap),
            PropTextEditor(
              key: ValueKey('$prefix-$index-message'),
              initial: step.message,
              placeholderLabel: 'message',
              onChanged: (s) => update(
                ActionStep.dialog(title: step.title, message: s),
              ),
            ),
          ],
        );
      case 'condition':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _varPicker(
              key: ValueKey('$prefix-$index-var'),
              value: step.variable,
              placeholder:
                  vars.isEmpty ? 'No state vars' : 'Pick variable',
              onChanged: (v) => update(
                ActionStep.condition(
                  variable: v,
                  equals: step.equals,
                  then: step.thenSteps,
                ),
              ),
            ),
            const SizedBox(height: _kInspectorGap),
            PropTextEditor(
              key: ValueKey('$prefix-$index-equals'),
              initial: step.equals,
              placeholderLabel: 'equals (compared as text)',
              onChanged: (s) => update(
                ActionStep.condition(
                  variable: step.variable,
                  equals: s,
                  then: step.thenSteps,
                ),
              ),
            ),
          ],
        );
      case 'apiCall':
        return _apiCallEditor(step, doc, prefix, index, update);
    }
    return Text('Unknown step: ${step.kind}');
  }

  /// Track S1 `apiCall` step editor: URL field, GET/POST segmented method,
  /// per-row header editor (key/value pairs with add/delete), POST-only body
  /// field, and an optional `saveTo` var picker. Validation is inline notes
  /// only (warn, never block — the executor skips bad steps, see
  /// `validateActionSteps` in canvas_core). Secrets note: headers/bodies
  /// live in the doc like any other prop (no vault).
  ///
  /// Keys are `$prefix-$index-url|method|header-add|header-key-<i>|`
  /// `header-value-<i>|header-delete-<i>|body|saveTo|saveTo-clear`, so tests
  /// can drive every field like the other step editors.
  Widget _apiCallEditor(
    ActionStep step,
    ScreenDoc doc,
    String prefix,
    int index,
    ValueChanged<ActionStep> update,
  ) {
    final vars = doc.states;
    final method =
        kApiCallMethods.contains(step.method) ? step.method : 'GET';
    final entries = step.headers.entries.toList();
    ActionStep withHeaders(Map<String, String> next) => ActionStep.apiCall(
          url: step.url,
          method: step.method,
          headers: next,
          body: step.body,
          saveTo: step.saveTo,
        );
    void updateHeaderKey(int at, String nextKey) {
      final next = <String, String>{};
      for (var j = 0; j < entries.length; j++) {
        if (j == at) {
          next[nextKey] = entries[j].value;
        } else {
          next[entries[j].key] = entries[j].value;
        }
      }
      update(withHeaders(next));
    }

    void updateHeaderValue(int at, String nextValue) {
      final next = <String, String>{};
      for (var j = 0; j < entries.length; j++) {
        next[entries[j].key] = j == at ? nextValue : entries[j].value;
      }
      update(withHeaders(next));
    }

    void deleteHeader(int at) {
      final next = <String, String>{};
      for (var j = 0; j < entries.length; j++) {
        if (j != at) next[entries[j].key] = entries[j].value;
      }
      update(withHeaders(next));
    }

    void addHeader() {
      final taken = step.headers.keys.toSet();
      var i = taken.length + 1;
      var name = 'Header$i';
      while (taken.contains(name)) {
        i++;
        name = 'Header$i';
      }
      update(withHeaders({...step.headers, name: ''}));
    }

    final saveTo = step.saveTo;
    AppStateVar? saveTarget;
    for (final v in vars) {
      if (v.name == saveTo) saveTarget = v;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropTextEditor(
          key: ValueKey('$prefix-$index-url'),
          initial: step.url,
          placeholderLabel: 'https://api.example.com/items',
          onChanged: (s) => update(
            ActionStep.apiCall(
              url: s,
              method: step.method,
              headers: Map<String, String>.from(step.headers),
              body: step.body,
              saveTo: step.saveTo,
            ),
          ),
        ),
        const SizedBox(height: _kInspectorGap),
        PropSegmentedEditor(
          key: ValueKey('$prefix-$index-method'),
          value: method,
          options: const ['GET', 'POST'],
          onChanged: (m) => update(
            ActionStep.apiCall(
              url: step.url,
              method: m,
              headers: Map<String, String>.from(step.headers),
              body: step.body,
              saveTo: step.saveTo,
            ),
          ),
        ),
        const SizedBox(height: _kInspectorGap),
        const Text('Headers', style: EditorType.sectionHeader),
        const SizedBox(height: _kInspectorGap),
        for (var i = 0; i < entries.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: PropTextEditor(
                  key: ValueKey('$prefix-$index-header-key-$i'),
                  initial: entries[i].key,
                  placeholderLabel: 'name',
                  onChanged: (s) => updateHeaderKey(i, s),
                ),
              ),
              const SizedBox(width: _kInspectorGap),
              Expanded(
                child: PropTextEditor(
                  key: ValueKey('$prefix-$index-header-value-$i'),
                  initial: entries[i].value,
                  placeholderLabel: 'value',
                  onChanged: (s) => updateHeaderValue(i, s),
                ),
              ),
              const SizedBox(width: _kInspectorGap),
              shadcn.OutlineButton(
                key: ValueKey('$prefix-$index-header-delete-$i'),
                size: shadcn.ButtonSize.small,
                onPressed: () => deleteHeader(i),
                child: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: _kInspectorGap),
        ],
        shadcn.OutlineButton(
          key: ValueKey('$prefix-$index-header-add'),
          size: shadcn.ButtonSize.small,
          onPressed: addHeader,
          child: const Text('Add header'),
        ),
        const SizedBox(height: _kInspectorGap),
        if (method == 'POST') ...[
          PropTextEditor(
            key: ValueKey('$prefix-$index-body'),
            initial: step.body,
            placeholderLabel: 'request body (JSON)',
            onChanged: (s) => update(
              ActionStep.apiCall(
                url: step.url,
                method: step.method,
                headers: Map<String, String>.from(step.headers),
                body: s,
                saveTo: step.saveTo,
              ),
            ),
          ),
          const SizedBox(height: _kInspectorGap),
        ],
        _varPicker(
          key: ValueKey('$prefix-$index-saveTo'),
          value: saveTo,
          placeholder:
              vars.isEmpty ? 'No state vars' : 'No save (optional)',
          onChanged: (v) => update(
            ActionStep.apiCall(
              url: step.url,
              method: step.method,
              headers: Map<String, String>.from(step.headers),
              body: step.body,
              saveTo: v,
            ),
          ),
        ),
        if (saveTo.isNotEmpty) ...[
          const SizedBox(height: _kInspectorGap),
          shadcn.OutlineButton(
            key: ValueKey('$prefix-$index-saveTo-clear'),
            size: shadcn.ButtonSize.small,
            onPressed: () => update(
              ActionStep.apiCall(
                url: step.url,
                method: step.method,
                headers: Map<String, String>.from(step.headers),
                body: step.body,
                saveTo: '',
              ),
            ),
            child: const Text('Clear saveTo'),
          ),
        ],
        if (step.url.isEmpty) ...[
          const SizedBox(height: _kInspectorGap),
          const Text(
            'Enter an http(s) URL.',
            style: EditorType.tileLabel,
          ),
        ] else if (!isApiCallUrlValid(step.url)) ...[
          const SizedBox(height: _kInspectorGap),
          const Text(
            'Invalid URL: use http(s):// with a host.',
            style: EditorType.tileLabel,
          ),
        ],
        for (final entry in entries)
          if (!isApiHeaderValid(entry.key, entry.value)) ...[
            const SizedBox(height: _kInspectorGap),
            Text(
              'Invalid header "${entry.key}".',
              style: EditorType.tileLabel,
            ),
          ],
        if (saveTo.isNotEmpty && saveTarget == null) ...[
          const SizedBox(height: _kInspectorGap),
          Text(
            'Unknown var "$saveTo" — response will be discarded.',
            style: EditorType.tileLabel,
          ),
        ],
        if (saveTarget != null && saveTarget.type != 'string') ...[
          const SizedBox(height: _kInspectorGap),
          Text(
            'Var "$saveTo" is ${saveTarget.type} — response stored as text.',
            style: EditorType.tileLabel,
          ),
        ],
      ],
    );
  }

  /// State-var picker shared by the setState/condition editors: a plain
  /// dropdown over the doc's var names (no scope read — the executor skips
  /// unknown vars, so a stale value degrades to the placeholder).
  Widget _varPicker({
    required Key key,
    required String value,
    required String placeholder,
    required ValueChanged<String> onChanged,
  }) {
    final names = [for (final v in widget.store.doc.states) v.name];
    return shadcn.Select<String>(
      key: key,
      value: names.contains(value) ? value : null,
      placeholder: Text(placeholder),
      itemBuilder: (context, option) => Text(option),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      popup: shadcn.SelectPopup(
        items: shadcn.SelectItemList(
          children: [for (final name in names) shadcn.SelectItemButton(value: name, child: Text(name))],
        ),
      ).call,
    );
  }

  /// One small add button per step kind. [onAdd] receives the fresh default
  /// step (navigate targets the first screen; setState/condition reference
  /// the first var, or `''` when the doc has no vars — the executor skips
  /// unknown vars, so adding before declaring is safe).
  Widget _addStepRow(ValueChanged<ActionStep> onAdd, String prefix) {
    final doc = widget.store.doc;
    final firstScreen = doc.screens.isEmpty ? '' : doc.screens.first.id;
    final firstVar = doc.states.isEmpty ? '' : doc.states.first.name;
    return Wrap(
      spacing: _kInspectorGap,
      runSpacing: _kInspectorGap,
      children: [
        _addStepButton(
          prefix,
          'navigate',
          'Navigate',
          ActionStep.navigate(to: firstScreen),
          onAdd,
        ),
        _addStepButton(
          prefix,
          'setState',
          'Set state',
          ActionStep.setState(variable: firstVar, value: ''),
          onAdd,
        ),
        _addStepButton(
          prefix,
          'showSnackBar',
          'Snackbar',
          const ActionStep.snackBar(message: 'Saved'),
          onAdd,
        ),
        _addStepButton(
          prefix,
          'showDialog',
          'Dialog',
          const ActionStep.dialog(title: 'Title', message: 'Message'),
          onAdd,
        ),
        _addStepButton(
          prefix,
          'condition',
          'Condition',
          ActionStep.condition(variable: firstVar, equals: ''),
          onAdd,
        ),
        _addStepButton(
          prefix,
          'apiCall',
          'API',
          const ActionStep.apiCall(url: ''),
          onAdd,
        ),
      ],
    );
  }

  Widget _addStepButton(
    String prefix,
    String kind,
    String label,
    ActionStep step,
    ValueChanged<ActionStep> onAdd,
  ) {
    return shadcn.OutlineButton(
      key: ValueKey('$prefix-$kind'),
      size: shadcn.ButtonSize.small,
      onPressed: () => onAdd(step),
      child: Text(label),
    );
  }

  /// Missing-target notes for stepped flows (top-level and nested),
  /// mirroring the legacy missing note below.
  List<String> _missingStepTargets(
    ScreenDoc doc,
    List<ActionStep> steps,
    String path,
  ) {
    final out = <String>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final label = path.isEmpty ? 'Step ${i + 1}' : '$path.${i + 1}';
      if (step.kind == 'navigate' &&
          !doc.screens.any((s) => s.id == step.to)) {
        out.add('$label target screen “${step.to}” is missing.');
      }
      if (step.kind == 'condition') {
        out.addAll(_missingStepTargets(doc, step.thenSteps, label));
      }
    }
    return out;
  }

  /// App-state management card (Track R1): lists the doc's vars with rename
  /// + delete, plus a one-tap add (next free `varN`, string type, `''`
  /// default — zero extra editors while the doc has no vars, so legacy
  /// widget counts hold).
  ///
  /// Rename commits per valid change through `store.renameVar`, gated on
  /// identifier syntax + uniqueness so intermediate keystrokes never throw
  /// (mirroring how prop text editors commit per keystroke). Type and
  /// default are immutable after creation — delete + re-add to change them —
  /// so no default migration is ever needed.
  Widget _stateCard(ScreenDoc doc) {
    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App state${doc.states.isEmpty ? '' : ' (${doc.states.length})'}',
            style: EditorType.sectionHeader,
          ),
          const SizedBox(height: _kInspectorGap),
          if (doc.states.isEmpty)
            const Text(
              'No state vars yet. Add one, then bind text props as =name.',
              style: EditorType.tileLabel,
            ),
          for (final v in doc.states) ...[
            _varRow(v),
            const SizedBox(height: _kInspectorGap),
          ],
          shadcn.OutlineButton(
            key: const ValueKey('state-add'),
            size: shadcn.ButtonSize.small,
            onPressed: _addVar,
            child: const Text('Add variable'),
          ),
        ],
      ),
    );
  }

  /// One var row: rename field + immutable type + default readout + delete.
  Widget _varRow(AppStateVar v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: PropTextEditor(
                key: ValueKey('state-name-${v.name}'),
                initial: v.name,
                placeholderLabel: 'name',
                onChanged: (s) => _renameVar(v.name, s),
              ),
            ),
            const SizedBox(width: _kInspectorGap),
            Text(v.type, style: EditorType.tileLabel),
            const SizedBox(width: _kInspectorGap),
            shadcn.OutlineButton(
              key: ValueKey('state-delete-${v.name}'),
              size: shadcn.ButtonSize.small,
              onPressed: () => widget.store.deleteVar(v.name),
              child: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: _kInspectorGap),
        Text(
          'default: ${v.defaultValue ?? '—'}',
          style: EditorType.tileLabel,
        ),
      ],
    );
  }

  /// Adds the next free `varN` (string, `''`): always valid, never throws.
  void _addVar() {
    final taken = {for (final v in widget.store.doc.states) v.name};
    var i = widget.store.doc.states.length + 1;
    var name = 'var$i';
    while (taken.contains(name)) {
      i++;
      name = 'var$i';
    }
    widget.store.addVar(AppStateVar(name: name, type: 'string', defaultValue: ''));
  }

  /// Gated rename: only identifier-shaped, non-taken names reach the store
  /// (same-name and intermediate keystrokes are quiet no-ops).
  void _renameVar(String old, String next) {
    final trimmed = next.trim();
    if (trimmed == old) return;
    if (!kAppStateName.hasMatch(trimmed)) return;
    final names = {for (final v in widget.store.doc.states) v.name};
    if (names.contains(trimmed)) return;
    try {
      widget.store.renameVar(old, trimmed);
    } on ArgumentError {
      // Gate above already validated; belt-and-braces for races.
    } on StateError {
      // Same — the var vanished under us (e.g. undo raced a keystroke).
    }
  }

  /// Shared empty state: centered icon + title + hint. Used for the
  /// no-selection hint and for kinds with zero editable specs.
  Widget _emptyState({
    required IconData icon,
    required String title,
    required String hint,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EditorMetrics.panelInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: EditorTheme.of(context).disabled),
            const SizedBox(height: _kInspectorGap),
            Text(
              title,
              style: EditorType.sectionHeader.copyWith(
                color: EditorTheme.of(context).onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _kInspectorGap),
            Text(
              hint,
              style: EditorType.tileLabel.copyWith(
                color: EditorTheme.of(context).onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Forge SELECTED-card header (FORGE.md §1-4c): the `<Kind> · <id>` idiom
  /// from [_nodeShortLabel], painted as a single 13/600 line (see
  /// [EditorType.readout]) instead of the old badge + id row. The prop
  /// editors below are unchanged (same specs, same `patchItem` paths).
  Widget _selectedHeader(String kind, String nodeId) {
    final title = kind.isEmpty
        ? 'Empty'
        : '${kind[0].toUpperCase()}${kind.substring(1)}';
    return Text(
      '$title · $nodeId',
      key: const ValueKey('inspector-selected-header'),
      style: EditorType.readout.copyWith(
        color: EditorTheme.of(context).onSurface,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Forge SELECTED-card action row (FORGE.md §1-4e, §3): Duplicate
  /// (outline) + Delete (red-text via [EditorColors.danger], the Y2 token
  /// for inspector deletes), side by side at the card bottom. Both fire the
  /// Y5 pass-through callbacks with [nodeId] — the shell owns the
  /// `duplicateNode`/`deleteNode` store calls (Y6), so this widget never
  /// imports them; null callbacks render the buttons disabled.
  Widget _duplicateDeleteRow(String nodeId) {
    final colors = EditorTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: shadcn.OutlineButton(
            key: const ValueKey('inspector-duplicate'),
            size: shadcn.ButtonSize.small,
            onPressed: widget.onDuplicate == null
                ? null
                : () => widget.onDuplicate!(nodeId),
            child: const Text('Duplicate'),
          ),
        ),
        const SizedBox(width: _kInspectorGap),
        Expanded(
          child: shadcn.TextButton(
            key: const ValueKey('inspector-delete'),
            onPressed: widget.onDelete == null
                ? null
                : () => widget.onDelete!(nodeId),
            child: Text(
              'Delete',
              style: EditorType.tileLabel.copyWith(color: colors.danger),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _relay,
      builder: (context, _) {
        final item = _selectedItem(widget.store.doc);
        if (item == null) {
          final row = _selectedRow(widget.store.doc);
          if (row != null) return _rowCard(row);
          return _emptyState(
            icon: Icons.tune,
            title: 'Select an item to edit its props',
            hint: 'Click a component on the canvas to edit it.',
          );
        }
        final schema = kPropSchemas[item.kind];
        if (schema == null || schema.isEmpty) {
          final node = _selectedNode(widget.store.doc);
          return StateScope(
            // Editor scope: defaults (no session overrides in the editor —
            // see `state_scope.dart`; preview provides live values).
            values: StateScope.defaultsFor(widget.store.doc.states),
            // Eager layout like the schema branch below (never unmounts
            // cards while scrolling).
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(EditorMetrics.panelInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                shadcn.Card(
                  padding: const EdgeInsets.all(EditorMetrics.panelInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _selectedHeader(item.kind, widget.nodeId!),
                      const SizedBox(height: _kInspectorGap),
                      Text(
                        'No editable properties',
                        style: EditorType.sectionHeader.copyWith(
                          color: EditorTheme.of(context).onSurface,
                        ),
                      ),
                      const SizedBox(height: _kInspectorGap),
                      Text(
                        'Kind “${item.kind}” has no editable props yet.',
                        style: EditorType.tileLabel.copyWith(
                          color: EditorTheme.of(context).onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: _kInspectorGap),
                      _duplicateDeleteRow(widget.nodeId!),
                    ],
                  ),
                ),
                if (node != null) ...[
                  const SizedBox(height: EditorMetrics.panelInset),
                  _sizeCard(node),
                  const SizedBox(height: EditorMetrics.panelInset),
                  _actionCard(item),
                  const SizedBox(height: EditorMetrics.panelInset),
                  _stateCard(widget.store.doc),
                  const SizedBox(height: EditorMetrics.panelInset),
                  _visibilityCard(node),
                  const SizedBox(height: EditorMetrics.panelInset),
                  _nestingCard(node),
                  ..._nodeSlotLockCards(node),
                ],
              ],
            ),
          ),
        );
        }
        final kindDefaults = findEntry(item.kind)?.defaults;
        final node = _selectedNode(widget.store.doc);
        return StateScope(
          // Editor scope: defaults (no session overrides in the editor —
          // see `state_scope.dart`; preview provides live values).
          values: StateScope.defaultsFor(widget.store.doc.states),
          // Eager layout (a scroll view over a Column, not a lazy
          // ListView): every card builds up front and is never unmounted
          // by scrolling, so editors keep their in-flight state and every
          // finder sees the whole panel (see the NOTE on the schema
          // branch below for why laziness had to go).
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(EditorMetrics.panelInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // NOTE: eager layout (not a lazy ListView): the Track R1
              // state/action cards lengthen this panel past the sliver
              // cache, so deep scrolls would unmount scrolled-away editors
              // and drop their in-flight state (see `responsive_inspector_
              // test.dart`, which asserts the leaf Switch after revealing
              // `On tap`). The panel holds a handful of cards, so eager
              // building costs nothing; the host (`right_aside.dart`)
              // bounds the height, so the scroll view never overflows.
              shadcn.Card(
                  padding: const EdgeInsets.all(EditorMetrics.panelInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _selectedHeader(item.kind, widget.nodeId!),
                      const SizedBox(height: _kInspectorGap),
                      ..._rows(item, schema, kindDefaults),
                      // TODO(Forge follow-up, FORGE.md §1-4d + §4.4):
                      // SURFACE/RADIUS/PADDING editors are deferred — `card`
                      // has no such props in `props_schema.dart`, so Y5 must
                      // not invent them or hand-roll sliders. When the props
                      // land (number PropSpecs with min/max/step so the
                      // kit-Slider branch renders, plus catalog + codegen
                      // support), their editors mount here above the action
                      // row.
                      const SizedBox(height: _kInspectorGap),
                      _duplicateDeleteRow(widget.nodeId!),
                    ],
                  ),
                ),
              const SizedBox(height: EditorMetrics.panelInset),
              _actionCard(item),
              const SizedBox(height: EditorMetrics.panelInset),
              // App-state card rides BELOW the action card, preserving the
              // legacy card order (props → action → visibility → nesting).
              _stateCard(widget.store.doc),
              if (node != null) ...[
                const SizedBox(height: EditorMetrics.panelInset),
                _sizeCard(node),
                const SizedBox(height: EditorMetrics.panelInset),
                _visibilityCard(node),
                const SizedBox(height: EditorMetrics.panelInset),
                _nestingCard(node),
                ..._nodeSlotLockCards(node),
              ],
            ],
          ),
          ),
        );
      },
    );
  }

  /// Track X2 stage width for size presets: the node's screen device width
  /// (`store → node → screenId → screen.device → specForScreenDevice().width`).
  /// Null device means the phone default (see [specForScreenDevice]); a
  /// missing screen or an unknown non-null device id yields null (presets
  /// disable — see [_sizePresetReason]).
  double? _stageWidthForNode(CanvasNode node) {
    CanvasScreen? screen;
    for (final s in widget.store.doc.screens) {
      if (s.id == node.screenId) {
        screen = s;
        break;
      }
    }
    if (screen == null) return null;
    final deviceId = screen.device;
    if (deviceId != null &&
        !kPreviewDevices.any((d) => d.id == deviceId)) {
      return null;
    }
    return specForScreenDevice(deviceId).width;
  }

  /// Disabled reason for the size presets, or null when they are enabled.
  /// Unknown screen (no matching screen for the node) or unknown device
  /// (non-null id outside [kPreviewDevices]) disables every preset button.
  String? _sizePresetReason(CanvasNode node) {
    for (final s in widget.store.doc.screens) {
      if (s.id == node.screenId) {
        final deviceId = s.device;
        if (deviceId != null &&
            !kPreviewDevices.any((d) => d.id == deviceId)) {
          return 'Unknown device "$deviceId" — presets unavailable';
        }
        return null;
      }
    }
    return 'Unknown screen — presets unavailable';
  }

  /// Track X2 width presets (Track U2 steppers above stay verbatim): Fill
  /// clears to auto, Half sets `stage/2`, Third sets `stage/3`. All write
  /// through the undoable `store.setNodeSize` (no store changes). Disabled
  /// while the stage is unknown (see [_sizePresetReason]).
  Widget _widthPresets(CanvasNode node, double? stageWidth) {
    final disabled = stageWidth == null;
    return Wrap(
      spacing: _kInspectorGap,
      runSpacing: _kInspectorGap,
      children: [
        shadcn.OutlineButton(
          key: const ValueKey('node-width-fill'),
          size: shadcn.ButtonSize.small,
          onPressed: disabled
              ? null
              : () => widget.store.setNodeSize(node.id, clearW: true),
          child: const Text('Fill'),
        ),
        shadcn.OutlineButton(
          key: const ValueKey('node-width-half'),
          size: shadcn.ButtonSize.small,
          onPressed: disabled
              ? null
              : () => widget.store.setNodeSize(node.id, w: stageWidth / 2),
          child: const Text('Half'),
        ),
        shadcn.OutlineButton(
          key: const ValueKey('node-width-third'),
          size: shadcn.ButtonSize.small,
          onPressed: disabled
              ? null
              : () => widget.store.setNodeSize(node.id, w: stageWidth / 3),
          child: const Text('Third'),
        ),
      ],
    );
  }

  /// Track X2 height presets: Fill only (clears to auto). Gated on the same
  /// known-stage rule as the width presets (unknown screen/device disables
  /// even the clear, so every preset shares one reason).
  Widget _heightPresets(CanvasNode node, double? stageWidth) {
    final disabled = stageWidth == null;
    return Wrap(
      spacing: _kInspectorGap,
      runSpacing: _kInspectorGap,
      children: [
        shadcn.OutlineButton(
          key: const ValueKey('node-height-fill'),
          size: shadcn.ButtonSize.small,
          onPressed: disabled
              ? null
              : () => widget.store.setNodeSize(node.id, clearH: true),
          child: const Text('Fill'),
        ),
      ],
    );
  }

  /// Track U2 node-size card: one stepper row per dimension (W/H) writing
  /// through the undoable `store.setNodeSize`. Shown for every selected node
  /// (leaves and rows alike — rows additionally carry their container
  /// editors in [_rowCard]).
  ///
  /// Track X2: one-tap presets below each stepper (width Fill/Half/Third,
  /// height Fill only — see [_widthPresets]/[_heightPresets]).
  Widget _sizeCard(CanvasNode node) {
    final stageWidth = _stageWidthForNode(node);
    final reason = _sizePresetReason(node);
    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Size', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
          _nodeSizeRow(
            label: 'Width',
            value: node.w,
            max: kMaxNodeWidth,
            keyPrefix: 'node-width',
            onSet: (v) => widget.store.setNodeSize(node.id, w: v),
            onClear: () => widget.store.setNodeSize(node.id, clearW: true),
          ),
          const SizedBox(height: _kInspectorGap),
          _widthPresets(node, stageWidth),
          const SizedBox(height: _kInspectorGap),
          _nodeSizeRow(
            label: 'Height',
            value: node.h,
            max: kMaxNodeHeight,
            keyPrefix: 'node-height',
            onSet: (v) => widget.store.setNodeSize(node.id, h: v),
            onClear: () => widget.store.setNodeSize(node.id, clearH: true),
          ),
          const SizedBox(height: _kInspectorGap),
          _heightPresets(node, stageWidth),
          if (reason != null) ...[
            const SizedBox(height: _kInspectorGap),
            Text(
              reason,
              key: const ValueKey('node-size-preset-reason'),
              style: EditorType.tileLabel,
            ),
          ],
        ],
      ),
    );
  }

  /// One dimension stepper (Track U2): icon steppers + numeric readout + a
  /// clear-to-auto affordance. Null renders as `Auto`; stepping from auto
  /// starts at [_kSizeFallback], then moves in 8px steps clamped to
  /// `[kMinNodeSize, max]` (the same bounds the canvas drag handles enforce —
  /// see `clampResizeWidth/Height` in `phone_frame.dart`). The `Auto` reset
  /// button only renders while set (a true sparse delete via the `clear*`
  /// path, mirroring the prop override reset).
  ///
  /// Icon (not text) stepper glyphs: the row gap stepper owns the bare
  /// `+`/`−` texts (`inspector_row_test.dart` taps `find.text('+')`), so
  /// text glyphs here would make that finder ambiguous.
  Widget _nodeSizeRow({
    required String label,
    required double? value,
    required double max,
    required String keyPrefix,
    required ValueChanged<double> onSet,
    required VoidCallback onClear,
  }) {
    const step = 8.0;
    final atMin = value != null && value <= kMinNodeSize;
    final atMax = value != null && value >= max;
    double stepped(double base, double delta) =>
        (base + delta).clamp(kMinNodeSize, max).toDouble();
    return Row(
      children: [
        Expanded(child: Text(label, style: EditorType.tileLabel)),
        shadcn.OutlineButton(
          key: ValueKey('$keyPrefix-dec'),
          size: shadcn.ButtonSize.small,
          onPressed: atMin
              ? null
              : () => onSet(
                    value == null ? _kSizeFallback : stepped(value, -step),
                  ),
          child: const Icon(Icons.remove, size: 16),
        ),
        SizedBox(
          width: _kGapValueWidth,
          child: Text(
            value == null ? 'Auto' : value.toInt().toString(),
            key: ValueKey('$keyPrefix-value'),
            textAlign: TextAlign.center,
          ),
        ),
        shadcn.OutlineButton(
          key: ValueKey('$keyPrefix-inc'),
          size: shadcn.ButtonSize.small,
          onPressed: atMax
              ? null
              : () => onSet(
                    value == null ? _kSizeFallback : stepped(value, step),
                  ),
          child: const Icon(Icons.add, size: 16),
        ),
        if (value != null) ...[
          const SizedBox(width: _kInspectorGap),
          shadcn.OutlineButton(
            key: ValueKey('$keyPrefix-auto'),
            size: shadcn.ButtonSize.small,
            onPressed: onClear,
            child: const Text('Auto'),
          ),
        ],
      ],
    );
  }

  /// Container editor for a row node: badge + id + child count + gap
  /// stepper (bounds from the `row`/`gap` spec, reporting through undoable
  /// `store.patchNode`) + enabled `mainAxis`/`crossAxis` selects + per-child
  /// `expand`/`flex` editors.
  Widget _rowCard(CanvasNode node) {
    final children = [
      for (final n in widget.store.doc.nodes)
        if (n.parentId == node.id) n,
    ];
    final gapSpec = findSpec('row', 'gap');
    final gapMin = gapSpec?.min ?? 0.0;
    final gapMax = gapSpec?.max ?? 32.0;
    final gapStep = gapSpec?.step ?? 4.0;
    return ListView(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      shrinkWrap: true,
      children: [
        shadcn.Card(
          padding: const EdgeInsets.all(EditorMetrics.panelInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _selectedHeader('row', node.id),
              const SizedBox(height: _kInspectorGap),
              Text(
                '${children.length} ${children.length == 1 ? 'child' : 'children'}',
              ),
              const Padding(
                padding: EdgeInsets.only(
                  top: _kInspectorGap,
                  bottom: _kInspectorGap,
                ),
                child: Text('Layout', style: EditorType.sectionHeader),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text('gap', style: EditorType.tileLabel),
                  ),
                  shadcn.OutlineButton(
                    size: shadcn.ButtonSize.small,
                    onPressed: node.gap > gapMin
                        ? () => widget.store.patchNode(
                              node.id,
                              gap: (node.gap - gapStep)
                                  .clamp(gapMin, gapMax)
                                  .toDouble(),
                            )
                        : null,
                    child: const Text('−'),
                  ),
                  SizedBox(
                    width: _kGapValueWidth,
                    child: Text(
                      node.gap.toInt().toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  shadcn.OutlineButton(
                    size: shadcn.ButtonSize.small,
                    onPressed: node.gap < gapMax
                        ? () => widget.store.patchNode(
                              node.id,
                              gap: (node.gap + gapStep)
                                  .clamp(gapMin, gapMax)
                                  .toDouble(),
                            )
                        : null,
                    child: const Text('+'),
                  ),
                ],
              ),
              const SizedBox(height: _kInspectorGap),
              _containerSelect(
                name: 'mainAxis',
                value: node.mainAxis,
                placeholderLabel: 'Default (start)',
                onChanged: (v) =>
                    widget.store.patchNode(node.id, mainAxis: v),
              ),
              const SizedBox(height: _kInspectorGap),
              _containerSelect(
                name: 'crossAxis',
                value: node.crossAxis,
                placeholderLabel: 'Default (center)',
                onChanged: (v) =>
                    widget.store.patchNode(node.id, crossAxis: v),
              ),
              const SizedBox(height: _kInspectorGap),
              _nodeSizeRow(
                label: 'Width',
                value: node.w,
                max: kMaxNodeWidth,
                keyPrefix: 'node-width',
                onSet: (v) => widget.store.setNodeSize(node.id, w: v),
                onClear: () => widget.store.setNodeSize(node.id, clearW: true),
              ),
              const SizedBox(height: _kInspectorGap),
              _widthPresets(node, _stageWidthForNode(node)),
              const SizedBox(height: _kInspectorGap),
              _nodeSizeRow(
                label: 'Height',
                value: node.h,
                max: kMaxNodeHeight,
                keyPrefix: 'node-height',
                onSet: (v) => widget.store.setNodeSize(node.id, h: v),
                onClear: () => widget.store.setNodeSize(node.id, clearH: true),
              ),
              const SizedBox(height: _kInspectorGap),
              _heightPresets(node, _stageWidthForNode(node)),
              if (_sizePresetReason(node) != null) ...[
                const SizedBox(height: _kInspectorGap),
                Text(
                  _sizePresetReason(node)!,
                  key: const ValueKey('node-size-preset-reason'),
                  style: EditorType.tileLabel,
                ),
              ],
              if (children.isNotEmpty) ...[
                const SizedBox(height: _kInspectorGap),
                const Padding(
                  padding: EdgeInsets.only(
                    top: _kInspectorGap,
                    bottom: _kInspectorGap,
                  ),
                  child: Text(
                    'Child layout',
                    style: EditorType.sectionHeader,
                  ),
                ),
                for (final child in children) ...[
                  _childFlexEditor(child),
                  const SizedBox(height: _kInspectorGap),
                ],
              ],
              const SizedBox(height: _kInspectorGap),
              const Text('Children are arranged on the canvas and in Layers.'),
              const SizedBox(height: _kInspectorGap),
              _duplicateDeleteRow(node.id),
            ],
          ),
        ),
        const SizedBox(height: EditorMetrics.panelInset),
        _nestingCard(node),
        const SizedBox(height: EditorMetrics.panelInset),
        _visibilityCard(node),
        ..._nodeSlotLockCards(node),
      ],
    );
  }

  /// Enabled dropdown for a row-container alignment prop. No override
  /// badge/reset: `patchNode` treats null as "leave unchanged", so a value
  /// cannot be cleared back to null once set (documented compromise).
  Widget _containerSelect({
    required String name,
    required String? value,
    required String placeholderLabel,
    required ValueChanged<String> onChanged,
  }) {
    final spec = findSpec('row', name);
    return PropShell(
      name: name,
      overridden: false,
      onReset: null,
      child: PropSelectEditor(
        value: value,
        options: spec?.options ?? const [],
        placeholderLabel: placeholderLabel,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  /// Track C2 nesting card: the breadcrumb trail (Screen › … › Node) plus
  /// the parent picker. Shown for every selected node (rows and leaves
  /// alike), reusing the inspector card/padding/rhythm tokens.
  ///
  /// The picker lists the screen-root target plus every same-screen row or
  /// container node (see [_isParentTarget]). Moves go through the undoable
  /// [CanvasStore.reparentNode], so the store's refusals (cross-screen,
  /// self, cycles) apply; the button rebuilds live off the store relay, so
  /// the breadcrumb and the disabled reasons follow every move.
  Widget _nestingCard(CanvasNode node) {
    final doc = widget.store.doc;
    final chain = _breadcrumbChain(doc, node);
    final crumb = [
      _screenName(doc, node.screenId),
      for (final ancestor in chain) _nodeShortLabel(ancestor),
      _nodeShortLabel(node),
    ].join(' › ');
    final descendantIds = {
      for (final d in descendants(doc, node.id)) d.id,
    };
    final targets = [
      for (final n in doc.nodes)
        if (n.screenId == node.screenId && _isParentTarget(n)) n,
    ];
    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nesting', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
          Text(
            crumb,
            key: const ValueKey('nesting-breadcrumb'),
            style: EditorType.tileLabel,
          ),
          const SizedBox(height: _kInspectorGap),
          const Text('Parent', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
          _parentOption(
            label: 'Screen root',
            optionKey: const ValueKey('nesting-move-root'),
            disabledReason:
                node.parentId == null ? 'already at root' : null,
            onMove: () => widget.store.reparentNode(node.id, null),
          ),
          for (final target in targets)
            _parentOption(
              label: _nodeShortLabel(target),
              optionKey: ValueKey('nesting-move-${target.id}'),
              disabledReason:
                  _parentDisabledReason(node, target, descendantIds),
              onMove: () => widget.store.reparentNode(node.id, target.id),
            ),
        ],
      ),
    );
  }

  /// One parent-picker row: the target [label] plus a `Move here` button,
  /// or the [disabledReason] text when the move is illegal (the button is
  /// omitted, never hidden-after-tap — illegal targets cannot be invoked).
  Widget _parentOption({
    required String label,
    required ValueKey<String> optionKey,
    required String? disabledReason,
    required VoidCallback onMove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kInspectorGap),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: EditorType.tileLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (disabledReason != null)
            Flexible(
              child: Text(
                disabledReason,
                style: EditorType.tileLabel.copyWith(
                  color: EditorTheme.of(context).onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            )
          else
            shadcn.OutlineButton(
              key: optionKey,
              size: shadcn.ButtonSize.small,
              onPressed: onMove,
              child: const Text('Move here'),
            ),
        ],
      ),
    );
  }

  /// Track DD slots card: one child picker per named slot from [kNodeSlots]
  /// for the host kind (see [_slotHostKind]), plus a Clear per slot. Null
  /// for kinds with no slots (rows, leaves, unknown kinds) — those nodes
  /// render no card at all. All writes go through the undoable
  /// `store.setSlotChild`, so undo/redo keep working.
  ///
  /// The picker lists every same-screen node (cross-screen nodes are
  /// excluded outright — a slot child never changes screens); illegal
  /// targets render disabled with their reason (see [_slotDisabledReason]).
  /// While the host is locked the pickers and Clear buttons disable with a
  /// hint (the store throws [StateError] on locked-host writes, so the UI
  /// never issues one).
  Widget? _slotsCard(CanvasNode node) {
    final slots = kNodeSlots[_slotHostKind(node)];
    if (slots == null || slots.isEmpty) return null;
    final doc = widget.store.doc;
    final byId = {for (final n in doc.nodes) n.id: n};
    final descendantIds = {
      for (final d in descendants(doc, node.id)) d.id,
    };
    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Slots', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
          if (node.locked) ...[
            const Text(
              'Unlock to edit slots.',
              style: EditorType.tileLabel,
            ),
            const SizedBox(height: _kInspectorGap),
          ],
          for (final slot in slots) _slotRow(node, slot, byId, descendantIds),
        ],
      ),
    );
  }

  /// One slot row: the slot name plus a child picker and a Clear button.
  Widget _slotRow(
    CanvasNode node,
    String slot,
    Map<String, CanvasNode> byId,
    Set<String> descendantIds,
  ) {
    final doc = widget.store.doc;
    final currentId = node.slotNodes[slot];
    final current = currentId == null ? null : byId[currentId];
    final candidates = [
      for (final n in doc.nodes)
        if (n.screenId == node.screenId) n,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: _kInspectorGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slot, style: EditorType.tileLabel),
          const SizedBox(height: _kInspectorGap),
          Row(
            children: [
              Expanded(
                child: shadcn.Select<String>(
                  key: ValueKey('slot-$slot'),
                  value: current != null ? current.id : null,
                  enabled: !node.locked,
                  placeholder: const Text('Empty slot'),
                  itemBuilder: (context, option) {
                    final target = byId[option];
                    return Text(
                      target == null ? option : _nodeShortLabel(target),
                    );
                  },
                  onChanged: (id) {
                    if (id == null || node.locked) return;
                    final target = byId[id];
                    if (target == null) return;
                    // Belt-and-braces: disabled items cannot fire, but a
                    // stale tap must never reach the throwing store path.
                    if (_slotDisabledReason(node, slot, target, descendantIds) !=
                        null) {
                      return;
                    }
                    widget.store.setSlotChild(node.id, slot, id);
                  },
                  popup: shadcn.SelectPopup(
                    items: shadcn.SelectItemList(
                      children: [
                        for (final target in candidates)
                          shadcn.SelectItemButton(
                            key: ValueKey('slot-$slot-${target.id}'),
                            value: target.id,
                            enabled: _slotDisabledReason(
                                  node,
                                  slot,
                                  target,
                                  descendantIds,
                                ) ==
                                null,
                            child: Text(
                              _slotOptionLabel(
                                node,
                                slot,
                                target,
                                descendantIds,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).call,
                ),
              ),
              const SizedBox(width: _kInspectorGap),
              shadcn.OutlineButton(
                key: ValueKey('slot-clear-$slot'),
                size: shadcn.ButtonSize.small,
                onPressed: (node.locked || currentId == null)
                    ? null
                    : () => widget.store.setSlotChild(node.id, slot, null),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Picker option label: `<Kind> · <id>`, plus the disabled reason when the
  /// target is illegal (mirrors the nesting picker's discoverable refusals).
  String _slotOptionLabel(
    CanvasNode node,
    String slot,
    CanvasNode target,
    Set<String> descendantIds,
  ) {
    final reason = _slotDisabledReason(node, slot, target, descendantIds);
    final base = _nodeShortLabel(target);
    return reason == null ? base : '$base — $reason';
  }

  /// Track DD lock card: the current lock state plus a Lock/Unlock toggle
  /// writing through the undoable `store.setNodeLocked`. Shown for every
  /// selected node (leaves, rows, and unknown kinds alike). A locked node
  /// additionally shows a banner hint naming the frozen operations.
  Widget _lockCard(CanvasNode node) {
    final locked = node.locked;
    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lock', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  locked ? 'Locked' : 'Unlocked',
                  style: EditorType.tileLabel,
                ),
              ),
              if (locked)
                shadcn.PrimaryButton(
                  key: const ValueKey('node-lock'),
                  size: shadcn.ButtonSize.small,
                  onPressed: () =>
                      widget.store.setNodeLocked(node.id, false),
                  child: const Text('Unlock'),
                )
              else
                shadcn.OutlineButton(
                  key: const ValueKey('node-lock'),
                  size: shadcn.ButtonSize.small,
                  onPressed: () => widget.store.setNodeLocked(node.id, true),
                  child: const Text('Lock'),
                ),
            ],
          ),
          if (locked) ...[
            const SizedBox(height: _kInspectorGap),
            const Text(
              'Locked — selection, resize, reparent and delete are disabled '
              'until unlock.',
              style: EditorType.tileLabel,
            ),
          ],
        ],
      ),
    );
  }

  /// Slots (when the kind declares any) plus lock cards for a selected node,
  /// with the inter-card rhythm (mirrors the visibility/nesting mounts).
  List<Widget> _nodeSlotLockCards(CanvasNode node) {
    final slots = _slotsCard(node);
    return [
      if (slots != null) ...[
        const SizedBox(height: EditorMetrics.panelInset),
        slots,
      ],
      const SizedBox(height: EditorMetrics.panelInset),
      _lockCard(node),
    ];
  }

  /// Per-child flex editor: `expand` dropdown (null shows the default
  /// placeholder) + integral `flex` stepper. Both report through undoable
  /// `store.patchNode` on the CHILD node id.
  Widget _childFlexEditor(CanvasNode child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(child.id, style: EditorType.tileLabel),
        const SizedBox(height: _kInspectorGap),
        PropSelectEditor(
          value: child.expand,
          options: kExpandOptions,
          placeholderLabel: 'Default (none)',
          onChanged: (v) {
            if (v != null) widget.store.patchNode(child.id, expand: v);
          },
        ),
        const SizedBox(height: _kInspectorGap),
        PropNumberEditor(
          value: (child.flex ?? 1).toDouble(),
          min: 0,
          step: 1,
          isInt: true,
          onChanged: (v) =>
              widget.store.patchNode(child.id, flex: v.toInt()),
        ),
      ],
    );
  }

  List<Widget> _rows(
    CanvasItem item,
    List<PropSpec> schema,
    Map<String, dynamic>? kindDefaults,
  ) {
    final rows = <Widget>[];
    var lastGroup = '';
    for (final spec in schema) {
      if (spec.group != lastGroup) {
        lastGroup = spec.group;
        rows.add(
          Padding(
            // The first header sits directly under the badge row (no top
            // inset); later headers separate from the previous editor.
            padding: EdgeInsets.only(
              top: rows.isEmpty ? 0 : _kInspectorGap,
              bottom: _kInspectorGap,
            ),
            child: Text(_groupTitle(spec.group), style: EditorType.sectionHeader),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: _kInspectorGap),
          child: _editor(item, spec, kindDefaults),
        ),
      );
    }
    return rows;
  }

  Widget _editor(
    CanvasItem item,
    PropSpec spec,
    Map<String, dynamic>? kindDefaults,
  ) {
    final resolved = resolveProp(item.kind, spec.name, item.props, kindDefaults);
    final overridden = isPropOverridden(
      item.kind,
      spec.name,
      item.props,
      kindDefaults,
    );
    // Reset is a true sparse delete: removes the override key from
    // node.props via the store clear-path so the value falls back to the
    // schema/catalog default. Normal edits keep using [_patch].
    void reset() {
      widget.store.clearItemProps(
        widget.nodeId!,
        widget.itemId!,
        {spec.name},
      );
    }

    late final Widget editor;
    switch (spec.type) {
      case 'string':
        editor = PropTextEditor(
          key: ValueKey('${item.id}/${spec.name}'),
          initial: (resolved as String?) ?? '',
          placeholderLabel: spec.name,
          onChanged: (v) => _patch(spec.name, v),
        );      case 'bool':
        editor = PropSwitchEditor(
          value: (resolved as bool?) ?? false,
          onChanged: (v) => _patch(spec.name, v),
        );
      case 'enum':
        final value = resolved as String?;
        // Segmented control when the research rule fires (<= 3 options).
        final useSegmented =
            spec.control == 'segmented' ||
            (spec.control == 'select' && spec.options.length <= 3);
        editor = useSegmented
            ? PropSegmentedEditor(
                value: value,
                options: spec.options,
                onChanged: (v) => _patch(spec.name, v),
              )
            : PropSelectEditor(
                value: value,
                options: spec.options,
                placeholderLabel: 'Pick ${spec.name}',
                onChanged: (v) {
                  if (v != null) _patch(spec.name, v);
                },
              );
      case 'number':
        final current =
            (resolved as num?)?.toDouble() ??
            (spec.defaultValue as num?)?.toDouble() ??
            0.0;
        editor = PropNumberEditor(
          value: current,
          min: spec.min,
          max: spec.max,
          step: spec.step ?? 1,
          isInt: spec.isInt,
          onChanged: (v) => _patch(spec.name, spec.isInt ? v.toInt() : v),
        );
      case 'color':
        editor = PropColorEditor(
          value: resolved as String?,
          onChanged: (v) => _patch(spec.name, v),
        );
      case 'slot':
        editor = PropSlotEditor(
          label: '${spec.name}: ${resolved ?? spec.defaultValue ?? 'empty'}',
        );
      case 'edgeInsets':
        // Track F4 box-model editor (container padding/margin, padding
        // primitive). Writes the canonical raw `{l,t,r,b}` map; reset
        // clears back to the null (unset) default via the shared path.
        final dims = PropEdgeInsetsEditor.parse(resolved);
        editor = PropEdgeInsetsEditor(
          key: ValueKey('${item.id}/${spec.name}'),
          value: dims,
          onChanged: (v) => _patch(spec.name, v),
        );
      case 'alignment':
        // Track F4 alignment grid (stack/align/container). Named constants
        // round-trip as strings; exotic forms (tagged maps) show no
        // selection until picked.
        editor = PropAlignmentGrid(
          key: ValueKey('${item.id}/${spec.name}'),
          value: PropAlignmentGrid.read(resolved),
          onChanged: (v) => _patch(spec.name, v),
        );
      default:
        // Unknown spec types render read-only instead of crashing.
        editor = Text('${spec.name}: $resolved');
    }
    // Track R1: string props gain the binding affordance below the text
    // editor (other types never bind — documented in `app_state.dart`).
    Widget body = editor;
    if (spec.type == 'string') {
      final binding = _bindingRow(item, spec);
      if (binding != null) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [editor, binding],
        );
      }
    }
    return PropShell(
      name: spec.name,
      overridden: overridden,
      onReset: reset,
      child: body,
    );
  }

  /// Binding affordance for a string prop (Track R1): null while the doc
  /// has no vars (zero extra widgets for legacy docs); a var picker writing
  /// `=name` when unbound; a resolved hint plus Unlink (back to the literal)
  /// when bound. Resolution reads the nearest [StateScope], falling back to
  /// the doc defaults — the same rule preview uses with live values.
  Widget? _bindingRow(CanvasItem item, PropSpec spec) {
    final vars = widget.store.doc.states;
    if (vars.isEmpty) return null;
    final raw = item.props[spec.name];
    final name = bindingNameOf(raw);
    if (name == null) {
      return Padding(
        padding: const EdgeInsets.only(top: _kInspectorGap),
        child: PropSelectEditor(
          key: ValueKey('bind-${item.id}-${spec.name}'),
          value: null,
          options: [for (final v in vars) v.name],
          placeholderLabel: 'Bind to state…',
          onChanged: (v) {
            if (v != null) _patch(spec.name, '=$v');
          },
        ),
      );
    }
    final scope =
        StateScope.maybeOf(context) ?? StateScope.defaultsFor(vars);
    final resolved = resolveBoundProp(item.kind, spec.name, raw, scope);
    final known = vars.any((v) => v.name == name);
    return Padding(
      padding: const EdgeInsets.only(top: _kInspectorGap),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '→ =$name = $resolved${known ? '' : ' (missing var)'}',
              key: ValueKey('bind-hint-${item.id}-${spec.name}'),
              style: EditorType.tileLabel,
            ),
          ),
          const SizedBox(width: _kInspectorGap),
          shadcn.OutlineButton(
            key: ValueKey('bind-unlink-${item.id}-${spec.name}'),
            size: shadcn.ButtonSize.small,
            onPressed: () => _patch(spec.name, known ? '$resolved' : name),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }
}
