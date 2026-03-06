# Detailed Migration Guide: Unified Theming While Keeping `ThemeData` (No `components` Map)

This version adopts your updated direction:

- keep `ThemeData` / `Theme` naming
- keep preset installation separate via `app_theme_preset.dart`
- remove `ThemeData.components`
- store component token defaults/overrides in each component’s own theme folder

Example component path:

- `lib/registry/components/control/button/_impl/themes/`

---

## 1) Core Decision

Yes — you can remove the `components` map and use per-component token config files.

Each component owns its tokens and can expose one replaceable config file. When that file is replaced, changes are global for that component because every instance resolves from the same source.

---

## 2) Final Target Architecture

### 2.1 Global theme remains focused

`ThemeData` contains only global primitives/tokens:

- `colorScheme`
- `typography`
- `radius`
- `scaling`
- `density`
- `spacing`
- `tracking`
- `shadows`
- `iconTheme`
-  surface/feedback fields

No component override map is needed.

### 2.2 Preset split stays as two files

- `shared/theme/app_theme_preset.dart` (CLI-installed preset payload)
- `shared/theme/app_theme.dart` (stable app-facing ThemeData builder)

`app_theme.dart` imports preset payload and builds global `ThemeData`.

### 2.3 Component-level token config files

Inside each component theme folder, add one config file (single source for global component override):

- `button/_impl/themes/button_theme_tokens.config.dart`
- `toast/_impl/themes/toast_theme_tokens.config.dart`

These files are generated/replaced by CLI/website when user customizes that component.

---

## 3) Recommended Per-Component File Contract

For each component:

1. `*_theme_data.dart` (runtime token model + defaults)
2. `*_theme_tokens.config.dart` (global override payload; replaceable)
3. optional `*_theme_schema.dart` (schema for website)

### Example (`button`)

```dart
// button_theme_data.dart
class ButtonThemeData {
  static const String id = 'button';

  final double corner;
  final EdgeInsets padding;
  final Duration pressDuration;

  const ButtonThemeData({
    required this.corner,
    required this.padding,
    required this.pressDuration,
  });

  static ButtonThemeData defaults(ThemeData t) {
    return ButtonThemeData(
      corner: t.radiusMd,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm,
      ),
      pressDuration: const Duration(milliseconds: 120),
    );
  }

  ButtonThemeData copyWith({
    double? corner,
    EdgeInsets? padding,
    Duration? pressDuration,
  }) => ButtonThemeData(
    corner: corner ?? this.corner,
    padding: padding ?? this.padding,
    pressDuration: pressDuration ?? this.pressDuration,
  );

  ButtonThemeData merge(ButtonThemeData? other) {
    if (other == null) return this;
    return copyWith(
      corner: other.corner,
      padding: other.padding,
      pressDuration: other.pressDuration,
    );
  }
}
```

```dart
// button_theme_tokens.config.dart
class ButtonThemeTokensConfig {
  // null means “use defaults(ThemeData)”
  static const ButtonThemeData? global = ButtonThemeData(
    corner: 14,
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    pressDuration: Duration(milliseconds: 140),
  );
}
```

Widget resolution:

```dart
final t = Theme.of(context);
final base = ButtonThemeData.defaults(t);
final global = ButtonThemeTokensConfig.global;
final scoped = ComponentTheme.maybeOf<ButtonThemeData>(context); // optional bridge

final resolved = base
    .merge(global)
    .merge(scoped)
    .merge(widget.theme); // per-instance override
```

Resolution order:

1. `defaults(ThemeData)`
2. component global config file
3. optional subtree `ComponentTheme`
4. per-instance `theme:`

---

## 4) Why This Works for “Replace 1 File”

If user customizes button tokens, only replace:

- `button_theme_tokens.config.dart`

No `app_theme.dart` rewrite is required for component token changes.

If user changes color preset, only replace:

- `app_theme_preset.dart`

So updates are isolated and predictable.

---

## 5) Changes Required vs Previous Doc

### Remove

- `ThemeData.components`
- `ThemeData.component<T>(...)` lookup extension
- map-based overrides in `app_theme.dart`

### Keep

- `ThemeData` class name and token fields
- `Theme.of(context)` provider access
- `AnimatedTheme` and `ThemeData.lerp`
- optional `ComponentTheme<T>` bridge

### Add

- per-component `*_theme_tokens.config.dart` files
- generator workflow that writes component config files

---

## 6) Updated `app_theme.dart` Role

`app_theme.dart` should only compose global theme from preset + global app overrides.

```dart
import 'app_theme_preset.dart';

class AppTheme {
  static ThemeData light() {
    final preset = InstalledThemePreset.current;
    return _build(preset: preset, dark: false);
  }

  static ThemeData dark() {
    final preset = InstalledThemePreset.current;
    return _build(preset: preset, dark: true);
  }

  static ThemeData _build({
    required RegistryThemePreset preset,
    required bool dark,
  }) {
    final base = _themeDataFromPreset(preset, dark);

    return base.copyWith(
      colorScheme: () => base.colorScheme,
      typography: () => base.typography,
      // global app-level overrides only
    );
  }
}
```

No component map in this file.

---

## 7) CLI + Website Output Contract

### 7.1 Preset install

CLI replaces:

- `shared/theme/app_theme_preset.dart`

### 7.2 Component customization

CLI/website replaces only targeted component config file, e.g.:

- `components/control/button/_impl/themes/button_theme_tokens.config.dart`

### 7.3 Optional bundle mode

You may still export a zip containing:

- one preset file
- N component config files (only changed components)

---

## 8) Migration Phases

### Phase 0

- Keep existing runtime behavior.
- Add `app_theme_preset.dart` + stable `app_theme.dart` import path.

### Phase 1

- Introduce first component config file (`button` or `toast`).
- Update that component widget to consume config file in resolution chain.

### Phase 2

- Roll out same pattern per component folder.
- Keep `ComponentTheme<T>` optional for scoped overrides.

### Phase 3

- Remove any docs that require central component override maps.
- Switch website generator to emit component config files.

---

## 9) Pros/Cons — `components` Map vs Component Config Files

## A) Central `ThemeData.components` map

### Pros

- Single place for all component overrides.
- Easy to serialize one object for export.
- Good for runtime dynamic theme editors.

### Cons

- `ThemeData` grows in conceptual complexity.
- `app_theme.dart` becomes large as overrides scale.
- Merge logic and map typing checks add runtime plumbing.
- Updating one component often touches central file.

## B) Component-local token config files (your proposal)

### Pros

- Strong module ownership: each component owns its theme data.
- Replace one file to update one component globally.
- Cleaner `ThemeData` with no component map.
- Better for copy/paste registries and per-component distribution.

### Cons

- Many small files across component tree.
- Bulk export/import requires multi-file orchestration.
- Harder to do “single JSON snapshot” of all component overrides.
- Cross-component preview tooling must read multiple locations.

---

## 10) Recommendation

Given your CLI flow and folder structure, component-local config files are a strong fit.

Use this final rule:

- global palette/typography preset → `app_theme_preset.dart`
- app-level global tweaks → `app_theme.dart`
- per-component global token overrides → component `*_theme_tokens.config.dart`

This keeps `ThemeData` aligned with Flutter-style naming and removes the need for `ThemeData.components`.

---

## 11) One-Sentence Summary

Yes, you can remove `components` and move to per-component replaceable token config files; this is cleaner for your registry/CLI workflow and still supports global application plus per-instance overrides.
