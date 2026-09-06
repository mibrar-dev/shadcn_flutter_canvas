/// One editor widget per schema control type, token-styled.
///
/// Editors are dumb: every edit reports through the `onChanged` callback the
/// caller passes in (the inspector wires those to `store.patchItem` for leaf
/// props and `store.patchNode` for container props, so undo/redo keep
/// working). Text-bearing editors own their `TextEditingController` and
/// ignore store-echo rebuilds, mirroring the `_StringRow` pattern from
/// `inspector_panel.dart` (no cursor jumps while typing).
///
/// Chrome uses registry widgets via `lib/shadcn_ui.dart` — no raw Material
/// or Cupertino interactive widgets in here. Labels follow [EditorType].
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';

/// Intra-editor vertical rhythm (label → editor, editor → slider): one step
/// of the inspector 8px rhythm (see `inspector_panel.dart`). Tiny inline gaps
/// (badge → reset, stepper buttons → field) reuse
/// [EditorMetrics.toolbarButtonGap] instead.
const double _kEditorGap = 8.0;

/// Theme `ColorScheme` keys a `color` control may bind to as a token, plus
/// free-form literal hex via the sibling text field.
const kColorTokenKeys = [
  'background',
  'foreground',
  'card',
  'primary',
  'secondary',
  'muted',
  'accent',
  'destructive',
  'border',
  'ring',
];

/// Section wrapper for one prop: name label + override badge + reset
/// affordance above the editor itself. [onReset] is only invoked from the
/// reset button, which only renders when [overridden] is true.
class PropShell extends StatelessWidget {
  final String name;
  final bool overridden;
  final VoidCallback? onReset;
  final Widget child;

  const PropShell({
    super.key,
    required this.name,
    required this.overridden,
    required this.onReset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: EditorType.tileLabel)),
            if (overridden) ...[
              shadcn.SecondaryBadge(child: Text('modified')),
              const SizedBox(width: EditorMetrics.toolbarButtonGap),
              shadcn.OutlineButton(
                size: shadcn.ButtonSize.small,
                onPressed: onReset,
                child: const Text('reset'),
              ),
            ],
          ],
        ),
        const SizedBox(height: _kEditorGap),
        child,
      ],
    );
  }
}

/// Controller-owning text field shared by the text/number-hex editors.
/// Store-echo rebuilds only rewrite the controller when the incoming
/// [initial] differs from the last emitted value, so in-flight typing and
/// cursor position survive parent rebuilds.
class PropTextEditor extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final String? placeholderLabel;
  final TextInputType keyboardType;

  const PropTextEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.placeholderLabel,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<PropTextEditor> createState() => PropTextEditorState();
}

/// Public state so tests can drive the controller without keystrokes.
class PropTextEditorState extends State<PropTextEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  late String _lastSent = widget.initial;

  @override
  void didUpdateWidget(covariant PropTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    return shadcn.TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      placeholder: Text(widget.placeholderLabel ?? ''),
      onChanged: (v) {
        _lastSent = v;
        widget.onChanged(v);
      },
    );
  }
}

/// Number editor: stepper (−/field/+) plus a slider when [min]/[max] are
/// both known. [onChanged] always receives the clamped value; integral
/// specs ([isInt]) round to whole numbers before reporting.
class PropNumberEditor extends StatefulWidget {
  final double value;
  final double? min;
  final double? max;
  final double step;
  final bool isInt;
  final ValueChanged<double> onChanged;

  const PropNumberEditor({
    super.key,
    required this.value,
    this.min,
    this.max,
    required this.step,
    this.isInt = false,
    required this.onChanged,
  });

  @override
  State<PropNumberEditor> createState() => _PropNumberEditorState();
}

String _formatNumber(double value, bool isInt) {
  if (isInt) return value.toInt().toString();
  if (value == value.toInt()) return value.toInt().toString();
  return value.toString();
}

class _PropNumberEditorState extends State<PropNumberEditor> {
  double _clamp(double v) {
    var out = v;
    if (widget.min != null) out = out.clamp(widget.min!, double.infinity);
    if (widget.max != null)
      out = out.clamp(double.negativeInfinity, widget.max!);
    return out;
  }

  void _nudge(double delta) {
    final next = _clamp(widget.value + delta);
    widget.onChanged(widget.isInt ? next.toInt().toDouble() : next);
  }

  @override
  Widget build(BuildContext context) {
    final ranged = widget.min != null && widget.max != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            shadcn.OutlineButton(
              size: shadcn.ButtonSize.small,
              onPressed: widget.min == null || widget.value > widget.min!
                  ? () => _nudge(-widget.step)
                  : null,
              child: const Text('−'),
            ),
            const SizedBox(width: EditorMetrics.toolbarButtonGap),
            Expanded(
              // No ValueKey here: [PropTextEditor] absorbs store echo via
              // its last-sent check, so a stable identity preserves the
              // cursor across keystroke-driven rebuilds.
              child: PropTextEditor(
                initial: _formatNumber(widget.value, widget.isInt),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed == null) return;
                  final next = _clamp(parsed);
                  widget.onChanged(
                    widget.isInt ? next.toInt().toDouble() : next,
                  );
                },
              ),
            ),
            const SizedBox(width: EditorMetrics.toolbarButtonGap),
            shadcn.OutlineButton(
              size: shadcn.ButtonSize.small,
              onPressed: widget.max == null || widget.value < widget.max!
                  ? () => _nudge(widget.step)
                  : null,
              child: const Text('+'),
            ),
          ],
        ),
        if (ranged) ...[
          const SizedBox(height: _kEditorGap),
          shadcn.Slider(
            value: _clamp(widget.value),
            min: widget.min!,
            max: widget.max!,
            onChanged: (v) => widget.onChanged(
              widget.isInt ? v.toInt().toDouble() : v,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bool editor: a single registry switch (the [PropShell] header carries the
/// prop name, so no label duplication).
class PropSwitchEditor extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const PropSwitchEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: shadcn.Switch(value: value, onChanged: onChanged),
    );
  }
}

/// Enum dropdown for > 3 options (segmented control below otherwise).
class PropSelectEditor extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String placeholderLabel;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const PropSelectEditor({
    super.key,
    required this.value,
    required this.options,
    required this.placeholderLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return shadcn.Select<String>(
      value: options.contains(value) ? value : null,
      enabled: enabled,
      placeholder: Text(placeholderLabel),
      itemBuilder: (context, option) => Text(option),
      onChanged: onChanged,
      popup: shadcn.SelectPopup(
        items: shadcn.SelectItemList(
          children: [
            for (final option in options)
              shadcn.SelectItemButton(value: option, child: Text(option)),
          ],
        ),
      ).call,
    );
  }
}

/// Enum segmented control for <= 3 options: one small button per option,
/// the active one filled. Built from registry buttons (the kit ships no
/// segmented widget).
class PropSegmentedEditor extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const PropSegmentedEditor({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: EditorMetrics.toolbarButtonGap,
      runSpacing: EditorMetrics.toolbarButtonGap,
      children: [
        for (final option in options)
          if (option == value)
            shadcn.PrimaryButton(
              size: shadcn.ButtonSize.small,
              onPressed: () => onChanged(option),
              child: Text(option),
            )
          else
            shadcn.OutlineButton(
              size: shadcn.ButtonSize.small,
              onPressed: () => onChanged(option),
              child: Text(option),
            ),
      ],
    );
  }
}

/// Color editor: theme-palette token dropdown plus a literal-hex text field.
/// A value naming a token selects it; a `#…` value pre-fills the hex field.
class PropColorEditor extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const PropColorEditor(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hexInitial = value != null && value!.startsWith('#') ? value! : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropSelectEditor(
          value: value,
          options: kColorTokenKeys,
          placeholderLabel: 'Pick a token',
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        const SizedBox(height: _kEditorGap),
        PropTextEditor(
          initial: hexInitial,
          placeholderLabel: '#rrggbb',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Slot editor (widget/child props): read-only chip for now — reparenting UI
/// is out of scope.
class PropSlotEditor extends StatelessWidget {
  final String label;

  const PropSlotEditor({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return shadcn.SecondaryBadge(child: Text(label));
  }
}

/// Track F4 box-model editor for `edgeInsets` props (container
/// padding/margin, padding primitive).
///
/// Parses the same shapes as the catalog builders (tagged envelope, raw num,
/// raw `{l,t,r,b}` map; absent/unparseable → zeros) and always writes the
/// canonical raw `{l,t,r,b}` map — builders and both codegen emitters read
/// it back identically (the emitters collapse uniform maps to `.all` /
/// `.symmetric` per §6.1, so this editor never writes envelopes).
/// Four compact labeled steppers (left/top/right/bottom), reusing
/// [PropNumberEditor] so stepping/clamping/typing behave exactly like every
/// other number prop.
///
/// FF6 (BUILD_SPEC §9.2-5b): an `All` stepper below the four sides plus a
/// uniformity/symmetry readout (`All sides equal` / `Symmetric sides` /
/// `Mixed sides`). The `All` row uses icon steppers (never text `+`/`-`,
/// the `_nodeSizeRow` precedent in `inspector_panel.dart`) and its readout
/// shows the shared value only while uniform, `Mixed` otherwise — so the
/// per-side `+` steppers keep their tree order AND no numeric readout is
/// ever duplicated (see `f4_primitive_editors_test.dart`, which taps the
/// first `+` and pins a unique `8`). Stepping `All` writes a uniform map
/// seeded from the left value (mixed re-unforms — the same documented
/// compromise as [PropBorderRadiusEditor]'s `radius-all`).
class PropEdgeInsetsEditor extends StatelessWidget {
  final Map<String, double> value;
  final ValueChanged<Map<String, double>> onChanged;

  const PropEdgeInsetsEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Lenient parse shared with the inspector wiring below (never a throw).
  static Map<String, double> parse(Object? raw) {
    double n(Object? x) => x is num ? x.toDouble() : 0.0;
    if (raw is num) {
      final d = raw.toDouble();
      return {'l': d, 't': d, 'r': d, 'b': d};
    }
    if (raw is Map) {
      final Map v = (raw[r'$'] == 'edgeInsets' && raw['v'] is Map)
          ? raw['v'] as Map
          : raw;
      if (v.keys.any((k) => k == 'l' || k == 't' || k == 'r' || k == 'b')) {
        return {'l': n(v['l']), 't': n(v['t']), 'r': n(v['r']), 'b': n(v['b'])};
      }
    }
    return {'l': 0, 't': 0, 'r': 0, 'b': 0};
  }

  @override
  Widget build(BuildContext context) {
    const sides = ['l', 't', 'r', 'b'];
    const labels = {'l': 'Left', 't': 'Top', 'r': 'Right', 'b': 'Bottom'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sides.length; i++) ...[
          if (i > 0) const SizedBox(height: _kEditorGap),
          Row(
            children: [
              SizedBox(
                width: _kEdgeLabelWidth,
                child: Text(labels[sides[i]]!, style: EditorType.tileLabel),
              ),
              Expanded(
                child: PropNumberEditor(
                  key: ValueKey('edge-${sides[i]}'),
                  value: value[sides[i]] ?? 0,
                  min: 0,
                  step: 4,
                  onChanged: (v) => onChanged({...value, sides[i]: v}),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: _kEditorGap),
        Builder(
          builder: (context) {
            final l = value['l'] ?? 0;
            final t = value['t'] ?? 0;
            final r = value['r'] ?? 0;
            final b = value['b'] ?? 0;
            final uniform = l == t && t == r && r == b;
            Map<String, double> all(double v) =>
                {'l': v, 't': v, 'r': v, 'b': v};
            return Row(
              children: [
                const SizedBox(
                  width: _kEdgeLabelWidth,
                  child: Text('All', style: EditorType.tileLabel),
                ),
                shadcn.OutlineButton(
                  key: const ValueKey('edge-all-dec'),
                  size: shadcn.ButtonSize.small,
                  onPressed: l <= 0
                      ? null
                      : () => onChanged(
                            all((l - _kEdgeAllStep)
                                .clamp(0.0, double.infinity)
                                .toDouble()),
                          ),
                  child: const Icon(Icons.remove, size: _kEdgeIconSize),
                ),
                SizedBox(
                  width: _kEdgeAllValueWidth,
                  child: Text(
                    uniform ? _formatNumber(l, false) : 'Mixed',
                    key: const ValueKey('edge-all-value'),
                    textAlign: TextAlign.center,
                  ),
                ),
                shadcn.OutlineButton(
                  key: const ValueKey('edge-all-inc'),
                  size: shadcn.ButtonSize.small,
                  onPressed: () => onChanged(all(l + _kEdgeAllStep)),
                  child: const Icon(Icons.add, size: _kEdgeIconSize),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: _kEditorGap),
        Text(
          _symmetryLabel(value),
          key: const ValueKey('edge-symmetry'),
          style: EditorType.tileLabel,
        ),
      ],
    );
  }

  /// Uniformity/symmetry readout for the four sides: uniform (all equal)
  /// collapses to `.all` downstream, left==right && top==bottom collapses
  /// to `.symmetric`, anything else stays an explicit `fromLTRB`.
  static String _symmetryLabel(Map<String, double> value) {
    final l = value['l'] ?? 0;
    final t = value['t'] ?? 0;
    final r = value['r'] ?? 0;
    final b = value['b'] ?? 0;
    if (l == t && t == r && r == b) return 'All sides equal';
    if (l == r && t == b) return 'Symmetric sides';
    return 'Mixed sides';
  }
}

/// Track F4 alignment grid for `alignment` props (stack/align/container).
///
/// Nine small buttons writing the named `Alignment` constants
/// (`topLeft`…`bottomRight`, `center`); the active one fills. Values that
/// are not named constants (tagged `{x,y}` maps, raw maps) show no active
/// button but stay pickable — picking writes the name. Pure props, no store
/// import (same contract as every other editor here).
class PropAlignmentGrid extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const PropAlignmentGrid(
      {super.key, required this.value, required this.onChanged});

  static const names = [
    ['topLeft', 'topCenter', 'topRight'],
    ['centerLeft', 'center', 'centerRight'],
    ['bottomLeft', 'bottomCenter', 'bottomRight'],
  ];

  /// Lenient read: named strings pass through; anything else (tagged/raw
  /// maps, null) shows no selection.
  static String? read(Object? raw) => raw is String ? raw : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in names)
          Padding(
            padding: const EdgeInsets.only(bottom: _kEditorGap),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0)
                    const SizedBox(width: EditorMetrics.toolbarButtonGap),
                  Expanded(
                    child: value == row[i]
                        ? shadcn.PrimaryButton(
                            size: shadcn.ButtonSize.small,
                            onPressed: () => onChanged(row[i]),
                            child: Text(row[i]),
                          )
                        : shadcn.OutlineButton(
                            size: shadcn.ButtonSize.small,
                            onPressed: () => onChanged(row[i]),
                            child: Text(row[i]),
                          ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Track F4 paint editor for `paint` props (container `color`).
///
/// The §6.1 rule lives here: the token path writes the tagged envelope
/// (`{"$":"color","v":{"kind":"token","token"}}`), which both codegen
/// emitters resolve to a `Theme.of(context).colorScheme` accessor — never a
/// raw hex for a token-bound value. The literal path writes the raw
/// `#rrggbb` string the catalog builders (`_primParseHex`) and both
/// emitters (`Color(0xFF…)`) already read. Typing a hex replaces a token
/// envelope outright; unsetting rides the shared [PropShell] reset
/// (sparse delete), so this editor never needs a null write.
class PropPaintEditor extends StatelessWidget {
  final String? token;
  final String hex;
  final ValueChanged<Object?> onChanged;

  const PropPaintEditor({
    super.key,
    required this.token,
    required this.hex,
    required this.onChanged,
  });

  /// Lenient read of every color shape the builders accept (tagged token /
  /// literal envelopes, bare `{kind, …}` maps, raw int ARGB, `#…` strings).
  /// Absent/unparseable → no token, empty hex (never a throw).
  static ({String? token, String hex}) parse(Object? raw) {
    String hexOf(int argb) =>
        '#${argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';
    if (raw is String) return (token: null, hex: raw);
    if (raw is int) return (token: null, hex: hexOf(raw));
    if (raw is Map) {
      final Object? v =
          (raw[r'$'] == 'color' && raw['v'] is Map) ? raw['v'] : raw;
      if (v is Map) {
        if (v['kind'] == 'token' && v['token'] is String) {
          return (token: v['token'] as String, hex: '');
        }
        if (v['kind'] == 'literal' && v['argb'] is num) {
          return (
            token: null,
            hex: hexOf((v['argb'] as num).toInt()),
          );
        }
      }
    }
    return (token: null, hex: '');
  }

  /// Tagged token envelope for [token] (the §6.1 token path).
  static Map<String, Object?> tokenEnvelope(String token) => {
        r'$': 'color',
        'v': {'kind': 'token', 'token': token}
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropSelectEditor(
          value: token,
          options: kColorTokenKeys,
          placeholderLabel: 'Pick a token',
          onChanged: (v) {
            if (v != null) onChanged(tokenEnvelope(v));
          },
        ),
        const SizedBox(height: _kEditorGap),
        PropTextEditor(
          initial: hex,
          placeholderLabel: '#rrggbb',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Track F4 radius editor for `borderRadius` props (container `radius`).
///
/// Parses the tagged envelope, a raw num (uniform), and raw corner maps;
/// absent/unparseable → zeros. Writes are collapse-aware: uniform corners
/// collapse to the raw num so both emitters emit `BorderRadius.circular`
/// (§6.1), mixed corners keep the tagged envelope. The `All` stepper seeds
/// from top-left while mixed (documented), so stepping it re-unforms.
class PropBorderRadiusEditor extends StatelessWidget {
  final Map<String, double> value;
  final ValueChanged<Object?> onChanged;

  const PropBorderRadiusEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Lenient parse shared with the inspector wiring below (never a throw).
  static Map<String, double> parse(Object? raw) {
    double n(Object? x) => x is num ? x.toDouble() : 0.0;
    if (raw is num) {
      final d = raw.toDouble();
      return {'tl': d, 'tr': d, 'br': d, 'bl': d};
    }
    if (raw is Map) {
      final Map v = (raw[r'$'] == 'borderRadius' && raw['v'] is Map)
          ? raw['v'] as Map
          : raw;
      if (v.keys.any((k) => k == 'tl' || k == 'tr' || k == 'br' || k == 'bl')) {
        return {
          'tl': n(v['tl']),
          'tr': n(v['tr']),
          'br': n(v['br']),
          'bl': n(v['bl']),
        };
      }
    }
    return {'tl': 0.0, 'tr': 0.0, 'br': 0.0, 'bl': 0.0};
  }

  /// Collapse-aware write (see the class docs).
  static Object? collapse(Map<String, double> v) {
    final tl = v['tl'] ?? 0.0;
    final tr = v['tr'] ?? 0.0;
    final br = v['br'] ?? 0.0;
    final bl = v['bl'] ?? 0.0;
    if (tl == tr && tr == br && br == bl) return tl;
    return {
      r'$': 'borderRadius',
      'v': {'tl': tl, 'tr': tr, 'br': br, 'bl': bl},
    };
  }

  @override
  Widget build(BuildContext context) {
    const corners = ['tl', 'tr', 'br', 'bl'];
    const labels = {
      'tl': 'Top left',
      'tr': 'Top right',
      'br': 'Bottom right',
      'bl': 'Bottom left',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: _kCompositeLabelWidth,
              child: const Text('All', style: EditorType.tileLabel),
            ),
            Expanded(
              child: PropNumberEditor(
                key: const ValueKey('radius-all'),
                // Seeds from top-left while mixed (see the class docs):
                // stepping re-unforms to the raw-num write.
                value: value['tl'] ?? 0.0,
                min: 0,
                step: 4,
                onChanged: (v) => onChanged(v),
              ),
            ),
          ],
        ),
        for (final corner in corners) ...[
          const SizedBox(height: _kEditorGap),
          Row(
            children: [
              SizedBox(
                width: _kCompositeLabelWidth,
                child: Text(labels[corner]!, style: EditorType.tileLabel),
              ),
              Expanded(
                child: PropNumberEditor(
                  key: ValueKey('radius-$corner'),
                  value: value[corner] ?? 0.0,
                  min: 0,
                  step: 4,
                  onChanged: (v) => onChanged(collapse({...value, corner: v})),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Track F4 border editor for `border` props (container `border`).
///
/// The `{color, width}` map both emitters read (`Border.all…`, width
/// defaulting to 1 when absent): a width stepper plus a nested paint editor
/// for the color (any color shape in, same shape family out). Parses
/// leniently; maps without either key read as the default (width 1, no
/// color → builder black, emitter `Color(0xFF000000)` — never a crash).
class PropBorderEditor extends StatelessWidget {
  final Object? color;
  final double width;
  final ValueChanged<Map<String, Object?>> onChanged;

  const PropBorderEditor({
    super.key,
    required this.color,
    required this.width,
    required this.onChanged,
  });

  /// Lenient parse shared with the inspector wiring below (never a throw).
  static ({Object? color, double width}) parse(Object? raw) {
    if (raw is Map && (raw.containsKey('color') || raw.containsKey('width'))) {
      final w = raw['width'];
      return (
        color: raw['color'],
        width: w is num ? w.toDouble() : 1.0,
      );
    }
    return (color: null, width: 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final paint = PropPaintEditor.parse(color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: _kCompositeLabelWidth,
              child: const Text('Width', style: EditorType.tileLabel),
            ),
            Expanded(
              child: PropNumberEditor(
                key: const ValueKey('border-width'),
                value: width,
                min: 0,
                step: 1,
                onChanged: (v) => onChanged({'color': color, 'width': v}),
              ),
            ),
          ],
        ),
        const SizedBox(height: _kEditorGap),
        PropPaintEditor(
          token: paint.token,
          hex: paint.hex,
          onChanged: (c) => onChanged({'color': c, 'width': width}),
        ),
      ],
    );
  }
}

/// Named-alignment ↔ `{x,y}` table for gradient ends (coordinates mirror
/// the emitter-side `AlignmentValue` named constants; `{x,y}` maps are the
/// one shape both the catalog builders and both emitters read for ends —
/// named strings would fall back silently, so the selects below map
/// name → map on write and map → name on read).
const kGradientAlignXy = {
  'topLeft': (-1.0, -1.0),
  'topCenter': (0.0, -1.0),
  'topRight': (1.0, -1.0),
  'centerLeft': (-1.0, 0.0),
  'center': (0.0, 0.0),
  'centerRight': (1.0, 0.0),
  'bottomLeft': (-1.0, 1.0),
  'bottomCenter': (0.0, 1.0),
  'bottomRight': (1.0, 1.0),
};

/// Track F4 gradient editor for `gradient` props (container `gradient`).
///
/// Edits the `{begin, end, colors}` map both emitters read (`LinearGradient`
/// with `centerLeft → centerRight` defaults, per-stop token-or-literal
/// colors, optional stops omitted — absent stops stay absent): begin/end
/// selects over the nine named alignments plus a stop list where every stop
/// is a nested paint editor with add/remove. Writes always carry resolved
/// `{x,y}` ends (defaults when unset) so canvas and codegen never disagree.
/// Empty colors / unparseable stops degrade to no-gradient downstream
/// (never a partial gradient, never a crash).
class PropGradientEditor extends StatelessWidget {
  final List<Object?> colors;
  final String? beginName;
  final String? endName;
  final ValueChanged<Map<String, Object?>> onChanged;

  const PropGradientEditor({
    super.key,
    required this.colors,
    required this.beginName,
    required this.endName,
    required this.onChanged,
  });

  static String? _nameOf(Object? v) {
    if (v is String && kGradientAlignXy.containsKey(v)) return v;
    if (v is Map && v['x'] is num && v['y'] is num) {
      final x = (v['x'] as num).toDouble();
      final y = (v['y'] as num).toDouble();
      for (final entry in kGradientAlignXy.entries) {
        if (entry.value.$1 == x && entry.value.$2 == y) return entry.key;
      }
    }
    return null;
  }

  /// Lenient parse shared with the inspector wiring below (never a throw).
  static ({List<Object?> colors, String? beginName, String? endName}) parse(
    Object? raw,
  ) {
    if (raw is Map) {
      final c = raw['colors'];
      return (
        colors: c is List ? List<Object?>.from(c) : <Object?>[],
        beginName: _nameOf(raw['begin']),
        endName: _nameOf(raw['end']),
      );
    }
    return (colors: <Object?>[], beginName: null, endName: null);
  }

  static Map<String, double> _xy(String? name, (double, double) fallback) {
    final pair = name == null ? null : kGradientAlignXy[name];
    final (x, y) = pair ?? fallback;
    return {'x': x, 'y': y};
  }

  void _commit(List<Object?> next, String? begin, String? end) => onChanged({
        'begin': _xy(begin, (-1.0, 0.0)),
        'end': _xy(end, (1.0, 0.0)),
        'colors': next,
      });

  @override
  Widget build(BuildContext context) {
    const names = [
      'topLeft',
      'topCenter',
      'topRight',
      'centerLeft',
      'center',
      'centerRight',
      'bottomLeft',
      'bottomCenter',
      'bottomRight',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PropSelectEditor(
          value: beginName,
          options: names,
          placeholderLabel: 'Begin (center-left)',
          onChanged: (v) => _commit(colors, v ?? beginName, endName),
        ),
        const SizedBox(height: _kEditorGap),
        PropSelectEditor(
          value: endName,
          options: names,
          placeholderLabel: 'End (center-right)',
          onChanged: (v) => _commit(colors, beginName, v ?? endName),
        ),
        const SizedBox(height: _kEditorGap),
        for (var i = 0; i < colors.length; i++) ...[
          if (i > 0) const SizedBox(height: _kEditorGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                key: ValueKey('gradient-stop-$i'),
                child: Builder(
                  builder: (context) {
                    final paint = PropPaintEditor.parse(colors[i]);
                    return PropPaintEditor(
                      token: paint.token,
                      hex: paint.hex,
                      onChanged: (c) {
                        final next = List<Object?>.from(colors);
                        next[i] = c;
                        _commit(next, beginName, endName);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: EditorMetrics.toolbarButtonGap),
              shadcn.OutlineButton(
                key: ValueKey('gradient-remove-$i'),
                size: shadcn.ButtonSize.small,
                onPressed: () {
                  final next = List<Object?>.from(colors)..removeAt(i);
                  _commit(next, beginName, endName);
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
        if (colors.isNotEmpty) const SizedBox(height: _kEditorGap),
        shadcn.OutlineButton(
          key: const ValueKey('gradient-add'),
          size: shadcn.ButtonSize.small,
          onPressed: () => _commit(
            [...colors, PropPaintEditor.tokenEnvelope('primary')],
            beginName,
            endName,
          ),
          child: const Text('Add stop'),
        ),
      ],
    );
  }
}

/// Default shadow entry appended by [PropShadowEditor] (user-data defaults,
/// not chrome constants): a token-bound color (never a literal), a soft
/// blur, and a small downward offset.
Map<String, Object?> newShadowEntry() => {
      'color': PropPaintEditor.tokenEnvelope('primary'),
      'blur': 4.0,
      'offset': {'x': 0.0, 'y': 2.0},
      'spread': 0.0,
    };

/// Track F4 shadow editor for `shadow` props (container `shadow`).
///
/// Edits the `[{color, blur, offset, spread?}]` list both emitters read
/// (`boxShadow:`, skipped entries never crash): per entry a nested paint
/// editor for the color plus blur / offset-X / offset-Y / spread steppers
/// (offsets unbounded — shadows point any direction), with per-entry
/// remove and one add. Parses leniently (non-maps dropped, numbers
/// defaulted); an emptied list degrades to no-shadow downstream.
class PropShadowEditor extends StatelessWidget {
  final List<Map<String, Object?>> entries;
  final ValueChanged<List<Map<String, Object?>>> onChanged;

  const PropShadowEditor({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  /// Lenient parse shared with the inspector wiring below (never a throw).
  static List<Map<String, Object?>> parse(Object? raw) {
    if (raw is! List) return [];
    return [
      for (final s in raw)
        if (s is Map) Map<String, Object?>.from(s),
    ];
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0.0;

  static ({double x, double y}) _offsetOf(Object? v) {
    if (v is Map) return (x: _num(v['x']), y: _num(v['y']));
    return (x: 0.0, y: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: _kEditorGap),
          Column(
            key: ValueKey('shadow-entry-$i'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final paint = PropPaintEditor.parse(entries[i]['color']);
                  return PropPaintEditor(
                    token: paint.token,
                    hex: paint.hex,
                    onChanged: (c) {
                      final next = [
                        for (final e in entries) Map<String, Object?>.from(e),
                      ];
                      next[i]['color'] = c;
                      onChanged(next);
                    },
                  );
                },
              ),
              const SizedBox(height: _kEditorGap),
              _stepperRow(
                label: 'Blur',
                value: _num(entries[i]['blur']),
                min: 0,
                onChanged: (v) {
                  final next = [
                    for (final e in entries) Map<String, Object?>.from(e),
                  ];
                  next[i]['blur'] = v;
                  onChanged(next);
                },
              ),
              const SizedBox(height: _kEditorGap),
              _stepperRow(
                label: 'Offset X',
                value: _offsetOf(entries[i]['offset']).x,
                onChanged: (v) {
                  final next = [
                    for (final e in entries) Map<String, Object?>.from(e),
                  ];
                  final o = _offsetOf(next[i]['offset']);
                  next[i]['offset'] = {'x': v, 'y': o.y};
                  onChanged(next);
                },
              ),
              const SizedBox(height: _kEditorGap),
              _stepperRow(
                label: 'Offset Y',
                value: _offsetOf(entries[i]['offset']).y,
                onChanged: (v) {
                  final next = [
                    for (final e in entries) Map<String, Object?>.from(e),
                  ];
                  final o = _offsetOf(next[i]['offset']);
                  next[i]['offset'] = {'x': o.x, 'y': v};
                  onChanged(next);
                },
              ),
              const SizedBox(height: _kEditorGap),
              _stepperRow(
                label: 'Spread',
                value: _num(entries[i]['spread']),
                min: 0,
                onChanged: (v) {
                  final next = [
                    for (final e in entries) Map<String, Object?>.from(e),
                  ];
                  next[i]['spread'] = v;
                  onChanged(next);
                },
              ),
              const SizedBox(height: _kEditorGap),
              shadcn.OutlineButton(
                key: ValueKey('shadow-remove-$i'),
                size: shadcn.ButtonSize.small,
                onPressed: () {
                  final next = [
                    for (final e in entries) Map<String, Object?>.from(e),
                  ]..removeAt(i);
                  onChanged(next);
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
        if (entries.isNotEmpty) const SizedBox(height: _kEditorGap),
        shadcn.OutlineButton(
          key: const ValueKey('shadow-add'),
          size: shadcn.ButtonSize.small,
          onPressed: () => onChanged([...entries, newShadowEntry()]),
          child: const Text('Add shadow'),
        ),
      ],
    );
  }

  /// Labeled stepper row shared by the shadow numeric fields (same
  /// caption width as the border/radius rows above).
  Widget _stepperRow({
    required String label,
    required double value,
    double? min,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: _kCompositeLabelWidth,
          child: Text(label, style: EditorType.tileLabel),
        ),
        Expanded(
          child: PropNumberEditor(
            value: value,
            min: min,
            step: 1,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Side-label width for the [PropEdgeInsetsEditor] rows (left/top/right/
/// bottom plus the FF6 `All` row): a single named constant per the
/// no-magic-numbers rule.
const double _kEdgeLabelWidth = 64.0;

/// FF6 `All`-row step (matches the per-side step above) and readout width
/// (mirrors the zoom/size readout role — see `EditorMetrics.zoomLabelWidth`
/// and the inspector's own gap-value width).
const double _kEdgeAllStep = 4.0;
const double _kEdgeAllValueWidth = 48.0;

/// Icon-stepper glyph size for the FF6 `All` row (the `_nodeSizeRow`
/// precedent in `inspector_panel.dart` uses text-free icon steppers so the
/// row-gap `find.text('+')` suites keep their unique match).
const double _kEdgeIconSize = 16.0;

/// Caption width for the composite Track F4 editors above (border width,
/// radius corners, shadow numerics): one step wider than the edge-insets
/// side labels, a single named constant per the no-magic-numbers rule.
const double _kCompositeLabelWidth = 72.0;

/// Disabled-editor marker for dictated store params that have not landed
/// yet (W3 `patchNode` params): a TODO chip plus the reason.
class TodoChip extends StatelessWidget {
  final String note;

  const TodoChip({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        shadcn.SecondaryBadge(child: const Text('TODO')),
        const SizedBox(width: EditorMetrics.toolbarButtonGap),
        Expanded(child: Text(note, style: EditorType.tileLabel)),
      ],
    );
  }
}
