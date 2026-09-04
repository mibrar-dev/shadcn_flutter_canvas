/// Split theme panels for the color/shape/type/motion rail items.
///
/// Per HANDOFF P1-5, the left panel showed the same combined [ThemeBar] for
/// the color/shape/motion rail items; the shell now renders one of these four
/// panels instead. Each panel is controlled: it renders [CanvasTheme] and
/// reports edits through [ValueChanged], preserving untouched fields with full
/// `CanvasTheme(...)` copies (the `_emit` pattern from `theme_bar.dart`).
///
/// Layout: these render in the 268px left-panel column, so every panel is a
/// full-width stacked column (label above control) with [EditorMetrics]
/// spacing throughout. Each panel owns its outer padding
/// ([EditorMetrics.panelInset]) — the shell must NOT add a second layer of
/// padding around them. Chrome labels use [EditorType], chrome colors use
/// [EditorTheme]; registry widgets come via `lib/shadcn_ui.dart`.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_core/canvas_core.dart';

/// Motion ids offered by [MotionPanel].
///
/// `canvas_core` defines no motion id set: `prompt_builder.dart` only
/// interpolates `theme.motion` into the exported prompt (line 108) with no
/// enum, const list, or validation of legal values. The documented default
/// across the repo (`screen_doc_schema.dart`, `canvas_store.dart`, every test
/// fixture) is `'standard'`, so the panel offers exactly that until core
/// defines a real set.
const kMotionOptions = <String>['standard'];

/// Panel title in chrome type/color.
class _PanelTitle extends StatelessWidget {
  final String text;

  const _PanelTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Text(
      text,
      style: EditorType.sectionHeader.copyWith(color: colors.onSurface),
    );
  }
}

/// Field label above a control, in chrome type/color.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Text(
      text,
      style: EditorType.tileLabel.copyWith(color: colors.onSurface),
    );
  }
}

/// Muted one-line caption/note, in chrome type/color.
class _MutedNote extends StatelessWidget {
  final String text;

  const _MutedNote(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Text(
      text,
      style: EditorType.tileLabel.copyWith(color: colors.onSurfaceVariant),
    );
  }
}

/// String [shadcn.Select] reusing the [ThemeBar] popup idiom.
shadcn.Select<String> _optionSelect({
  required String? value,
  required String placeholder,
  required List<String> options,
  required ValueChanged<String> onSelected,
}) {
  return shadcn.Select<String>(
    value: value,
    placeholder: Text(placeholder),
    itemBuilder: (context, option) => Text(option),
    onChanged: (v) {
      if (v != null) onSelected(v);
    },
    popup: shadcn.SelectPopup(
      items: shadcn.SelectItemList(
        children: [
          for (final option in options)
            shadcn.SelectItemButton(
              value: option,
              child: Text(option),
            ),
        ],
      ),
    ).call,
  );
}

/// Outer panel chrome: own [EditorMetrics.panelInset] padding plus a
/// [shadcn.Card] holding the stacked rows.
Widget _panelShell({required List<Widget> children}) {
  return Padding(
    padding: const EdgeInsets.all(EditorMetrics.panelInset),
    child: shadcn.Card(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    ),
  );
}

/// Color panel: dark-mode [shadcn.Switch] plus palette [shadcn.Select] built
/// from [kPaletteOptions].
class ColorPanel extends StatelessWidget {
  const ColorPanel({super.key, required this.theme, required this.onChanged});

  final CanvasTheme theme;
  final ValueChanged<CanvasTheme> onChanged;

  void _emit({String? paletteKey, bool? dark}) {
    onChanged(
      CanvasTheme(
        paletteKey: paletteKey ?? theme.paletteKey,
        dark: dark ?? theme.dark,
        shape: theme.shape,
        motion: theme.motion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _panelShell(
      children: [
        const _PanelTitle('Color'),
        const SizedBox(height: EditorMetrics.panelInset),
        const _FieldLabel('Dark'),
        Align(
          alignment: Alignment.centerLeft,
          child: shadcn.Switch(
            value: theme.dark,
            onChanged: (v) => _emit(dark: v),
          ),
        ),
        const SizedBox(height: EditorMetrics.panelInset),
        const _FieldLabel('Palette'),
        _optionSelect(
          value: kPaletteOptions.contains(theme.paletteKey)
              ? theme.paletteKey
              : null,
          placeholder: 'Palette',
          options: kPaletteOptions,
          onSelected: (v) => _emit(paletteKey: v),
        ),
      ],
    );
  }
}

/// Shape panel: shape [shadcn.Select] from [kShapeOptions] plus a muted
/// one-line caption of what it does (the `ThemeData` radius multiplier).
class ShapePanel extends StatelessWidget {
  const ShapePanel({super.key, required this.theme, required this.onChanged});

  final CanvasTheme theme;
  final ValueChanged<CanvasTheme> onChanged;

  void _emit({String? shape}) {
    onChanged(
      CanvasTheme(
        paletteKey: theme.paletteKey,
        dark: theme.dark,
        shape: shape ?? theme.shape,
        motion: theme.motion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = kShapeRadii[theme.shape];
    return _panelShell(
      children: [
        const _PanelTitle('Shape'),
        const SizedBox(height: EditorMetrics.panelInset),
        const _FieldLabel('Shape'),
        _optionSelect(
          value: kShapeOptions.contains(theme.shape) ? theme.shape : null,
          placeholder: 'Shape',
          options: kShapeOptions,
          onSelected: (v) => _emit(shape: v),
        ),
        const SizedBox(height: EditorMetrics.panelInset),
        _MutedNote(
          radius == null
              ? 'Sets the ThemeData radius multiplier.'
              : 'Sets the ThemeData radius multiplier ($radius).',
        ),
      ],
    );
  }
}

/// Type panel placeholder: [CanvasTheme] (frozen in canvas_core) has exactly
/// paletteKey/dark/shape/motion and NO type field, so there is nothing to
/// edit. Renders a muted note instead. [theme] and [onChanged] exist only so
/// the shell can treat all four panels uniformly; both are intentionally
/// unused.
class TypePanel extends StatelessWidget {
  const TypePanel({super.key, required this.theme, required this.onChanged});

  final CanvasTheme theme;
  final ValueChanged<CanvasTheme> onChanged;

  @override
  Widget build(BuildContext context) {
    return _panelShell(
      children: const [
        _PanelTitle('Type'),
        SizedBox(height: EditorMetrics.panelInset),
        _MutedNote('Type follows the palette preset.'),
      ],
    );
  }
}

/// Motion panel: motion [shadcn.Select] with options from [kMotionOptions].
class MotionPanel extends StatelessWidget {
  const MotionPanel({super.key, required this.theme, required this.onChanged});

  final CanvasTheme theme;
  final ValueChanged<CanvasTheme> onChanged;

  void _emit({String? motion}) {
    onChanged(
      CanvasTheme(
        paletteKey: theme.paletteKey,
        dark: theme.dark,
        shape: theme.shape,
        motion: motion ?? theme.motion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _panelShell(
      children: [
        const _PanelTitle('Motion'),
        const SizedBox(height: EditorMetrics.panelInset),
        const _FieldLabel('Motion'),
        _optionSelect(
          value: kMotionOptions.contains(theme.motion) ? theme.motion : null,
          placeholder: 'Motion',
          options: kMotionOptions,
          onSelected: (v) => _emit(motion: v),
        ),
      ],
    );
  }
}
