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
              const SizedBox(width: 4),
              shadcn.OutlineButton(
                size: shadcn.ButtonSize.small,
                onPressed: onReset,
                child: const Text('reset'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
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
    if (widget.max != null) out = out.clamp(double.negativeInfinity, widget.max!);
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
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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
          const SizedBox(height: 4),
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
      spacing: 4,
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

  const PropColorEditor({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hexInitial =
        value != null && value!.startsWith('#') ? value! : '';
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
        const SizedBox(height: 4),
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
        const SizedBox(width: 4),
        Expanded(child: Text(note, style: EditorType.tileLabel)),
      ],
    );
  }
}
