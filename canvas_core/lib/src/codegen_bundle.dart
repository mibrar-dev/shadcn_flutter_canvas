/// Clean-folders bundle exporter (P2c): screens + shadcn bodies + manifest + zip.
///
/// Pure Dart (CLI-reusable): builds the installable `screen add` bundle from
/// a [ScreenDoc]. Kind metadata snapshots `components.json` for the 29
/// canvas-ready kinds; bodies arrive via [sourcesByDestination]. Unknown kinds warn.
///
/// Emitted screens are vanilla `StatefulWidget`s with no store dependency
/// (flutter + kit only): adopt any state management by lifting the `build`
/// body into your own widget. Per-node responsive uses the same
/// tier-conditional idiom as `codegen_single.dart`; tap actions navigate
/// with `Navigator.pushNamed` to the target screen's route (unknown `to`
/// ids emit a comment and no navigation, never a crash).
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

// Exact metadata for the 46 canvas-ready kinds (19 seed + 10 W1: chip, alert,
// circular_progress_indicator, linear_progress_indicator, triple_dots,
// dot_indicator, empty_state, code_snippet, number_ticker, text_area + 17
// Track J: basic, card_image, scaffold, collapsible, steps, timeline,
// outlined_container, hidden, keyboard_shortcut, tracker, chat, selectable,
// star_rating, clickable, scrollbar, pagination, alert_dialog —
// snapshotted from the pinned kit's `components.json`: destination prefix
// from `files[].destination` (`{installPath}/components/<category>/<id>/`),
// alphabetized `shared`, `pubspec.dependencies`, `dependsOn` verbatim —
// unknown dep ids warn at export time, same as the seed kinds' `text_field`).
// NOTE: `select`'s `dependsOn` (`async`, `command`, `hover`,
// `menu`, `text_field`) names component ids with no `_KindSpec` here — they
// warn at export time (transitively pulled bodies are out of scope for this
// batch; the ids are kept verbatim, never invented). Its `chip` and `dialog`
// deps now resolve (this batch adds `chip`; `dialog` came with the seed
// batch, pulling `card` transitively).
// NOTE: `tooltip`'s `dependsOn` (`popover`) likewise names a component id
// with no `_KindSpec` here — it warns at export time (same verbatim policy).
// NOTE: `text_area`'s `dependsOn` (`text_field`) warns the same way `input`'s
// does (verbatim policy).
// NOTE (Track J): `scaffold`'s `dependsOn` (`drawer`, `linear_progress_indicator`,
// `text`) partially warns — `drawer`/`linear_progress_indicator` resolve, `text`
// has no `_KindSpec` (verbatim policy). `steps`/`timeline` also name `text`.
// `card_image`'s (`basic`, `button`, `outlined_container`), `chat`'s (same
// three), `collapsible`'s (`button`), `keyboard_shortcut`'s (`card`),
// `tracker`'s (`tooltip`), `pagination`'s (`button`, `triple_dots`), and
// `alert_dialog`'s (`dialog`) deps all resolve.
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
  'dialog': _KindSpec('{installPath}/components/overlay/dialog/',
      ['color_extensions', 'component_schema', 'constants', 'geometry_extensions', 'overlay', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card']),
  'tooltip': _KindSpec('{installPath}/components/overlay/tooltip/',
      ['animated_value_builder', 'color_extensions', 'component_schema', 'constants', 'hover', 'outlined_container', 'overlay', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['popover']),
  'toast': _KindSpec('{installPath}/components/overlay/toast/',
      ['component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'drawer': _KindSpec('{installPath}/components/overlay/drawer/',
      ['color_extensions', 'component_schema', 'constants', 'controlled_animation', 'geometry_extensions', 'outlined_container', 'overlay', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['dialog']),
  'chip': _KindSpec('{installPath}/components/display/chip/',
      ['component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, ['button']),
  'alert': _KindSpec('{installPath}/components/layout/alert/',
      ['basic_layout', 'component_schema', 'outlined_container', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'circular_progress_indicator': _KindSpec('{installPath}/components/display/circular_progress_indicator/',
      ['animated_value_builder', 'color_extensions', 'component_schema', 'constants', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'linear_progress_indicator': _KindSpec('{installPath}/components/display/linear_progress_indicator/',
      ['animated_value_builder', 'color_extensions', 'component_schema', 'constants', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'triple_dots': _KindSpec('{installPath}/components/display/triple_dots/',
      [],
      {}, []),
  'dot_indicator': _KindSpec('{installPath}/components/display/dot_indicator/',
      ['clickable', 'component_schema', 'constants', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'empty_state': _KindSpec('{installPath}/components/display/empty_state/',
      ['component_schema', 'radix_icons', 'theme'],
      {'gap': '^3.0.1'}, ['card', 'button']),
  'code_snippet': _KindSpec('{installPath}/components/display/code_snippet/',
      ['component_schema', 'style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'number_ticker': _KindSpec('{installPath}/components/display/number_ticker/',
      ['animated_value_builder', 'component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1', 'intl': '^0.20.2'}, []),
  'text_area': _KindSpec('{installPath}/components/form/text_area/',
      ['theme'],
      {'gap': '^3.0.1'}, ['text_field']),
  'basic': _KindSpec('{installPath}/components/layout/basic/',
      ['style_value', 'text_modifiers', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'card_image': _KindSpec('{installPath}/components/layout/card_image/',
      ['constants', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, ['basic', 'button', 'outlined_container']),
  'scaffold': _KindSpec('{installPath}/components/layout/scaffold/',
      ['color_extensions', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['drawer', 'linear_progress_indicator', 'text']),
  'collapsible': _KindSpec('{installPath}/components/layout/collapsible/',
      ['component_schema', 'text_modifiers', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['button']),
  'steps': _KindSpec('{installPath}/components/layout/steps/',
      ['theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['text']),
  'timeline': _KindSpec('{installPath}/components/layout/timeline/',
      ['theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['text']),
  'outlined_container': _KindSpec('{installPath}/components/layout/outlined_container/',
      ['animated_value_builder', 'border_utils', 'component_schema', 'constants', 'geometry_extensions', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'hidden': _KindSpec('{installPath}/components/layout/hidden/',
      ['animated_value_builder', 'component_schema', 'constants', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'keyboard_shortcut': _KindSpec('{installPath}/components/display/keyboard_shortcut/',
      ['color_extensions', 'component_schema', 'keyboard_shortcut_utils', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['card']),
  'tracker': _KindSpec('{installPath}/components/display/tracker/',
      ['component_schema', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['tooltip']),
  'chat': _KindSpec('{installPath}/components/display/chat/',
      ['axis', 'clickable', 'constants', 'style_value', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['basic', 'button', 'outlined_container']),
  'selectable': _KindSpec('{installPath}/components/display/selectable/',
      ['theme'],
      {'gap': '^3.0.1'}, []),
  'star_rating': _KindSpec('{installPath}/components/form/star_rating/',
      ['animated_value_builder', 'component_schema', 'constants', 'form_control', 'form_value_supplier', 'style_value', 'theme', 'util'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'clickable': _KindSpec('{installPath}/components/control/clickable/',
      ['animated_value_builder', 'clickable', 'constants', 'focus_outline', 'platform_utils', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, []),
  'scrollbar': _KindSpec('{installPath}/components/control/scrollbar/',
      ['component_schema', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, []),
  'pagination': _KindSpec('{installPath}/components/navigation/pagination/',
      ['icon_extensions', 'localizations', 'radix_icons', 'style_value', 'theme'],
      {'gap': '^3.0.1'}, ['button', 'triple_dots']),
  'alert_dialog': _KindSpec('{installPath}/components/overlay/alert_dialog/',
      ['overlay', 'theme'],
      {'data_widget': '^0.0.2', 'gap': '^3.0.1'}, ['dialog']),
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
///
/// Vanilla `StatefulWidget` with no store dependency (see the library docs):
/// per-node responsive rides the `codegen_single.dart` tier-conditional
/// idiom, and items with tap actions navigate with `Navigator.pushNamed`.
String _screenFile(ScreenDoc doc, CanvasScreen screen, List<String> kinds) {
  final routes = {for (final s in doc.screens) s.id: _routeOf(s.name)};
  final ids = {for (final s in doc.screens) s.id};
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
    _writeBundleNode(rows, node, routes, ids, '      ');
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
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `package:flutter/widgets.dart`
/// plus the shipped kit bodies.
class ${cls}Screen extends StatefulWidget {
  const ${cls}Screen({super.key});

  @override
  State<${cls}Screen> createState() => _${cls}ScreenState();
}

class _${cls}ScreenState extends State<${cls}Screen> {
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

/// Whether [node] needs a responsive wrapper: the same rule as
/// `codegen_single.dart` — a known `hiddenOn` tier or a known-tier
/// `breakpointValues` entry. Unknown tiers are inert, so docs without
/// responsive fields keep byte-identical output.
bool _isBundleResponsive(CanvasNode node) =>
    _bundleHiddenTiers(node).isNotEmpty || _bundleOverrideTiers(node).isNotEmpty;

/// Known `hiddenOn` tiers, sorted (deterministic conditions/comments).
List<String> _bundleHiddenTiers(CanvasNode node) =>
    (node.hiddenOn.where(kResponsiveTiers.contains).toList()..sort());

/// Known `breakpointValues` tiers, sorted (deterministic branch order).
List<String> _bundleOverrideTiers(CanvasNode node) =>
    (node.breakpointValues.keys.where(kResponsiveTiers.contains).toList()
      ..sort());

/// One-line `// kind 'label' (...)` doc comment for [item], naming the tap
/// target route (or the unknown-target fallback) when it has an action.
String _bundleItemComment(
  CanvasItem item,
  Map<String, String> routes,
  Set<String> ids,
) {
  final detail = _detailOf(item);
  final head =
      "// ${item.kind} '${_labelOf(item)}'${detail.isEmpty ? '' : ' ($detail)'}";
  final action = item.action;
  if (action == null) return '$head.';
  final route = ids.contains(action.to) ? routes[action.to] : null;
  if (route == null) return "$head — unknown target '${action.to}': no navigation.";
  return '$head — pushes $route (transition: ${action.transition}).';
}

/// Placeholder widget expression lines for [item] (unindented, trailing
/// comma on the last line). An item whose action targets a known screen
/// wraps in a `GestureDetector` pushing the route by name (the transition
/// rides along as a comment — `pushNamed` carries no transition); unknown
/// `to` ids and action-less items render the bare placeholder, never a
/// crash.
List<String> _bundleItemExpr(
  CanvasItem item,
  Map<String, String> routes,
  Set<String> ids,
) {
  final label = _labelOf(item);
  final action = item.action;
  if (action == null) return ["Text('$label'),"];
  final route = ids.contains(action.to) ? routes[action.to] : null;
  if (route == null) return ["Text('$label'),"];
  return [
    'GestureDetector(',
    "  onTap: () => Navigator.of(context).pushNamed('$route'), // transition: ${action.transition}",
    "  child: Text('$label'),",
    '),',
  ];
}

/// Writes [node]'s placeholder rows at [indent]: plain item widgets, or —
/// for responsive nodes — a `LayoutBuilder` tier conditional in the
/// `codegen_single.dart` idiom (tier resolution line, hidden-tier early
/// return, one `if (tier == …)` branch per override tier with statically
/// merged props, then the default branch). A node hidden on every tier
/// emits a bare `SizedBox.shrink()`.
void _writeBundleNode(
  List<String> rows,
  CanvasNode node,
  Map<String, String> routes,
  Set<String> ids,
  String indent,
) {
  final hidden = _bundleHiddenTiers(node);
  final tiers = _bundleOverrideTiers(node);
  if (hidden.length == kResponsiveTiers.length) {
    rows
      ..add('$indent// hidden on: ${hidden.join(', ')} (all tiers)')
      ..add('${indent}const SizedBox.shrink(),');
    return;
  }
  if (!_isBundleResponsive(node)) {
    for (final item in node.items) {
      rows.add('$indent${_bundleItemComment(item, routes, ids)}');
      for (final line in _bundleItemExpr(item, routes, ids)) {
        rows.add('$indent$line');
      }
    }
    return;
  }
  final summary = [
    if (hidden.isNotEmpty) 'hidden on ${hidden.join(', ')}',
    if (tiers.isNotEmpty) 'overrides on ${tiers.join(', ')}',
  ].join('; ');
  rows
    ..add('$indent// responsive ($summary)')
    ..add('${indent}LayoutBuilder(')
    ..add('$indent  builder: (context, constraints) {')
    ..add(
      "$indent    final tier = constraints.maxWidth >= 1024 "
      "? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';",
    );
  if (hidden.isNotEmpty) {
    final cond = hidden.map((t) => "tier == '$t'").join(' || ');
    rows.add('$indent    if ($cond) return const SizedBox.shrink();');
  }
  for (final tier in tiers) {
    _writeBundleBranch(
      rows,
      node,
      node.breakpointValues[tier]!,
      routes,
      ids,
      '$indent    ',
      "tier == '$tier'",
    );
  }
  _writeBundleBranch(rows, node, const {}, routes, ids, '$indent    ', null);
  rows
    ..add('$indent  },')
    ..add('$indent),');
}

/// Writes one tier branch (or the default branch when [guard] is null):
/// the item doc comments above a `return <expr>;` for the node's
/// placeholder content with [overrides] statically merged over item props.
void _writeBundleBranch(
  List<String> rows,
  CanvasNode node,
  Map<String, dynamic> overrides,
  Map<String, String> routes,
  Set<String> ids,
  String indent,
  String? guard,
) {
  final items = [
    for (final item in node.items)
      overrides.isEmpty
          ? item
          : item.copyWith(props: {...item.props, ...overrides}),
  ];
  for (final item in items) {
    rows.add('$indent${_bundleItemComment(item, routes, ids)}');
  }
  final expr = _bundleNodeExpr(items, routes, ids);
  final prefix = guard == null ? 'return ' : 'if ($guard) return ';
  final lines = [
    for (final line in expr.split('\n')) if (line.isNotEmpty) line,
  ];
  for (var i = 0; i < lines.length; i++) {
    final tail = i == lines.length - 1 ? ';' : '';
    if (i == 0) {
      rows.add('$indent$prefix${lines[i]}$tail');
    } else {
      rows.add('$indent${lines[i]}$tail');
    }
  }
}

/// Placeholder content expression for [items] (unindented, no trailing
/// comma): one item renders its widget, empty renders
/// `SizedBox.shrink()`, many render a `Column` of widgets.
String _bundleNodeExpr(
  List<CanvasItem> items,
  Map<String, String> routes,
  Set<String> ids,
) {
  if (items.length == 1) {
    var out = _bundleItemExpr(items.single, routes, ids).join('\n').trimRight();
    if (out.endsWith(',')) out = out.substring(0, out.length - 1);
    return out;
  }
  if (items.isEmpty) return 'SizedBox.shrink()';
  final buf = StringBuffer()
    ..writeln('Column(')
    ..writeln('mainAxisSize: MainAxisSize.min,')
    ..writeln('children: [');
  for (final item in items) {
    for (final line in _bundleItemExpr(item, routes, ids)) {
      buf.writeln('  $line');
    }
  }
  buf.write(')');
  return buf.toString();
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
