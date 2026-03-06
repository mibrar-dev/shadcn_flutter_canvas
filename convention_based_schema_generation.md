# Convention-Based Schema Generation (No Annotations)

## Overview

Generate schemas automatically by following **naming conventions** and **smart inference** - zero annotations required!

---

## 1) Convention Rules

### File Structure Convention
```
component/
└── config/
    ├── component_theme_defaults.dart       ← Parse this
    ├── component_theme_tokens.dart         ← Parse this
    ├── component_theme_config.dart         ← Skip
    └── component_theme_schema.dart         ← Generate this
```

### Property Naming Conventions

The generator infers everything from property names and types:

| Property Name Pattern | Inferred Field Type | Inferred Group | Example |
|-----------------------|---------------------|----------------|---------|
| `height`, `width`, `minHeight`, `maxWidth` | NumberField | Dimensions | `height = 40.0` |
| `padding*`, `margin*`, `gap*`, `spacing*` | NumberField | Dimensions | `paddingX = 16.0` |
| `border*` | NumberField | Appearance | `borderWidth = 1.0` |
| `radius*`, `corner*` | NumberField | Appearance | `borderRadius = 6.0` |
| `fontSize*`, `fontWeight*`, `letterSpacing*` | NumberField/EnumField | Typography | `fontSize = 14.0` |
| `icon*` | NumberField | Typography | `iconSize = 16.0` |
| `duration*`, `delay*`, `*Duration`, `*Delay` | DurationField | Animation | `duration = 200` |
| `color*`, `*Color`, `background*`, `foreground*` | ColorField | Colors | `backgroundColor` |
| `show*`, `enable*`, `is*`, `has*` | BooleanField | Options | `showIcon = true` |
| `opacity*`, `*Opacity` | NumberField (0-1) | Appearance | `opacity = 0.8` |
| `shadow*`, `elevation*` | NumberField | Appearance | `elevation = 2` |
| `ignore*` | BooleanField | Advanced | `ignoreGlobalScaling` |

### Type-Based Inference

| Dart Type | Schema Field Type | Default Range |
|-----------|-------------------|---------------|
| `double` | NumberField | min: 0, max: 1000, step: 1.0 |
| `int` | NumberField | min: 0, max: 1000, step: 1 |
| `bool` | BooleanField | - |
| `Color` | ColorField | - |
| `Duration` | DurationField | min: 0, max: 5000 (ms) |
| `String` (if limited) | EnumField | Auto-detect options |

---

## 2) Smart Generator Script

**File**: `tool/generate_schemas_convention.dart`

```dart
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main() async {
  print('🔍 Scanning for theme defaults...\n');
  
  final componentsDir = Directory('lib/registry/components');
  int generated = 0;
  
  await for (final entity in componentsDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('_theme_defaults.dart')) {
      final relativePath = entity.path.split('lib/').last;
      print('📄 Processing: $relativePath');
      
      try {
        await generateSchemaForFile(entity);
        generated++;
        print('   ✓ Generated schema\n');
      } catch (e) {
        print('   ✗ Error: $e\n');
      }
    }
  }
  
  print('✨ Complete! Generated $generated schemas');
}

Future<void> generateSchemaForFile(File file) async {
  final content = await file.readAsString();
  final parseResult = parseString(content: content);
  
  final visitor = _DefaultsAnalyzer();
  parseResult.unit.visitChildren(visitor);
  
  if (visitor.classInfo == null) {
    throw Exception('No defaults class found');
  }
  
  // Generate schema
  final schemaContent = _generateSchema(visitor.classInfo!);
  
  // Write to schema file
  final schemaFile = File(file.path.replaceAll('_defaults.dart', '_schema.dart'));
  await schemaFile.writeAsString(schemaContent);
}

String _generateSchema(_ClassInfo classInfo) {
  // Group fields by inferred group
  final groupedFields = <String, List<_FieldInfo>>{};
  
  for (final field in classInfo.fields) {
    final group = _inferGroup(field.name);
    groupedFields.putIfAbsent(group, () => []).add(field);
  }
  
  // Generate groups
  final groupsCode = groupedFields.entries.map((entry) {
    final fieldsCode = entry.value.map((f) => _generateFieldCode(f)).join(',\n          ');
    
    return '''
      SchemaGroup(
        title: '${entry.key}',
        fields: [
          $fieldsCode
        ],
      )''';
  }).join(',\n      ');
  
  // Extract component ID from class name
  final id = _extractComponentId(classInfo.className);
  final title = _toTitleCase(id);
  
  return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from: ${classInfo.className}
// Generator: convention-based schema generator

import 'package:flutter_shadcn_kit/registry/shared/theme/schema/component_schema.dart';

class ${classInfo.className}Schema {
  static const String id = '$id';
  
  static const ComponentSchema schema = ComponentSchema(
    id: id,
    title: '$title',
    description: 'Auto-generated schema for $title component',
    groups: [
      $groupsCode
    ],
  );
}
''';
}

String _generateFieldCode(_FieldInfo field) {
  final fieldType = _inferFieldType(field);
  final label = _toLabel(field.name);
  final description = _generateDescription(field.name, field.type);
  
  final params = <String>[];
  params.add("name: '${field.name}'");
  params.add("label: '$label'");
  params.add("description: '$description'");
  params.add("defaultValue: ${field.defaultValue}");
  
  // Add isAdvanced for ignore* fields
  if (field.name.startsWith('ignore')) {
    params.add('isAdvanced: true');
  }
  
  // Add field-specific params
  if (fieldType == 'NumberField') {
    final range = _inferRange(field.name, field.type);
    params.add('min: ${range.min}');
    params.add('max: ${range.max}');
    params.add('step: ${range.step}');
    
    // Add token binding suggestion
    final tokenPath = _suggestTokenPath(field.name);
    if (tokenPath != null) {
      params.add('''tokenBinding: TokenBinding(
              path: '$tokenPath',
              allowedFamilies: ['${_getTokenFamily(field.name)}'],
            )''');
    }
  }
  
  if (fieldType == 'EnumField') {
    final options = _inferEnumOptions(field.name, field.type);
    if (options != null) {
      params.add("options: [${options.map((o) => "'$o'").join(', ')}]");
    }
  }
  
  return '''
$fieldType(
            ${params.join(',\n            ')},
          )''';
}

// ═══════════════════════════════════════════════════════════
// INFERENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════

String _inferGroup(String fieldName) {
  final lower = fieldName.toLowerCase();
  
  if (lower.contains('height') || 
      lower.contains('width') || 
      lower.contains('padding') || 
      lower.contains('margin') ||
      lower.contains('gap') ||
      lower.contains('spacing')) {
    return 'Dimensions';
  }
  
  if (lower.contains('border') || 
      lower.contains('radius') || 
      lower.contains('corner') ||
      lower.contains('shadow') ||
      lower.contains('elevation') ||
      lower.contains('opacity')) {
    return 'Appearance';
  }
  
  if (lower.contains('font') || 
      lower.contains('text') || 
      lower.contains('letter') ||
      lower.contains('icon')) {
    return 'Typography';
  }
  
  if (lower.contains('color') || 
      lower.contains('background') || 
      lower.contains('foreground')) {
    return 'Colors';
  }
  
  if (lower.contains('duration') || 
      lower.contains('delay') || 
      lower.contains('animation')) {
    return 'Animation';
  }
  
  if (lower.startsWith('ignore') || 
      lower.startsWith('enable') || 
      lower.startsWith('disable')) {
    return 'Advanced';
  }
  
  return 'General';
}

String _inferFieldType(_FieldInfo field) {
  final type = field.type;
  
  if (type == 'bool') return 'BooleanField';
  if (type == 'Color') return 'ColorField';
  if (type == 'Duration') return 'DurationField';
  
  // Check for enum-like int (fontWeight)
  if (type == 'int' && field.name.toLowerCase().contains('weight')) {
    return 'EnumField';
  }
  
  if (type == 'double' || type == 'int') {
    return 'NumberField';
  }
  
  return 'NumberField'; // default
}

class _Range {
  final num min;
  final num max;
  final num step;
  
  _Range(this.min, this.max, this.step);
}

_Range _inferRange(String fieldName, String type) {
  final lower = fieldName.toLowerCase();
  final isInt = type == 'int';
  
  // Opacity (0-1)
  if (lower.contains('opacity')) {
    return _Range(0.0, 1.0, 0.05);
  }
  
  // Font sizes (10-32)
  if (lower.contains('fontsize') || lower.contains('textsize')) {
    return _Range(10.0, 32.0, 1.0);
  }
  
  // Dimensions (0-200)
  if (lower.contains('height') || lower.contains('width')) {
    return _Range(0.0, 200.0, 4.0);
  }
  
  // Padding/margin (0-48)
  if (lower.contains('padding') || lower.contains('margin')) {
    return _Range(0.0, 48.0, 4.0);
  }
  
  // Gap/spacing (0-32)
  if (lower.contains('gap') || lower.contains('spacing')) {
    return _Range(0.0, 32.0, 2.0);
  }
  
  // Border width (0-8)
  if (lower.contains('borderwidth') || lower.contains('strokewidth')) {
    return _Range(0.0, 8.0, 0.5);
  }
  
  // Radius (0-32)
  if (lower.contains('radius') || lower.contains('corner')) {
    return _Range(0.0, 32.0, 1.0);
  }
  
  // Icon size (12-48)
  if (lower.contains('icon') && lower.contains('size')) {
    return _Range(12.0, 48.0, 2.0);
  }
  
  // Letter spacing (-2 to 4)
  if (lower.contains('letter') || lower.contains('tracking')) {
    return _Range(-2.0, 4.0, 0.1);
  }
  
  // Shadow/elevation (0-24)
  if (lower.contains('shadow') || lower.contains('elevation')) {
    return _Range(0.0, 24.0, 1.0);
  }
  
  // Default range
  return _Range(0.0, 100.0, isInt ? 1 : 1.0);
}

List<String>? _inferEnumOptions(String fieldName, String type) {
  final lower = fieldName.toLowerCase();
  
  if (lower.contains('weight')) {
    return ['300', '400', '500', '600', '700', '800', '900'];
  }
  
  if (lower.contains('align') && lower.contains('text')) {
    return ['left', 'center', 'right', 'justify'];
  }
  
  if (lower.contains('variant') || lower.contains('style')) {
    return ['default', 'primary', 'secondary', 'outline', 'ghost', 'destructive'];
  }
  
  if (lower.contains('size')) {
    return ['sm', 'md', 'lg', 'xl'];
  }
  
  return null;
}

String? _suggestTokenPath(String fieldName) {
  final lower = fieldName.toLowerCase();
  
  if (lower.contains('padding') || lower.contains('margin') || lower.contains('gap')) {
    return 'spacing.md';
  }
  
  if (lower.contains('radius') || lower.contains('corner')) {
    return 'radius.md';
  }
  
  if (lower.contains('fontsize')) {
    return 'typography.body.fontSize';
  }
  
  return null;
}

String _getTokenFamily(String fieldName) {
  final lower = fieldName.toLowerCase();
  
  if (lower.contains('padding') || lower.contains('margin') || lower.contains('gap')) {
    return 'spacing';
  }
  
  if (lower.contains('radius') || lower.contains('corner')) {
    return 'radius';
  }
  
  if (lower.contains('font') || lower.contains('text')) {
    return 'typography';
  }
  
  if (lower.contains('color') || lower.contains('background')) {
    return 'palette';
  }
  
  return 'general';
}

String _toLabel(String fieldName) {
  // Convert camelCase to Title Case
  final result = fieldName.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (match) => ' ${match.group(1)}',
  ).trim();
  
  return result.substring(0, 1).toUpperCase() + result.substring(1);
}

String _generateDescription(String fieldName, String type) {
  final label = _toLabel(fieldName);
  
  if (type == 'bool') {
    if (fieldName.startsWith('show')) return 'Show or hide $label';
    if (fieldName.startsWith('enable')) return 'Enable or disable $label';
    if (fieldName.startsWith('ignore')) return 'Override global theme setting';
    return 'Toggle $label';
  }
  
  if (fieldName.toLowerCase().contains('radius')) {
    return '$label in pixels (affected by theme.radius)';
  }
  
  if (fieldName.toLowerCase().contains('opacity')) {
    return '$label (0.0 = transparent, 1.0 = opaque)';
  }
  
  if (type == 'Color') {
    return '$label (hex format: #RRGGBB or #AARRGGBB)';
  }
  
  if (type == 'Duration' || fieldName.toLowerCase().contains('duration')) {
    return '$label in milliseconds';
  }
  
  return '$label in pixels (affected by theme.scaling)';
}

String _extractComponentId(String className) {
  // ButtonThemeDefaults -> button
  return className
      .replaceAll('ThemeDefaults', '')
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m.group(1)?.toLowerCase()}')
      .substring(1);
}

String _toTitleCase(String text) {
  return text.split('_').map((word) => 
    word.substring(0, 1).toUpperCase() + word.substring(1)
  ).join(' ');
}

// ═══════════════════════════════════════════════════════════
// AST VISITOR
// ═══════════════════════════════════════════════════════════

class _DefaultsAnalyzer extends SimpleAstVisitor<void> {
  _ClassInfo? classInfo;
  
  @override
  void visitCompilationUnit(CompilationUnit node) {
    for (final declaration in node.declarations) {
      if (declaration is ClassDeclaration && 
          declaration.name.lexeme.endsWith('ThemeDefaults')) {
        _analyzeClass(declaration);
        break;
      }
    }
  }
  
  void _analyzeClass(ClassDeclaration node) {
    final fields = <_FieldInfo>[];
    
    for (final member in node.members) {
      if (member is FieldDeclaration && !member.isStatic) {
        for (final variable in member.fields.variables) {
          final fieldType = member.fields.type?.toSource() ?? 'dynamic';
          final fieldName = variable.name.lexeme;
          
          // Find default value from constructor
          String? defaultValue;
          for (final constructor in node.members.whereType<ConstructorDeclaration>()) {
            for (final param in constructor.parameters.parameters) {
              if (param is DefaultFormalParameter && 
                  param.name?.lexeme == fieldName) {
                defaultValue = param.defaultValue?.toSource();
                break;
              }
            }
          }
          
          fields.add(_FieldInfo(
            name: fieldName,
            type: fieldType.replaceAll('?', ''),
            defaultValue: defaultValue ?? 'null',
          ));
        }
      }
    }
    
    classInfo = _ClassInfo(
      className: node.name.lexeme,
      fields: fields,
    );
  }
}

class _ClassInfo {
  final String className;
  final List<_FieldInfo> fields;
  
  _ClassInfo({required this.className, required this.fields});
}

class _FieldInfo {
  final String name;
  final String type;
  final String defaultValue;
  
  _FieldInfo({
    required this.name,
    required this.type,
    required this.defaultValue,
  });
}
```

---

## 3) Usage

### Generate All Schemas

```bash
dart tool/generate_schemas_convention.dart
```

**Output:**
```
🔍 Scanning for theme defaults...

📄 Processing: registry/components/control/button/_impl/themes/config/button_theme_defaults.dart
   ✓ Generated schema

📄 Processing: registry/components/control/checkbox/_impl/themes/config/checkbox_theme_defaults.dart
   ✓ Generated schema

📄 Processing: registry/components/feedback/toast/_impl/themes/config/toast_theme_defaults.dart
   ✓ Generated schema

✨ Complete! Generated 3 schemas
```

---

## 4) Example Input/Output

### Input: `button_theme_defaults.dart`

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
  final double letterSpacing;
  final double iconSize;
  final bool ignoreGlobalScaling;
  final bool ignoreGlobalRadius;
  
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
    this.letterSpacing = 0.0,
    this.iconSize = 16.0,
    this.ignoreGlobalScaling = false,
    this.ignoreGlobalRadius = false,
  });
}
```

### Generated Output: `button_theme_schema.dart`

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from: ButtonThemeDefaults
// Generator: convention-based schema generator

import 'package:flutter_shadcn_kit/registry/shared/theme/schema/component_schema.dart';

class ButtonThemeDefaultsSchema {
  static const String id = 'button';
  
  static const ComponentSchema schema = ComponentSchema(
    id: id,
    title: 'Button',
    description: 'Auto-generated schema for Button component',
    groups: [
      SchemaGroup(
        title: 'Dimensions',
        fields: [
          NumberField(
            name: 'height',
            label: 'Height',
            description: 'Height in pixels (affected by theme.scaling)',
            defaultValue: 40.0,
            min: 0.0,
            max: 200.0,
            step: 4.0,
          ),
          NumberField(
            name: 'minWidth',
            label: 'Min Width',
            description: 'Min Width in pixels (affected by theme.scaling)',
            defaultValue: 80.0,
            min: 0.0,
            max: 200.0,
            step: 4.0,
          ),
          NumberField(
            name: 'paddingX',
            label: 'Padding X',
            description: 'Padding X in pixels (affected by theme.scaling)',
            defaultValue: 16.0,
            min: 0.0,
            max: 48.0,
            step: 4.0,
            tokenBinding: TokenBinding(
              path: 'spacing.md',
              allowedFamilies: ['spacing'],
            ),
          ),
          NumberField(
            name: 'paddingY',
            label: 'Padding Y',
            description: 'Padding Y in pixels (affected by theme.scaling)',
            defaultValue: 0.0,
            min: 0.0,
            max: 48.0,
            step: 4.0,
            tokenBinding: TokenBinding(
              path: 'spacing.md',
              allowedFamilies: ['spacing'],
            ),
          ),
          NumberField(
            name: 'gap',
            label: 'Gap',
            description: 'Gap in pixels (affected by theme.scaling)',
            defaultValue: 8.0,
            min: 0.0,
            max: 32.0,
            step: 2.0,
            tokenBinding: TokenBinding(
              path: 'spacing.md',
              allowedFamilies: ['spacing'],
            ),
          ),
        ],
      ),
      SchemaGroup(
        title: 'Appearance',
        fields: [
          NumberField(
            name: 'borderWidth',
            label: 'Border Width',
            description: 'Border Width in pixels (affected by theme.scaling)',
            defaultValue: 1.0,
            min: 0.0,
            max: 8.0,
            step: 0.5,
          ),
          NumberField(
            name: 'borderRadius',
            label: 'Border Radius',
            description: 'Border Radius in pixels (affected by theme.radius)',
            defaultValue: 6.0,
            min: 0.0,
            max: 32.0,
            step: 1.0,
            tokenBinding: TokenBinding(
              path: 'radius.md',
              allowedFamilies: ['radius'],
            ),
          ),
        ],
      ),
      SchemaGroup(
        title: 'Typography',
        fields: [
          NumberField(
            name: 'fontSize',
            label: 'Font Size',
            description: 'Font Size in pixels (affected by theme.scaling)',
            defaultValue: 14.0,
            min: 10.0,
            max: 32.0,
            step: 1.0,
            tokenBinding: TokenBinding(
              path: 'typography.body.fontSize',
              allowedFamilies: ['typography'],
            ),
          ),
          EnumField(
            name: 'fontWeight',
            label: 'Font Weight',
            description: 'Font Weight in pixels (affected by theme.scaling)',
            defaultValue: 500,
            options: ['300', '400', '500', '600', '700', '800', '900'],
          ),
          NumberField(
            name: 'letterSpacing',
            label: 'Letter Spacing',
            description: 'Letter Spacing in pixels (affected by theme.scaling)',
            defaultValue: 0.0,
            min: -2.0,
            max: 4.0,
            step: 0.1,
          ),
          NumberField(
            name: 'iconSize',
            label: 'Icon Size',
            description: 'Icon Size in pixels (affected by theme.scaling)',
            defaultValue: 16.0,
            min: 12.0,
            max: 48.0,
            step: 2.0,
          ),
        ],
      ),
      SchemaGroup(
        title: 'Advanced',
        fields: [
          BooleanField(
            name: 'ignoreGlobalScaling',
            label: 'Ignore Global Scaling',
            description: 'Override global theme setting',
            defaultValue: false,
            isAdvanced: true,
          ),
          BooleanField(
            name: 'ignoreGlobalRadius',
            label: 'Ignore Global Radius',
            description: 'Override global theme setting',
            defaultValue: false,
            isAdvanced: true,
          ),
        ],
      ),
    ],
  );
}
```

---

## 5) Add to Your Build Process

**File**: `Makefile` or `package.json` scripts

```makefile
schemas:
	@echo "🔄 Generating schemas..."
	@dart tool/generate_schemas_convention.dart
	
schemas-json:
	@echo "📦 Exporting schemas to JSON..."
	@dart tool/export_schemas.dart
	
schemas-all: schemas schemas-json
```

Then run:
```bash
make schemas-all
```

---

## 6) Benefits

### ✅ Zero Developer Overhead
- No annotations to write
- No annotations to maintain
- Just write your defaults class normally

### ✅ Smart Inference
- Groups inferred from property names
- Ranges inferred from property names/types
- Token bindings suggested automatically
- Field types inferred from Dart types

### ✅ Always Up-to-Date
- Run generator after changing defaults
- Schemas automatically match defaults
- No sync issues possible

### ✅ Customizable
- Tweak inference rules as needed
- Add special cases for your patterns
- Override auto-detection when needed

---

## 7) Override Auto-Detection (Optional)

If you need to override the auto-detection for specific cases, add a simple JSON file:

**File**: `button_schema_overrides.json` (next to defaults file)

```json
{
  "groups": {
    "height": "Layout",
    "paddingX": "Layout"
  },
  "ranges": {
    "height": { "min": 32, "max": 96, "step": 8 }
  },
  "labels": {
    "paddingX": "Horizontal Padding"
  },
  "tokenPaths": {
    "height": "size.lg"
  }
}
```

The generator checks for this file and applies overrides. Still no code annotations needed!

---

## Summary

### ✅ Convention Over Configuration
- Smart inference from naming patterns
- Type-based field generation
- Automatic grouping and organization

### ✅ Zero Maintenance
- No annotations in your code
- Run one command to regenerate
- Schemas always match defaults

### ✅ Developer-Friendly
- Write defaults naturally
- No extra work required
- Optional JSON overrides for edge cases

**This is the simplest approach!** Just write your defaults class, run the generator, and get perfect schemas automatically. 🎉
