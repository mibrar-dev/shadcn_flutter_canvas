import 'dart:convert';
import 'dart:io';

const _allowedTypes = {'string', 'bool', 'double', 'enum', 'color', 'icon', 'slot'};
const _allowedGroups = {'content', 'style', 'state', 'layout', 'behavior', 'advanced'};

/// Testable core: returns per-manifest counts plus `componentId/canvas/prop` errors.
({int checked, int withCanvas, List<String> errors}) validateManifest(
  Map<String, dynamic> manifest,
) {
  final components = manifest['components'] as List;
  var checked = 0, withCanvas = 0;
  final errors = <String>[];
  for (final c in components) {
    checked++;
    final id = (c as Map)['id'] as String;
    final canvas = c['canvas'];
    if (canvas == null) continue;
    withCanvas++;
    final props = (canvas as Map)['propsSchema'] as List?;
    if (props == null || props.isEmpty) {
      errors.add('$id/canvas: propsSchema must be a non-empty array');
      continue;
    }
    for (final p in props) {
      final prop = p as Map;
      if (!_allowedTypes.contains(prop['type'])) {
        errors.add("$id/canvas/${prop['name']}: unknown type ${prop['type']}");
      }
      if (!_allowedGroups.contains(prop['group'])) {
        errors.add("$id/canvas/${prop['name']}: unknown group ${prop['group']}");
      }
      final enumValues = prop['enum'] as List?;
      if (prop['type'] == 'enum' && (enumValues == null || enumValues.isEmpty)) {
        errors.add("$id/canvas/${prop['name']}: enum type needs non-empty enum list");
      }
      _checkDefault(prop['type'] as String, prop['default'], enumValues,
          "$id/canvas/${prop['name']}", errors);
    }
  }
  return (checked: checked, withCanvas: withCanvas, errors: errors);
}

void _checkDefault(
  String type,
  Object? def,
  List? enumValues,
  String ctx,
  List<String> errors,
) {
  switch (type) {
    case 'string':
      if (def is! String) errors.add('$ctx: default must be a string');
    case 'bool':
      if (def is! bool) errors.add('$ctx: default must be a bool');
    case 'double':
      // JSON has no int/double split: accept num, normalize with (v as num).toDouble().
      if (def is! num) errors.add('$ctx: default must be a number');
    case 'color':
    case 'icon':
      if (def is! String) errors.add('$ctx: $type default must be a string');
    case 'enum':
      if (enumValues == null || !enumValues.contains(def)) {
        errors.add('$ctx: default must be one of $enumValues');
      }
    case 'slot':
      break; // slots carry widget trees, not scalar defaults
  }
}

int main(List<String> args) {
  final manifestPath = args.contains('--manifest')
      ? args[args.indexOf('--manifest') + 1]
      : 'shadcn_flutter_kit/flutter_shadcn_kit/lib/registry/manifests/components.json';
  final manifest = jsonDecode(File(manifestPath).readAsStringSync()) as Map<String, dynamic>;
  final result = validateManifest(manifest);
  if (result.errors.isNotEmpty) {
    for (final e in result.errors) stderr.writeln('ERROR $e');
    // NOTE(deviation from plan): `dart tool/validate_canvas.dart` (direct
    // script execution, no pubspec at repo root) ignores a sync int main()
    // return on Dart 3.12.2, so set exitCode explicitly for the CI gate.
    exitCode = 2;
    return 2;
  }
  stdout.writeln('✓ ${result.checked} checked, ${result.withCanvas} canvas-ready');
  return 0;
}
