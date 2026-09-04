/// Top theme bar: light/dark toggle + palette preset + shape radius.
///
/// No `wrapPreviewTheme`-style helper exists in the kit (verified: grep for
/// `wrapPreviewTheme` across the kit package finds nothing), so this file
/// provides the minimal application instead:
/// [resolveCanvasThemeData] picks the preset matching
/// [CanvasTheme.paletteKey] (falling back to `registryThemePresets.first`
/// for unknown keys such as the store default `'slate'`), builds kit
/// [ThemeData] via [AppTheme] — which reads the global
/// `InstalledThemePreset.current`, set here as a documented side effect
/// because `AppTheme._build` is private — then overrides the radius from
/// [kShapeRadii]. [ThemedCanvas] wraps a subtree with the kit [Theme] so the
/// canvas renders under the selection.
///
/// [ThemeBar] itself is a controlled widget: it renders [theme] and reports
/// edits through [onChanged]. `CanvasStore` exposes no theme setter, so the
/// host wires the callback (a future `setTheme` on the store can replace the
/// callback without touching this file's UI).
///
/// Dogfooding rule: chrome uses registry widgets via `lib/shadcn_ui.dart` —
/// no raw Material or Cupertino widgets in here.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;

/// Palette ids offered by the bar. All verified present in
/// `registryThemePresets` (`registry/shared/theme/preset_themes.dart`).
const kPaletteOptions = <String>[
  'clean-slate',
  'amber-minimal',
  'mono',
  'neo-brutalism',
  'ocean-breeze',
  'supabase',
  't3-chat',
];

/// Shape ids offered by the bar. Mirrors the `_radii` keys in
/// `canvas/prompt_builder.dart` so bar and exporter agree.
const kShapeOptions = <String>['sharp', 'rounded', 'pill'];

/// Minimal shape → `ThemeData.radius` multiplier map. `ThemeData.radius`
/// defaults to 0.5 ("base radius multiplier"); sharp removes rounding and
/// pill maxes it out. Documented approximation, not a token read.
const kShapeRadii = <String, double>{
  'sharp': 0.0,
  'rounded': 0.5,
  'pill': 1.0,
};

/// Returns the preset for [paletteKey], falling back to the first installed
/// preset when unknown. Never throws — the bar stays usable with stale docs.
shadcn.RegistryThemePreset resolvePreset(String paletteKey) {
  for (final preset in shadcn.registryThemePresets) {
    if (preset.id == paletteKey) return preset;
  }
  return shadcn.registryThemePresets.first;
}

/// Resolves [theme] to kit [ThemeData]: preset lookup (with fallback), then
/// [AppTheme] light/dark build, then the [kShapeRadii] radius override.
/// Sets `InstalledThemePreset.current` as a side effect (see file docs).
shadcn.ThemeData resolveCanvasThemeData(CanvasTheme theme) {
  shadcn.InstalledThemePreset.current = resolvePreset(theme.paletteKey);
  final base = theme.dark ? shadcn.AppTheme.dark() : shadcn.AppTheme.light();
  final radius = kShapeRadii[theme.shape];
  return radius == null ? base : base.copyWith(radius: () => radius);
}

/// Converts a kit (`dart:ui`) color to a Material color.
Color _materialColor(ui.Color color) => Color(color.toARGB32());

/// Builds the Material color scheme matching the shadcn [scheme], so the
/// editor chrome that must stay Material (`Scaffold`, `AppBar`) renders in
/// the selected palette instead of the default M3 baseline (whose lavender
/// surface tint leaked through everywhere).
ColorScheme _materialScheme(
    shadcn.ColorScheme scheme, CanvasTheme theme) {
  return ColorScheme(
    brightness: theme.dark ? Brightness.dark : Brightness.light,
    primary: _materialColor(scheme.primary),
    onPrimary: _materialColor(scheme.primaryForeground),
    secondary: _materialColor(scheme.secondary),
    onSecondary: _materialColor(scheme.secondaryForeground),
    surface: _materialColor(scheme.background),
    onSurface: _materialColor(scheme.foreground),
    error: _materialColor(scheme.destructive),
    onError: _materialColor(scheme.primaryForeground),
    outline: _materialColor(scheme.border),
    surfaceContainerHighest: _materialColor(scheme.muted),
    onSurfaceVariant: _materialColor(scheme.mutedForeground),
  );
}

/// Applies [theme] to a subtree with the kit [Theme] widget, plus a Material
/// [Theme] derived from the same shadcn scheme so `Scaffold`/`AppBar`/debug
/// chrome follow the selected palette and dark mode.
class ThemedCanvas extends StatelessWidget {
  final CanvasTheme theme;
  final Widget child;

  const ThemedCanvas({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    final data = resolveCanvasThemeData(theme);
    final scheme = _materialScheme(data.colorScheme, theme);
    return shadcn.Theme(
      data: data,
      child: Theme(
        data: ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          scaffoldBackgroundColor: scheme.surface,
          appBarTheme: AppBarTheme(
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Controlled theme bar: light/dark [shadcn.Switch] plus palette and shape
/// [shadcn.Select] dropdowns. Reports edits via [onChanged].
class ThemeBar extends StatelessWidget {
  final CanvasTheme theme;
  final ValueChanged<CanvasTheme> onChanged;

  const ThemeBar({super.key, required this.theme, required this.onChanged});

  void _emit({String? paletteKey, bool? dark, String? shape}) {
    onChanged(
      CanvasTheme(
        paletteKey: paletteKey ?? theme.paletteKey,
        dark: dark ?? theme.dark,
        shape: shape ?? theme.shape,
        motion: theme.motion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text('Theme'),
          const SizedBox(width: 12),
          const Text('Dark'),
          const SizedBox(width: 4),
          shadcn.Switch(
            value: theme.dark,
            onChanged: (v) => _emit(dark: v),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: shadcn.Select<String>(
              value: kPaletteOptions.contains(theme.paletteKey)
                  ? theme.paletteKey
                  : null,
              placeholder: const Text('Palette'),
              itemBuilder: (context, option) => Text(option),
              onChanged: (v) {
                if (v != null) _emit(paletteKey: v);
              },
              popup: shadcn.SelectPopup(
                items: shadcn.SelectItemList(
                  children: [
                    for (final option in kPaletteOptions)
                      shadcn.SelectItemButton(
                        value: option,
                        child: Text(option),
                      ),
                  ],
                ),
              ).call,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: shadcn.Select<String>(
              value: kShapeOptions.contains(theme.shape) ? theme.shape : null,
              placeholder: const Text('Shape'),
              itemBuilder: (context, option) => Text(option),
              onChanged: (v) {
                if (v != null) _emit(shape: v);
              },
              popup: shadcn.SelectPopup(
                items: shadcn.SelectItemList(
                  children: [
                    for (final option in kShapeOptions)
                      shadcn.SelectItemButton(
                        value: option,
                        child: Text(option),
                      ),
                  ],
                ),
              ).call,
            ),
          ),
        ],
      ),
    );
  }
}
