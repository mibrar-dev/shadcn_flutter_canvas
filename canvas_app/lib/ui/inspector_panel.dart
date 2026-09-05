/// Right-rail inspector: edits the selected item's props per propsSchema.
///
/// One editor row per [PropDef]: string → [shadcn.TextField], enum →
/// [shadcn.Select], bool → [shadcn.Switch]. Every edit goes through
/// `store.patchItem`, so undo/redo keep working.
///
/// Schema source: [kInspectorSchemas] mirrors the plan Task 3 `propsSchema`
/// canvas blocks for the five catalog kinds. Unknown kinds render a
/// "no editable props" note instead of crashing; unknown prop types render
/// read-only text (double/color/icon/slot editors are post-P1 scope).
///
/// Widget APIs verified in kit sources, never assumed:
/// `TextField(controller, onChanged, placeholder: Widget)` —
/// `form/text_field/_impl/core/text_field_widget.dart`;
/// `Switch(required value, required onChanged)` —
/// `form/switch/_impl/core/switch_widget.dart`;
/// `Select(value, onChanged, placeholder, itemBuilder, popup)` +
/// `SelectPopup(items: SelectItemList(...)).call` —
/// `form/select/select.dart` + `_select_preview_state.dart` reference usage.
///
/// Dogfooding rule: chrome uses registry widgets via `lib/shadcn_ui.dart` —
/// no raw Material or Cupertino widgets in here.
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;

/// One editable prop. Mirrors one `canvasProp` entry of the plan Task 1
/// contract (`name`/`type`/`enum`/`group`; `default` lives in the catalog).
class PropDef {
  /// Prop key inside [CanvasItem.props].
  final String name;

  /// One of `'string'`, `'bool'`, `'enum'`; anything else (e.g. `'double'`,
  /// `'int'`) renders read-only until an editor exists.
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

/// Per-kind schemas for the five catalog kinds. Values mirror the plan
/// Task 3 canvas blocks; labels/defaults match `component_catalog.dart`.
const kInspectorSchemas = <String, List<PropDef>>{
  'button': [
    PropDef(name: 'label', type: 'string', group: 'content'),
    PropDef(
      name: 'variant',
      type: 'enum',
      enumValues: ['primary', 'secondary', 'outline', 'ghost', 'destructive', 'link'],
      group: 'style',
    ),
    PropDef(
      name: 'size',
      type: 'enum',
      enumValues: ['sm', 'md', 'lg', 'icon'],
      group: 'style',
    ),
    PropDef(name: 'disabled', type: 'bool', group: 'state'),
  ],
  'card': [
    PropDef(name: 'title', type: 'string', group: 'content'),
    PropDef(name: 'description', type: 'string', group: 'content'),
    PropDef(name: 'showFooter', type: 'bool', group: 'state'),
  ],
  'input': [
    PropDef(name: 'placeholder', type: 'string', group: 'content'),
    PropDef(name: 'label', type: 'string', group: 'content'),
    PropDef(name: 'disabled', type: 'bool', group: 'state'),
    PropDef(name: 'obscure', type: 'bool', group: 'state'),
  ],
  'badge': [
    PropDef(name: 'label', type: 'string', group: 'content'),
    PropDef(
      name: 'variant',
      type: 'enum',
      enumValues: ['primary', 'secondary', 'destructive', 'outline'],
      group: 'style',
    ),
  ],
  'switch': [
    PropDef(name: 'value', type: 'bool', group: 'state'),
    PropDef(name: 'disabled', type: 'bool', group: 'state'),
  ],
  'avatar': [
    PropDef(name: 'initials', type: 'string', group: 'content'),
  ],
  'checkbox': [
    PropDef(name: 'value', type: 'bool', group: 'state'),
    PropDef(name: 'disabled', type: 'bool', group: 'state'),
  ],
  'divider': [
    PropDef(name: 'label', type: 'string', group: 'content'),
  ],
  // Doubles/ints have no editor yet and render read-only (see _editor).
  'progress': [
    PropDef(name: 'progress', type: 'double', group: 'state'),
  ],
  'tabs': [
    PropDef(name: 'tab1', type: 'string', group: 'content'),
    PropDef(name: 'tab2', type: 'string', group: 'content'),
  ],
  'accordion': [
    PropDef(name: 'title', type: 'string', group: 'content'),
    PropDef(name: 'content', type: 'string', group: 'content'),
    PropDef(name: 'expanded', type: 'bool', group: 'state'),
  ],
  'select': [
    PropDef(name: 'placeholder', type: 'string', group: 'content'),
    PropDef(name: 'option1', type: 'string', group: 'content'),
    PropDef(name: 'option2', type: 'string', group: 'content'),
    PropDef(name: 'value', type: 'string', group: 'state'),
  ],
  'radio_group': [
    PropDef(name: 'option1', type: 'string', group: 'content'),
    PropDef(name: 'option2', type: 'string', group: 'content'),
    PropDef(name: 'value', type: 'string', group: 'state'),
  ],
  'skeleton': [
    PropDef(name: 'label', type: 'string', group: 'content'),
    PropDef(name: 'enabled', type: 'bool', group: 'state'),
  ],
  'breadcrumb': [
    PropDef(name: 'home', type: 'string', group: 'content'),
    PropDef(name: 'current', type: 'string', group: 'content'),
  ],
  'dialog': [
    PropDef(name: 'title', type: 'string', group: 'content'),
    PropDef(name: 'message', type: 'string', group: 'content'),
    PropDef(name: 'showActions', type: 'bool', group: 'state'),
  ],
  'tooltip': [
    PropDef(name: 'label', type: 'string', group: 'content'),
    PropDef(name: 'tip', type: 'string', group: 'content'),
  ],
  'toast': [
    PropDef(name: 'title', type: 'string', group: 'content'),
    PropDef(name: 'message', type: 'string', group: 'content'),
  ],
  'drawer': [
    PropDef(name: 'title', type: 'string', group: 'content'),
    PropDef(name: 'content', type: 'string', group: 'content'),
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

  /// Per-kind schemas; defaults to [kInspectorSchemas].
  final Map<String, List<PropDef>> schemas;

  const InspectorPanel({
    super.key,
    required this.store,
    this.nodeId,
    this.itemId,
    this.schemas = kInspectorSchemas,
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
        final schema = widget.schemas[item.kind];
        if (schema == null) {
          return Center(child: Text('No editable props for kind ${item.kind}'));
        }
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
                  ..._rows(item, schema),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Container editor for a row node: badge + id + child count + gap
  /// stepper (0–32, step 4) reporting through `store.patchItem`-style
  /// undoable `store.patchNode`.
  Widget _rowCard(CanvasNode node) {
    final children = [
      for (final n in widget.store.doc.nodes)
        if (n.parentId == node.id) n,
    ];
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
                child: Text('layout'),
              ),
              Row(
                children: [
                  const Expanded(child: Text('gap')),
                  shadcn.OutlineButton(
                    size: shadcn.ButtonSize.small,
                    onPressed: node.gap > 0
                        ? () => widget.store.patchNode(
                              node.id,
                              gap: (node.gap - 4).clamp(0.0, 32.0).toDouble(),
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
                    onPressed: node.gap < 32
                        ? () => widget.store.patchNode(
                              node.id,
                              gap: (node.gap + 4).clamp(0.0, 32.0).toDouble(),
                            )
                        : null,
                    child: const Text('+'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Children are arranged on the canvas and in Layers.'),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _rows(CanvasItem item, List<PropDef> schema) {
    final rows = <Widget>[];
    var lastGroup = '';
    for (final def in schema) {
      if (def.group != lastGroup) {
        lastGroup = def.group;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(def.group),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _editor(item, def),
        ),
      );
    }
    return rows;
  }

  Widget _editor(CanvasItem item, PropDef def) {
    final current = item.props[def.name];
    switch (def.type) {
      case 'string':
        return _StringRow(
          key: ValueKey('${item.id}/${def.name}'),
          name: def.name,
          initial: (current as String?) ?? '',
          onChanged: (v) => _patch(def.name, v),
        );
      case 'bool':
        return Row(
          children: [
            Expanded(child: Text(def.name)),
            shadcn.Switch(
              value: (current as bool?) ?? false,
              onChanged: (v) => _patch(def.name, v),
            ),
          ],
        );
      case 'enum':
        final value = current as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.name),
            const SizedBox(height: 4),
            shadcn.Select<String>(
              value: def.enumValues.contains(value) ? value : null,
              placeholder: Text('Pick ${def.name}'),
              itemBuilder: (context, option) => Text(option),
              onChanged: (v) {
                if (v != null) _patch(def.name, v);
              },
              popup: shadcn.SelectPopup(
                items: shadcn.SelectItemList(
                  children: [
                    for (final option in def.enumValues)
                      shadcn.SelectItemButton(value: option, child: Text(option)),
                  ],
                ),
              ).call,
            ),
          ],
        );
      default:
        // Post-P1 types (double/color/icon/slot) render read-only for now.
        return Text('${def.name}: $current');
    }
  }
}

/// String editor owning its controller so store-echo rebuilds never reset
/// in-flight typing. Keyed by item+prop so switching selection recreates it.
class _StringRow extends StatefulWidget {
  final String name;
  final String initial;
  final ValueChanged<String> onChanged;

  const _StringRow({
    super.key,
    required this.name,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_StringRow> createState() => _StringRowState();
}

class _StringRowState extends State<_StringRow> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  late String _lastSent = widget.initial;

  @override
  void didUpdateWidget(covariant _StringRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External change only (e.g. undo): store echo of our own edit is equal
    // to [_lastSent] and must not disturb the cursor.
    if (widget.initial != _lastSent) {
      _lastSent = widget.initial;
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.name),
        const SizedBox(height: 4),
        shadcn.TextField(
          controller: _controller,
          placeholder: Text(widget.name),
          onChanged: (v) {
            _lastSent = v;
            widget.onChanged(v);
          },
        ),
      ],
    );
  }
}
