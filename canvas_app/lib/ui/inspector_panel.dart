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
/// `reset` affordance. COMPROMISE (documented): `store.patchItem` has no
/// key-deletion path — it merges `{...old, ...new}` — so `reset` writes the
/// default value back instead of deleting the key. The badge still clears
/// because [isPropOverridden] treats "key present with default value" as not
/// overridden; true sparse deletion needs a store `clearProps` path that does
/// not exist at this runtime.
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _relay,
      builder: (context, _) {
        final item = _selectedItem(widget.store.doc);
        if (item == null) {
          final row = _selectedRow(widget.store.doc);
          if (row != null) return _rowCard(row);
          return const Center(child: Text('Select an item to edit its props'));
        }
        final schema = kPropSchemas[item.kind];
        if (schema == null) {
          return Center(child: Text('No editable props for kind ${item.kind}'));
        }
        final kindDefaults = findEntry(item.kind)?.defaults;
        return ListView(
          padding: const EdgeInsets.all(12),
          shrinkWrap: true,
          children: [
            shadcn.Card(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      shadcn.PrimaryBadge(child: Text(item.kind)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.id)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._rows(item, schema, kindDefaults),
                ],
              ),
            ),
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
      padding: const EdgeInsets.all(12),
      shrinkWrap: true,
      children: [
        shadcn.Card(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  shadcn.PrimaryBadge(child: Text('row')),
                  const SizedBox(width: 8),
                  Expanded(child: Text(node.id)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${children.length} ${children.length == 1 ? 'child' : 'children'}',
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Text('layout', style: EditorType.sectionHeader),
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
                    width: 48,
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
              const SizedBox(height: 8),
              _containerSelect(
                name: 'mainAxis',
                value: node.mainAxis,
                placeholderLabel: 'Default (start)',
                onChanged: (v) =>
                    widget.store.patchNode(node.id, mainAxis: v),
              ),
              const SizedBox(height: 8),
              _containerSelect(
                name: 'crossAxis',
                value: node.crossAxis,
                placeholderLabel: 'Default (center)',
                onChanged: (v) =>
                    widget.store.patchNode(node.id, crossAxis: v),
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'child layout',
                    style: EditorType.sectionHeader,
                  ),
                ),
                for (final child in children) ...[
                  _childFlexEditor(child),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 8),
              const Text('Children are arranged on the canvas and in Layers.'),
            ],
          ),
        ),
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
        const SizedBox(height: 4),
        PropSelectEditor(
          value: child.expand,
          options: kExpandOptions,
          placeholderLabel: 'Default (none)',
          onChanged: (v) {
            if (v != null) widget.store.patchNode(child.id, expand: v);
          },
        ),
        const SizedBox(height: 4),
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
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(spec.group, style: EditorType.sectionHeader),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
    // Reset writes the default value back. True sparse deletion (removing
    // the key from node.props) needs a store clear-path that patchItem does
    // not offer — see the library doc compromise note.
    void reset() {
      final baseline =
          kindDefaults != null && kindDefaults.containsKey(spec.name)
          ? kindDefaults[spec.name]
          : spec.defaultValue;
      if (baseline == null && spec.defaultValue == null) return;
      _patch(spec.name, baseline);
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
