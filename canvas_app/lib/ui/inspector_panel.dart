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
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/props_schema.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/property_editors.dart';
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

/// Display title for a spec [group] id (`content` → `Content`). Group ids
/// stay lowercase in [PropSpec]; only the header paint capitalizes.
String _groupTitle(String group) {
  if (group.isEmpty) return group;
  return group[0].toUpperCase() + group.substring(1);
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
class _StoreRelay extends foundation.ChangeNotifier {
  _StoreRelay(this._store) {
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

  /// Pre-W2 per-kind schemas. Retained for source compatibility only; editors
  /// are driven by [kPropSchemas] from `props_schema.dart`.
  final Map<String, List<PropDef>>? schemas;

  const InspectorPanel({
    super.key,
    required this.store,
    this.nodeId,
    this.itemId,
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

  /// Per-item "On tap" action editor: a screen picker (dropdown listing every
  /// doc screen by name; the value is the action target id, or null when the
  /// item has no action or points at a missing screen) plus a transition
  /// select (legal values from [_kActionTransitions], never invented) and a
  /// Clear action button. Every write goes through the undoable
  /// `store.setItemAction` path (clearing passes null, i.e. the
  /// `action: () => null` clear). A fresh pick defaults the transition to
  /// `'slide'` while keeping an existing transition untouched; the
  /// transition select stays disabled until a target is picked. Deleting a
  /// screen needs no handling here: `store.deleteScreen` already refuses
  /// while an action points at it (the shell surfaces the dangling list),
  /// so a target can never dangle through the UI — a stale `to` from an
  /// imported doc shows a missing-target note instead of a value.
  Widget _actionCard(CanvasItem item) {
    final screens = widget.store.doc.screens;
    final action = item.action;
    final targetValue =
        (action != null && screens.any((s) => s.id == action.to))
            ? action.to
            : null;
    final hasTarget = action != null && targetValue != null;
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

    return shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('On tap', style: EditorType.sectionHeader),
          const SizedBox(height: _kInspectorGap),
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
          if (action != null && !hasTarget) ...[
            const SizedBox(height: _kInspectorGap),
            Text(
              'Target screen “${action.to}” is missing.',
              style: EditorType.tileLabel,
            ),
          ],
        ],
      ),
    );
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
          return ListView(
            padding: const EdgeInsets.all(EditorMetrics.panelInset),
            shrinkWrap: true,
            children: [
              shadcn.Card(
                padding: const EdgeInsets.all(EditorMetrics.panelInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        shadcn.PrimaryBadge(child: Text(item.kind)),
                        const SizedBox(width: _kInspectorGap),
                        Expanded(child: Text(item.id)),
                      ],
                    ),
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
                  ],
                ),
              ),
              if (node != null) ...[
                const SizedBox(height: EditorMetrics.panelInset),
                _actionCard(item),
                const SizedBox(height: EditorMetrics.panelInset),
                _visibilityCard(node),
              ],
            ],
          );
        }
        final kindDefaults = findEntry(item.kind)?.defaults;
        final node = _selectedNode(widget.store.doc);
        return ListView(
          padding: const EdgeInsets.all(EditorMetrics.panelInset),
          shrinkWrap: true,
          children: [
            shadcn.Card(
              padding: const EdgeInsets.all(EditorMetrics.panelInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      shadcn.PrimaryBadge(child: Text(item.kind)),
                      const SizedBox(width: _kInspectorGap),
                      Expanded(child: Text(item.id)),
                    ],
                  ),
                  const SizedBox(height: _kInspectorGap),
                  ..._rows(item, schema, kindDefaults),
                ],
              ),
            ),
            const SizedBox(height: EditorMetrics.panelInset),
            _actionCard(item),
            if (node != null) ...[
              const SizedBox(height: EditorMetrics.panelInset),
              _visibilityCard(node),
            ],
          ],
        );
      },
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
              Row(
                children: [
                  shadcn.PrimaryBadge(child: Text('row')),
                  const SizedBox(width: _kInspectorGap),
                  Expanded(child: Text(node.id)),
                ],
              ),
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
            ],
          ),
        ),
        const SizedBox(height: EditorMetrics.panelInset),
        _visibilityCard(node),
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
        );
      case 'bool':
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
      default:
        // Unknown spec types render read-only instead of crashing.
        editor = Text('${spec.name}: $resolved');
    }
    return PropShell(
      name: spec.name,
      overridden: overridden,
      onReset: reset,
      child: editor,
    );
  }
}
