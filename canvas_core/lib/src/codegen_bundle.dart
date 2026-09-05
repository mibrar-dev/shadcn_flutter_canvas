/// Clean-folders bundle exporter (P2c): screens + shadcn bodies + manifest + zip.
///
/// Pure Dart (CLI-reusable): builds the installable `screen add` bundle from
/// a [ScreenDoc]. Kind metadata snapshots `components.json` for the 15 catalog
/// kinds; bodies arrive via [sourcesByDestination]. Unknown kinds warn.
library;

import 'dart:convert';

import 'package:archive/archive.dart';

import 'screen_doc.dart';

/// Result of [buildCleanBundle].
class BundleManifest {
  final String manifestJson; // JSON descriptor (`manifest.json` content).
  final Map<String, String> files; // Writable code files: destPath->content.
  final String pubspecPatch; // YAML merge of used components' pubspec deps.
  final List<int> zipBytes; // Zip of [files] + manifest.json + patch yaml.

  const BundleManifest({
    required this.manifestJson,
    required this.files,
    required this.pubspecPatch,
    required this.zipBytes,
  });
}

/// Per-kind install metadata snapshotted from `components.json`.
/// Positional: (destination-template prefix, shared ids, pubspec deps,
/// component dependsOn). The barrel is derived: `<prefix><kind>.dart`.
class _KindSpec {
  final String prefix;
  final List<String> shared;
  final Map<String, String> pubspecDeps;
  final List<String> dependsOn;

  const _KindSpec(this.prefix, this.shared, this.pubspecDeps, this.dependsOn);
}

// Exact metadata for the 15 catalog kinds (snapshotted from the pinned kit's
// `components.json`: destination prefix from `files[].destination`,
// alphabetized `shared`, `pubspec.dependencies`, `dependsOn` verbatim —
// unknown dep ids warn at export time, same as the seed kinds' `text_field`).
// NOTE: `select`'s `dependsOn` (`async`, `chip`, `command`, `dialog`,
// `hover`, `menu`, `text_field`) names component ids with no `_KindSpec`
// here — they warn at export time (transitively pulled bodies are out of
// scope for this batch; the ids are kept verbatim, never invented).
const _kinds = <String, _KindSpec>{
  'button': _KindSpec('{installPath}/components/control/button/',
      ['clickable', 'color_extensions', 'component_schema', 'focus_outline', 'form_control', 'form_value_supplier', 'generated_colors', 'geometry_extensions', 'menu_group', 'platform_utils', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'card': _KindSpec('{installPath}/components/layout/card/',
      ['border_utils', 'color_extensions', 'component_schema', 'outlined_container', 'sheet_overlay', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'input': _KindSpec('{installPath}/components/form/input/',
      ['constants', 'form_value_supplier', 'lucide_icons', 'overlay', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button', 'text_field']),
  'badge': _KindSpec('{installPath}/components/display/badge/',
      ['component_schema', 'theme'],
      {'gap': '^3.0.1'}, ['button']),
  'switch': _KindSpec('{installPath}/components/form/switch/',
      ['border_utils', 'component_schema', 'focus_outline', 'form_control', 'form_value_supplier', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'avatar': _KindSpec('{installPath}/components/display/avatar/',
      ['component_schema', 'geometry_extensions', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'checkbox': _KindSpec('{installPath}/components/form/checkbox/',
      ['animated_value_builder', 'border_utils', 'clickable', 'color_extensions', 'component_schema', 'constants', 'form_control', 'form_value_supplier', 'style_value', 'text_modifiers', 'theme'],
      {'animation_kit': '^0.0.2', 'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'divider': _KindSpec('{installPath}/components/display/divider/',
      ['animated_value_builder', 'axis', 'axis_insets', 'axis_insets_directional', 'axis_insets_geometry', 'component_schema', 'constants', 'style_value', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'progress': _KindSpec('{installPath}/components/display/progress/',
      ['component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'tabs': _KindSpec('{installPath}/components/navigation/tabs/',
      ['border_utils', 'component_schema', 'constants', 'fade_scroll', 'geometry_extensions', 'outlined_container', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['sortable', 'text', 'button']),
  'accordion': _KindSpec('{installPath}/components/layout/accordion/',
      ['component_schema', 'constants', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'select': _KindSpec('{installPath}/components/form/select/',
      ['clickable', 'component_schema', 'focus_outline', 'form_control', 'form_value_supplier', 'icon_extensions', 'lucide_icons', 'overlay', 'radix_icons', 'style_value', 'subfocus', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['async', 'button', 'chip', 'command', 'dialog', 'hover', 'menu', 'text_field']),
  'radio_group': _KindSpec('{installPath}/components/form/radio_group/',
      ['color_extensions', 'component_schema', 'constants', 'focus_outline', 'form_control', 'form_value_supplier', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card']),
  'skeleton': _KindSpec('{installPath}/components/display/skeleton/',
      ['color_extensions', 'component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1', 'skeletonizer': '^2.1.0+1'}, ['avatar']),
  'breadcrumb': _KindSpec('{installPath}/components/navigation/breadcrumb/',
      ['basic_layout', 'radix_icons', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
};

const _installPath = '{installPath}/';
const _sharedPath = '{sharedPath}/';
const _installRoot = 'lib/ui/shadcn';
const _sharedRoot = 'lib/ui/shadcn/shared';
const _flutterWidgets = 'package:' 'flutter/widgets.dart'; // split: generated output imports widgets, this file does not.

/// Builds the clean-folders bundle for [doc].
BundleManifest buildCleanBundle(
  ScreenDoc doc,
  Map<String, String> sourcesByDestination,
) {
  final warnings = <String>[];
  final kinds = <String>[];
  void requireKind(String kind, String requiredBy) {
    if (kinds.contains(kind)) return;
    final spec = _kinds[kind];
    if (spec == null) {
      warnings.add("unknown component '$kind' required by $requiredBy: skipped");
      return;
    }
    kinds.add(kind);
    for (final dep in spec.dependsOn) {
      requireKind(dep, "'$kind'");
    }
  }

  for (final node in doc.nodes) {
    for (final item in node.items) {
      if (_kinds[item.kind] == null) {
        warnings.add("unknown kind '${item.kind}' (item ${item.id}): skipped");
      } else {
        requireKind(item.kind, 'canvas item ${item.id}');
      }
    }
  }
  // Component bodies + manifest files[] (registry source -> resolved dest).
  final bodies = <String, String>{};
  final manifestFiles = <Map<String, String>>[];
  for (final kind in kinds) {
    final templates = sourcesByDestination.keys
        .where((k) => k.startsWith(_kinds[kind]!.prefix))
        .toList()
      ..sort();
    for (final template in templates) {
      final dest = _resolveDestination(template);
      bodies[dest] = sourcesByDestination[template]!;
      manifestFiles.add(
        {'source': _registrySource(template), 'destination': dest},
      );
    }
  }
  manifestFiles.sort((a, b) => a['destination']!.compareTo(b['destination']!));
  // One minimal scaffold per screen (deduped snake names).
  final screenNames = <String>[];
  final usedPaths = <String>{};
  final screenFiles = <String, String>{};
  for (final screen in doc.screens) {
    var slug = _snakeName(screen.name);
    var path = _screenPath(slug);
    if (usedPaths.contains(path)) {
      var i = 2;
      while (usedPaths.contains(_screenPath('${slug}_$i'))) {
        i++;
      }
      slug = '${slug}_$i';
      path = _screenPath(slug);
    }
    usedPaths.add(path);
    screenNames.add(slug);
    screenFiles[path] = _screenFile(doc, screen, kinds);
  }
  final shared = <String>{
    for (final kind in kinds) ..._kinds[kind]!.shared,
  }.toList()
    ..sort();
  final deps = <String, String>{};
  for (final kind in kinds) {
    deps.addAll(_kinds[kind]!.pubspecDeps);
  }
  final depKeys = deps.keys.toList()..sort();
  final manifest = <String, dynamic>{
    'screens': screenNames,
    'namespace': 'shadcn',
    'root': _installRoot,
    'files': manifestFiles,
    'shared': shared,
    'pubspec': {'dependencies': {for (final k in depKeys) k: deps[k]}},
    'entry': doc.screens.isEmpty ? '' : screenFiles.keys.first,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
  final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest) + '\n';
  final patch = StringBuffer('# GENERATED by canvas bundle exporter — merge into pubspec.yaml.\ndependencies:\n');
  if (depKeys.isEmpty) {
    patch.write('  {}\n');
  } else {
    for (final k in depKeys) {
      patch.write('  $k: ${deps[k]}\n');
    }
  }

  final files = <String, String>{...screenFiles, ...bodies};
  return BundleManifest(
    manifestJson: manifestJson,
    files: files,
    pubspecPatch: patch.toString(),
    zipBytes: _zipBundle(files, manifestJson, patch.toString()),
  );
}

String _resolveDestination(String t) {
  if (t.startsWith(_installPath)) return '$_installRoot/${t.substring(_installPath.length)}';
  if (t.startsWith(_sharedPath)) return '$_sharedRoot/${t.substring(_sharedPath.length)}';
  return t;
}

String _registrySource(String t) {
  if (t.startsWith(_installPath)) return 'registry/${t.substring(_installPath.length)}';
  if (t.startsWith(_sharedPath)) return 'registry/shared/${t.substring(_sharedPath.length)}';
  return t;
}

List<int> _zipBundle(Map<String, String> files, String manifestJson, String pubspecPatch) {
  final archive = Archive();
  final names = [...files.keys, 'manifest.json', 'pubspec_patch.yaml']..sort();
  for (final name in names) {
    final content = name == 'manifest.json' ? manifestJson : name == 'pubspec_patch.yaml' ? pubspecPatch : files[name]!;
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

String _screenPath(String slug) => slug.endsWith('_screen')
    ? 'lib/ui/screens/$slug.dart'
    : 'lib/ui/screens/${slug}_screen.dart';

String _barrel(String kind) => '$_installRoot/${_kinds[kind]!.prefix.substring(_installPath.length)}$kind.dart';

/// Minimal screen scaffold: package imports plus item placeholders.
/// Component bodies are NOT inlined — they ship under `lib/ui/shadcn/`
/// (barrel paths listed in the header for wiring).
String _screenFile(ScreenDoc doc, CanvasScreen screen, List<String> kinds) {
  final routes = {for (final s in doc.screens) s.id: _routeOf(s.name)};
  final nodes = [
    for (final n in doc.nodes)
      if (n.screenId == screen.id) n,
  ]..sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });
  final usedKinds = {
    for (final n in nodes)
      for (final i in n.items)
        if (kinds.contains(i.kind)) i.kind,
  }.toList()
    ..sort();
  final rows = <String>[];
  for (final node in nodes) {
    for (final item in node.items) {
      final detail = _detailOf(item);
      final action = item.action == null
          ? ''
          : ' — pushes ${routes[item.action!.to] ?? '/${item.action!.to}'}';
      rows.add(
        "      // ${item.kind} '${_labelOf(item)}'"
        "${detail.isEmpty ? '' : ' ($detail)'}$action.",
      );
      rows.add("      Text('${_labelOf(item)}'),");
    }
  }
  if (rows.isEmpty) rows.add('      // (empty screen).');
  final barrels = usedKinds.isEmpty ? '// (no known components on this screen).' : [for (final k in usedKinds) '// - $k -> ${_barrel(k)}'].join('\n');
  final cls = _pascalName(screen.name);
  return '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
// Screen: ${screen.name} (id: ${screen.id}). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
$barrels
import '$_flutterWidgets';

/// ${screen.name} screen.
class ${cls}Screen extends StatelessWidget {
  const ${cls}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
${rows.join('\n')}
      ],
    );
  }
}
''';
}

String _labelOf(CanvasItem item) {
  for (final key in ['label', 'title', 'placeholder']) {
    final value = item.props[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return item.kind;
}

String _detailOf(CanvasItem item) {
  final keys = item.props.keys
      .where((k) => k != 'label' && k != 'title' && k != 'placeholder')
      .toList()
    ..sort();
  return keys.map((k) => '$k ${item.props[k]}').join(', ');
}

String _routeOf(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-\$'), '');
  return '/${slug.isEmpty ? 'screen' : slug}';
}

String _snakeName(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp('^_+|_+\$'), '');
  return slug.isEmpty ? 'screen' : slug;
}

String _pascalName(String name) {
  final parts = name
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'Screen';
  final joined = parts.map((p) => p[0].toUpperCase() + p.substring(1)).join();
  return RegExp('^[0-9]').hasMatch(joined) ? '_$joined' : joined;
}
