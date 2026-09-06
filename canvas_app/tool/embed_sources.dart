// Embeds the registry sources the exporters inline/ship, as a CLOSED map.
//
// WHAT THIS SHIPS (the "embed closure", Track F1). The exporters posed three
// compile gaps (proven by a scratch-package `flutter analyze` of the 10-screen
// demo seed): stripped imports, missing shared files, orphaned parts. This
// tool closes all three from data alone (no exporter-logic change):
//
// 1. COMPONENT BODIES for every kind an exporter can name: the 68 catalog
//    kinds (parsed live from `lib/canvas/component_catalog.dart`, so growing
//    the catalog grows the closure), the 10 hand-verified registry kinds
//    (parsed live from `tool/gen_registry.dart`'s `_readyKinds`), the
//    `text_field` component (the `input` kind's `TextField` lives there —
//    `input`'s `dependsOn` names it), and the transitive `dependsOn` closure
//    of all of the above (`sortable`/`text`/`icon`/`async`/`hover`/`alpha`/
//    `color`/`eye_dropper`/`formatter` — referenced-only kinds with no
//    catalog builder; present so dependency edges resolve to bodies).
//    Each component contributes its manifest `files[]` verbatim
//    (destination keys reused verbatim, so the bundle exporter keeps working).
// 2. SHARED BODIES for the union of every embedded component's `shared[]`
//    ids, resolved through the kit's `shared_manifest.json` groups (verbatim
//    `{sharedPath}/…` destinations, so the bundle exporter's shared-prefix
//    handling keeps working), PLUS a relative-reference fixpoint: any
//    relative `import`/`export`/`part` target that exists on disk but fell
//    outside the union (kit-manifest gaps, e.g. the `theme` group omitting
//    `density.dart`/`design_tokens.dart` its own barrel parts, or the
//    `resizer` group omitting `__borrow_info.dart`) is pulled in as a whole
//    owning group/component. Non-Dart files (fonts, json, READMEs) are never
//    embedded.
// 3. `kEmbeddedImports`: the sorted union of every `dart:` + `package:`
//    import/export URI the embedded bodies reference (both quote styles).
//    `_stripDirectives` deletes these at inline time, so the single-file
//    exporter must re-emit them (package name = first URI segment → pubspec
//    dep). Same-directory bare imports (`'button_size.dart'`) are relative
//    and resolve inside the shipped set — never listed here.
// 4. `kEmbeddedParts`: part-file destination → library destination for every
//    embedded URI-form `part of` (the kit uses no named `part of` and no
//    `library` declarations, so URI resolution is total).
//
// PART MECHANISM (smallest correct): parts ship ALONGSIDE their libraries —
// no rewriting. Every `files[]`/group set already contains each barrel plus
// its `part` targets (verified strictly below), so inliners strip `part of`
// and drop `part` directives into one library scope, and bundlers ship the
// set as separate files with relative URIs intact. The ONE exception is
// preview state: `part of preview.dart` files (nearly every
// `*_preview_state.dart`) cannot compile standalone (dangling `part of` for
// bundles, undefined `CheckboxPreview`-style names for single-file), and
// neither can the one standalone exception (hover's preview state imports
// its preview helper, which is preview surface) — so `preview.dart`
// libraries, `part of preview.dart` files, and files imported only from
// preview surface are EXCLUDED, and the strict pass below fails the regen
// if any other part edge dangles.
//
// STRICTNESS: the tool exits(1) instead of shipping a broken closure when a
// catalog/ready kind is absent from the manifest, a `shared[]` id has no
// group, a relative ref points at a file missing on disk, or any surviving
// `part`/`part of`/relative import/export edge lacks an embedded endpoint.
// Warnings go to stderr; the map is all-or-nothing.
//
// CLI CONTRACT (unchanged): kit root defaults to a `shadcn_flutter_kit`
// checkout sitting next to this repo (the app itself resolves the kit from
// GitHub; only regeneration needs a local checkout). Pass it explicitly to
// override: `dart run tool/embed_sources.dart /path/to/shadcn_flutter_kit`
// (the sibling checkout does not exist in this repo — pass the pub-cache
// path explicitly). Output always lands in this package's lib/, wherever the
// kit was read from.
import 'dart:convert';
import 'dart:io';

/// Catalog kinds parsed from `component_catalog.dart` (must stay exact: a
/// count change means the catalog grew and this tool's expectation needs a
/// deliberate update, not a silent drift).
const _catalogKindCount = 68;

/// Registry ready kinds parsed from `gen_registry.dart` (same exactness rule).
const _readyKindCount = 10;

/// `TextField` (the `input` kind's widget) lives in this component, which has
/// no catalog entry of its own — always seeded explicitly.
const _textFieldKind = 'text_field';

void main(List<String> args) {
  // Kit root defaults to a `shadcn_flutter_kit` checkout sitting next to this
  // repo (the app itself resolves the kit from GitHub; only regeneration
  // needs a local checkout). Pass it explicitly to override:
  // `dart run tool/embed_sources.dart /path/to/shadcn_flutter_kit`.
  final kitRoot = args.isNotEmpty
      ? args[0]
      : '${File(Platform.script.toFilePath()).parent.parent.parent.path}/shadcn_flutter_kit';
  final appRoot = File(Platform.script.toFilePath()).parent.parent;
  final kitLib = '$kitRoot/flutter_shadcn_kit/lib';

  final manifest = jsonDecode(File(
    '$kitLib/registry/manifests/components.json',
  ).readAsStringSync()) as Map<String, dynamic>;
  final byId = <String, Map<String, dynamic>>{
    for (final c in manifest['components'] as List)
      ((c as Map)['id'] as String): (c as Map<String, dynamic>),
  };
  final sharedManifest = jsonDecode(File(
    '$kitLib/registry/shared/shared_manifest.json',
  ).readAsStringSync()) as Map<String, dynamic>;
  final groups = <String, List<Map<String, String>>>{
    for (final g in sharedManifest['groups'] as List)
      ((g as Map)['id'] as String): [
        for (final f in (g['files'] as List))
          {'source': (f as Map)['source'] as String,
           'destination': f['destination'] as String},
      ],
  };
  // Registry-relative source → owning component id / shared group id.
  final sourceOwnerComponent = <String, String>{};
  for (final entry in byId.entries) {
    for (final f in entry.value['files'] as List) {
      sourceOwnerComponent[(f as Map)['source'] as String] = entry.key;
    }
  }
  final sourceOwnerGroup = <String, String>{};
  for (final entry in groups.entries) {
    for (final f in entry.value) {
      sourceOwnerGroup[f['source']!] = entry.key;
    }
  }

  // Seed: catalog kinds (live-parsed) + ready kinds (live-parsed) +
  // text_field, then the transitive dependsOn closure.
  final catalogKinds = _parseCatalogKinds('${appRoot.path}/lib/canvas/component_catalog.dart');
  final readyKinds = _parseReadyKinds('${appRoot.path}/tool/gen_registry.dart');
  final seed = <String>{...catalogKinds, ...readyKinds, _textFieldKind};
  for (final kind in seed) {
    if (!byId.containsKey(kind)) {
      stderr.writeln('embed_sources: kind "$kind" absent from components.json');
      exit(1);
    }
  }
  final kinds = _closeDependsOn(seed, byId);
  final neededShared = <String>{
    for (final kind in kinds) ...(byId[kind]!['shared'] as List).cast<String>(),
  };
  for (final id in neededShared) {
    if (!groups.containsKey(id)) {
      stderr.writeln('embed_sources: shared "$id" has no shared_manifest group');
      exit(1);
    }
  }

  // Destination → registry-relative source, seeded verbatim.
  final destToSource = <String, String>{};
  void addSource(String source, String destination) {
    if (!source.endsWith('.dart')) return; // fonts/json/READMEs never embed.
    destToSource.putIfAbsent(destination, () => source);
  }

  final contentCache = <String, String>{};
  String readSource(String source) => contentCache.putIfAbsent(
    source,
    () => File('$kitLib/$source').readAsStringSync(),
  );

  bool excluded(String source, String content) {
    // Preview libraries never embed (repo policy — previews render full
    // `Scaffold`s), nor do `part of preview.dart` files (they cannot
    // compile without that library). Every other preview-adjacent file is
    // decided by the dangling-edge rule in the fixpoint: `part` targets of
    // a runtime barrel are runtime by construction and always pulled in,
    // while files imported only from preview surface stay out with their
    // importer (see `previewSurface` below). The strict pass below backstops
    // any gap: a surviving dangling edge fails the regen loudly.
    final base = source.split('/').last;
    if (base == 'preview.dart') return true;
    // Preview state parts (`part of preview.dart`) cannot compile without
    // their preview library — drop them, keep everything else.
    for (final uri in _directiveUris(content, which: 'part of')) {
      if (uri.endsWith('/preview.dart') || uri == 'preview.dart') return true;
    }
    return false;
  }

  /// Preview-surface probe: basename contains `preview` (covers
  /// `hover_preview.dart`-style helpers) while `part` targets are exempt —
  /// a barrel parts exactly its library implementation, so a parted file is
  /// runtime by construction (e.g. the eye-dropper's `_color_preview_painter`
  /// is painted by runtime state, despite its name).
  bool previewSurface(String targetSource, String edgeKind) {
    if (edgeKind == 'part') return false;
    return targetSource.split('/').last.contains('preview');
  }

  for (final kind in kinds) {
    for (final f in byId[kind]!['files'] as List) {
      final source = (f as Map)['source'] as String;
      if (!source.endsWith('.dart')) continue;
      final content = readSource(source);
      if (excluded(source, content)) continue;
      addSource(source, f['destination'] as String);
    }
  }
  for (final id in neededShared) {
    for (final f in groups[id]!) {
      if (!f['source']!.endsWith('.dart')) continue;
      final content = readSource(f['source']!);
      if (excluded(f['source']!, content)) continue;
      addSource(f['source']!, f['destination']!);
    }
  }

  // Relative-reference fixpoint at group/component granularity: any relative
  // target existing on disk but not yet embedded pulls its whole owning
  // group/component (plus that component's shared[] + dependsOn, transitively).
  final embeddedSources = {for (final e in destToSource.entries) e.value};
  final queue = embeddedSources.toList();

  void dropExcluded(String source) {
    destToSource.removeWhere((_, v) => v == source);
    embeddedSources.remove(source);
  }

  final pulledComponents = <String>{...kinds};
  final pulledGroups = <String>{...neededShared};
  void pullGroup(String id) {
    if (!pulledGroups.add(id)) return;
    final files = groups[id];
    if (files == null) {
      stderr.writeln('embed_sources: shared "$id" has no shared_manifest group');
      exit(1);
    }
    for (final f in files) {
      if (!f['source']!.endsWith('.dart') ||
          embeddedSources.contains(f['source']!)) {
        continue;
      }
      final content = readSource(f['source']!);
      if (excluded(f['source']!, content)) continue;
      addSource(f['source']!, f['destination']!);
      embeddedSources.add(f['source']!);
      queue.add(f['source']!);
    }
  }

  void pullComponent(String id) {
    if (!pulledComponents.add(id)) return;
    final spec = byId[id];
    if (spec == null) {
      stderr.writeln('embed_sources: dependsOn "$id" is not a component; skipped');
      return;
    }
    for (final dep in (spec['dependsOn'] as List).cast<String>()) {
      pullComponent(dep);
    }
    for (final shared in (spec['shared'] as List).cast<String>()) {
      pullGroup(shared);
    }
    for (final f in spec['files'] as List) {
      final source = (f as Map)['source'] as String;
      if (!source.endsWith('.dart') || embeddedSources.contains(source)) {
        continue;
      }
      final content = readSource(source);
      if (excluded(source, content)) continue;
      addSource(source, f['destination'] as String);
      embeddedSources.add(source);
      queue.add(source);
    }
  }

  String naturalDest(String source) {
    // Mirrors the manifest convention: registry/components/… →
    // {installPath}/components/…, registry/shared/… → {sharedPath}/….
    if (source.startsWith('registry/shared/')) {
      return '{sharedPath}/${source.substring('registry/shared/'.length)}';
    }
    if (source.startsWith('registry/')) {
      return '{installPath}/${source.substring('registry/'.length)}';
    }
    stderr.writeln('embed_sources: no destination convention for "$source"');
    exit(1);
  }

  while (queue.isNotEmpty) {
    final source = queue.removeLast();
    if (!embeddedSources.contains(source)) continue; // dropped meanwhile.
    final onDisk = '$kitLib/$source';
    final base = File(onDisk).parent.path;
    final content = readSource(source);
    for (final ref in _directiveRefs(content)) {
      final uri = ref.uri;
      if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
      final target = _normalizeJoin(base, uri);
      final kitLibPath = '$kitLib/';
      if (!target.startsWith(kitLibPath)) continue;
      final targetSource = target.substring(kitLibPath.length);
      if (embeddedSources.contains(targetSource)) continue;
      if (targetSource.endsWith('/preview.dart') ||
          targetSource == 'preview.dart') {
        continue;
      }
      if (previewSurface(targetSource, ref.kind)) {
        // Imported only from preview surface (e.g. hover's preview state
        // imports its preview helper): the importer is preview surface too
        // — drop it rather than dragging previews into the closure.
        dropExcluded(source);
        break;
      }
      if (!File(target).existsSync()) {
        stderr.writeln('embed_sources: "$source" refs missing "$uri"');
        exit(1);
      }
      final peek = File(target).readAsStringSync();
      if (excluded(targetSource, peek)) continue;
      final ownerComponent = sourceOwnerComponent[targetSource];
      final ownerGroup = sourceOwnerGroup[targetSource];
      if (ownerComponent != null) {
        pullComponent(ownerComponent);
      } else if (ownerGroup != null) {
        pullGroup(ownerGroup);
      } else {
        // No manifest owner (kit-manifest gap): lone file under its natural
        // destination. Must still match convention (asserted in naturalDest).
        contentCache[targetSource] = peek;
        addSource(targetSource, naturalDest(targetSource));
        embeddedSources.add(targetSource);
        queue.add(targetSource);
      }
    }
  }

  // STRICT verification: every surviving relative/part edge resolves inside
  // the map, so inliners (strip directives) and bundlers (ship files) both
  // get a compilable set. Anything dangling fails the regen loudly.
  final sourceByDest = {for (final e in destToSource.entries) e.key: e.value};
  final embeddedSet = embeddedSources;
  String resolveTarget(String source, String uri) {
    final base = File('$kitLib/$source').parent.path;
    final target = _normalizeJoin(base, uri);
    return target.substring('$kitLib/'.length);
  }

  for (final entry in destToSource.entries) {
    final content = readSource(entry.value);
    for (final uri in _directiveUris(content)) {
      if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
      final targetSource = resolveTarget(entry.value, uri);
      if (!embeddedSet.contains(targetSource)) {
        stderr.writeln(
          'embed_sources: dangling ref "${entry.key}" -> "$uri"',
        );
        exit(1);
      }
    }
  }
  // Manifest-convention assertion: recorded destinations must equal the
  // natural derivation (guards against silent kit renames).
  for (final entry in destToSource.entries) {
    if (sourceOwnerComponent.containsKey(entry.value) ||
        sourceOwnerGroup.containsKey(entry.value)) {
      final expected = naturalDest(entry.value);
      if (entry.key != expected) {
        stderr.writeln(
          'embed_sources: destination drift for "${entry.value}": '
          '"${entry.key}" != "$expected"',
        );
        exit(1);
      }
    }
  }

  // Import manifest: every dart:/package: URI (both quote styles, import and
  // re-export forms alike).
  final importUris = <String>{};
  for (final source in embeddedSet) {
    for (final uri in _packageUris(readSource(source))) {
      importUris.add(uri);
    }
  }
  // Part map: part-file destination → library destination (URI-form only —
  // the kit has no named `part of`).
  final partToLibrary = <String, String>{};
  for (final entry in destToSource.entries) {
    for (final uri in _directiveUris(readSource(entry.value), which: 'part of')) {
      partToLibrary[entry.key] = sourceByDest.keys.firstWhere(
        (d) => sourceByDest[d] == resolveTarget(entry.value, uri),
      );
    }
  }

  final dests = destToSource.keys.toList()..sort();
  final imports = importUris.toList()..sort();
  final partKeys = partToLibrary.keys.toList()..sort();
  final out = StringBuffer()
    ..writeln('// GENERATED by tool/embed_sources.dart — DO NOT EDIT.')
    ..writeln(
      '// ${dests.length} sources · ${imports.length} imports · '
      '${partKeys.length} part links '
      '(${pulledComponents.length} components, ${pulledGroups.length} shared groups).',
    )
    ..writeln('const Map<String, String> kEmbeddedSources = {');
  for (final dest in dests) {
    final content = readSource(destToSource[dest]!);
    // jsonEncode yields a double-quoted literal, but Dart would still
    // interpolate `$` from embedded sources — escape it (JSON escapes never
    // emit `$`, so every `$` here is a literal content char).
    final encoded = jsonEncode(content).replaceAll(r'$', r'\$');
    out.writeln('  ${jsonEncode(dest)}: $encoded,');
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln(
      '// Import closure for kEmbeddedSources: every `dart:` + `package:` URI',
    )
    ..writeln(
      '// the embedded bodies reference. The single-file exporter strips',
    )
    ..writeln(
      '// directives at inline time, so it must re-emit these (package name =',
    )
    ..writeln('// first URI segment → pubspec dep). Sorted, deduped.')
    ..writeln('const List<String> kEmbeddedImports = [');
  for (final uri in imports) {
    out.writeln('  ${jsonEncode(uri)},');
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln('// Part library map for kEmbeddedSources: part-file destination')
    ..writeln('// → its library destination. Parts ship alongside their')
    ..writeln('// libraries (no rewriting): inliners strip `part of` into one')
    ..writeln('// library scope, bundlers ship the set with relative URIs')
    ..writeln('// intact. Preview parts are excluded, never listed here.')
    ..writeln('const Map<String, String> kEmbeddedParts = {');
  for (final part in partKeys) {
    out.writeln('  ${jsonEncode(part)}: ${jsonEncode(partToLibrary[part])},');
  }
  out.writeln('};');
  // Output always lands in this package's lib/, wherever the kit was read from.
  File('${appRoot.path}/lib/canvas/_impl/embedded_sources.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(out.toString());
  stdout.writeln(
    'embedded ${out.length} chars '
    '(${dests.length} sources, ${imports.length} imports, '
    '${partKeys.length} part links; '
    '${pulledComponents.length} components, ${pulledGroups.length} shared groups)',
  );
}

/// `kind: '…'` ids from the catalog (the closure's renderable core).
Set<String> _parseCatalogKinds(String path) {
  final content = File(path).readAsStringSync();
  final kinds = {
    for (final m in RegExp(r"kind:\s*'([^']+)'").allMatches(content))
      m.group(1)!,
  };
  if (kinds.length != _catalogKindCount) {
    stderr.writeln(
      'embed_sources: catalog kinds = ${kinds.length}, expected '
      '$_catalogKindCount — update the tool if the catalog changed on purpose',
    );
    exit(1);
  }
  return kinds;
}

/// `_readyKinds` keys from the registry generator (bare-widget builders).
Set<String> _parseReadyKinds(String path) {
  final content = File(path).readAsStringSync();
  final kinds = {
    for (final m in RegExp(
      r"^  '([a-z0-9_]+)':\s*'build\w+Entry',",
      multiLine: true,
    ).allMatches(content))
      m.group(1)!,
  };
  if (kinds.length != _readyKindCount) {
    stderr.writeln(
      'embed_sources: ready kinds = ${kinds.length}, expected '
      '$_readyKindCount — update the tool if gen_registry changed on purpose',
    );
    exit(1);
  }
  return kinds;
}

/// Transitive `dependsOn` closure over [seed] (unknown ids warn + skip, same
/// verbatim policy as the bundle exporter).
Set<String> _closeDependsOn(
  Set<String> seed,
  Map<String, Map<String, dynamic>> byId,
) {
  final seen = <String>{...seed};
  final stack = seed.toList();
  while (stack.isNotEmpty) {
    final kind = stack.removeLast();
    for (final dep in (byId[kind]!['dependsOn'] as List).cast<String>()) {
      if (seen.add(dep)) {
        if (!byId.containsKey(dep)) {
          stderr.writeln('embed_sources: dependsOn "$dep" unknown; skipped');
          continue;
        }
        stack.add(dep);
      }
    }
  }
  return seen;
}

/// Joins [base] + [uri] and normalizes `.`/`..` lexically (no filesystem
/// access — targets may be checked for existence by the caller).
String _normalizeJoin(String base, String uri) {
  final parts = <String>[];
  for (final seg in [...base.split('/'), ...uri.split('/')]) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(seg);
  }
  return '/${parts.join('/')}';
}

/// One `import`/`export`/`part`/`part of` reference: [uri] plus [kind]
/// (`'import'`, `'export'`, `'part'`, or `'partof'`).
class _Ref {
  final String uri;
  final String kind;

  const _Ref(this.uri, this.kind);
}

/// Target URIs of `import`/`export`/`part` directives in [content], joining
/// multi-line directives through `;` (directives must precede declarations,
/// so a mid-file copy would break validity — same rule the single-file
/// exporter's stripper relies on). With [which] set to `'part of'`, only
/// `part of` targets are returned. Both quote styles.
List<String> _directiveUris(String content, {String? which}) => [
  for (final r in _directiveRefs(content))
    if (which == null || (which == 'part of' && r.kind == 'partof')) r.uri,
];

/// [_directiveUris] with the directive kind attached (the fixpoint treats
/// `part` targets as runtime-by-construction; see [main]'s closure).
List<_Ref> _directiveRefs(String content) {
  final refs = <_Ref>[];
  String pending = '';
  String pendingKind = '';
  void flush() {
    if (pending.isEmpty) return;
    final m = RegExp(
      '^(?:import|export|part)\\s+(?:of\\s+)?[\\x27"]([^\\x27"]+)[\\x27"]',
    ).firstMatch(pending);
    if (m != null) refs.add(_Ref(m.group(1)!, pendingKind));
    pending = '';
    pendingKind = '';
  }

  for (final line in content.split('\n')) {
    final trimmed = line.trimLeft();
    if (pending.isEmpty) {
      if (trimmed.startsWith('import ')) {
        pendingKind = 'import';
      } else if (trimmed.startsWith('export ')) {
        pendingKind = 'export';
      } else if (trimmed.startsWith('part ')) {
        pendingKind = trimmed.startsWith('part of ') ||
                trimmed.startsWith('part of\t') ||
                trimmed == 'part of'
            ? 'partof'
            : 'part';
      } else if (trimmed.startsWith('library ') || trimmed == 'library;') {
        // Library declarations open no collectible edge; they only matter
        // as continuation blockers (never span lines in the kit).
        continue;
      } else {
        continue;
      }
    }
    pending = pending.isEmpty ? trimmed : '$pending $trimmed';
    if (pending.contains(';')) flush();
  }
  return refs;
}

/// `dart:` + `package:` URIs from `import`/`export` directives (both quote
/// styles; single-line form — the kit keeps these on one line).
List<String> _packageUris(String content) => [
  for (final m in RegExp(
    '''(?:import|export)\\s+['"](dart:[^'"]+|package:[^'"]+)['"]''',
  ).allMatches(content))
    m.group(1)!,
];
