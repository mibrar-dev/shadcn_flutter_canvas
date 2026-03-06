# Component Theming Architecture: Complete Specification

## 1) Overview

This architecture enables **single-file component theme customization** where users can replace one generated tokens file to completely customize a component's appearance while maintaining global theme consistency.

---

## 2) Core Philosophy

### 2.1 Separation of Concerns
- **Defaults** = Built-in literal values that make components look correct (never changes)
- **Tokens** = User customization layer (website generates, user replaces entire file)
- **Resolution** = Runtime logic that applies global theme properties (scaling, radius multipliers, etc.)

### 2.2 Key Principles
1. **One file to replace**: User only needs to replace the tokens file
2. **Literal values only**: No expression strings like `'16 * scaling'` in config
3. **Global theme respect**: Custom values still benefit from global theme properties unless explicitly opted out
4. **Type-safe**: All values are properly typed Dart classes
5. **Self-documenting**: Structure makes customization obvious

---

## 3) File Structure Per Component

Each component has three config files:

```
component_name/
├── _impl/
│   └── themes/
│       ├── base/
│       │   └── component_theme_data.dart      # Theme data class + resolver
│       ├── variants/
│       │   └── variant_theme_data.dart        # (if component has variants)
│       └── config/
│           ├── component_theme_defaults.dart   # Built-in defaults (NEVER CHANGES)
│           ├── component_theme_tokens.dart     # User customization (USER REPLACES THIS)
│           └── component_theme_config.dart     # Registration (never changes)
```

---

## 4) File Templates

### 4.1 Defaults File (Never Changes)

**Purpose**: Contains the literal default values that make the component look correct out of the box.

**File**: `component_theme_defaults.dart`

```dart
// ═══════════════════════════════════════════════════════════
// COMPONENT THEME DEFAULTS
// Built-in values that make [ComponentName] look correct
// DO NOT EDIT - This file contains framework defaults
// ═══════════════════════════════════════════════════════════

class [ComponentName]ThemeDefaults {
  // Dimensions (literal values)
  final double height;
  final double width;
  final double paddingX;
  final double paddingY;
  final double gap;
  
  // Border & Radius (literal values)
  final double borderWidth;
  final double borderRadius;
  
  // Typography (literal values)
  final double fontSize;
  final int fontWeight;
  final double letterSpacing;
  
  // Spacing (literal values)
  final double margin;
  final double iconSize;
  
  const [ComponentName]ThemeDefaults({
    // Dimensions
    this.height = 40.0,
    this.width = 200.0,
    this.paddingX = 16.0,
    this.paddingY = 8.0,
    this.gap = 8.0,
    
    // Border & Radius
    this.borderWidth = 1.0,
    this.borderRadius = 6.0,
    
    // Typography
    this.fontSize = 14.0,
    this.fontWeight = 400,
    this.letterSpacing = 0.0,
    
    // Spacing
    this.margin = 0.0,
    this.iconSize = 16.0,
  });
}
```

**Rules for Defaults**:
- ✅ Use literal numeric values only (e.g., `40.0`, `16.0`)
- ✅ Use literal int values for weights (e.g., `400`, `500`, `600`)
- ✅ Document what each value controls
- ❌ NO token references (no `'sm'`, `'md'`)
- ❌ NO expressions (no `'16 * scaling'`)
- ❌ NO theme references (no `'theme.radiusSm'`)

---

### 4.2 Tokens File (User Replaces This)

**Purpose**: User customization layer. Website generates this file with user's custom values.

**File**: `component_theme_tokens.dart`

```dart
// ═══════════════════════════════════════════════════════════
// COMPONENT THEME TOKENS
// User customization for [ComponentName]
// This file can be replaced with website-generated code
// ═══════════════════════════════════════════════════════════

class [ComponentName]ThemeTokens {
  // Dimensions (nullable - null means use default)
  final double? height;
  final double? width;
  final double? paddingX;
  final double? paddingY;
  final double? gap;
  
  // Border & Radius (nullable)
  final double? borderWidth;
  final double? borderRadius;
  
  // Typography (nullable)
  final double? fontSize;
  final int? fontWeight;
  final double? letterSpacing;
  
  // Spacing (nullable)
  final double? margin;
  final double? iconSize;
  
  // Global theme override flags (optional - advanced)
  final bool? ignoreGlobalScaling;
  final bool? ignoreGlobalRadius;
  
  const [ComponentName]ThemeTokens({
    // Dimensions
    this.height,
    this.width,
    this.paddingX,
    this.paddingY,
    this.gap,
    
    // Border & Radius
    this.borderWidth,
    this.borderRadius,
    
    // Typography
    this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    
    // Spacing
    this.margin,
    this.iconSize,
    
    // Global theme override flags
    this.ignoreGlobalScaling,
    this.ignoreGlobalRadius,
  });
}

// ═══════════════════════════════════════════════════════════
// ACTIVE TOKENS INSTANCE
// Website generates this - user replaces entire file
// ═══════════════════════════════════════════════════════════
const [componentName]ThemeTokens = [ComponentName]ThemeTokens(
  // Uncomment and set values to customize
  // height: 48.0,
  // paddingX: 24.0,
  // borderRadius: 8.0,
  // fontSize: 16.0,
  // fontWeight: 500,
);
```

**Rules for Tokens**:
- ✅ All properties must be nullable (`double?`, `int?`, `bool?`)
- ✅ Include optional override flags for advanced control
- ✅ Provide clear comments showing how to customize
- ✅ Create a const instance at the bottom
- ❌ Never include required parameters
- ❌ Never include default values in class properties

---

### 4.3 Config File (Never Changes)

**Purpose**: Registers the component with the global theme system.

**File**: `component_theme_config.dart`

```dart
// ═══════════════════════════════════════════════════════════
// COMPONENT THEME CONFIG
// Registers [ComponentName] with global theme system
// DO NOT EDIT - This file wires defaults and tokens together
// ═══════════════════════════════════════════════════════════

import 'component_theme_defaults.dart';
import 'component_theme_tokens.dart';

class [ComponentName]ThemeConfig {
  /// Global type identifier for theme registry
  static const String globalType = '[ComponentName]Theme';
  
  /// Built-in default values
  static const defaults = [ComponentName]ThemeDefaults();
  
  /// User customization tokens (references instance from tokens file)
  static const tokens = [componentName]ThemeTokens;
}
```

**Rules for Config**:
- ✅ Import both defaults and tokens files
- ✅ Use PascalCase for class name
- ✅ Use exact component name for `globalType`
- ✅ Reference the const instance from tokens file
- ❌ Never modify this file structure
- ❌ Never add logic here

---

### 4.4 Base Theme Data (Resolution Logic)

**Purpose**: Resolves tokens and defaults into actual theme data, applying global theme properties.

**File**: `base/component_theme_data.dart`

```dart
// ═══════════════════════════════════════════════════════════
// COMPONENT THEME DATA
// Runtime theme data for [ComponentName]
// Resolves tokens + defaults with global theme properties
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../config/component_theme_config.dart';

class [ComponentName]ThemeData {
  // Resolved values (non-nullable, actual runtime values)
  final double height;
  final double width;
  final double paddingX;
  final double paddingY;
  final double gap;
  final double borderWidth;
  final BorderRadius borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double margin;
  final double iconSize;
  
  const [ComponentName]ThemeData({
    required this.height,
    required this.width,
    required this.paddingX,
    required this.paddingY,
    required this.gap,
    required this.borderWidth,
    required this.borderRadius,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
    required this.margin,
    required this.iconSize,
  });
  
  /// Resolves tokens and defaults into actual theme data
  /// Applies global theme properties (scaling, radius multipliers, etc.)
  static [ComponentName]ThemeData resolve(ThemeData theme) {
    final d = [ComponentName]ThemeConfig.defaults;
    final t = [ComponentName]ThemeConfig.tokens;
    
    // ═══════════════════════════════════════════════════════
    // STEP 1: Get raw values (tokens override defaults)
    // ═══════════════════════════════════════════════════════
    final rawHeight = t.height ?? d.height;
    final rawWidth = t.width ?? d.width;
    final rawPaddingX = t.paddingX ?? d.paddingX;
    final rawPaddingY = t.paddingY ?? d.paddingY;
    final rawGap = t.gap ?? d.gap;
    final rawBorderWidth = t.borderWidth ?? d.borderWidth;
    final rawBorderRadius = t.borderRadius ?? d.borderRadius;
    final rawFontSize = t.fontSize ?? d.fontSize;
    final rawFontWeight = t.fontWeight ?? d.fontWeight;
    final rawLetterSpacing = t.letterSpacing ?? d.letterSpacing;
    final rawMargin = t.margin ?? d.margin;
    final rawIconSize = t.iconSize ?? d.iconSize;
    
    // ═══════════════════════════════════════════════════════
    // STEP 2: Check global theme override flags
    // ═══════════════════════════════════════════════════════
    final ignoreScaling = t.ignoreGlobalScaling ?? false;
    final ignoreRadius = t.ignoreGlobalRadius ?? false;
    
    // ═══════════════════════════════════════════════════════
    // STEP 3: Apply global theme properties
    // ═══════════════════════════════════════════════════════
    final scaling = ignoreScaling ? 1.0 : theme.scaling;
    final radiusMultiplier = ignoreRadius ? 1.0 : theme.radius;
    
    return [ComponentName]ThemeData(
      // Apply scaling to dimensions
      height: rawHeight * scaling,
      width: rawWidth * scaling,
      paddingX: rawPaddingX * scaling,
      paddingY: rawPaddingY * scaling,
      gap: rawGap * scaling,
      borderWidth: rawBorderWidth * scaling,
      
      // Apply radius multiplier (multiply raw value by theme.radius)
      borderRadius: BorderRadius.circular(rawBorderRadius * radiusMultiplier),
      
      // Apply scaling to typography
      fontSize: rawFontSize * scaling,
      fontWeight: _resolveFontWeight(rawFontWeight),
      letterSpacing: rawLetterSpacing * scaling,
      
      // Apply scaling to spacing
      margin: rawMargin * scaling,
      iconSize: rawIconSize * scaling,
    );
  }
  
  /// Helper: Convert int weight to FontWeight
  static FontWeight _resolveFontWeight(int weight) {
    return FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1];
  }
}
```

**Resolution Rules**:
1. **Get raw value**: `tokens.property ?? defaults.property`
2. **Check override flags**: `ignoreGlobalScaling`, `ignoreGlobalRadius`
3. **Apply global theme**:
   - Dimensions: multiply by `theme.scaling` (unless ignored)
   - Radius: multiply by `theme.radiusMultiplier` (unless ignored)
   - Typography: multiply fontSize by `theme.scaling`
4. **Return resolved data**: All non-nullable, ready-to-use values

---

## 5) Global Theme Properties

The global theme system provides these properties that components can use:

```dart
class ThemeData {
  /// Scale factor for sizes and spacing (e.g., 1.0 = default, 1.2 = larger, 0.9 = compact)
  final double scaling;
  
  /// Base radius multiplier for border radius calculations
  /// (e.g., 0.5 = default, 1.0 = rounder, 0.25 = sharper)
  final double radius;
  
  /// Computed radius values (radius * multiplier)
  double get radiusXs => radius * 4;    // At 0.5 = 2.0
  double get radiusSm => radius * 8;    // At 0.5 = 4.0
  double get radiusMd => radius * 12;   // At 0.5 = 6.0
  double get radiusLg => radius * 16;   // At 0.5 = 8.0
  double get radiusXl => radius * 20;   // At 0.5 = 10.0
  double get radiusXxl => radius * 24;  // At 0.5 = 12.0
  
  /// Pre-computed BorderRadius getters
  BorderRadius get borderRadiusXs => BorderRadius.circular(radiusXs);
  BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  BorderRadius get borderRadiusXxl => BorderRadius.circular(radiusXxl);
  
  /// Density tokens for container/content padding and inter-item gaps
  final Density density;
  
  /// Spacing scale tokens for padding/margins (based on base unit, default 4.0)
  final SpacingScale spacing;
  
  /// Letter-spacing scale for typography tracking
  final TrackingScale tracking;
  
  /// Color scheme
  final ColorScheme colorScheme;
  
  /// Typography settings (includes font sizes, weights, line heights)
  final Typography typography;
  
  /// Icon theme properties (icon sizes across different scales)
  final IconThemeProperties iconTheme;
  
  /// Shadow scale tokens for elevation styling
  final ShadowScale shadows;
  
  /// Default opacity for surface overlays (0.0 to 1.0)
  final double? surfaceOpacity;
  
  /// Default blur radius for surface effects
  final double? surfaceBlur;
  
  /// Default haptic/sound feedback toggle for interactive controls
  final bool? enableFeedback;
}
```

---

## 6) User Workflow Examples

### 6.1 Default Component (No Customization)

**tokens file**:
```dart
const buttonThemeTokens = ButtonThemeTokens();
```

**Result**:
- Uses all default values
- Global theme scaling applies: `height: 40.0 * theme.scaling`
- Global radius applies: `borderRadius: 6.0 * theme.radius` (at radius=0.5, result is 3.0)

---

### 6.2 Custom Height, Global Theme Still Applies

**Website generates**:
```dart
const buttonThemeTokens = ButtonThemeTokens(
  height: 48.0,  // Taller button
);
```

**Result**:
- Custom height: `48.0 * theme.scaling` (still respects scaling)
- Default padding: `16.0 * theme.scaling`
- Default radius: `6.0 * theme.radius` (still respects global radius multiplier)

---

### 6.3 Multiple Custom Values

**Website generates**:
```dart
const buttonThemeTokens = ButtonThemeTokens(
  height: 52.0,
  paddingX: 24.0,
  borderRadius: 12.0,
  fontSize: 16.0,
  fontWeight: 500,
);
```

**Result**:
- All custom values still respect global theme
- `height: 52.0 * theme.scaling`
- `paddingX: 24.0 * theme.scaling`
- `borderRadius: 12.0 * theme.radius` (at radius=0.5, result is 6.0)
- `fontSize: 16.0 * theme.scaling`

---

### 6.4 Fixed Custom Values (Ignore Global Theme)

**Website generates** (advanced option):
```dart
const buttonThemeTokens = ButtonThemeTokens(
  height: 48.0,
  borderRadius: 8.0,
  ignoreGlobalScaling: true,    // Fixed height
  ignoreGlobalRadius: true,     // Fixed radius
);
```

**Result**:
- `height: 48.0` (exact, no scaling applied)
- `borderRadius: 8.0` (exact, no radius multiplier applied)
- User has complete control

---

## 7) Global Registration

### 7.1 Component Registration File

**File**: `lib/registry/components/component_theme_global_configs.dart`

```dart
import 'control/button/_impl/themes/config/button_theme_config.dart';
import 'control/checkbox/_impl/themes/config/checkbox_theme_config.dart';
import 'control/input/_impl/themes/config/input_theme_config.dart';
// ... import all component configs

/// Global registry of all component theme configs
const Map<String, dynamic> componentThemeGlobalConfigs = {
  ButtonThemeConfig.globalType: ButtonThemeConfig,
  CheckboxThemeConfig.globalType: CheckboxThemeConfig,
  InputThemeConfig.globalType: InputThemeConfig,
  // ... register all components
};
```

---

### 7.2 Runtime Registry

**File**: `lib/registry/shared/theme/component_theme_global_registry.dart`

```dart
class ComponentThemeGlobalRegistry {
  /// Get config for a component by type name
  static dynamic getConfig(String typeName) {
    return componentThemeGlobalConfigs[typeName];
  }
  
  /// Check if component has custom config
  static bool hasConfig(String typeName) {
    return componentThemeGlobalConfigs.containsKey(typeName);
  }
  
  /// Get all registered component types
  static List<String> getAllTypes() {
    return componentThemeGlobalConfigs.keys.toList();
  }
}
```

---

## 8) Website Generation Logic

### 8.1 Website Workflow

1. **User customizes component** on website UI
2. **Website collects values**: height, padding, radius, etc.
3. **Website generates complete tokens file**
4. **User copies entire file** and replaces local tokens file
5. **Component theme updates** globally across app

---

### 8.2 Generation Template

```typescript
function generateTokensFile(componentName: string, customizations: Record<string, any>) {
  const className = `${componentName}ThemeTokens`;
  const instanceName = `${componentName.toLowerCase()}ThemeTokens`;
  
  // Build customization parameters
  const params = Object.entries(customizations)
    .map(([key, value]) => {
      if (typeof value === 'number') {
        return `  ${key}: ${value},`;
      } else if (typeof value === 'boolean') {
        return `  ${key}: ${value},`;
      }
      return null;
    })
    .filter(Boolean)
    .join('\n');
  
  return `
// ═══════════════════════════════════════════════════════════
// COMPONENT THEME TOKENS
// User customization for ${componentName}
// Generated by shadcn_flutter_kit website
// ═══════════════════════════════════════════════════════════

class ${className} {
  final double? height;
  final double? width;
  final double? paddingX;
  final double? paddingY;
  final double? gap;
  final double? borderWidth;
  final double? borderRadius;
  final double? fontSize;
  final int? fontWeight;
  final double? letterSpacing;
  final double? margin;
  final double? iconSize;
  final bool? ignoreGlobalScaling;
  final bool? ignoreGlobalRadius;
  
  const ${className}({
    this.height,
    this.width,
    this.paddingX,
    this.paddingY,
    this.gap,
    this.borderWidth,
    this.borderRadius,
    this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    this.margin,
    this.iconSize,
    this.ignoreGlobalScaling,
    this.ignoreGlobalRadius,
  });
}

const ${instanceName} = ${className}(
${params}
);
`.trim();
}
```

---

## 9) Advanced Features

### 9.1 Override Flags

Components support two override flags for advanced control:

```dart
class ComponentThemeTokens {
  final bool? ignoreGlobalScaling;    // Disable scaling multiplier
  final bool? ignoreGlobalRadius;     // Disable radius multiplier
}
```

**Use cases**:
- Fixed-size components (icons, badges)
- Pixel-perfect designs
- Components that shouldn't scale
- Absolute positioning requirements

---

### 9.2 Variant Support

For components with variants, add variant-specific tokens:

```dart
class ButtonThemeTokens {
  // Base tokens
  final double? height;
  final double? paddingX;
  
  // Variant-specific tokens
  final double? primaryHeight;      // Override for primary variant
  final double? secondaryHeight;    // Override for secondary variant
  final double? destructiveHeight;  // Override for destructive variant
}
```

Resolution prioritizes: `variant token > base token > default`

---

## 10) Migration Guide

### 10.1 From Old Expression-Based Config

**Before** (old style):
```dart
class CheckboxThemeConfig {
  final Object? size;
  
  const CheckboxThemeConfig({
    this.size = '16 * scaling',  // ❌ Expression string
  });
}
```

**After** (new style):
```dart
// defaults.dart
class CheckboxThemeDefaults {
  final double size;
  const CheckboxThemeDefaults({
    this.size = 16.0,  // ✅ Literal value
  });
}

// tokens.dart
class CheckboxThemeTokens {
  final double? size;
  const CheckboxThemeTokens({this.size});
}

// Resolution applies scaling
final resolvedSize = (tokens.size ?? defaults.size) * theme.scaling;
```

---

### 10.2 Migration Steps

1. **Create defaults file** with literal values
2. **Create tokens file** with nullable properties
3. **Update config file** to import both
4. **Move resolution logic** to base theme data
5. **Update global registration**
6. **Test with default tokens** (empty customization)
7. **Test with custom tokens** (website-generated values)

---

## 11) Validation & Testing

### 11.1 Component Checklist

A component is complete when:

- ✅ Defaults file exists with all literal values
- ✅ Tokens file exists with nullable properties
- ✅ Config file registers both correctly
- ✅ Base theme data resolves with global theme
- ✅ Component registered in global configs
- ✅ Default tokens work (no customization)
- ✅ Custom tokens work (website-generated)
- ✅ Global theme changes affect component
- ✅ Override flags work when set

---

### 11.2 Testing Scenarios

**Test 1: Default behavior**
```dart
const tokens = ComponentThemeTokens();
// Should use all defaults with global theme applied
```

**Test 2: Partial customization**
```dart
const tokens = ComponentThemeTokens(height: 48.0);
// Should use custom height, default everything else
// Global theme should still apply to custom value
```

**Test 3: Full customization**
```dart
const tokens = ComponentThemeTokens(
  height: 52.0,
  paddingX: 24.0,
  borderRadius: 12.0,
  fontSize: 16.0,
);
// All custom values, global theme still applies
```

**Test 4: Global theme changes**
```dart
// Change theme.scaling from 1.0 to 1.2
// All components should scale proportionally

// Change theme.radius from 0.5 to 1.0
// All radius values double (e.g., radiusSm goes from 4.0 to 8.0)
// Component borderRadius values automatically adjust
```

**Test 5: Override flags**
```dart
const tokens = ComponentThemeTokens(
  height: 48.0,
  ignoreGlobalScaling: true,
);
// Height should be exactly 48.0 regardless of theme.scaling
```

---

## 12) Best Practices

### 12.1 For Component Authors

1. **Keep defaults minimal** - Only essential properties
2. **Use semantic names** - `height` not `h`, `paddingX` not `px`
3. **Document units** - Assume pixels unless specified
4. **Group properties** - Dimensions, colors, typography, spacing
5. **Consistent naming** - Follow Flutter conventions
6. **Provide comments** - Explain non-obvious defaults

---

### 12.2 For Website Implementation

1. **Generate complete file** - Don't ask users to merge
2. **Include all properties** - Even if using defaults (as comments)
3. **Format consistently** - Use same spacing/style as templates
4. **Validate values** - Ensure positive numbers, valid weights
5. **Show preview** - Let users see changes before downloading
6. **Provide reset** - Easy way to return to defaults

---

### 12.3 For Users

1. **Replace entire file** - Don't manually edit
2. **Test after replacing** - Hot reload should work
3. **Use override flags sparingly** - Let global theme work
4. **Keep customizations minimal** - Only change what's needed
5. **Document changes** - Comment why custom values used

---

## 13) Common Patterns

### 13.1 Dimension Properties

```dart
// Always use double for dimensions
final double height;
final double width;
final double padding;
final double margin;
final double gap;
final double spacing;
```

---

### 13.2 Border Properties

```dart
// Border width as double
final double borderWidth;

// Radius as double (gets wrapped in BorderRadius.circular at resolution)
final double borderRadius;

// Complex borders (if needed)
final double borderTopWidth;
final double borderBottomWidth;
```

---

### 13.3 Typography Properties

```dart
// Font size as double
final double fontSize;

// Font weight as int (100-900)
final int fontWeight;

// Letter spacing as double
final double letterSpacing;

// Line height as double
final double lineHeight;
```

---

### 13.4 Color Properties

Colors are typically NOT in tokens (they come from theme.colorScheme), but if needed:

```dart
// In defaults (use null to indicate "use theme color")
final Color? backgroundColor;   // null = use theme
final Color? foregroundColor;   // null = use theme

// In tokens (override theme colors)
final Color? backgroundColor;   // Custom color
final Color? foregroundColor;   // Custom color
```

---

## 14) File Size Optimization

### 14.1 Minimal Tokens File

For components with few customizable properties:

```dart
class BadgeThemeTokens {
  final double? size;
  final double? fontSize;
  final int? fontWeight;
  
  const BadgeThemeTokens({
    this.size,
    this.fontSize,
    this.fontWeight,
  });
}

const badgeThemeTokens = BadgeThemeTokens();
```

---

### 14.2 Comprehensive Tokens File

For complex components with many properties:

```dart
class InputThemeTokens {
  // Dimensions
  final double? height;
  final double? minHeight;
  final double? maxHeight;
  final double? paddingX;
  final double? paddingY;
  
  // Border
  final double? borderWidth;
  final double? borderRadius;
  final double? focusBorderWidth;
  
  // Typography
  final double? fontSize;
  final int? fontWeight;
  final double? placeholderFontSize;
  
  // States
  final double? disabledOpacity;
  final double? errorBorderWidth;
  
  // Flags
  final bool? ignoreGlobalScaling;
  final bool? ignoreGlobalRadius;
  
  const InputThemeTokens({
    this.height,
    this.minHeight,
    this.maxHeight,
    this.paddingX,
    this.paddingY,
    this.borderWidth,
    this.borderRadius,
    this.focusBorderWidth,
    this.fontSize,
    this.fontWeight,
    this.placeholderFontSize,
    this.disabledOpacity,
    this.errorBorderWidth,
    this.ignoreGlobalScaling,
    this.ignoreGlobalRadius,
  });
}
```

---

## 15) Summary

### 15.1 Architecture Benefits

✅ **Single file replacement** - Users replace one tokens file  
✅ **Clean separation** - Defaults, tokens, and resolution are separate  
✅ **Type-safe** - All values properly typed  
✅ **Global theme consistency** - Automatic scaling and radius application  
✅ **Flexible control** - Override flags for absolute control  
✅ **Self-documenting** - Structure makes customization obvious  
✅ **Website-friendly** - Easy to generate complete files  
✅ **Developer-friendly** - Clear, predictable patterns  

---

### 15.2 File Roles Summary

| File | Purpose | User Edits | Website Generates |
|------|---------|------------|-------------------|
| `defaults.dart` | Built-in literal values | ❌ Never | ❌ No |
| `tokens.dart` | User customization | ✅ Replace entire file | ✅ Yes |
| `config.dart` | Registration/wiring | ❌ Never | ❌ No |
| `theme_data.dart` | Resolution logic | ❌ Never | ❌ No |

---

### 15.3 Quick Reference

**Add new component**:
1. Create `defaults.dart` with literal values
2. Create `tokens.dart` with nullable properties
3. Create `config.dart` to register both
4. Create `theme_data.dart` with resolver
5. Register in global configs

**Customize component**:
1. Visit website
2. Adjust values
3. Download generated `tokens.dart`
4. Replace local file
5. Hot reload

**Global theme change affects all components automatically** 🎉

---

## 17) Practical Example: Button Component

### 17.1 Complete Implementation

**File: button_theme_defaults.dart**
```dart
class ButtonThemeDefaults {
  final double height;
  final double minWidth;
  final double paddingX;
  final double paddingY;
  final double gap;
  final double borderWidth;
  final double borderRadius;
  final double fontSize;
  final int fontWeight;
  final double iconSize;
  
  const ButtonThemeDefaults({
    this.height = 40.0,
    this.minWidth = 80.0,
    this.paddingX = 16.0,
    this.paddingY = 0.0,
    this.gap = 8.0,
    this.borderWidth = 1.0,
    this.borderRadius = 6.0,
    this.fontSize = 14.0,
    this.fontWeight = 500,
    this.iconSize = 16.0,
  });
}
```

**File: button_theme_tokens.dart**
```dart
class ButtonThemeTokens {
  final double? height;
  final double? minWidth;
  final double? paddingX;
  final double? paddingY;
  final double? gap;
  final double? borderWidth;
  final double? borderRadius;
  final double? fontSize;
  final int? fontWeight;
  final double? iconSize;
  final bool? ignoreGlobalScaling;
  final bool? ignoreGlobalRadius;
  
  const ButtonThemeTokens({
    this.height,
    this.minWidth,
    this.paddingX,
    this.paddingY,
    this.gap,
    this.borderWidth,
    this.borderRadius,
    this.fontSize,
    this.fontWeight,
    this.iconSize,
    this.ignoreGlobalScaling,
    this.ignoreGlobalRadius,
  });
}

const buttonThemeTokens = ButtonThemeTokens();
```

**File: button_theme_config.dart**
```dart
import 'button_theme_defaults.dart';
import 'button_theme_tokens.dart';

class ButtonThemeConfig {
  static const String globalType = 'ButtonTheme';
  static const defaults = ButtonThemeDefaults();
  static const tokens = buttonThemeTokens;
}
```

**File: base/button_theme_data.dart**
```dart
import 'package:flutter/material.dart';
import '../config/button_theme_config.dart';

class ButtonThemeData {
  final double height;
  final double minWidth;
  final EdgeInsets padding;
  final double gap;
  final BorderSide border;
  final BorderRadius borderRadius;
  final TextStyle textStyle;
  final double iconSize;
  
  const ButtonThemeData({
    required this.height,
    required this.minWidth,
    required this.padding,
    required this.gap,
    required this.border,
    required this.borderRadius,
    required this.textStyle,
    required this.iconSize,
  });
  
  static ButtonThemeData resolve(ThemeData theme) {
    final d = ButtonThemeConfig.defaults;
    final t = ButtonThemeConfig.tokens;
    
    // Get raw values
    final rawHeight = t.height ?? d.height;
    final rawMinWidth = t.minWidth ?? d.minWidth;
    final rawPaddingX = t.paddingX ?? d.paddingX;
    final rawPaddingY = t.paddingY ?? d.paddingY;
    final rawGap = t.gap ?? d.gap;
    final rawBorderWidth = t.borderWidth ?? d.borderWidth;
    final rawBorderRadius = t.borderRadius ?? d.borderRadius;
    final rawFontSize = t.fontSize ?? d.fontSize;
    final rawFontWeight = t.fontWeight ?? d.fontWeight;
    final rawIconSize = t.iconSize ?? d.iconSize;
    
    // Check override flags
    final ignoreScaling = t.ignoreGlobalScaling ?? false;
    final ignoreRadius = t.ignoreGlobalRadius ?? false;
    
    // Apply global theme
    final scaling = ignoreScaling ? 1.0 : theme.scaling;
    final radiusMultiplier = ignoreRadius ? 1.0 : theme.radius;
    
    return ButtonThemeData(
      height: rawHeight * scaling,
      minWidth: rawMinWidth * scaling,
      padding: EdgeInsets.symmetric(
        horizontal: rawPaddingX * scaling,
        vertical: rawPaddingY * scaling,
      ),
      gap: rawGap * scaling,
      border: BorderSide(
        width: rawBorderWidth * scaling,
        color: theme.colorScheme.border,
      ),
      borderRadius: BorderRadius.circular(rawBorderRadius * radiusMultiplier),
      textStyle: TextStyle(
        fontSize: rawFontSize * scaling,
        fontWeight: FontWeight.values[(rawFontWeight ~/ 100).clamp(1, 9) - 1],
        color: theme.colorScheme.primary,
      ),
      iconSize: rawIconSize * scaling,
    );
  }
}
```

### 17.2 How Values Resolve

**Scenario: Default with theme.scaling = 1.0, theme.radius = 0.5**

| Property | Default | Token | Raw Value | Global Theme | Final Value |
|----------|---------|-------|-----------|--------------|-------------|
| height | 40.0 | null | 40.0 | × 1.0 (scaling) | 40.0 |
| paddingX | 16.0 | null | 16.0 | × 1.0 (scaling) | 16.0 |
| borderRadius | 6.0 | null | 6.0 | × 0.5 (radius) | 3.0 |
| fontSize | 14.0 | null | 14.0 | × 1.0 (scaling) | 14.0 |

**Scenario: Custom with theme.scaling = 1.2, theme.radius = 1.0**

Token customization:
```dart
const buttonThemeTokens = ButtonThemeTokens(
  height: 48.0,
  borderRadius: 12.0,
);
```

| Property | Default | Token | Raw Value | Global Theme | Final Value |
|----------|---------|-------|-----------|--------------|-------------|
| height | 40.0 | 48.0 | 48.0 | × 1.2 (scaling) | 57.6 |
| paddingX | 16.0 | null | 16.0 | × 1.2 (scaling) | 19.2 |
| borderRadius | 6.0 | 12.0 | 12.0 | × 1.0 (radius) | 12.0 |
| fontSize | 14.0 | null | 14.0 | × 1.2 (scaling) | 16.8 |

**Scenario: Fixed with override flags**

Token customization:
```dart
const buttonThemeTokens = ButtonThemeTokens(
  height: 48.0,
  borderRadius: 8.0,
  ignoreGlobalScaling: true,
  ignoreGlobalRadius: true,
);
```

| Property | Default | Token | Raw Value | Global Theme | Final Value |
|----------|---------|-------|-----------|--------------|-------------|
| height | 40.0 | 48.0 | 48.0 | ignored | 48.0 |
| paddingX | 16.0 | null | 16.0 | × 1.2 (scaling) | 19.2 |
| borderRadius | 6.0 | 8.0 | 8.0 | ignored | 8.0 |
| fontSize | 14.0 | null | 14.0 | × 1.2 (scaling) | 16.8 |

Note: `ignoreGlobalScaling` affects ALL dimension properties, `ignoreGlobalRadius` only affects radius properties.

---

## 16) Next Steps

### 16.1 Implementation Order

1. ✅ Define file structure
2. ✅ Create templates
3. ⏳ Implement for one component (Button)
4. ⏳ Test all scenarios
5. ⏳ Build website generator
6. ⏳ Migrate remaining components
7. ⏳ Document user workflow
8. ⏳ Release to users

### 16.2 Future Enhancements

- **Variant presets** - Common variant combinations
- **Dark mode tokens** - Separate tokens for dark theme
- **Responsive tokens** - Different values per breakpoint
- **Animation tokens** - Duration, curves, etc.
- **Accessibility tokens** - Touch target sizes, contrast ratios

---

**End of Specification**
