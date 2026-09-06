/// Single-file exporter: inlines registry sources into one Dart file.
///
/// Pure Dart (no `package:flutter` imports) so web and CLI share it.
/// Callers pass the source map: web passes `kEmbeddedSources` from
/// `../_impl/embedded_sources.dart`, the CLI reads bodies from disk.
import 'screen_doc.dart';
import 'app_state.dart';

/// Builds a single-file Dart program for [doc], inlining the registry
/// sources of every used component [kind] found in [sourcesByDestination].
///
/// Never throws for unknown kinds: they get a
/// `TODO(canvas): no source for kind` comment plus a placeholder expression.
///
/// ## Closure parameters (Track G1)
///
/// With [sharedSources], [extraImports] and [partOf] all null (the default)
/// the exporter inlines only the used-kind bodies with all directives
/// stripped — the historical behavior, kept byte-identical for existing
/// goldens. Pass the embed-closure maps (all three together) to emit a
/// self-contained file instead:
///
/// * [extraImports]: `dart:`/`package:` URIs re-emitted as imports (pass
///   `kEmbeddedImports`).
/// * [sharedSources]: destination → body for shared files (the
///   `{sharedPath}/…` subset of `kEmbeddedSources`). `{sharedPath}/…` entries
///   already inside [sourcesByDestination] are picked up automatically, so
///   passing `kEmbeddedSources` as [sourcesByDestination] plus
///   `kEmbeddedImports`/`kEmbeddedParts` alone is enough; [sharedSources] is
///   for callers that keep the maps split.
/// * [partOf]: part-file destination → library destination (pass
///   `kEmbeddedParts`). Parts are emitted directly after their library so
///   each barrel + its parts reads as one scope; a collected part whose
///   library is missing is pulled in when either map has it.
///
/// Closure emission additionally dedupes: export-only barrels (empty after
/// stripping) are skipped, byte-identical files are emitted once, and a file
/// whose every top-level declaration is already emitted is skipped (the kit
/// vendors shared helpers per component — e.g. the HSL sliders under both
/// `color_picker` and `hsl`). Relative import/export/part edges are followed
/// to a fixpoint from the used-kind seeds (same edges the embed tool closed
/// over), so `dependsOn`-only components (`alpha`, `async`, …) that no node
/// names directly are still inlined. Inlined `// ignore_for_file` lines are
/// merged into one header line (repeating them trips `duplicate_ignore`).
/// SDK imports keep their observed `as` prefixes (`dart:math as math`, …);
/// relative-import prefixes whose target is claimed are stripped
/// (`shadcn_dialog.X` → `X`); and bare uses of SDK names hidden by kit
/// declarations ([_kShadowSdk]: `Colors`, `ThemeData`, `Table`) are qualified
/// with a private alias. `show`/`hide` combinators cannot survive the merge;
/// co-visible rival `on Widget` extensions are disambiguated instead by
/// electing a keeper per (member, on-type) from Widget-typed uses (resolved
/// type-aware: constructors, typed identifiers, `widget.` paths, field
/// paths, subscripts, and Widget-extension call chains) and suffixing the
/// losers' declarations plus their single-exposure uses. Type twins
/// (classes/mixins/extensions, plus diverged enums/typedefs/functions) home
/// to one declaration with scope-aware rebinding; identical enums/typedefs
/// (docs, trailing commas, or positional parameter names aside) unify to a
/// single declaration, as do strict enum supersets when no `case Name.`
/// switch exists.
///
/// WIRING (no in-repo call site yet — for the coordinator): the future export
/// UI should call:
/// ```dart
/// import 'canvas/_impl/embedded_sources.dart';
/// buildSingleFile(
///   doc,
///   kEmbeddedSources,
///   extraImports: kEmbeddedImports,
///   partOf: kEmbeddedParts,
/// );
/// ```
/// (`kEmbeddedSources`/`kEmbeddedImports`/`kEmbeddedParts` live in
/// `canvas_app/lib/canvas/_impl/embedded_sources.dart`.) The generated
/// project's pubspec additionally needs `expressions` whenever the doc uses
/// the `form`/`formatter` kinds (their bodies import `package:expressions`;
/// every other closure URI is SDK or already in the per-kind pubspec
/// comment).
///
/// TAP ACTIONS: items whose `action.to` matches a screen id are wrapped in
/// the bundle-equivalent `GestureDetector` pushing that screen's route by
/// name (same slug mapping as `codegen_bundle.dart`; the transition rides as
/// a `// transition:` comment since `pushNamed` carries none). Unknown
/// targets keep the `// taps -> ...` comment with the bare expression —
/// never a crash.
///
/// TRACK R1 (app state + action flows): docs using state vars or multi-step
/// actions emit stateful screens instead (see [_screenIsStateful]):
/// * every screen holds one field per var ([stateFieldDecl], initialized
///   from the default), so app state is app-wide like FlutterFlow's;
/// * text props bound as `=var` read their field via interpolation
///   (`'${_count}'` — see [_str]), falling back to the raw literal for
///   unknown vars, exactly like preview;
/// * items with steps get `onTap: () => _onTap<id>(context)` methods built
///   by [emitStepStatements] (state writes via `setState`, feedback, then
///   navigation — the partitionSteps order). Steps needing material-only
///   APIs (`showSnackBar`/`showDialog`) switch the header from
///   `widgets.dart` to `material.dart` (a widgets superset), conditional so
///   legacy docs keep byte-identical headers.
/// Screens in docs with NO vars/bindings/actions emit exactly the historical
/// stateless output.
String buildSingleFile(
  ScreenDoc doc,
  Map<String, String> sourcesByDestination, {
  Map<String, String>? sharedSources,
  List<String>? extraImports,
  Map<String, String>? partOf,
}) {
  final kinds = _usedKinds(doc);
  final deps = _mergedDeps(kinds, doc);
  final closure =
      sharedSources != null || extraImports != null || partOf != null;
  // Track R1: per-emission state tables for binding interpolation ([_str])
  // and action methods. Reset on every call (empty for legacy docs, so the
  // helpers below behave exactly as before).
  _stateFields = _hasAppState(doc) ? stateFieldsFor(doc.states) : const {};
  _stateVars = {for (final v in doc.states) v.name: v};
  final needsMaterialSteps = _docNeedsMaterialSteps(doc);
  // Track S1: `package:http` rides the same dep-table mechanism as the
  // per-kind deps below (appended only when an apiCall step exists, so
  // legacy docs keep byte-identical pubspec comments).
  final needsHttp = _docNeedsHttp(doc);
  // Resolved before the header: closure imports are written up front.
  final _ClosureModel? model = closure
      ? _resolveClosure(
          kinds,
          sourcesByDestination,
          sharedSources ?? const <String, String>{},
          partOf ?? const <String, String>{},
        )
      : null;
  final out = StringBuffer()
    ..writeln('// generated by shadcn canvas — DO NOT EDIT.')
    ..writeln(
      '// pubspec: ${deps.isEmpty ? '(none)' : deps.join(', ')}',
    )
    ..writeln(
      '// screens: ${doc.screens.isEmpty ? '(none)' : doc.screens.map((s) => s.name).join(', ')}',
    )
    ..writeln();
  if (!closure) {
    // Track R1: material (a widgets superset) replaces the widgets import
    // only when an action step needs material-only APIs — legacy docs keep
    // the exact old header.
    out.writeln(
      needsMaterialSteps
          ? "import 'package:flutter/material.dart';"
          : "import 'package:flutter/widgets.dart';",
    );

    // `keyboard_shortcut` keys need `LogicalKeyboardKey`
    // (`package:flutter/services.dart`, not exported by `widgets.dart`):
    // imported only when used, so docs without it keep byte-identical output.
    if (kinds.contains('keyboard_shortcut')) {
      out.writeln("import 'package:flutter/services.dart';");
    }
    // Track S1: `package:http` for apiCall steps (conditional, same rule).
    if (needsHttp) {
      out.writeln("import 'package:http/http.dart' as http;");
    }
  } else {
    final uris = <String>{
      'package:flutter/widgets.dart',
      ...model!.sdkUris,
      if (extraImports != null) ...extraImports,
      // Same `keyboard_shortcut` rule as above; the set dedupes it against
      // `kEmbeddedImports` (which already lists services.dart).
      if (kinds.contains('keyboard_shortcut'))
        'package:flutter/services.dart',
      // Track S1: closure files with apiCall steps need the http import.
      if (needsHttp) 'package:http/http.dart',
    };
    final sorted = uris.toList()..sort();
    // Each distinct import line goes out once (duplicate lines are dropped,
    // never silenced: `duplicate_import` is intentionally absent from
    // [_kClosureIgnores] so a regression surfaces in analysis).
    final seenImports = <String>{};
    void emitImport(String line) {
      if (seenImports.add(line)) out.writeln(line);
    }

    for (final uri in sorted) {
      emitImport("import '$uri';");
      // The kit aliases some SDK imports (`dart:math as math`,
      // `material.dart as m`, …): re-emit the surviving prefix or the
      // qualified uses stay undefined. At most one alias per URI survives —
      // [_resolveClosure] pass (S) canonicalizes multi-prefix URIs (e.g.
      // `m`/`mat`/`material`) to the smallest prefix and rebinds the losers'
      // qualified uses, so the bare + single-aliased imports of one URI are
      // the only repetition left (legal side by side). Shadow aliases
      // (`as _shadowMaterial`) are a distinct mechanism and stay.
      final prefixes = model.sdkPrefixes[uri];
      if (prefixes != null) {
        final sortedPrefixes = prefixes.toList()..sort();
        for (final prefix in sortedPrefixes) {
          emitImport("import '$uri' as $prefix;");
        }
      }
    }
    // Shadow-qualify helpers (see [_kShadowSdk]): files whose SDK names are
    // hidden by kit declarations get a private alias.
    final shadowUris = model.shadowImports.keys.toList()..sort();
    for (final uri in shadowUris) {
      emitImport("import '$uri' as ${model.shadowImports[uri]};");
    }
    out
      ..writeln()
      ..writeln('// ignore_for_file: ${_kClosureIgnores.join(', ')}');
  }

  final taps = _tapTargets(doc);
  for (final screen in doc.screens) {
    if (_screenIsStateful(doc, screen)) {
      _writeStatefulScreen(out, doc, screen, taps);
      continue;
    }
    out
      ..writeln()
      ..writeln('class ${_classNameFor(screen.name)} extends StatelessWidget {')
      ..writeln('  const ${_classNameFor(screen.name)}({super.key});')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  Widget build(BuildContext context) {')
      // Flow root: screen padding outside, vertical Column inside. Gap and
      // padding values come from kFlowScreenGap/kFlowScreenPadding so the
      // generated literals track the model consts.
      ..writeln('    return Padding(')
      ..writeln(
          '      padding: const EdgeInsets.all(${_flowNum(kFlowScreenPadding)}),')
      ..writeln('      child: Column(')
      ..writeln('        crossAxisAlignment: CrossAxisAlignment.start,')
      ..writeln('        children: [');
    final roots = _rootNodes(doc, screen.id);
    if (roots.isEmpty) {
      out.writeln('          // (empty screen)');
    }
    var first = true;
    for (final root in roots) {
      if (!first) {
        out.writeln(
            '          const SizedBox(height: ${_flowNum(kFlowScreenGap)}),');
      }
      first = false;
      // Fresh ancestor path per root (roots are disjoint subtrees; corrupt
      // cycles are unreachable from roots but guarded anyway — see
      // [_writeFlowChild]).
      _writeFlowChild(out, doc, root, '          ', <String>{});
    }
    out
      ..writeln('        ],')
      ..writeln('      ),')
      ..writeln('    );')
      ..writeln('  }')
      ..writeln('}');
  }

  // Stateful helpers for kinds whose kit widget needs lifecycle-owned state
  // (mirroring the catalog's stateful cells): appended only when used, so
  // docs without those kinds keep byte-identical output.
  if (kinds.contains('stepper')) {
    out
      ..writeln()
      ..writeln(_kStepperHelper);
  }

  final emitted = <String>{};
  if (!closure) {
    for (final kind in kinds) {
      final dests = [
        for (final dest in sourcesByDestination.keys)
          if (_idOfDest(dest) == kind && !emitted.contains(dest)) dest,
      ]..sort();
      if (dests.isEmpty) {
        out.writeln();
        out.writeln('// TODO(canvas): no source for kind "$kind"');
        continue;
      }
      for (final dest in dests) {
        emitted.add(dest);
        out
          ..writeln()
          ..writeln('// from: $dest')
          ..writeln(_stripDirectives(sourcesByDestination[dest]!));
      }
    }
  } else {
    _writeClosureBodies(out, model!);
  }
  return out.toString();
}

/// `ignore_for_file` codes merged into one header line for closure output.
///
/// The kit stamps every file with this list; inlining repeats it hundreds of
/// times, which trips `duplicate_ignore`. Kept in sync with the kit stamp by
/// inspection (the embed tool does not ship the list as data).
/// `duplicate_import` is deliberately NOT listed: the header emits each
/// distinct import line once (pass (S) canonicalization plus line dedupe),
/// so a duplicate would be an honest analyzer warning, never silenced.
const _kClosureIgnores = <String>[
  'unnecessary_import',
  'unused_import',
  'unnecessary_null_comparison',
  'dead_code',
  'deprecated_member_use',
  'use_null_aware_elements',
  'sort_child_properties_last',
];

/// Shadowed SDK names: a kit top-level declaration with one of these names
/// hides the same-named SDK import in the merged single-file scope, so files
/// whose scope resolves the bare name to the SDK get their uses qualified
/// with a private alias (see [_shadowAliasFor]). Values are candidate SDK
/// URIs in preference order.
///
/// Soundness: the kit compiles, so a bare use in a file means exactly one of
/// the two — the rewrite fires only when the file's scope exposes the SDK
/// name (`show`/`hide`-aware) and does NOT expose the kit declaration (own
/// group, direct imports, or their export closure). `Offset`/`Clip`/`Image`
/// and friends need no entry: the kit declares nothing by those names (their
/// errors were `as ui`-prefix cascades, fixed by alias re-emission).
const _kShadowSdk = <String, List<String>>{
  'Colors': ['package:flutter/material.dart'],
  'Theme': ['package:flutter/material.dart'],
  'ThemeData': ['package:flutter/material.dart'],
  'Table': [
    'package:flutter/material.dart',
    'package:flutter/widgets.dart',
  ],
  'TableRow': [
    'package:flutter/material.dart',
    'package:flutter/widgets.dart',
  ],
  'TextField': ['package:flutter/material.dart'],
};

/// Private import alias used to shadow-qualify [uri] (see [_kShadowSdk]).
/// Verified absent from the kit (no embedded body contains these).
String _shadowAliasFor(String uri) => switch (uri) {
      'package:flutter/material.dart' => '_shadowMaterial',
      'package:flutter/widgets.dart' => '_shadowWidgets',
      _ => '_shadowImport',
    };

/// Whether [trimmed] (a left-trimmed line) opens an
/// import/export/part/part-of/library directive.
///
/// Mirrors the embed tool's edge scanner: the keyword must be followed by a
/// quoted URI (or `of` for `part of`). A code line like
/// `part == other.part &&` is NOT a directive — the old prefix-only test ate
/// it and everything after it up to the next `;`.
bool _isDirectiveStart(String trimmed) => _kDirectiveStart.hasMatch(trimmed);

final _kDirectiveStart = RegExp(
  // ignore: unnecessary_raw_strings (both quote styles appear inside).
  r'''^(?:import|export)\s+["']|^part\s+(?:of\b|["'])|^library(?:\s|;)''',
);

/// One import/export/part/part-of statement (possibly multi-line in source).
class _DirectiveStmt {
  /// `'import'`, `'export'`, `'part'`, or `'partof'`.
  final String kind;

  /// Every quoted URI in the statement (conditional imports contribute each
  /// branch; all resolve into the same namespace).
  final List<String> uris;

  /// The `as` prefix of imports, else null.
  final String? alias;

  /// `show` combinator names (empty = no show clause).
  final List<String> show;

  /// `hide` combinator names (empty = no hide clause).
  final List<String> hide;

  const _DirectiveStmt(this.kind, this.uris, this.alias, this.show, this.hide);

  /// Whether [name] stays visible through this statement's combinators.
  bool exposes(String name) =>
      (show.isEmpty || show.contains(name)) && !hide.contains(name);
}

/// Identifier lists of one combinator clause: captures after [keyword] up to
/// the other clause or `;` (`show A hide B;` must not leak `B` into show).
List<String> _combinatorNames(String text, String keyword, String other) {
  final out = <String>[];
  final pattern = RegExp(
    '\\b$keyword\\s+((?:(?!\\b$other\\b)[^;])*)',
  );
  for (final m in pattern.allMatches(text)) {
    for (final tok in m.group(1)!.split(RegExp(r'[\s,]+'))) {
      final name = tok.trim();
      if (name.isEmpty) continue;
      if (!RegExp(r'^[\w$]+$').hasMatch(name)) continue;
      out.add(name);
    }
  }
  return out;
}

/// Directive statements of [body], joining multi-line directives through
/// `;` (same appetite as [_stripDirectives], so both agree on what is and
/// is not a directive). Unterminated trailing statements are dropped.
List<_DirectiveStmt> _directiveStmts(String body) {
  final out = <_DirectiveStmt>[];
  String? kind;
  final buf = StringBuffer();
  void flush() {
    final text = buf.toString();
    buf.clear();
    final current = kind;
    kind = null;
    if (text.isEmpty || current == null || current == 'library') return;
    final uris = <String>[];
    for (final m in RegExp(r'''"([^"]*)"|'([^']*)''').allMatches(text)) {
      uris.add(m.group(1) ?? m.group(2)!);
    }
    if (uris.isEmpty) return;
    String? alias;
    if (current == 'import') {
      alias = RegExp(r'\bas\s+(\w+)').firstMatch(text)?.group(1);
    }
    out.add(
      _DirectiveStmt(
        current,
        uris,
        alias,
        _combinatorNames(text, 'show', 'hide'),
        _combinatorNames(text, 'hide', 'show'),
      ),
    );
  }

  for (final line in body.split('\n')) {
    final trimmed = line.trimLeft();
    if (kind == null) {
      if (!_isDirectiveStart(trimmed)) continue;
      kind = trimmed.startsWith('import ')
          ? 'import'
          : trimmed.startsWith('export ')
              ? 'export'
              : trimmed.startsWith('part ')
                  ? (RegExp(r'^part\s+of\b').hasMatch(trimmed)
                      ? 'partof'
                      : 'part')
                  : 'library';
      if (kind == 'library') {
        kind = null;
        continue;
      }
    }
    buf.write(trimmed);
    buf.write(' ');
    if (trimmed.contains(';')) flush();
  }
  return out;
}

/// Resolves a relative directive target [uri] from file [from] against the
/// destination keys of [pool] (lexical only, no filesystem).
///
/// Handles the manifest convention the embed tool derives destinations with
/// (`registry/components/…` → `{installPath}/components/…`,
/// `registry/shared/…` → `{sharedPath}/…`): a component file importing
/// `…/shared/x.dart` normalizes to `{installPath}/shared/x.dart`, which is
/// retried as `{sharedPath}/x.dart` (and symmetrically for
/// `{sharedPath}/components/…`). Returns null when unresolvable (preview
/// surface excluded at embed time, or a hand-built stub gap): callers skip
/// silently and the residual stays an honest analyzer error.
/// Manifest-convention roundtrip helpers for [_resolveRelativeDest].
///
/// The embed tool derives destinations as `registry/components/…` →
/// `{installPath}/components/…` and `registry/shared/…` → `{sharedPath}/…`,
/// so resolving at source level crosses pseudo-roots exactly (a component
/// importing `…/shared/x.dart` lands on `registry/shared/x.dart`, which no
/// dest-level fold can see). Non-conventional (stub) destinations yield null
/// and fall back to dest-level resolution.
String? _destToSourcePath(String dest) {
  if (dest.startsWith('{sharedPath}/')) {
    return 'registry/shared/${dest.substring('{sharedPath}/'.length)}';
  }
  if (dest.startsWith('{installPath}/')) {
    return 'registry/${dest.substring('{installPath}/'.length)}';
  }
  return null;
}

/// See [_destToSourcePath].
String? _sourceToDestPath(String source) {
  if (source.startsWith('registry/shared/')) {
    return '{sharedPath}/${source.substring('registry/shared/'.length)}';
  }
  if (source.startsWith('registry/')) {
    return '{installPath}/${source.substring('registry/'.length)}';
  }
  return null;
}

String? _resolveRelativeDest(
  String from,
  String uri,
  Map<String, String> pool,
) {
  // Exact path first: convention roundtrip.
  final fromSource = _destToSourcePath(from);
  if (fromSource != null) {
    final base = fromSource.split('/')..removeLast();
    final out = <String>[...base];
    var ok = true;
    for (final seg in uri.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (out.isEmpty) {
          ok = false;
          break;
        }
        out.removeLast();
      } else {
        out.add(seg);
      }
    }
    if (ok) {
      final dest = _sourceToDestPath(out.join('/'));
      if (dest != null && pool.containsKey(dest)) return dest;
    }
  }
  // Raw dest-level resolution (stub maps and conventional same-root refs).
  final fromSegs = from.split('/');
  final out = fromSegs.sublist(0, fromSegs.length - 1);
  for (final seg in uri.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (out.length <= 1) return null; // never pop the pseudo-root.
      out.removeLast();
    } else {
      out.add(seg);
    }
  }
  String join(List<String> segs) => segs.join('/');
  if (pool.containsKey(join(out))) return join(out);
  if (out.length >= 2 && out[0] == '{installPath}' && out[1] == 'shared') {
    final cand = join(['{sharedPath}', ...out.sublist(2)]);
    if (pool.containsKey(cand)) return cand;
  }
  if (out.length >= 2 && out[0] == '{sharedPath}' && out[1] == 'components') {
    final cand = join(['{installPath}', ...out.sublist(1)]);
    if (pool.containsKey(cand)) return cand;
  }
  return null;
}

/// Top-level type names declared by the stripped [body] (classes, mixins,
/// enums, extensions, typedefs). Comments and strings are removed first, so
/// only real declarations match; column-0 anchored (members are always
/// indented in formatted code, and nested type declarations do not exist in
/// Dart). The typedef arm requires new-style `=` (the kit has no old-style
/// typedefs; without the anchor a return type would pose as the name).
/// Used for the shadow-qualify scope engine and duplicate detection (never
/// for emission decisions).
Set<String> _topLevelNames(String body) {
  final clean = _stripStrings(_stripComments(body));
  final names = <String>{};
  for (final m in RegExp(
    r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*'
    r'(?:class|mixin|enum)\s+(\w+)|'
    r'^extension\s+(?:type\s+)?(?!on\b)(\w+)|'
    r'^typedef\s+(\w+)\s*(?:<[^;{}()]*>)?\s*=',
    multiLine: true,
  ).allMatches(clean)) {
    names.add(m.group(1) ?? m.group(2) ?? m.group(3)!);
  }
  return names;
}

/// Declared kind of top-level type [name] in the stripped [body]
/// (`'class'`, `'mixin'`, `'extension'`, `'enum'`, or `'typedef'`), or null.
/// Comment/string-cleaned like [_topLevelNames] so only real declarations
/// match. `mixin class` reports as `'class'` (rename-worthy either way).
String? _topLevelKindOf(String body, String name) {
  final clean = _stripStrings(_stripComments(body));
  final e = RegExp.escape(name);
  if (RegExp(
    '^(?:abstract\\s+|final\\s+|sealed\\s+|base\\s+|interface\\s+|mixin\\s+)*'
    'class\\s+$e(?![\\w\$])',
    multiLine: true,
  ).hasMatch(clean)) {
    return 'class';
  }
  if (RegExp(
    '^mixin\\s+$e(?![\\w\$])',
    multiLine: true,
  ).hasMatch(clean)) {
    return 'mixin';
  }
  if (RegExp(
    '^extension\\s+(?:type\\s+)?(?!on\\b)$e(?![\\w\$])',
    multiLine: true,
  ).hasMatch(clean)) {
    return 'extension';
  }
  if (RegExp(
    '^enum\\s+$e(?![\\w\$])',
    multiLine: true,
  ).hasMatch(clean)) {
    return 'enum';
  }
  if (RegExp(
    '^typedef\\s+$e\\s*(?:<[^;{}()]*>)?\\s*=',
    multiLine: true,
  ).hasMatch(clean)) {
    return 'typedef';
  }
  return null;
}

/// Whether a member-declaration return/field type position is plausible:
/// UpperCamel (or `_`+UpperCamel), `void`/`dynamic`/SDK primitives, or a
/// compound (`<…>`, `?`, `*`, brackets, multi-word). Rejects statement
/// keywords (`return`, `new`, `const`, `factory`, …) so member-shaped lines
/// inside bodies (`return muted(x);`, `new muted()`) never pose as
/// declarations.
bool _isPlausibleMemberType(String type) {
  final t = type.trim();
  if (t.isEmpty) return false;
  if (RegExp(r'\b(factory|const)\b').hasMatch(t)) return false;
  if (RegExp(r'^[A-Z_$]').hasMatch(t)) return true;
  if (RegExp(r'^_[A-Z]').hasMatch(t)) return true;
  const primitives = {
    'void',
    'dynamic',
    'int',
    'double',
    'num',
    'bool',
    'String',
    'Object',
  };
  if (primitives.contains(t)) return true;
  return RegExp(r'[ <>,?*\[\]]').hasMatch(t);
}

/// Renames member declarations at their declaration lines only: for each
/// site span, member-decl lines (method/getter/setter/static-field shapes
/// with a plausible type position) get exactly the declaration-name
/// occurrence substituted. Matching runs on cleaned lines
/// (length-preserving: offsets map back exactly); substitution lands in the
/// original lines, so comments, strings, named arguments, locals, enum
/// values, and neighboring tokens are untouched.
String _renameMemberDecls(
  String body,
  List<({int s, int e, Map<String, String> renames})> sites,
) {
  if (sites.isEmpty) return body;
  final clean = _stripStrings(_stripComments(body));
  final bodyLines = body.split('\n');
  final cleanLines = clean.split('\n');
  if (bodyLines.length != cleanLines.length) return body;
  final starts = <int>[0];
  for (var i = 0; i < body.length; i++) {
    if (body[i] == '\n') starts.add(i + 1);
  }
  int lineOf(int offset) {
    var lo = 0;
    var hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  String? declNameOnLine(String cleaned, String member) {
    final e = RegExp.escape(member);
    var m = RegExp(
      r'^\s*((?:static\s+)?[\w$][\w$<>, \?*\[\]]*?)\s+' + e + r'\s*\(',
    ).firstMatch(cleaned);
    if (m != null && _isPlausibleMemberType(m.group(1)!)) return m.group(1);
    m = RegExp(
      r'^\s*((?:[\w$][\w$<>, \?*\[\]]*?))\s+get\s+' + e + r'\s*(?:[;{=]|$)',
    ).firstMatch(cleaned);
    if (m != null && _isPlausibleMemberType(m.group(1)!)) return m.group(1);
    m = RegExp(
      r'^\s*((?:[\w$][\w$<>, \?*\[\]]*?))\s+set\s+' + e + r'\s*\(',
    ).firstMatch(cleaned);
    if (m != null && _isPlausibleMemberType(m.group(1)!)) return m.group(1);
    m = RegExp(
      r'^\s*static\s+(?:(?:const|final|late|var)\s+)?((?:[\w$][\w$<>, \?*\[\]]*?))\s+' +
          e +
          r'\s*(?:=[^=]|;)',
    ).firstMatch(cleaned);
    if (m != null) {
      final type = m.group(1)!;
      if (_isPlausibleMemberType(type) ||
          RegExp(r'^(const|final|late|var)$').hasMatch(type.trim())) {
        return m.group(1);
      }
    }
    return null;
  }

  final edited = <int, String>{};
  for (final site in sites) {
    if (site.renames.isEmpty) continue;
    final first = lineOf(site.s);
    final last = lineOf(site.e - 1);
    for (var ln = first; ln <= last && ln < cleanLines.length; ln++) {
      final cleaned = cleanLines[ln];
      for (final entry in site.renames.entries) {
        final prefix = declNameOnLine(cleaned, entry.key);
        if (prefix == null) continue;
        final at = cleaned.indexOf(entry.key, prefix.length);
        if (at < 0) continue;
        final line = edited[ln] ?? bodyLines[ln];
        // `at` is valid for the original line: cleaning is
        // length-preserving, and the match sits before any dropped tail.
        edited[ln] = line.substring(0, at) +
            entry.value +
            line.substring(at + entry.key.length);
      }
    }
  }
  if (edited.isEmpty) return body;
  final out = List<String>.from(bodyLines);
  edited.forEach((idx, line) => out[idx] = line);
  return out.join('\n');
}

/// Type-aware receiver resolution for rival-extension rewriting (Track I1).
///
/// Resolves the static type of the receiver of a `.m` member use at [dot]
/// (offset of the `.`) as a raw type string, so keeper election and the
/// rewrite gate can tell Widget uses (which collide) from class-declared,
/// enum, SDK, and otherwise non-Widget uses (which never collide and must
/// stay untouched). Shapes handled, recursively with a depth cap:
///
/// * postfix `!`/`?` are stripped (`label!`, `widget.title!`);
/// * bare `Name(`/`const Name(` constructors resolve to [Name] (the
///   SDK-ctor heuristic: names absent from the class index count as Widget —
///   pinned by the rival tests — while indexed non-Widget classes do not);
/// * `as T` cast tails resolve to `T` (same heuristic for absent names);
/// * bare identifiers resolve through lexical scope — method/function params,
///   locals (including `for`-loop and `catch` variables and `final x = Ctor(`
///   inference), field formals via the enclosing class, and class fields —
///   plus `this` (the enclosing class) and `widget` (the `State<W>` type
///   argument). UpperCamel identifiers (statics, enum values like
///   `StepSize.medium`/`Typography.large`) resolve to null, as do `super`,
///   `dynamic`/untyped names, and names whose type is unknown;
/// * dotted paths resolve left-to-right through the class field-type map
///   (`data.title`, `widget.title`, `theme.typography` — the last proving
///   non-Widget so `Typography` getters are never suffixed);
/// * subscripts unwrap `List`/`Set`/`Iterable` element and `Map` value types
///   (`rows[i].label`);
/// * calls resolve through Widget-extension callees: renamed (`__sfx`)
///   members by construction, and plain members declared only by
///   Widget-extensions (never the SDK denylist — `Future.then` — and never
///   when the callee's own receiver is provably non-Widget or its class
///   declares the callee). Anything else (function calls, literals,
///   cascades, spreads, operators) resolves to null.
///
/// Resolution is conservative by construction: unknown means "not Widget",
/// so unresolvable uses stay honest residuals instead of corrupting.
/// Backwards bracket matching consults a per-file code mask (real code vs
/// comments/strings, computed forward once), so doc comments inside call
/// arguments no longer abort constructor classification.
/// Callee names that exist on SDK types and collide with rival members.
const _kSdkChainDeny = <String>{
  'then',
  'toString',
  'hashCode',
  'runtimeType',
  'noSuchMethod',
};

/// Declared-but-untyped names resolve to this internally and are treated as
/// unknown (never Widget) by the gate.
const _kUntypedName = 'dynamic';

/// One class or mixin span for enclosing-class lookups.
class _ClassSpan {
  final String name;
  final int start;
  final int end;
  final String? stateArg;

  const _ClassSpan(this.name, this.start, this.end, this.stateArg);
}

/// One function/method/constructor/getter span with its lexical environment.
class _FuncSpan {
  final int start;
  final int end;
  final String? className;
  final Map<String, String> params;
  final Map<String, String> locals;

  /// Untyped declarations (`final x = <expr>`) resolved in a post-pass once
  /// the whole file environment exists: name plus the absolute exclusive end
  /// offset of the RHS expression.
  final inits = <({String name, int rhsEnd})>[];

  _FuncSpan(
    this.start,
    this.end,
    this.className,
    this.params,
    this.locals,
  );
}

/// Per-file lexical environment for [_receiverType].
class _FileEnv {
  final String body;
  final String clean;
  final List<bool> code;
  final List<_ClassSpan> classes;
  final List<_FuncSpan> funcs;

  const _FileEnv(this.body, this.clean, this.code, this.classes, this.funcs);
}

/// A resolved receiver type: [raw] is the raw type string and [assumed] is
/// true only for the SDK-constructor/cast heuristic (absent from the class
/// index, counted as Widget). Every other shape reports what it knows, so
/// the gate can tell heuristic-Widget from known-Widget from unknown.
class _RType {
  final String raw;
  final bool assumed;

  const _RType(this.raw, this.assumed);
}

/// Base name of a raw type string (`Widget?` → `Widget`,
/// `List<FormField>` → `List`, `a.b.C` → `C`; function types → `''`).
String _baseOfType(String t) {
  var s = t.trim();
  while (s.endsWith('?')) {
    s = s.substring(0, s.length - 1).trim();
  }
  final lt = s.indexOf('<');
  var head = lt < 0 ? s : s.substring(0, lt);
  if (head.contains(' ') || head.contains('(') || head.contains(')')) {
    return '';
  }
  final dot = head.lastIndexOf('.');
  if (dot >= 0) head = head.substring(dot + 1);
  return head.trim();
}

/// Top-level generic arguments of a raw type string (`Map<K, V>` → `[K, V]`),
/// or empty when absent/unbalanced.
List<String> _typeArgsOf(String t) {
  final l = t.indexOf('<');
  if (l < 0) return const [];
  var depth = 0;
  for (var i = l; i < t.length; i++) {
    if (t[i] == '<') depth++;
    if (t[i] == '>') {
      depth--;
      if (depth == 0) {
        return _splitTopLevel(t.substring(l + 1, i), ',');
      }
    }
  }
  return const [];
}

/// Splits [text] on [sep] at depth 0 over `()[]{}<>`.
List<String> _splitTopLevel(String text, String sep) {
  final out = <String>[];
  var dParen = 0;
  var dSquare = 0;
  var dCurly = 0;
  var dAngle = 0;
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '(') dParen++;
    if (c == ')') dParen--;
    if (c == '[') dSquare++;
    if (c == ']') dSquare--;
    if (c == '{') dCurly++;
    if (c == '}') dCurly--;
    if (c == '<') dAngle++;
    if (c == '>') dAngle--;
    if (c == sep &&
        dParen == 0 &&
        dSquare == 0 &&
        dCurly == 0 &&
        dAngle == 0) {
      out.add(text.substring(start, i));
      start = i + 1;
    }
  }
  out.add(text.substring(start));
  return out;
}

/// Whether raw type [t] is Widget-typed: a Widget root or a class that
/// transitively extends one. Absent names (SDK types, type variables,
/// `dynamic`) report false here — the constructor/cast heuristic lives in
/// [_receiverType], which is the only place absence implies Widget.
bool _isWidgetTypeName(String t, Map<String, _ClassInfo> index) {
  final base = _baseOfType(t);
  if (base.isEmpty) return false;
  if (base == 'Widget' ||
      base == 'StatelessWidget' ||
      base == 'StatefulWidget') {
    return true;
  }
  var cur = base;
  final seen = <String>{};
  for (var i = 0; i < 25; i++) {
    if (!seen.add(cur)) return false;
    final info = index[cur];
    if (info == null) return false;
    final sup = info.superName;
    if (sup == null) return false;
    if (sup == 'Widget' ||
        sup == 'StatelessWidget' ||
        sup == 'StatefulWidget') {
      return true;
    }
    cur = sup;
  }
  return false;
}

/// Declared type of field [field] on class [base] (instance fields, statics,
/// and getters), walking superclasses and mixins with a cycle guard, or null
/// when no declaration is visible.
String? _fieldTypeOf(
  String base,
  String field,
  Map<String, _ClassInfo> index,
) {
  final stack = <String>[base];
  final seen = <String>{};
  for (var i = 0; i < 25 && stack.isNotEmpty; i++) {
    final cur = stack.removeLast();
    if (!seen.add(cur)) continue;
    final info = index[cur];
    if (info == null) continue;
    final t = info.fields[field];
    if (t != null) return t;
    if (info.superName != null) stack.add(info.superName!);
    stack.addAll(info.mixins);
  }
  return null;
}

/// Field name → raw declared type for one class body ([inner] is clean text
/// between its braces). Depth-0 lines only, so locals inside method bodies
/// never pose as fields. Multi-declarators (`final Widget? a, b;`) share the
/// last seen type.
Map<String, String> _classFieldTypes(String inner) {
  final fields = <String, String>{};
  var depth = 0;
  final line = StringBuffer();
  void flush() {
    final text = line.toString();
    line.clear();
    if (text.trim().isEmpty) return;
    var lastType = '';
    for (final part in text.split(';')) {
      for (final seg in part.split(',')) {
        final t = seg.trim();
        if (t.isEmpty) continue;
        var m = RegExp(
          r'^(?:static\s+)?(?:late\s+|final\s+|const\s+)?'
          r'([\w$][\w$<>, ?*\[\].]*?)\s+(\w+)\s*(?:=[^=].*)?$',
        ).firstMatch(t);
        if (m != null) {
          lastType = m.group(1)!;
          fields[m.group(2)!] = lastType;
          continue;
        }
        m = RegExp(
          r'^(?:static\s+)?[\w$][\w$<>, ?*\[\].]*?\s+get\s+(\w+)',
        ).firstMatch(t);
        if (m != null) {
          final gm = RegExp(
            r'^(?:static\s+)?([\w$][\w$<>, ?*\[\].]*?)\s+get\s+\w+',
          ).firstMatch(t);
          fields[m.group(1)!] = gm?.group(1) ?? _kUntypedName;
          continue;
        }
        m = RegExp(r'^(\w+)\s*(?:=[^=].*)?$').firstMatch(t);
        if (m != null && lastType.isNotEmpty) {
          fields[m.group(1)!] = lastType;
        }
      }
    }
  }

  var i = 0;
  while (i < inner.length) {
    final c = inner[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth < 0) break;
    }
    if (c == '\n') {
      flush();
    } else if (depth == 0) {
      line.write(c);
    }
    i++;
  }
  flush();
  return fields;
}

/// Whether [name] is a declaration keyword that can never head a function
/// span (`if (`, `for (`, `return (`, …).
bool _isSpanKeyword(String name) => const {
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'catch',
      'return',
      'assert',
      'throw',
      'rethrow',
      'break',
      'continue',
      'yield',
      'await',
      'new',
      'super',
      'this',
      'true',
      'false',
      'null',
      'var',
      'final',
      'late',
      'required',
      'covariant',
      'extends',
      'implements',
      'with',
      'on',
      'show',
      'hide',
      'async',
      'sync',
      'get',
      'set',
    }.contains(name);

/// Parses one parameter segment into (name, type): `this.x` formals resolve
/// through [fieldsOf], bare names are `dynamic`, `Type name` (with defaults
/// stripped) keeps its type. Returns null for unparseable segments.
MapEntry<String, String>? _parseParam(
  String seg,
  String? Function(String field) fieldsOf,
) {
  var s = seg.trim().replaceAll(RegExp(r'^[{}[\]]+|[{}[\]]+$'), '').trim();
  s = s.replaceAll(RegExp(r'^@\w+(?:\([^()]*\))?\s*'), '');
  s = s.replaceAll(RegExp(r'^(?:required\s+|covariant\s+)'), '');
  if (s.isEmpty || s == '_' || s.startsWith('*')) return null;
  final eq = s.indexOf('=');
  if (eq >= 0) s = s.substring(0, eq).trim();
  if (s.startsWith('this.')) {
    final name = s.substring(5).trim().split(RegExp(r'\s')).first;
    if (!RegExp(r'^\w+$').hasMatch(name)) return null;
    return MapEntry(name, fieldsOf(name) ?? _kUntypedName);
  }
  if (s.startsWith('super.')) return null;
  final parts = s.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    if (!RegExp(r'^\w+$').hasMatch(parts[0])) return null;
    return MapEntry(parts[0], _kUntypedName);
  }
  final name = parts.last;
  if (!RegExp(r'^\w+$').hasMatch(name)) return null;
  final type = parts.sublist(0, parts.length - 1).join(' ');
  if (type.contains('(') || type.contains('.')) {
    // Function-typed or prefixed parameters: keep the text (function types
    // test non-Widget downstream); dotted ones are constructors-ish noise.
    if (type.contains('(')) return MapEntry(name, type);
    return MapEntry(name, type);
  }
  return MapEntry(name, type);
}

/// Builds the lexical environment for [body] (a carved or rewritten survivor
/// body): code mask plus class/function spans with params and locals.
_FileEnv _fileEnv(
  String body,
  Map<String, _ClassInfo> classIndex,
) {
  final commentBlanked = _stripComments(body);
  final clean = _stripStrings(commentBlanked);
  final code = List<bool>.filled(body.length, true);
  for (var i = 0; i < body.length; i++) {
    if (commentBlanked[i] != body[i] || clean[i] != commentBlanked[i]) {
      code[i] = false;
    }
  }
  final classes = <_ClassSpan>[];
  for (final m in RegExp(
    r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+)*'
    r'(?:class|mixin)\s+(\w+)',
    multiLine: true,
  ).allMatches(clean)) {
    var i = m.end;
    var open = -1;
    while (i < clean.length) {
      if (clean[i] == '{') {
        open = i;
        break;
      }
      if (clean[i] == ';' || clean[i] == '}') break;
      i++;
    }
    if (open < 0) continue;
    var depth = 0;
    var close = -1;
    for (var k = open; k < clean.length; k++) {
      if (clean[k] == '{') depth++;
      if (clean[k] == '}') {
        depth--;
        if (depth == 0) {
          close = k + 1;
          break;
        }
      }
    }
    if (close < 0) continue;
    final header = clean.substring(m.start, open);
    final stateArg =
        RegExp(r'\bextends\s+State\s*<\s*([\w$][\w$<>?, ]*?)\s*>')
            .firstMatch(header)
            ?.group(1);
    classes.add(_ClassSpan(m.group(1)!, m.start, close, stateArg));
  }
  String? classAt(int offset) {
    for (final c in classes) {
      if (c.start <= offset && offset < c.end) return c.name;
    }
    return null;
  }

  final funcs = <_FuncSpan>[];
  void addSpan(int paren, String? fixedName, String? cls) {
    // Balance backward to the opening paren (clean text: exact).
    var depth = 0;
    var p = -1;
    for (var k = paren; k >= 0; k--) {
      if (clean[k] == ')') depth++;
      if (clean[k] == '(') {
        depth--;
        if (depth == 0) {
          p = k;
          break;
        }
      }
    }
    if (p < 0) return;
    var e = p - 1;
    while (e >= 0 && (clean[e] == ' ' || clean[e] == '\t')) {
      e--;
    }
    String name = fixedName ?? '';
    if (fixedName == null) {
      var s = e;
      while (s >= 0 && _isIdentChar(clean[s])) {
        s--;
      }
      s++;
      if (s > e) return;
      name = clean.substring(s, e + 1);
      if (name.isEmpty || _isSpanKeyword(name)) return;
      // A `.` immediately before the name means a method call, not a
      // declaration (`foo.bar() {` never declares).
      var b = s - 1;
      while (b >= 0 && (clean[b] == ' ' || clean[b] == '\t')) {
        b--;
      }
      if (b >= 0 && clean[b] == '.') return;
    }
    // Body span: `{…}` balance or `=> … ;`.
    var bs = paren + 1;
    while (bs < clean.length && (clean[bs] == ' ' || clean[bs] == '\t')) {
      bs++;
    }
    if (bs >= clean.length) return;
    int spanEnd;
    if (clean[bs] == '{') {
      var d = 0;
      var close = -1;
      for (var k = bs; k < clean.length; k++) {
        if (clean[k] == '{') d++;
        if (clean[k] == '}') {
          d--;
          if (d == 0) {
            close = k + 1;
            break;
          }
        }
      }
      if (close < 0) return;
      spanEnd = close;
    } else if (clean.startsWith('=>', bs)) {
      var dParen = 0;
      var dSquare = 0;
      var dCurly = 0;
      var semi = -1;
      for (var k = bs; k < clean.length; k++) {
        final c = clean[k];
        if (c == '(') dParen++;
        if (c == ')') dParen--;
        if (c == '[') dSquare++;
        if (c == ']') dSquare--;
        if (c == '{') dCurly++;
        if (c == '}') dCurly--;
        if (c == ';' && dParen == 0 && dSquare == 0 && dCurly == 0) {
          semi = k + 1;
          break;
        }
      }
      if (semi < 0) return;
      spanEnd = semi;
    } else {
      return; // declaration without a body (`;`): no locals to track.
    }
    final params = <String, String>{};
    final clsName = cls ?? classAt(p);
    String? fieldsOf(String field) {
      if (clsName == null) return null;
      return _fieldTypeOf(clsName, field, classIndex);
    }

    for (final seg in _splitTopLevel(clean.substring(p + 1, paren), ',')) {
      final parsed = _parseParam(seg, fieldsOf);
      if (parsed != null) params[parsed.key] = parsed.value;
    }
    final locals = <String, String>{};
    final inner = clean.substring(bs, spanEnd);
    for (final m in RegExp(
      r'for\s*\(\s*(?:(?:final|const|late|var)\s+)?'
      r'([\w$.<>?*\[\] ]+?)\s+(\w+)\s+in\b',
    ).allMatches(inner)) {
      locals.putIfAbsent(m.group(2)!, () => m.group(1)!.trim());
    }
    for (final m in RegExp(
      r'catch\s*\(\s*(\w+)(?:\s*,\s*(\w+))?\s*\)',
    ).allMatches(inner)) {
      locals.putIfAbsent(m.group(1)!, () => _kUntypedName);
      if (m.group(2) != null) {
        locals.putIfAbsent(m.group(2)!, () => _kUntypedName);
      }
    }
    for (final m in RegExp(
      r'(?:^|[;{}()])\s*(?:(final|const|late|var)\s+)?'
      r'([\w$.<>?*\[\] ]+?)\s+(\w+)\s*(?=[=;,)])',
      multiLine: true,
    ).allMatches(inner)) {
      var type = m.group(2)!.trim();
      final vname = m.group(3)!;
      if (locals.containsKey(vname)) continue;
      if (RegExp(r'\b(is|as|return|yield|throw|await|else|new|in)\b')
          .hasMatch(type)) {
        continue;
      }
      if (type == 'final' ||
          type == 'const' ||
          type == 'late' ||
          type == 'var') {
        // Inferred (`final x = Ctor(`): the constructor name is the type;
        // otherwise unknown — left out so the initializer post-pass below
        // may still resolve it (`final data = this.data[i]`).
        final tail = inner.substring(m.end);
        final inf = RegExp(r'^\s*=\s*(?:const\s+)?([A-Z][\w$]*)\s*[(\.]')
            .firstMatch(tail);
        type = inf?.group(1) ?? _kUntypedName;
      }
      if (type == _kUntypedName) continue;
      locals[vname] = type;
    }
    final span = _FuncSpan(bs, spanEnd, clsName, params, locals);
    // Untyped initializers (`final x = <expr>`, no explicit type): record
    // the RHS span for the post-pass (anything else — explicit decls,
    // `for`-`in` headers — is already covered above).
    for (final m in RegExp(
      r'(?:^|[;{}()])\s*(?:final|const|late|var)\s+(\w+)\s*=\s*',
      multiLine: true,
    ).allMatches(inner)) {
      final vname = m.group(1)!;
      if (locals.containsKey(vname)) continue;
      var dParen = 0;
      var dSquare = 0;
      var dCurly = 0;
      var dAngle = 0;
      var rhsEnd = -1;
      var k = bs + m.end;
      // Collection literals keep their element type unknown.
      var kk = k;
      while (kk < spanEnd &&
          (clean[kk] == ' ' || clean[kk] == '\t' || clean[kk] == '\n')) {
        kk++;
      }
      if (kk < spanEnd && (clean[kk] == '[' || clean[kk] == '{')) continue;
      for (; k < spanEnd; k++) {
        final ch = clean[k];
        if (ch == '(') dParen++;
        if (ch == '[') dSquare++;
        if (ch == '{') dCurly++;
        if (ch == '<') dAngle++;
        final top =
            dParen == 0 && dSquare == 0 && dCurly == 0 && dAngle == 0;
        if (top && (ch == ',' || ch == ';' || ch == ')' || ch == '}')) {
          rhsEnd = k;
          break;
        }
        // Ternaries, null-aware tails, re-assignments, cascades, and
        // unbalanced generics/comparisons stay unknown (conservative).
        if (top &&
            (ch == '?' ||
                ch == '=' ||
                (ch == '.' &&
                    k + 1 < spanEnd &&
                    clean[k + 1] == '.') ||
                (ch == '>' && dAngle == 0))) {
          break;
        }
        if (ch == ')') dParen--;
        if (ch == ']') dSquare--;
        if (ch == '}') dCurly--;
        // Clamped: a bare `>` is a comparison, not a closing angle.
        if (ch == '>' && dAngle > 0) dAngle--;
      }
      if (rhsEnd < 0) continue;
      span.inits.add((name: vname, rhsEnd: rhsEnd));
    }
    funcs.add(span);
  }

  for (final m in RegExp(r'\)\s*(\{|=>)').allMatches(clean)) {
    addSpan(m.start, null, null);
  }
  for (final m in RegExp(r'\bget\s+(\w+)\s*(=>|\{)').allMatches(clean)) {
    // Getters carry no params; track the body span for locals/fields.
    final arrowOrBrace = m.start + m.group(0)!.indexOf(m.group(2)!);
    int spanEnd;
    if (m.group(2) == '{') {
      var d = 0;
      var close = -1;
      for (var k = arrowOrBrace; k < clean.length; k++) {
        if (clean[k] == '{') d++;
        if (clean[k] == '}') {
          d--;
          if (d == 0) {
            close = k + 1;
            break;
          }
        }
      }
      if (close < 0) continue;
      spanEnd = close;
    } else {
      var dParen = 0;
      var dSquare = 0;
      var dCurly = 0;
      var semi = -1;
      for (var k = arrowOrBrace; k < clean.length; k++) {
        final c = clean[k];
        if (c == '(') dParen++;
        if (c == ')') dParen--;
        if (c == '[') dSquare++;
        if (c == ']') dSquare--;
        if (c == '{') dCurly++;
        if (c == '}') dCurly--;
        if (c == ';' && dParen == 0 && dSquare == 0 && dCurly == 0) {
          semi = k + 1;
          break;
        }
      }
      if (semi < 0) continue;
      spanEnd = semi;
    }
    funcs.add(
      _FuncSpan(arrowOrBrace, spanEnd, classAt(m.start), const {}, const {}),
    );
  }
  final env = _FileEnv(body, clean, code, classes, funcs);
  // Initializer post-pass: untyped `final x = <expr>` declarations resolve
  // their RHS now that every span exists (the RHS may reference anything in
  // scope, including later declarations). Chains resolve without extension
  // knowledge here (empty sets — initializers with Widget-extension chains
  // stay unknown, conservative); fields, subscripts, constructors, and
  // plain paths resolve fully (`final data = this.data[i]` → `TimelineData`).
  for (final f in funcs) {
    for (final init in f.inits) {
      if (f.locals.containsKey(init.name)) continue;
      final t = _receiverType(
        body,
        init.rhsEnd,
        env,
        classIndex,
        const {},
        const {},
        0,
      );
      if (t == null || t.assumed) continue;
      if (_baseOfType(t.raw).isEmpty) continue;
      f.locals[init.name] = t.raw;
    }
    f.inits.clear();
  }
  return env;
}

/// Enclosing class name at [offset], or null at top level.
String? _enclosingClass(_FileEnv env, int offset) {
  for (final c in env.classes) {
    if (c.start <= offset && offset < c.end) return c.name;
  }
  return null;
}

/// Innermost function span containing [offset], or null.
_FuncSpan? _enclosingFunc(_FileEnv env, int offset) {
  _FuncSpan? best;
  for (final f in env.funcs) {
    if (f.start <= offset && offset < f.end) {
      if (best == null || (f.end - f.start) < (best.end - best.start)) {
        best = f;
      }
    }
  }
  return best;
}

/// Lexical type of bare identifier [word] used at [offset]: innermost params,
/// then locals (inner scopes first), then the enclosing class's fields.
/// `dynamic` (untyped) and absent names yield null (unknown, never Widget).
String? _lookupIdent(
  _FileEnv env,
  Map<String, _ClassInfo> index,
  int offset,
  String word,
) {
  final chain = <_FuncSpan>[];
  var f = _enclosingFunc(env, offset);
  while (f != null && chain.length < 8) {
    chain.add(f);
    _FuncSpan? outer;
    for (final g in env.funcs) {
      if (g.start <= f.start &&
          f.end <= g.end &&
          (g.start != f.start || g.end != f.end)) {
        if (outer == null || (g.end - g.start) < (outer.end - outer.start)) {
          outer = g;
        }
      }
    }
    f = outer;
  }
  for (final scope in chain) {
    final p = scope.params[word];
    if (p != null) return p == _kUntypedName ? null : p;
    final l = scope.locals[word];
    if (l != null) return l == _kUntypedName ? null : l;
  }
  final cls = _enclosingClass(env, offset);
  if (cls != null) return _fieldTypeOf(cls, word, index);
  return null;
}

/// Matches the opening bracket for the closer at [i] ([open]/[close] pair),
/// skipping non-code offsets. Returns -1 when unbalanced.
int _matchBack(String body, List<bool> code, int i, String open, String close) {
  var depth = 0;
  for (var j = i; j >= 0; j--) {
    if (!code[j]) continue;
    if (body[j] == close) depth++;
    if (body[j] == open) {
      depth--;
      if (depth == 0) return j;
    }
  }
  return -1;
}

/// Resolves the receiver expression ending at [end] (exclusive) to a type, or
/// null when unknowable. See the [_receiverType] design note above for the
/// shape table; [widgetExtMembers] are plain member names of Widget
/// extensions (chain rule) and [suffixed] the renamed ones.
_RType? _receiverType(
  String body,
  int end,
  _FileEnv env,
  Map<String, _ClassInfo> index,
  Set<String> widgetExtMembers,
  Set<String> suffixed,
  int depth,
) {
  if (depth > 12) return null;
  var i = end - 1;
  while (i >= 0 &&
      (body[i] == ' ' ||
          body[i] == '\t' ||
          body[i] == '\n' ||
          body[i] == '\r' ||
          body[i] == '!' ||
          body[i] == '?' ||
          !env.code[i])) {
    i--;
  }
  if (i < 0) return null;
  final c = body[i];
  if (c == ')') {
    final j = _matchBack(body, env.code, i, '(', ')');
    if (j < 0) return null;
    final inner = body.substring(j + 1, i);
    final cast =
        RegExp(r'\bas\s+([\w$.<>?,\s]+?)\s*$').firstMatch(inner);
    if (cast != null) {
      final t = cast.group(1)!.trim();
      if (t.isEmpty) return null;
      final base = _baseOfType(t);
      if (base.isEmpty) return null;
      // Casts mirror the constructor heuristic for absent (SDK) names.
      return _RType(t, !index.containsKey(base));
    }
    var e = j - 1;
    while (e >= 0 &&
        (body[e] == ' ' ||
            body[e] == '\t' ||
            body[e] == '\n' ||
            body[e] == '\r' ||
            !env.code[e])) {
      e--;
    }
    var k = e;
    if (e >= 0 && body[e] == '>') {
      k = _matchBack(body, env.code, e, '<', '>');
      if (k < 0) return null;
      k--;
      while (k >= 0 &&
          (body[k] == ' ' ||
              body[k] == '\t' ||
              body[k] == '\n' ||
              body[k] == '\r')) {
        k--;
      }
    }
    String? callee;
    var calleeDot = -1;
    if (k >= 0 && _isIdentChar(body[k])) {
      var s = k;
      while (s >= 0 && _isIdentChar(body[s])) {
        s--;
      }
      s++;
      callee = body.substring(s, k + 1);
      if (s - 1 >= 0 && body[s - 1] == '.') calleeDot = s - 1;
    }
    if (callee == null || callee.isEmpty) {
      // Grouping parens `(E).m`: the type of E.
      return _receiverType(
        body,
        i,
        env,
        index,
        widgetExtMembers,
        suffixed,
        depth + 1,
      );
    }
    if (calleeDot >= 0) {
      if (suffixed.contains(callee)) return const _RType('Widget', false);
      if (!widgetExtMembers.contains(callee)) return null;
      if (_kSdkChainDeny.contains(callee)) return null;
      final pt = _receiverType(
        body,
        calleeDot,
        env,
        index,
        widgetExtMembers,
        suffixed,
        depth + 1,
      );
      if (pt == null) return null;
      final pb = _baseOfType(pt.raw);
      if (pb.isEmpty) return null;
      final pinfo = index[pb];
      if (pinfo != null && _classDeclaresIn(index, pb, callee)) return null;
      return const _RType('Widget', false);
    }
    if (!RegExp(r'^[A-Z]').hasMatch(callee)) return null;
    if (_isWidgetTypeName(callee, index)) return _RType(callee, false);
    // SDK-constructor heuristic (documented): absent names count as Widget.
    if (!index.containsKey(callee)) return _RType(callee, true);
    return null;
  }
  if (c == ']') {
    final j = _matchBack(body, env.code, i, '[', ']');
    if (j < 0) return null;
    final t = _receiverType(
      body,
      j,
      env,
      index,
      widgetExtMembers,
      suffixed,
      depth + 1,
    );
    if (t == null || t.assumed) return null;
    final b = _baseOfType(t.raw);
    final args = _typeArgsOf(t.raw);
    if (args.isEmpty) return null;
    if (b == 'Map') {
      if (args.length < 2) return null;
      final v = args.last.trim();
      return v.isEmpty ? null : _RType(v, false);
    }
    // Only list-likes are unwrapped; any other container keeps its element
    // type unknown (conservative).
    if (b == 'List' ||
        b == 'Set' ||
        b == 'Iterable' ||
        b == 'Queue' ||
        b == 'ListBase') {
      final v = args.first.trim();
      return v.isEmpty ? null : _RType(v, false);
    }
    return null;
  }
  if (_isIdentChar(c)) {
    var s = i;
    while (s >= 0 && _isIdentChar(body[s])) {
      s--;
    }
    s++;
    final word = body.substring(s, i + 1);
    if (s - 1 >= 0 && body[s - 1] == '.') {
      if (s - 2 >= 0 && body[s - 2] == '.') return null; // cascade/spread.
      final pt = _receiverType(
        body,
        s - 1,
        env,
        index,
        widgetExtMembers,
        suffixed,
        depth + 1,
      );
      if (pt == null || pt.assumed) return null;
      final pb = _baseOfType(pt.raw);
      if (pb.isEmpty || !index.containsKey(pb)) return null;
      final ft = _fieldTypeOf(pb, word, index);
      return ft == null ? null : _RType(ft, false);
    }
    // Statics and enum values (`StepSize.medium`, `Typography.large`) never
    // qualify — the same gating the member rewrite relies on.
    if (RegExp(r'^[A-Z]').hasMatch(word)) return null;
    if (word == 'this') {
      final cls = _enclosingClass(env, end);
      return cls == null ? null : _RType(cls, false);
    }
    if (word == 'super') return null;
    if (word == 'widget') {
      final cls = _enclosingClass(env, end);
      final w = cls == null ? null : index[cls]?.stateArg;
      return w == null ? null : _RType(w, false);
    }
    final t = _lookupIdent(env, index, end, word);
    return t == null ? null : _RType(t, false);
  }
  return null;
}

/// Whether the receiver of the `.` at [dot] is Widget-typed for [member]:
/// the resolved type tests Widget (or the SDK-constructor heuristic), and a
/// resolvable class that declares [member] vetoes (class members win over
/// extensions, so such uses never meant the extension).
bool _receiverIsWidget(
  String body,
  int dot,
  String member,
  _FileEnv env,
  Map<String, _ClassInfo> index,
  bool Function(String, String) classDeclares,
  Set<String> widgetExtMembers,
  Set<String> suffixed,
) {
  // Member uses inside strings/comments are never real uses (docs mention
  // `.small()` freely); the rewrite scanner never reports those, but keeper
  // election scans raw text and must skip them.
  if (dot < 0 || dot >= env.code.length || !env.code[dot]) return false;
  final r = _receiverType(
    body,
    dot,
    env,
    index,
    widgetExtMembers,
    suffixed,
    0,
  );
  if (r == null) return false;
  final base = _baseOfType(r.raw);
  if (base.isEmpty) return false;
  if (!r.assumed && !_isWidgetTypeName(r.raw, index)) return false;
  if (!r.assumed &&
      index.containsKey(base) &&
      classDeclares(base, member)) {
    return false;
  }
  return true;
}

/// Top-level function and getter names declared by the stripped [body].
/// Column-0 anchored (members are always indented in formatted code), with
/// control-flow and declaration keywords excluded so `if (`-style line starts
/// never pose as declarations.
Set<String> _topLevelFunctionNames(String body) {
  final clean = _stripStrings(_stripComments(body));
  final names = <String>{};
  for (final m in RegExp(
    r'^([\w$][\w$<>, ?*\[\].]*?)\s+(\w+)\s*\(',
    multiLine: true,
  ).allMatches(clean)) {
    final typeHead = m.group(1)!.trim().split(RegExp(r'\s+')).first;
    if (_isSpanKeyword(typeHead)) continue;
    final name = m.group(2)!;
    if (_isSpanKeyword(name)) continue;
    names.add(name);
  }
  for (final m in RegExp(
    r'^[\w$][\w$<>, ?*\[\].]*?\s+get\s+(\w+)',
    multiLine: true,
  ).allMatches(clean)) {
    names.add(m.group(1)!);
  }
  return names;
}

/// Whether renaming top-level [name] in the file with cleaned text [clean]
/// would be unsafe: the file declares a same-named local, param, field,
/// method, or function (which shadows the top level), or uses [name] as a
/// qualifier (`p.name`, e.g. an import prefix or named constructor on a
/// same-named class). Declaration spans in [exclude] (the renamed
/// declarations themselves) are blanked first. Conservative: any doubt skips
/// the file (honest residual, never corruption).
bool _fileShadowsName(
  String clean,
  String name,
  List<({int s, int e})> exclude,
) {
  final work = clean.split('');
  for (final x in exclude) {
    for (var k = x.s; k < x.e && k < work.length; k++) {
      if (work[k] != '\n') work[k] = ' ';
    }
  }
  final text = work.join();
  // `this.name` / `super.name` are member references, not shadows.
  final scrubbed = text
      .replaceAll(RegExp('\\bthis\\s*\\.\\s*' + RegExp.escape(name) + '\\b'),
          'this ')
      .replaceAll(RegExp('\\bsuper\\s*\\.\\s*' + RegExp.escape(name) + '\\b'),
          'super ');
  final e = RegExp.escape(name);
  final patterns = [
    // Method/function declaration (a type position is required, so bare
    // line-start calls like `name Phonecase(` never match... i.e. `name(`
    // alone cannot match: the type run needs at least one word char).
    RegExp('^\\s*[\\w\$][\\w\$<>, ?*\\[\\].]*?\\s+$e\\s*\\(',
        multiLine: true),
    RegExp('^\\s*[\\w\$][\\w\$<>, ?*\\[\\].]*?\\s+get\\s+$e\\b',
        multiLine: true),
    RegExp('^\\s*[\\w\$][\\w\$<>, ?*\\[\\].]*?\\s+set\\s+$e\\s*\\(',
        multiLine: true),
    // Untyped declarations (never calls: `=`, `;`, `,` `)` `:` follow, and a
    // call's `(` is excluded by the lookahead).
    RegExp('[(,;{]\\s*(?:final|const|late|var)\\s+$e\\b(?!\\s*\\()'),
    // Typed params/locals/fields.
    RegExp('[(,;{]\\s*[\\w\$][\\w\$<>, ?*\\[\\].]*?\\s+$e\\b\\s*(?=[=;,):])'),
    // Qualifier uses (`p.name`, import prefixes, named constructors).
    RegExp('\\b$e\\s*\\.(?!\\.)'),
  ];
  return patterns.any((p) => p.hasMatch(scrubbed));
}

/// Structured parts of an enum declaration [text] (already normalized):
/// [head] is `name|typeparams|ctor|with|implements`, [values] the ordered
/// `name+args` value strings, and [members] the normalized member section
/// (after the `;`, empty for plain enums). Returns null when unparseable.
({String head, List<String> values, String members})? _enumParts(
  String text,
) {
  final norm = _normalizeBody(text);
  final m = RegExp(
    r'^enum\s+(\w+)\s*(<[^;{}()]*>)?\s*(\([^;{}]*\))?\s*'
    r'(with\s+[^{;]+?)?\s*(implements\s+[^{;]+?)?\s*\{',
  ).firstMatch(norm);
  if (m == null) return null;
  var depth = 0;
  var paren = 0;
  var close = -1;
  for (var k = m.end - 1; k < norm.length; k++) {
    if (norm[k] == '(') paren++;
    if (norm[k] == ')') paren--;
    if (norm[k] == '{' && paren == 0) depth++;
    if (norm[k] == '}' && paren == 0) {
      depth--;
      if (depth == 0) {
        close = k;
        break;
      }
    }
  }
  if (close < 0) return null;
  final inner = norm.substring(m.end, close);
  // Member section after the first top-level `;`.
  var valuesPart = inner;
  var members = '';
  var d = 0;
  var p = 0;
  for (var k = 0; k < inner.length; k++) {
    if (inner[k] == '(') p++;
    if (inner[k] == ')') p--;
    if (inner[k] == '{' && p == 0) d++;
    if (inner[k] == '}' && p == 0) d--;
    if (inner[k] == ';' && d == 0 && p == 0) {
      valuesPart = inner.substring(0, k);
      members = inner.substring(k + 1).trim();
      break;
    }
  }
  final values = <String>[];
  for (final seg in _splitTopLevel(valuesPart, ',')) {
    var v = seg.trim();
    if (v.isEmpty) continue;
    v = v.replaceAll(RegExp(r'^@\w+(?:\([^()]*\))?\s*'), '');
    final vm = RegExp(r'^(\w+)(.*)$', dotAll: true).firstMatch(v);
    if (vm == null) return null;
    values.add('${vm.group(1)}${vm.group(2)!.trim()}');
  }
  if (values.isEmpty) return null;
  return (
    head: 'enum|${m.group(1)}|${m.group(2) ?? ''}|${m.group(3) ?? ''}|'
        '${m.group(4) ?? ''}|${m.group(5) ?? ''}',
    values: values,
    members: members,
  );
}

/// Canonical form of a new-style typedef declaration [text]: type parameters
/// are de Bruijn-normalized (`#0`, …) and positional parameter *names* of
/// function types are blanked (they are irrelevant to subtyping — the
/// `pending` vs `errors` twins). Named/optional parameter names, defaults,
/// and everything else are kept, so genuinely different aliases never
/// compare equal. Returns null when unparseable.
String? _typedefCanonical(String text) {
  final norm = _normalizeBody(text);
  final m = RegExp(
    r'^typedef\s+(\w+)\s*(<[^;{}()]*>)?\s*=\s*(.+?);$',
    dotAll: true,
  ).firstMatch(norm);
  if (m == null) return null;
  var rhs = m.group(3)!;
  // Blank positional names in every `Function(` parameter list, innermost
  // first (re-scanned after each splice, so nesting terminates), stopping
  // when a pass changes nothing.
  for (var round = 0; round < 8; round++) {
    final matches =
        RegExp(r'Function\s*(<[^()]*>)?\s*\(').allMatches(rhs).toList();
    if (matches.isEmpty) break;
    final before = rhs;
    final fm = matches.last;
    final open = fm.end - 1;
    var d = 0;
    var close = -1;
    for (var k = open; k < rhs.length; k++) {
      if (rhs[k] == '(') d++;
      if (rhs[k] == ')') {
        d--;
        if (d == 0) {
          close = k;
          break;
        }
      }
    }
    if (close < 0) return null;
    final params = _splitTopLevel(rhs.substring(open + 1, close), ',');
    var positionalEnd = params.length;
    for (var k = 0; k < params.length; k++) {
      final t = params[k].trim();
      if (t.startsWith('[') || t.startsWith('{')) {
        positionalEnd = k;
        break;
      }
    }
    for (var k = 0; k < positionalEnd; k++) {
      final pm = RegExp(r'^(.*\S)\s+(\w+)$', dotAll: true)
          .firstMatch(params[k].trim());
      if (pm != null) params[k] = pm.group(1)!;
    }
    rhs = '${rhs.substring(0, open + 1)}${params.join(',')}${rhs.substring(close)}';
    if (rhs == before) break;
  }
  var canon = 'typedef|${m.group(1)}|${m.group(2) ?? ''}|$rhs';
  final tps = m.group(2);
  if (tps != null) {
    final names = tps
        .substring(1, tps.length - 1)
        .split(',')
        .map((s) => s.trim().split(RegExp(r'\s+')).first)
        .where((s) => s.isNotEmpty)
        .toList();
    for (var k = 0; k < names.length; k++) {
      canon = canon.replaceAll(RegExp('\\b${RegExp.escape(names[k])}\\b'), '#$k');
    }
  }
  return canon;
}

/// Class/member index for the receiver check: class or mixin name → member
/// names (methods, getters, setters, static and instance fields), superclass
/// name, mixed-in names, field name → raw declared type (for receiver type
/// resolution), and the `State<W>` type argument (so `widget` in a state
/// class resolves to `W`). Built lazily per queried class over survivors'
/// carved bodies and memoized.
class _ClassInfo {
  final Set<String> members = <String>{};
  String? superName;
  final List<String> mixins = <String>[];
  final Map<String, String> fields = <String, String>{};
  String? stateArg;
  _ClassInfo();
}

/// Whether [member] is declared by class [name] (or its superclasses or
/// mixins), with a cycle guard. Top-level companion to the closure-local
/// declaration check used inside [_resolveClosure].
bool _classDeclaresIn(
  Map<String, _ClassInfo> index,
  String name,
  String member, [
  Set<String>? seen,
]) {
  seen ??= <String>{};
  if (!seen.add(name) || seen.length > 25) return false;
  final info = index[name];
  if (info == null) return false;
  if (info.members.contains(member)) return true;
  if (info.superName != null &&
      _classDeclaresIn(index, info.superName!, member, seen)) {
    return true;
  }
  for (final mix in info.mixins) {
    if (_classDeclaresIn(index, mix, member, seen)) return true;
  }
  return false;
}

/// Whether [name] is safe for cross-file rebind: an UpperCamel letter after
/// any leading underscores (types and their companions — lint-clean kit code
/// never shadows those with locals). LowerCamel renames stay file-local.
bool _isRebindableName(String name) =>
    RegExp(r'^_*[A-Z]').hasMatch(name);

/// One `extension E on T` declaration site for the rival-member analysis
/// (classic extensions only — `extension type` constructors cannot be
/// renamed textually and are skipped at index time). [start]/[end] are
/// offsets in the searched body (cleaning is length-preserving, so the
/// spans stay valid); [onType] is whitespace-normalized.
class _ExtensionSite {
  final String name;
  final String onType;
  final Set<String> members;
  final int start;
  final int end;

  const _ExtensionSite(
    this.name,
    this.onType,
    this.members,
    this.start,
    this.end,
  );
}

/// `extension E on T` declaration sites in [body]: name, whitespace-
/// normalized `on` type, member names, and span (cleaning is
/// length-preserving, so spans stay valid for [body]). Runs on
/// comment/string-cleaned text so words inside them never pose as
/// declarations.
List<_ExtensionSite> _extensionDecls(String body) {
  final clean = _stripStrings(_stripComments(body));
  final out = <_ExtensionSite>[];
  for (final m in RegExp(
    r'^extension\s+(\w+)\s+on\b',
    multiLine: true,
  ).allMatches(clean)) {
    // The `on` type runs to the body brace (may wrap lines); then the
    // balanced close. Clean text has no strings/comments left, so plain
    // brace matching is exact.
    final typeStart = m.end;
    var i = typeStart;
    var open = -1;
    while (i < clean.length) {
      final c = clean[i];
      if (c == '{') {
        open = i;
        break;
      }
      if (c == ';' || c == '}') break;
      i++;
    }
    if (open < 0) continue;
    final onType =
        clean.substring(typeStart, open).replaceAll(RegExp(r'\s+'), ' ').trim();
    var depth = 0;
    var close = -1;
    for (var k = open; k < clean.length; k++) {
      if (clean[k] == '{') depth++;
      if (clean[k] == '}') {
        depth--;
        if (depth == 0) {
          close = k + 1;
          break;
        }
      }
    }
    if (close < 0) continue;
    out.add(
      _ExtensionSite(
        m.group(1)!,
        onType,
        _extensionMembers(clean.substring(open + 1, close - 1)),
        m.start,
        close,
      ),
    );
  }
  return out;
}

/// Member names declared directly in an extension body ([inner] is clean
/// text between its braces — no strings/comments left). Plain depth
/// tracking over braces, so only depth-0 member headers match — never
/// method bodies, cascades, or invocations. Every pattern runs over all
/// matches per line (blanked strings may join lines); a line matching
/// nothing is skipped (residual, never corruption).
Set<String> _extensionMembers(String inner, [bool instanceFields = false]) {
  final members = <String>{};
  var depth = 0;
  final line = StringBuffer();
  void flush() {
    final text = line.toString();
    line.clear();
    if (text.trim().isEmpty) return;
    for (final m in RegExp(
      r'[\w$][\w$<>, \?*\[\]]*?\s+get\s+(\w+)\s*(?:[;{=]|$)',
    ).allMatches(text)) {
      members.add(m.group(1)!);
    }
    for (final m in RegExp(
      r'[\w$][\w$<>, \?*\[\]]*?\s+set\s+(\w+)\s*\(',
    ).allMatches(text)) {
      members.add(m.group(1)!);
    }
    for (final m in RegExp(
      r'(?:static\s+)?[\w$][\w$<>, \?*\[\]]*?\s+(\w+)\s*\(',
    ).allMatches(text)) {
      members.add(m.group(1)!);
    }
    for (final m in RegExp(
      r'static\s+[\w$][\w$<>, \?*\[\]]*?\s+(\w+)\s*(?:=[^=]|;)',
    ).allMatches(text)) {
      members.add(m.group(1)!);
    }
    if (instanceFields) {
      for (final m in RegExp(
        r'^(?:late\s+|final\s+|const\s+|var\s+)?[\w$][\w$<>, \?*\[\]]*?\s+(\w+)\s*(?:=[^=]|;|$)',
      ).allMatches(text.trim())) {
        members.add(m.group(1)!);
      }
    }
  }

  var i = 0;
  while (i < inner.length) {
    final c = inner[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth < 0) break;
    }
    if (c == '\n') {
      flush();
    } else if (depth == 0) {
      line.write(c);
    }
    i++;
  }
  flush();
  return members;
}

/// One extension declaration group for the rival-member analysis: member
/// names plus the whitespace-normalized `on` types they were found under.
class _ExtInfo {
  final Set<String> members = <String>{};
  final Set<String> onTypes = <String>{};
  _ExtInfo();
}

/// Short import-style suffixes for rival-extension member renames, by
/// extension name. Unknown extensions fall back to `__xN` (deterministic
/// order). Verified absent as member suffixes in the kit by inspection of
/// the text-style/icon families; the bump-while-taken rule backstops the
/// rest.
const _kExtensionSuffix = <String, String>{
  'MenuTextStyleExtensions': '__menu',
  'MenuPopupTextStyleExtensions': '__menupopup',
  '_TabListTextStyles': '__tablist',
  'IconExtension': '__icon',
  'IconExtensions': '__icons',
  'MenuIconStyleExtensions': '__menuicon',
  'TextExtension': '__text',
};

/// Rewrites scoped names in a stripped [body] with string/comment awareness
/// (interpolation stays opaque):
///
/// * every `prefix.` in [stripPrefixes] is dropped (the prefix's relative
///   target is inlined in scope, so the qualification is dead weight);
/// * every bare [rename] key becomes its replacement (duplicate-declaration
///   disambiguation — the declaring file always, companions when rebindable);
///   skipped when part of `a.b`, `$a`, `:a`, `#a`, or `a:` (member access,
///   interpolation, symbols/labels/named arguments are never bare uses);
/// * every `.m` in [memberRename] becomes `.replacement` (rival extension
///   members, scope-gated by the caller AND receiver-gated by
///   [shouldRewriteMember] when provided — only Widget-typed receivers
///   qualify, so class fields, enum values, SDK methods, and initializing
///   formals like `this.then` are never suffixed);
/// * every bare [qualify] key becomes `alias.name` (its SDK import is hidden
///   by a kit declaration in the merged scope).
///
/// [chainNames] are the already-suffixed member names that mark Widget-typed
/// call chains for the receiver gate. [shouldRewriteMember] gates each `.m`
/// occurrence (called with the scanned [body], the `.` offset, and the member
/// name); a false return leaves that occurrence untouched.
String _rewriteNames(
  String body,
  Set<String> stripPrefixes,
  Map<String, String> rename,
  Map<String, String> memberRename,
  Map<String, String> qualify, {
  Set<String> chainNames = const <String>{},
  bool Function(String body, int dot, String member)? shouldRewriteMember,
}) {
  if (stripPrefixes.isEmpty &&
      rename.isEmpty &&
      memberRename.isEmpty &&
      qualify.isEmpty) {
    return body;
  }
  final out = StringBuffer();
  var i = 0;
  while (i < body.length) {
    final c = body[i];
    if (c == '/' && i + 1 < body.length && body[i + 1] == '/') {
      final end = body.indexOf('\n', i + 2);
      if (end < 0) {
        out.write(body.substring(i));
        break;
      }
      out.write(body.substring(i, end + 1));
      i = end + 1;
      continue;
    }
    if (c == '/' && i + 1 < body.length && body[i + 1] == '*') {
      final end = body.indexOf('*/', i + 2);
      if (end < 0) {
        out.write(body.substring(i));
        break;
      }
      out.write(body.substring(i, end + 2));
      i = end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final end = _stringEnd(body, i);
      if (end < 0) {
        out.write(body.substring(i));
        break;
      }
      out.write(body.substring(i, end));
      i = end;
      continue;
    }
    // Identifier token: bare uses (no leading dot) take the strip/rename/
    // qualify paths; `.m` / `?.m` / cascade `..m` member uses take the
    // member-rename path. `$` interpolation never enters; `...` spread of a
    // bare identifier is left alone (indistinguishable locally from a
    // cascade, and rewriting it would corrupt the spread expression).
    final prevIsDot = i > 0 && body[i - 1] == '.';
    final isSpread = prevIsDot &&
        i > 2 &&
        body[i - 2] == '.' &&
        body[i - 3] == '.';
    if (_isIdentChar(c) &&
        c != r'$' &&
        (i == 0 ||
            (!_isIdentChar(body[i - 1]) &&
                body[i - 1] != r'$' &&
                !isSpread))) {
      var j = i + 1;
      while (j < body.length && _isIdentChar(body[j])) {
        j++;
      }
      final name = body.substring(i, j);
      if (!prevIsDot) {
        if (stripPrefixes.contains(name) &&
            j < body.length &&
            body[j] == '.' &&
            (j + 1 >= body.length || body[j + 1] != '.')) {
          // Stripped-prefix dup rebinding (`t.FormKey` → `FormKey__dup2`):
          // the trailing name binds to the stripped target's home, which the
          // per-file [rename] map already resolves (no prefixed dup uses
          // exist in the kit, so bare and stripped homes agree where it
          // matters; anything else stays an honest residual).
          var k = j + 1;
          if (k < body.length && _isIdentChar(body[k])) {
            var l = k + 1;
            while (l < body.length && _isIdentChar(body[l])) {
              l++;
            }
            final trailing = body.substring(k, l);
            final repl = rename[trailing];
            if (repl != null) {
              out.write(repl);
              i = l;
              continue;
            }
          }
          i = j + 1;
          continue;
        }
        // Bare rename: never inside symbols/labels/named arguments.
        final prev = i == 0 ? '' : body[i - 1];
        final next = j >= body.length ? '' : body[j];
        if (prev != ':' && prev != '#' && next != ':') {
          final replacement = rename[name];
          if (replacement != null) {
            out.write(replacement);
            i = j;
            continue;
          }
          final alias = qualify[name];
          if (alias != null) {
            out.write(alias);
            out.write('.');
            out.write(name);
            i = j;
            continue;
          }
        }
        out.write(name);
        i = j;
        continue;
      }
      // Member access `.m` (single dot, not a cascade): rival-extension
      // member rewrite, gated by the caller AND by the receiver
      // ([shouldRewriteMember]). A trailing dot (`a.m.c`) still rewrites
      // the `m` link (each link gates independently). Without a receiver
      // gate this rewrote every same-named access in loser-exposed files —
      // Typography getters, enum values, `Future.then`, and initializing
      // formals like `this.then` — all of which must stay untouched.
      final memberReplacement = memberRename[name];
      if (memberReplacement != null) {
        var allow = true;
        if (shouldRewriteMember != null) {
          // `i` is the member-name start; the `.` sits at `i - 1`
          // (`?.` included — [_receiverHead] skips the `?`).
          allow = shouldRewriteMember(body, i - 1, name);
        }
        if (allow) {
          out.write(memberReplacement);
          i = j;
          continue;
        }
      }
      out.write(name);
      i = j;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Resolved closure model for [buildSingleFile]'s closure path.
class _ClosureModel {
  /// Emission order (grouped: libraries directly followed by their parts).
  final List<String> grouped;

  /// Claimed destination → rewritten stripped body.
  final Map<String, String> bodies;

  /// Referenced `dart:`/`package:` URIs (union over claimed files).
  final Set<String> sdkUris;

  /// SDK URI → observed `as` prefixes (union over claimed files).
  final Map<String, Set<String>> sdkPrefixes;

  /// Shadow-qualify imports to emit: URI → private alias (only used ones).
  final Map<String, String> shadowImports;

  /// Used kinds with no source anywhere.
  final List<String> missingKinds;

  const _ClosureModel({
    required this.grouped,
    required this.bodies,
    required this.sdkUris,
    required this.sdkPrefixes,
    required this.shadowImports,
    required this.missingKinds,
  });
}

/// Resolves the closure: used-kind seeds, then the shared pool, then the
/// relative import/export/part fixpoint over all of it (the same edges the
/// embed tool closed over — this pulls `dependsOn`-only components like
/// `alpha`/`async`, which no node names directly, as well as component files
/// only shared files reference), then orphan pull-in and part grouping. Per-file scopes (a part sees its library's imports) drive
/// the import union and the (D)/(E) rewrites, applied here so emission is a
/// pure dedupe pass.
_ClosureModel _resolveClosure(
  List<String> kinds,
  Map<String, String> sources,
  Map<String, String> shared,
  Map<String, String> partOf,
) {
  // Sources win over shared on duplicate keys (real maps are disjoint).
  final combined = <String, String>{...shared, ...sources};
  final bodies = <String, String>{};
  final order = <String>[];
  // Stripped + declaration-carved bodies (filled by the carve pass below;
  // name resolution consults these once filled).
  final carvedBodies = <String, String>{};
  void claim(String dest) {
    if (bodies.containsKey(dest)) return;
    final body = combined[dest];
    if (body == null) return;
    bodies[dest] = body;
    order.add(dest);
  }

  // Shared pool: explicit [shared] entries with no component-id shape (so
  // stub maps work, and passing a full source map as [shared] cannot drag
  // the whole kit in) plus `{sharedPath}/…` entries already inside [sources]
  // (so passing `kEmbeddedSources` as [sources] alone still closes over
  // shared). Claimed FIRST (biggest-first) so canonical shared homes win
  // declaration ties over component-vendored copies, and so the pool's own
  // relative edges (e.g. shared localizations → locale_utils) close over in
  // the fixpoint below.
  final pool = <String>[];
  for (final key in shared.keys) {
    if (_idOfDest(key) == null && !bodies.containsKey(key)) pool.add(key);
  }
  for (final key in sources.keys) {
    if (key.startsWith('{sharedPath}/') && !bodies.containsKey(key)) {
      pool.add(key);
    }
  }
  final preStripped = <String, String>{};
  String preStrippedOf(String dest) => preStripped.putIfAbsent(
        dest,
        () => _stripIgnoreForFile(_stripDirectives(combined[dest]!)),
      );
  final preDecls = <String, List<_Decl>?>{};
  int preDeclCount(String dest) =>
      (preDecls.putIfAbsent(dest, () => _topLevelDecls(preStrippedOf(dest)))
                  ?.length ??
              -1);
  pool.sort((a, b) {
    final cmp = preDeclCount(b).compareTo(preDeclCount(a));
    return cmp != 0 ? cmp : a.compareTo(b);
  });
  for (final dest in pool) {
    claim(dest);
  }

  // Seeds: used-kind dests in the historical per-kind sorted order.
  final missingKinds = <String>[];
  for (final kind in kinds) {
    final dests = [
      for (final dest in sources.keys)
        if (_idOfDest(dest) == kind && !bodies.containsKey(dest)) dest,
    ]..sort();
    if (dests.isEmpty) {
      missingKinds.add(kind);
      continue;
    }
    for (final dest in dests) {
      claim(dest);
    }
  }

  // Relative fixpoint (deterministic: sorted scan each round).
  final stmtsCache = <String, List<_DirectiveStmt>>{};
  List<_DirectiveStmt> stmtsOf(String dest, String body) =>
      stmtsCache.putIfAbsent(dest, () => _directiveStmts(body));
  for (var round = 0; round < 25; round++) {
    var changed = false;
    for (final dest in bodies.keys.toList()..sort()) {
      for (final stmt in stmtsOf(dest, bodies[dest]!)) {
        if (stmt.kind != 'import' &&
            stmt.kind != 'export' &&
            stmt.kind != 'part') {
          continue;
        }
        for (final uri in stmt.uris) {
          if (uri.startsWith('dart:') || uri.startsWith('package:')) {
            continue;
          }
          final target = _resolveRelativeDest(dest, uri, combined);
          if (target != null && !bodies.containsKey(target)) {
            claim(target);
            changed = true;
          }
        }
      }
    }
    if (!changed) break;
  }

  // Orphan pull-in: every collected part needs its library in scope (the
  // embed tool guarantees zero dangling links, so this only fires for
  // hand-built stub maps — and stays silent when the library is absent from
  // both maps).
  if (partOf.isNotEmpty) {
    for (var round = 0; round < 3; round++) {
      var pulled = false;
      for (final dest in List.of(order)) {
        final lib = partOf[dest];
        if (lib == null || bodies.containsKey(lib)) continue;
        if (!combined.containsKey(lib)) continue;
        claim(lib);
        pulled = true;
      }
      if (!pulled) break;
    }
  }

  // Adjacency regroup: each collected part moves directly after its
  // collected library, so a barrel + its parts reads as one scope. Parts
  // whose library is absent stay at their own position.
  final grouped = <String>[];
  if (partOf.isNotEmpty) {
    final partsByLib = <String, List<String>>{};
    for (final dest in order) {
      final lib = partOf[dest];
      if (lib != null &&
          lib != dest &&
          bodies.containsKey(lib) &&
          !partsByLib.containsKey(dest)) {
        partsByLib.putIfAbsent(lib, () => []).add(dest);
      }
    }
    bool isGroupedPart(String dest) =>
        partOf[dest] != null &&
        bodies.containsKey(partOf[dest]) &&
        !partsByLib.containsKey(dest);
    for (final dest in order) {
      if (isGroupedPart(dest)) continue; // placed with its library below.
      grouped.add(dest);
      final parts = partsByLib[dest];
      if (parts != null) {
        final sorted = parts.toList()..sort();
        grouped.addAll(sorted);
      }
    }
  } else {
    grouped.addAll(order);
  }

  // Scopes, import union, and rewrites. A part sees its library's imports
  // (parts carry their own imports too on occasion — the union covers both).
  //
  // Shadow-qualify soundness (E): the kit compiles, so a bare use of a
  // shadow-table name in a file means exactly one side. The rewrite fires
  // only when the file's scope exposes the SDK name (`show`/`hide`-aware)
  // and does NOT expose the kit declaration (own part-group, direct imports,
  // or their combinator-aware export closure).
  final sdkUris = <String>{};
  final sdkPrefixes = <String, Set<String>>{};
  final shadowImports = <String, String>{};
  final rewritten = <String, String>{};

  /// Pass (S) provenance: rewritten file → SDK URI → `as` prefixes bound in
  /// that file's import scope (own imports plus, for parts, the library's).
  /// Filled by `collect` inside the survivor loop below.
  final scopeSdk = <String, Map<String, Set<String>>>{};

  // Part-group key: parts (and their library) share one scope of sibling
  // declarations. Unclaimed libraries still count via [combined].
  String groupKeyOf(String dest) {
    final lib = partOf[dest];
    if (lib != null && lib != dest && combined.containsKey(lib)) return lib;
    return dest;
  }

  final namesCache = <String, Set<String>>{};
  Set<String> namesOf(String dest) => namesCache.putIfAbsent(dest, () {
        // Post-carve bodies where available (carved-away declarations must
        // not count as visible); originals otherwise.
        final body =
            carvedBodies[dest] ?? bodies[dest] ?? combined[dest];
        if (body == null) return const <String>{};
        return _topLevelNames(
          _stripIgnoreForFile(_stripDirectives(body)),
        );
      });
  final groupNamesCache = <String, Set<String>>{};
  Set<String> groupNames(String key) =>
      groupNamesCache.putIfAbsent(key, () {
        final names = <String>{};
        for (final member in combined.keys) {
          if (groupKeyOf(member) != key) continue;
          names.addAll(namesOf(member));
        }
        return names;
      });

  // Combinator-aware export-closure names visible THROUGH [dest] (its own
  // group declarations plus re-exports). Cycle-safe (a re-entrant edge
  // contributes nothing — an under-approximation the rewrite rule treats as
  // "not kit-visible", i.e. it may leave a residual, never corrupt).
  final exportNamesCache = <String, Set<String>>{};
  Set<String> exportScopeNames(String dest, [Set<String>? visiting]) {
    final hit = exportNamesCache[dest];
    if (hit != null) return hit;
    visiting ??= <String>{};
    if (!visiting.add(dest)) return const <String>{};
    final names = <String>{...groupNames(groupKeyOf(dest))};
    final body = bodies[dest] ?? combined[dest];
    if (body != null) {
      for (final stmt in stmtsOf(dest, body)) {
        if (stmt.kind != 'export') continue;
        for (final uri in stmt.uris) {
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final target = _resolveRelativeDest(dest, uri, combined);
          if (target == null) continue;
          var contrib = exportScopeNames(target, visiting);
          if (stmt.show.isNotEmpty) {
            contrib = contrib.where(stmt.show.contains).toSet();
          }
          if (stmt.hide.isNotEmpty) {
            contrib = contrib.where((n) => !stmt.hide.contains(n)).toSet();
          }
          names.addAll(contrib);
        }
      }
    }
    visiting.remove(dest);
    return exportNamesCache[dest] = names;
  }

  // Direct relative imports (own + library's) with provenance for per-file
  // resolution.
  List<({List<_DirectiveStmt> stmts, String base})> scopeStmtGroups(
    String dest,
    List<_DirectiveStmt> ownStmts,
    List<_DirectiveStmt> libStmts,
    String? lib,
  ) {
    final groups = [ (stmts: ownStmts, base: dest) ];
    if (lib != null) groups.add((stmts: libStmts, base: lib));
    return groups;
  }

  bool sdkExposes(
    List<({List<_DirectiveStmt> stmts, String base})> groups,
    String uri,
    String name,
  ) {
    for (final group in groups) {
      for (final stmt in group.stmts) {
        if (stmt.kind != 'import' || stmt.alias != null) continue;
        if (!stmt.uris.contains(uri)) continue;
        if (stmt.exposes(name)) return true;
      }
    }
    return false;
  }

  bool kitExposes(
    String dest,
    List<({List<_DirectiveStmt> stmts, String base})> groups,
    String name,
  ) {
    if (groupNames(groupKeyOf(dest)).contains(name)) return true;
    for (final group in groups) {
      for (final stmt in group.stmts) {
        if (stmt.kind != 'import') continue;
        for (final uri in stmt.uris) {
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final target = _resolveRelativeDest(group.base, uri, combined);
          if (target == null) continue;
          // Importing a part is illegal in valid kit code; skip defensively.
          if (partOf.containsKey(target)) continue;
          var visible = exportScopeNames(target);
          if (stmt.show.isNotEmpty) {
            visible = visible.where(stmt.show.contains).toSet();
          }
          if (stmt.hide.isNotEmpty) {
            visible = visible.where((n) => !stmt.hide.contains(n)).toSet();
          }
          if (visible.contains(name)) return true;
        }
      }
    }
    return false;
  }

  // Pre-rewrite stripped bodies + declaration records for the dedupe pass.
  final preBodies = <String, String>{};
  for (final dest in grouped) {
    preBodies[dest] = _stripIgnoreForFile(_stripDirectives(bodies[dest]!));
  }
  final declRecords = <String, List<_Decl>?>{};
  for (final dest in grouped) {
    declRecords[dest] = _topLevelDecls(preBodies[dest]!);
  }

  // Candidates: whole-hash plus non-empty (export-only barrels and void
  // `;`/trivia never survive).
  final seenFiles = <String>{};
  final candidates = <String>[];
  for (final dest in grouped) {
    final norm = _normalizeBody(preBodies[dest]!);
    if (norm.isEmpty) continue;
    if (!seenFiles.add(norm)) continue;
    candidates.add(dest);
  }

  // Declaration-level carve: a record whose normalized text already emitted
  // from an earlier file is spliced out (identical declaration ⇒ every
  // reference stays valid, whichever file it came from). `null`
  // (unattributable) files emit whole and contribute nothing; empty files
  // (void) never survive. Spans exclude surrounding trivia, so docs and
  // blank lines of kept neighbors survive byte-identical.
  final emittedTexts = <String>{};
  for (final dest in candidates) {
    final records = declRecords[dest];
    if (records == null) {
      carvedBodies[dest] = preBodies[dest]!;
      continue;
    }
    final cuts = <({int s, int e})>[];
    for (final record in records) {
      if (emittedTexts.contains(record.text)) {
        cuts.add((s: record.start, e: record.end));
      } else {
        emittedTexts.add(record.text);
      }
    }
    var body = preBodies[dest]!;
    if (cuts.isNotEmpty) {
      cuts.sort((a, b) => b.s.compareTo(a.s));
      for (final cut in cuts) {
        body = body.substring(0, cut.s) + body.substring(cut.e);
      }
    }
    carvedBodies[dest] = body;
  }

  // Survivors: carved files with no void remainder are gone (their
  // declarations all live in earlier files).
  bool isVoidBody(String body) =>
      _normalizeBody(body).replaceAll(';', '').trim().isEmpty;
  var survivors =
      [for (final dest in candidates) if (!isVoidBody(carvedBodies[dest]!)) dest];

  // Subset-unify for same-name twins (H1 — FormKey/TextExtension first).
  // Vendored copies are sometimes extended by the component (form's FormKey
  // adds getValue/[], display's TextExtension adds thenButton/etc.): the
  // subset decl is spliced out, leaving the single superset home with NO
  // rename. Two types cannot satisfy interface crossings
  // (FormFieldHandle/ValidationResult vs form impls use different FormKeys;
  // every Widget use would be twin-ambiguous), while one superset serves
  // every use. Neither-subset twins (StatedWidget ._/ .base, Clickable/Hover
  // field differences) keep both with scope-aware rebinding below.
  // Member sets: extensions via [_extensionDecls], classes/mixins via the
  // class inner (same shapes as the later class index). Token sets guard
  // against same-named-different-code (equal members, different bodies).
  Set<String>? classMembersIn(String body, String className) {
    final clean = _stripStrings(_stripComments(body));
    final e = RegExp.escape(className);
    final m = RegExp(
      '^(?:abstract\\s+|final\\s+|sealed\\s+|base\\s+|interface\\s+)*'
      '(?:class|mixin)\\s+$e(?![\\w\$])',
      multiLine: true,
    ).firstMatch(clean);
    if (m == null) return null;
    var i = m.end;
    var open = -1;
    while (i < clean.length) {
      if (clean[i] == '{') {
        open = i;
        break;
      }
      if (clean[i] == ';' || clean[i] == '}') break;
      i++;
    }
    if (open < 0) return null;
    var depth = 0;
    var close = -1;
    for (var k = open; k < clean.length; k++) {
      if (clean[k] == '{') depth++;
      if (clean[k] == '}') {
        depth--;
        if (depth == 0) {
          close = k;
          break;
        }
      }
    }
    if (close < 0) return null;
    return _extensionMembers(clean.substring(open + 1, close), true);
  }

  {
    // Preliminary homes (pre-unify) to find subset candidates.
    final preHomes = <String, List<String>>{};
    for (final dest in survivors) {
      for (final name in namesOf(dest)) {
        preHomes.putIfAbsent(name, () => []).add(dest);
      }
    }
    final toDrop = <String, List<({int s, int e})>>{};
    void cutOut(String dest, int s, int e) {
      toDrop.putIfAbsent(dest, () => []).add((s: s, e: e));
    }

    // Declaring record texts for top-level [name] in [home] (one entry per
    // record mentioning the name), or null when unattributable.
    List<String>? declTextsFor(String home, String name) {
      final recs = _topLevelDecls(carvedBodies[home]!);
      if (recs == null) return null;
      return [
        for (final rec in recs)
          if (_topLevelNames(rec.text).contains(name)) rec.text,
      ];
    }

    void cutNameOut(String home, String name) {
      final recs = _topLevelDecls(carvedBodies[home]!)!;
      for (final rec in recs) {
        if (_topLevelNames(rec.text).contains(name)) {
          cutOut(home, rec.start, rec.end);
        }
      }
    }

    // `case Name.` switches over [name] in any survivor: adding enum values
    // would break their exhaustiveness, so superset unification stays off.
    final caseSwitchCache = <String, bool>{};
    bool hasCaseSwitch(String name) => caseSwitchCache.putIfAbsent(name, () {
          final pat = RegExp(
            '\\bcase\\s+' + RegExp.escape(name) + r'\s*[\.<]',
          );
          for (final dest in survivors) {
            if (pat.hasMatch(carvedBodies[dest]!)) return true;
          }
          // `is Name` checks do not break, but `.values` iteration with an
          // exhaustive mapping nearby is unknowable — only `case` gates.
          return false;
        });

    // Enum twins: identical signatures (docs/trailing commas aside) unify to
    // the first home. Strict value-supersets unify to the single maximal
    // home when heads and member sections match and no `case Name.` switch
    // exists anywhere (added values cannot break exhaustiveness then);
    // anything else falls through to scope-aware renaming below.
    void unifyEnumTwins(String name, List<String> homes) {
      final partsByHome =
          <String, ({String head, List<String> values, String members})>{};
      for (final home in homes) {
        final texts = declTextsFor(home, name);
        if (texts == null || texts.length != 1) return;
        final parts = _enumParts(texts.single);
        if (parts == null) return;
        partsByHome[home] = parts;
      }
      if (partsByHome.values
              .map((p) => '${p.head}|${p.values.join(',')}|${p.members}')
              .toSet()
              .length ==
          1) {
        for (final home in homes.skip(1)) {
          cutNameOut(home, name);
        }
        return;
      }
      final head = partsByHome[homes.first]!.head;
      final members = partsByHome[homes.first]!.members;
      if (partsByHome.values
          .any((p) => p.head != head || p.members != members)) {
        return;
      }
      String? superset;
      for (final cand in homes) {
        final vc = partsByHome[cand]!.values.toSet();
        var coversAll = true;
        for (final other in homes) {
          if (other == cand) continue;
          final vo = partsByHome[other]!.values.toSet();
          if (vo.difference(vc).isNotEmpty || vc.length <= vo.length) {
            coversAll = false;
            break;
          }
        }
        if (coversAll) {
          if (superset != null) return; // two maximal: rename path.
          superset = cand;
        }
      }
      if (superset == null || hasCaseSwitch(name)) return;
      for (final home in homes) {
        if (home != superset) cutNameOut(home, name);
      }
    }

    // Typedef twins: identical canonical forms (positional parameter names
    // blanked — irrelevant to subtyping) unify to the first home; anything
    // else falls through to scope-aware renaming below.
    void unifyTypedefTwins(String name, List<String> homes) {
      final canons = <String, String>{};
      for (final home in homes) {
        final texts = declTextsFor(home, name);
        if (texts == null || texts.length != 1) return;
        final canon = _typedefCanonical(texts.single);
        if (canon == null) return;
        canons[home] = canon;
      }
      if (canons.values.toSet().length != 1) return;
      for (final home in homes.skip(1)) {
        cutNameOut(home, name);
      }
    }

    for (final entry in preHomes.entries) {
      final name = entry.key;
      final homes = entry.value;
      if (homes.length < 2) continue;
      final homeKinds = [
        for (final home in homes) _topLevelKindOf(carvedBodies[home]!, name),
      ];
      if (homeKinds.every((k) => k == 'enum')) {
        unifyEnumTwins(name, homes);
        continue;
      }
      if (homeKinds.every((k) => k == 'typedef')) {
        unifyTypedefTwins(name, homes);
        continue;
      }
      var kindsOk = true;
      var firstKind;
      for (final kind in homeKinds) {
        firstKind ??= kind;
        if (kind == null ||
            kind == 'enum' ||
            kind == 'typedef' ||
            kind != firstKind) {
          kindsOk = false;
          break;
        }
      }
      if (!kindsOk) continue;
      final kind = firstKind!;
      if (kind != 'class' && kind != 'mixin' && kind != 'extension') continue;
      // Extensions unify only on the identical on-type (different receivers
      // never collided).
      String? commonOnType;
      var onTypesOk = true;
      final membersByHome = <String, Set<String>>{};
      final tokensByHome = <String, Set<String>>{};
      for (final home in homes) {
        final body = carvedBodies[home]!;
        Set<String>? members;
        if (kind == 'extension') {
          final sites = [
            for (final site in _extensionDecls(body))
              if (site.name == name) site,
          ];
          if (sites.isEmpty) {
            onTypesOk = false;
            break;
          }
          final onTypes = {for (final s in sites) s.onType};
          if (onTypes.length != 1) {
            onTypesOk = false;
            break;
          }
          final onType = onTypes.single;
          commonOnType ??= onType;
          if (onType != commonOnType) {
            onTypesOk = false;
            break;
          }
          members = <String>{};
          for (final s in sites) {
            members.addAll(s.members);
          }
        } else {
          members = classMembersIn(body, name);
          if (members == null) {
            onTypesOk = false;
            break;
          }
        }
        membersByHome[home] = members;
        // Token set of the declaring record(s) for [name] in this file.
        final recs = _topLevelDecls(body);
        if (recs == null) {
          onTypesOk = false;
          break;
        }
        final toks = <String>{};
        var foundDecl = false;
        for (final rec in recs) {
          if (!_topLevelNames(rec.text).contains(name)) continue;
          foundDecl = true;
          for (final tok in rec.text.split(RegExp(r'[^A-Za-z0-9_$]+'))) {
            if (tok.isNotEmpty) toks.add(tok);
          }
        }
        if (!foundDecl) {
          onTypesOk = false;
          break;
        }
        tokensByHome[home] = toks;
      }
      if (!onTypesOk) continue;
      // Single strict superset containing every other home?
      String? superset;
      for (final cand in homes) {
        var coversAll = true;
        for (final other in homes) {
          if (other == cand) continue;
          final mc = membersByHome[cand]!;
          final mo = membersByHome[other]!;
          if (mo.difference(mc).isNotEmpty) {
            coversAll = false;
            break;
          }
          if (mc.length <= mo.length) {
            coversAll = false;
            break;
          }
          final tc = tokensByHome[cand]!;
          final to = tokensByHome[other]!;
          if (to.difference(tc).isNotEmpty) {
            coversAll = false;
            break;
          }
        }
        if (coversAll) {
          if (superset != null) {
            superset = null;
            break; // two maximal: ambiguous, keep both.
          }
          superset = cand;
        }
      }
      if (superset == null) continue;
      for (final home in homes) {
        if (home == superset) continue;
        final recs = _topLevelDecls(carvedBodies[home]!)!;
        for (final rec in recs) {
          if (_topLevelNames(rec.text).contains(name)) {
            cutOut(home, rec.start, rec.end);
          }
        }
      }
    }
    if (toDrop.isNotEmpty) {
      for (final e in toDrop.entries) {
        final cuts = e.value..sort((a, b) => b.s.compareTo(a.s));
        var body = carvedBodies[e.key]!;
        for (final cut in cuts) {
          body = body.substring(0, cut.s) + body.substring(cut.e);
        }
        carvedBodies[e.key] = body;
      }
      namesCache.clear();
      groupNamesCache.clear();
      exportNamesCache.clear();
      survivors = [
        for (final dest in candidates)
          if (!isVoidBody(carvedBodies[dest]!)) dest,
      ];
    }
  }

  // Duplicate top-level TYPE names among survivors (F): the kit's separate
  // libraries may declare the same type (shared-vs-kit twins like
  // `StatedWidget`, `FormKey`). Homes come from the structural index only
  // ([_topLevelNames] over comment/string-cleaned bodies — fragments can
  // never pose as declarations), so false homes are impossible; post-carve
  // survivors sharing a name are diverged by construction (identical texts
  // were carved). The first survivor in emission order keeps the name; later
  // homes are renamed (`Name__dup2`, bumped while taken).
  //
  // Rebinding is scope-aware (H1): every bare UpperCamel use resolves through
  // its file's kit scope (own part-group first, then the combinator-aware
  // import closure) to exactly one home, and is renamed iff that home is a
  // dup. The old part-group-only rebind left cross-group uses (e.g. form
  // files importing the shared `FormKey`, `ClickableState extends
  // State<Clickable>` binding to the keeper) split across the two types —
  // `FormKey<String>` vs `FormKey__dup2<String>`, `State<Clickable__dup2>`
  // returning `ClickableState`, `super.base()` missing on the keeper. Private
  // (`_`-prefixed) names never cross libraries via imports, so their resolve
  // stays group-local by construction. Rebind crosses file boundaries only
  // for UpperCamel-letter names (lint-clean code never shadows those with
  // locals).
  //
  // Track I1 extends the same treatment to the remaining duplicate shapes:
  // top-level functions (diverged twins like `getBullet` /
  // `buildEditableTextContextMenu` rename with scope-aware rebinding, guarded
  // per file against shadowing locals/params/members or qualifier uses —
  // doubt skips the file, never corrupts it) and enums/typedefs (identical
  // ones are unified in the subset pass above, so only diverged twins like
  // `InputFeaturePosition` arrive here; their values/aliases are qualified by
  // the type name itself, so renaming the type with scope-aware rebinding
  // fully resolves them — no receiver gating needed, unlike extension
  // members where `StepSize.medium`-style identifier receivers must stay
  // untouched).
  final renameByDest = <String, Map<String, String>>{};
  final dupeHomes = <String, List<String>>{};
  final allNames = <String>{};
  final funcNamesCache = <String, Set<String>>{};
  Set<String> funcNamesOf(String dest) => funcNamesCache.putIfAbsent(
        dest,
        () => _topLevelFunctionNames(carvedBodies[dest]!),
      );
  for (final dest in survivors) {
    final names = namesOf(dest);
    allNames.addAll(names);
    for (final name in names) {
      dupeHomes.putIfAbsent(name, () => []).add(dest);
    }
    final funcNames = funcNamesOf(dest);
    allNames.addAll(funcNames);
    for (final name in funcNames) {
      if (!names.contains(name)) {
        dupeHomes.putIfAbsent(name, () => []).add(dest);
      }
    }
  }
  // Homes of [name] visible THROUGH [target] (its own part-group plus the
  // combinator-aware export closure). Memoized per (target, name); cycle-safe
  // (a re-entrant edge contributes nothing). Mirrors [exportScopeNames] but
  // keeps per-home provenance so duplicate uses resolve to one twin.
  final exportHomesMemo = <String, Set<String>>{};
  Set<String> homesThrough(String target, String name,
      [Set<String>? visiting]) {
    final key = '$target\x00$name';
    final hit = exportHomesMemo[key];
    if (hit != null) return hit;
    visiting ??= <String>{};
    if (!visiting.add(target)) return const <String>{};
    final out = <String>{};
    final tgkey = groupKeyOf(target);
    for (final h in dupeHomes[name] ?? const <String>[]) {
      if (groupKeyOf(h) == tgkey) out.add(h);
    }
    final tbody = bodies[target] ?? combined[target];
    if (tbody != null) {
      for (final stmt in stmtsOf(target, tbody)) {
        if (stmt.kind != 'export') continue;
        if (!stmt.exposes(name)) continue;
        for (final uri in stmt.uris) {
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final t2 = _resolveRelativeDest(target, uri, combined);
          if (t2 == null) continue;
          out.addAll(homesThrough(t2, name, visiting));
        }
      }
    }
    visiting.remove(target);
    return exportHomesMemo[key] = out;
  }

  // Which duplicate home does a bare [name] in [dest] bind to? Own part-group
  // first (shadows imports, per Dart); otherwise the union over bare
  // (unprefixed, combinator-visible) import edges — own file's plus its
  // library's for parts — of homes visible through each target. Exactly one
  // home wins; zero (local/SDK/no use) or many (kit-ambiguous, impossible for
  // valid kit) returns null (leave alone — residual, never corruption).
  // Private names never travel via imports.
  String? resolveDupeHome(String dest, String name) {
    final homes = dupeHomes[name];
    if (homes == null || homes.length < 2) return null;
    final ownKey = groupKeyOf(dest);
    for (final h in homes) {
      if (groupKeyOf(h) == ownKey) return h;
    }
    if (name.startsWith('_')) return null;
    final lib = partOf[dest];
    final libBody =
        (lib == null || lib == dest) ? null : (bodies[lib] ?? combined[lib]);
    final ownStmts = stmtsOf(dest, bodies[dest]!);
    final libStmts = libBody == null
        ? const <_DirectiveStmt>[]
        : stmtsOf('lib:$lib', libBody);
    final found = <String>{};
    void scan(List<_DirectiveStmt> stmts, String base) {
      for (final stmt in stmts) {
        if (stmt.kind != 'import') continue;
        if (stmt.alias != null) continue; // prefixed: no bare exposure.
        if (!stmt.exposes(name)) continue;
        for (final uri in stmt.uris) {
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final target = _resolveRelativeDest(base, uri, combined);
          if (target == null || partOf.containsKey(target)) continue;
          found.addAll(homesThrough(target, name));
        }
      }
    }

    scan(ownStmts, dest);
    if (libBody != null) scan(libStmts, lib!);
    if (found.length != 1) return null;
    return found.single;
  }

  for (final entry in dupeHomes.entries) {
    final name = entry.key;
    final homes = entry.value;
    if (homes.length < 2) continue;
    // Uniform kind across homes (functions included); mixed or unattributable
    // twins stay honest residuals.
    String? firstKind;
    var kindsOk = true;
    for (final home in homes) {
      final kind = _topLevelKindOf(carvedBodies[home]!, name) ??
          (funcNamesOf(home).contains(name) ? 'function' : null);
      firstKind ??= kind;
      if (kind == null || kind != firstKind) {
        kindsOk = false;
        break;
      }
    }
    if (!kindsOk) continue;
    final kind = firstKind!;
    // Candidates per dup home (emission order, bumped while taken) so every
    // use site maps to the same replacement for its home.
    final candidateForHome = <String, String>{};
    var k = 2;
    for (final dup in homes.skip(1)) {
      var candidate = '${name}__dup$k';
      while (allNames.contains(candidate)) {
        k++;
        candidate = '${name}__dup$k';
      }
      allNames.add(candidate);
      candidateForHome[dup] = candidate;
      k++;
    }
    // Whether rebinding bare [name] in [dest] is unsafe: a same-named local,
    // param, member, or qualifier shadows the top level there (doubt skips
    // the file — residual, never corruption). Only the function path checks:
    // lint-clean code never shadows UpperCamel types with locals.
    bool shadowed(String dest) {
      final orig = bodies[dest]!;
      if (RegExp('\\bimport\\b[^;]*\\bas\\s+' + RegExp.escape(name) + r'\b')
          .hasMatch(orig)) {
        return true;
      }
      final carved = carvedBodies[dest]!;
      final clean = _stripStrings(_stripComments(carved));
      // Own declaration lines for [name], found textually (robust to
      // unattributable bodies where [_topLevelDecls] returns null): any
      // `Type name` / `get|set name` / type-keyword header at line start.
      // Over-blanking only hides uses from the shadow test (safe — real uses
      // still rename); under-blanking would falsely skip the file.
      final epat = RegExp.escape(name);
      final excl = <({int s, int e})>[];
      for (final m in RegExp(
        r'^[ \t]*[\w$][\w$<>, ?*\[\].]*?\s+' +
            epat +
            r'\b|^[ \t]*(?:class|mixin|enum|extension|typedef)\s+' +
            epat +
            r'\b',
        multiLine: true,
      ).allMatches(clean)) {
        var s = m.start;
        while (s > 0 && clean[s - 1] != '\n') {
          s--;
        }
        var e = m.end;
        while (e < clean.length && clean[e] != '\n') {
          e++;
        }
        excl.add((s: s, e: e));
      }
      return _fileShadowsName(clean, name, excl);
    }

    void rebindScopeAware() {
      for (final dest in survivors) {
        final resolved = resolveDupeHome(dest, name);
        if (resolved == null) continue;
        final candidate = candidateForHome[resolved];
        if (candidate == null) continue; // keeper: keep the name.
        if (kind == 'function' && shadowed(dest)) continue;
        renameByDest.putIfAbsent(dest, () => {})[name] = candidate;
      }
    }

    if (kind == 'function') {
      rebindScopeAware();
      continue;
    }
    if (!_isRebindableName(name)) {
      for (final dup in homes.skip(1)) {
        renameByDest.putIfAbsent(dup, () => {})[name] =
            candidateForHome[dup]!;
      }
      continue;
    }
    rebindScopeAware();
  }

  // (G) rival extension members: same member name on co-visible `on Widget`
  // extensions (the kit's per-file `hide` semantics is lost in the merge).
  // Parties are (extension, group) pairs; a use rewrites only when its
  // file's kit scope exposes EXACTLY ONE party (multi-exposure uses would
  // already conflict in the kit, so they stay honest residuals; with
  // uniform `on Widget` receivers that set is empty by construction).
  // extByGroup covers survivor groups (void files declare nothing;
  // unclaimed files are unreachable through claimed edges, both proven in
  // the fixpoint) — exposure is complete over emitted code.
  final extByGroup = <String, Map<String, _ExtInfo>>{};
  for (final dest in survivors) {
    final gkey = groupKeyOf(dest);
    for (final site in _extensionDecls(carvedBodies[dest]!)) {
      final info = extByGroup
          .putIfAbsent(gkey, () => <String, _ExtInfo>{})
          .putIfAbsent(site.name, () => _ExtInfo());
      info.members.addAll(site.members);
      info.onTypes.add(site.onType);
    }
  }
  // Rival member -> on-type -> extName -> groupKeys. Only identical
  // on-types truly collide (specificity still separates the rest in the
  // merged scope exactly as in the kit — e.g. the geometry helpers on
  // distinct geometry types are never renamed).
  final rivals = <String, Map<String, Map<String, Set<String>>>>{};
  extByGroup.forEach((gkey, byExt) {
    byExt.forEach((ext, info) {
      for (final m in info.members) {
        for (final t in info.onTypes) {
          rivals
              .putIfAbsent(m, () => <String, Map<String, Set<String>>>{})
              .putIfAbsent(t, () => <String, Set<String>>{})
              .putIfAbsent(ext, () => <String>{})
              .add(gkey);
        }
      }
    });
  });
  rivals.removeWhere(
    (m, byType) => byType.values.fold(
      0,
      (n, byExt) => n + byExt.values.fold(0, (k, s) => k + s.length),
    ) < 2,
  );

  String partyKey(String ext, String gkey) => '$ext\x00$gkey';

  final exportExtCache = <String, Map<String, Set<String>>>{};
  Map<String, Set<String>> exportScopeExts(
    String dest, [
    Set<String>? visiting,
  ]) {
    final hit = exportExtCache[dest];
    if (hit != null) return hit;
    visiting ??= <String>{};
    if (!visiting.add(dest)) return const {};
    final out = <String, Set<String>>{};
    final gkey = groupKeyOf(dest);
    extByGroup[gkey]?.forEach((ext, info) {
      if (info.members.isNotEmpty) {
        out.putIfAbsent(ext, () => <String>{}).add(gkey);
      }
    });
    final body = bodies[dest] ?? combined[dest];
    if (body != null) {
      for (final stmt in stmtsOf(dest, body)) {
        if (stmt.kind != 'export') continue;
        for (final uri in stmt.uris) {
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final target = _resolveRelativeDest(dest, uri, combined);
          if (target == null) continue;
          final sub = exportScopeExts(target, visiting);
          sub.forEach((ext, groups) {
            if (stmt.show.isNotEmpty && !stmt.show.contains(ext)) return;
            if (stmt.hide.contains(ext)) return;
            out.putIfAbsent(ext, () => <String>{}).addAll(groups);
          });
        }
      }
    }
    visiting.remove(dest);
    return exportExtCache[dest] = out;
  }

  List<({List<_DirectiveStmt> stmts, String base})> scopeGroupsOf(
    String dest,
  ) {
    final lib = partOf[dest];
    final libBody =
        (lib == null || lib == dest) ? null : (bodies[lib] ?? combined[lib]);
    final ownStmts = stmtsOf(dest, bodies[dest]!);
    if (libBody == null) return [(stmts: ownStmts, base: dest)];
    return [
      (stmts: ownStmts, base: dest),
      (stmts: stmtsOf('lib:$lib', libBody), base: lib!),
    ];
  }

  // (member → on-type → parties) exposures for [dest]: own group plus the
  // combinator-aware import closure over extension declarations.
  Map<String, Map<String, Set<String>>> exposuresFor(
    String dest,
    List<({List<_DirectiveStmt> stmts, String base})> scopeGroups,
  ) {
    final out = <String, Map<String, Set<String>>>{};
    void add(String member, String onType, String party) {
      out
          .putIfAbsent(member, () => <String, Set<String>>{})
          .putIfAbsent(onType, () => <String>{})
          .add(party);
    }

    final own = groupKeyOf(dest);
    extByGroup[own]?.forEach((ext, info) {
      for (final m in info.members) {
        if (!rivals.containsKey(m)) continue;
        for (final t in info.onTypes) {
          add(m, t, partyKey(ext, own));
        }
      }
    });
    for (final group in scopeGroups) {
      for (final stmt in group.stmts) {
        if (stmt.kind != 'import') continue;
        for (final uri in stmt.uris) {
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final target = _resolveRelativeDest(group.base, uri, combined);
          if (target == null || partOf.containsKey(target)) continue;
          final sub = exportScopeExts(target);
          sub.forEach((ext, groups) {
            if (stmt.show.isNotEmpty && !stmt.show.contains(ext)) return;
            if (stmt.hide.contains(ext)) return;
            for (final g in groups) {
              final info = extByGroup[g]?[ext];
              if (info == null) continue;
              for (final m in info.members) {
                if (!rivals.containsKey(m)) continue;
                for (final t in info.onTypes) {
                  add(m, t, partyKey(ext, g));
                }
              }
            }
          });
        }
      }
    }
    return out;
  }

  // Class index for the receiver check: class/mixin name → members
  // (methods, getters, setters, static and instance fields), superclass,
  // mixin names, field types, and the `State<W>` type argument. One pass over
  // survivors; superclass/mixin walks are cycle-guarded. SDK/unknown classes
  // are absent (constructors of absent names count as Widget by the
  // documented heuristic; declared types of absent names count as unknown).
  final classIndex = <String, _ClassInfo>{};
  for (final dest in survivors) {
    final clean = _stripStrings(_stripComments(carvedBodies[dest]!));
    for (final m in RegExp(
      r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+)*'
      r'(?:class|mixin)\s+(\w+)',
      multiLine: true,
    ).allMatches(clean)) {
      final name = m.group(1)!;
      final info = classIndex.putIfAbsent(name, () => _ClassInfo());
      // Header runs to the opening brace; body to its match (clean text:
      // plain brace matching is exact).
      var i = m.end;
      var open = -1;
      while (i < clean.length) {
        if (clean[i] == '{') {
          open = i;
          break;
        }
        if (clean[i] == ';' || clean[i] == '}') break;
        i++;
      }
      if (open < 0) continue;
      final header = clean.substring(m.start, open);
      final sup = RegExp(r'\bextends\s+([\w$.]+)').firstMatch(header);
      if (sup != null) {
        info.superName ??= sup.group(1)!.split('.').last.split('<').first;
      }
      info.stateArg ??= RegExp(r'\bextends\s+State\s*<\s*([\w$][\w$<>?, ]*?)\s*>')
          .firstMatch(header)
          ?.group(1);
      final wth =
          RegExp(r'\bwith\s+([\w$.,\s<>]+?)(?:\bimplements\b|$)')
              .firstMatch(header);
      if (wth != null) {
        for (final mix in wth.group(1)!.split(',')) {
          final mn = mix.trim().split('<').first.split('.').last.trim();
          if (mn.isNotEmpty &&
              RegExp(r'^[\w$]+$').hasMatch(mn) &&
              !info.mixins.contains(mn)) {
            info.mixins.add(mn);
          }
        }
      }
      var depth = 0;
      var close = -1;
      for (var k = open; k < clean.length; k++) {
        if (clean[k] == '{') depth++;
        if (clean[k] == '}') {
          depth--;
          if (depth == 0) {
            close = k;
            break;
          }
        }
      }
      if (close < 0) continue;
      info.members.addAll(
        _extensionMembers(clean.substring(open + 1, close), true),
      );
      for (final field in _classFieldTypes(clean.substring(open + 1, close))
          .entries) {
        info.fields.putIfAbsent(field.key, () => field.value);
      }
    }
  }

  bool classDeclares(String name, String member, [Set<String>? seen]) =>
      _classDeclaresIn(classIndex, name, member, seen);

  // Keeper per (member, on-type): most qualifying `.m` uses attributed to
  // one party wins (ties break by party key — deterministic); exposures
  // memoized for the rewrite loop. Qualifying = Widget-typed receiver
  // (bare `Name(`/`const Name(` constructor whose class lacks the member,
  // or a renamed-member call chain). On-type grouping is what makes this
  // complete: only identical on-types truly collide (specificity still
  // separates the rest in the merged scope exactly as in the kit).
  // Keeper per (member, on-type): most qualifying `.m` uses attributed to
  // one party wins (ties break by party key — deterministic); exposures
  // memoized for the rewrite loop. Qualifying = Widget-typed receiver under
  // the type-aware [_receiverIsWidget] gate (constructors, typed identifiers,
  // field paths, subscripts, and Widget-extension call chains — never
  // class-declared, enum, SDK, or unknown receivers). On-type grouping is
  // what makes this complete: only identical on-types truly collide
  // (specificity still separates the rest in the merged scope exactly as in
  // the kit).
  final keeperOf = <String, Map<String, String>>{};
  final exposuresCache =
      <String, Map<String, Map<String, Set<String>>>>{};
  // Per-file lexical environments over carved bodies (built lazily), and the
  // plain member names of Widget extensions (the chain rule over unrenamed
  // callees; renamed callees arrive via [suffixedNames] per round below).
  final envCache = <String, _FileEnv>{};
  _FileEnv envOf(String dest) => envCache.putIfAbsent(
        dest,
        () => _fileEnv(carvedBodies[dest]!, classIndex),
      );
  final widgetExtMembers = <String>{};
  for (final dest in survivors) {
    for (final site in _extensionDecls(carvedBodies[dest]!)) {
      if (site.onType == 'Widget') widgetExtMembers.addAll(site.members);
    }
  }

  bool qualifies(
    String body,
    String dest,
    int dot,
    String member,
    Set<String> suffixed,
  ) =>
      _receiverIsWidget(
        body,
        dot,
        member,
        envOf(dest),
        classIndex,
        classDeclares,
        widgetExtMembers,
        suffixed,
      );

  Map<String, Map<String, String>> electKeepers(Set<String> suffixed) {
    final next = <String, Map<String, String>>{};
    if (rivals.isEmpty) return next;
    final usesByParty = <String, Map<String, Map<String, int>>>{};
    for (final dest in survivors) {
      final scopeGroups = scopeGroupsOf(dest);
      final body = carvedBodies[dest]!;
      final exposures = exposuresFor(dest, scopeGroups);
      exposures.removeWhere((m, byType) => !rivals.containsKey(m));
      for (final m in rivals.keys) {
        var dots = 0;
        for (final match
            in RegExp('\\.' + RegExp.escape(m) + r'\b').allMatches(body)) {
          if (qualifies(body, dest, match.start, m, suffixed)) dots++;
        }
        if (dots == 0) continue;
        final byType = exposures[m];
        if (byType == null) continue;
        for (final t in byType.keys) {
          for (final p in byType[t]!) {
            usesByParty
                    .putIfAbsent(m, () => <String, Map<String, int>>{})
                    .putIfAbsent(t, () => <String, int>{})[p] =
                ((usesByParty[m]?[t]?[p]) ?? 0) + dots;
          }
        }
      }
      if (exposures.isNotEmpty) exposuresCache[dest] = exposures;
    }
    usesByParty.forEach((m, byType) {
      byType.forEach((t, byParty) {
        final sorted = byParty.entries.toList()
          ..sort((a, b) {
            final cmp = b.value.compareTo(a.value);
            return cmp != 0 ? cmp : a.key.compareTo(b.key);
          });
        next.putIfAbsent(m, () => <String, String>{})[t] =
            sorted.first.key;
      });
    });
    return next;
  }

  bool keeperMapsEqual(
    Map<String, Map<String, String>> a,
    Map<String, Map<String, String>> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || o.length != e.value.length) return false;
      for (final f in e.value.entries) {
        if (o[f.key] != f.value) return false;
      }
    }
    return true;
  }

  // Suffix per renamed party: short map by extension name, `__xN` fallback
  // in sorted party order; bumped while taken by any top-level or member
  // name so generated identifiers are always fresh. Pure in its inputs
  // (reads [allNames] but never mutates it), so election rounds can rerun it.
  ({Map<String, String> suffixes, Set<String> suffixed}) assignSuffixes(
    Map<String, Map<String, String>> keepers,
  ) {
    final suffixes = <String, String>{};
    final renamed = <String>[];
    for (final mEntry in rivals.entries) {
      for (final tEntry in mEntry.value.entries) {
        final keeper = keepers[mEntry.key]?[tEntry.key];
        if (keeper == null) continue;
        for (final ext in tEntry.value.keys) {
          for (final g in tEntry.value[ext]!) {
            final p = partyKey(ext, g);
            if (p != keeper && !renamed.contains(p)) renamed.add(p);
          }
        }
      }
    }
    renamed.sort();
    final taken = <String>{...allNames};
    for (final dest in survivors) {
      for (final site in _extensionDecls(carvedBodies[dest]!)) {
        taken.addAll(site.members);
      }
    }
    var fallback = 0;
    final baseUse = <String, int>{};
    for (final p in renamed) {
      final ext = p.split('\x00').first;
      var base = _kExtensionSuffix[ext];
      if (base == null) {
        fallback++;
        base = '__x$fallback';
      } else {
        final count = (baseUse[ext] ?? 0) + 1;
        baseUse[ext] = count;
        if (count > 1) base = '$base$count';
      }
      var candidate = base;
      var bump = 2;
      while (taken.contains(candidate)) {
        candidate = '$base$bump';
        bump++;
      }
      taken.add(candidate);
      suffixes[p] = candidate;
    }
    // Suffixed member names (for chain detection): every renamed
    // member+suffix combination assigned above.
    final suffixed = <String>{};
    for (final mEntry in rivals.entries) {
      for (final tEntry in mEntry.value.entries) {
        final keeper = keepers[mEntry.key]?[tEntry.key];
        for (final ext in tEntry.value.keys) {
          for (final g in tEntry.value[ext]!) {
            final p = partyKey(ext, g);
            if (p == keeper) continue;
            final sfx = suffixes[p];
            if (sfx != null) suffixed.add(mEntry.key + sfx);
          }
        }
      }
    }
    return (suffixes: suffixes, suffixed: suffixed);
  }

  // Election rounds: renamed-member chains are Widget-typed by construction,
  // so each round's suffixes unlock the next round's chain votes (the old
  // single pass ran without chains as a documented approximation). Capped at
  // three; deterministic regardless of convergence.
  var suffixOfParty = <String, String>{};
  var suffixedNames = <String>{};
  for (var round = 0; round < 3; round++) {
    final nextKeepers = electKeepers(suffixedNames);
    final assigned = assignSuffixes(nextKeepers);
    final stable = keeperMapsEqual(keeperOf, nextKeepers);
    keeperOf.clear();
    nextKeepers.forEach((k, v) => keeperOf[k] = Map.of(v));
    suffixOfParty = assigned.suffixes;
    suffixedNames = assigned.suffixed;
    if (stable) break;
  }

  // Home declaration renames: per extension-declaration span, rival members
  // of renamed parties are renamed at their declaration lines only
  // ([_renameMemberDecls] substitutes exactly the declaration occurrence —
  // named arguments, locals, enum values, and neighboring tokens in the
  // same file are untouched). Gated on observed ambiguity (H1): a member
  // suffixes only when its (member, on-type) elected a keeper (at least one
  // qualifying Widget-typed use in survivors). Without a keeper there is no
  // manifest collision — suffixing both twins (they share the party suffix
  // from other members) would erase the plain name every residual use needs.
  final homeDeclRenames =
      <String, List<({int s, int e, Map<String, String> renames})>>{};
  for (final dest in survivors) {
    final sites = <({int s, int e, Map<String, String> renames})>[];
    for (final site in _extensionDecls(carvedBodies[dest]!)) {
      final p = partyKey(site.name, groupKeyOf(dest));
      final sfx = suffixOfParty[p];
      if (sfx == null) continue;
      final renames = <String, String>{};
      for (final m in site.members) {
        final byType = rivals[m];
        if (byType == null || !byType.containsKey(site.onType)) continue;
        final keeper = keeperOf[m]?[site.onType];
        if (keeper == null) continue;
        if (keeper == p) continue;
        renames[m] = m + sfx;
      }
      if (renames.isNotEmpty) {
        sites.add((s: site.start, e: site.end, renames: renames));
      }
    }
    if (sites.isNotEmpty) homeDeclRenames[dest] = sites;
  }

  // Receiver gate for the (G3) rewrite below (H1+I1): a `.m` occurrence
  // rewrites only when its receiver is Widget-typed under the same
  // type-aware gate as election — constructors, typed identifiers (`child`,
  // `title`, `label`), `widget.` paths via the `State<W>` argument, field
  // paths (`data.title`), subscripts (`rows[i].label`), and Widget-extension
  // call chains (`.mono().bold()`). Anything else (property paths like
  // `theme.typography.sans`, enum accesses like `StepSize.medium`/
  // `TextDecoration.underline`, SDK calls like `future.then`, field accesses
  // like `this.then`, cascades, spreads, literals, unknowns) stays untouched.
  // This is what stops `__textN` suffixes from hitting non-rivals: the suffix
  // still disambiguates the true Widget extension collision, but
  // `Typography` getters, `then` formals, and friends never qualify as Widget
  // extension uses. Environments here run over rewritten bodies (post
  // home-decl renames), built lazily per file.
  final rewriteEnvs = <String, _FileEnv>{};
  final rewriteWidgetExts = <String>{};
  bool rewriteExtsBuilt = false;
  bool qualifiesForRewrite(String body, String dest, int dot, String member) {
    var env = rewriteEnvs[dest];
    if (env == null) {
      if (!rewriteExtsBuilt) {
        rewriteExtsBuilt = true;
        for (final d in survivors) {
          for (final site in _extensionDecls(carvedBodies[d]!)) {
            if (site.onType == 'Widget') {
              rewriteWidgetExts.addAll(site.members);
            }
          }
        }
        rewriteWidgetExts.addAll(suffixedNames);
      }
      // Built on the caller's (post-rename) text so offsets line up; member
      // names consulted are original (the scanner reports original offsets).
      env = _fileEnv(body, classIndex);
      rewriteEnvs[dest] = env;
    }
    return _receiverIsWidget(
      body,
      dot,
      member,
      env,
      classIndex,
      classDeclares,
      rewriteWidgetExts,
      suffixedNames,
    );
  }

  for (final dest in survivors) {
    final lib = partOf[dest];
    final libBody =
        (lib == null || lib == dest) ? null : (bodies[lib] ?? combined[lib]);
    final ownStmts = stmtsOf(dest, bodies[dest]!);
    final libStmts = libBody == null ? const <_DirectiveStmt>[] : stmtsOf(
          'lib:$lib',
          libBody,
        );
    // (G) member edits for this file: per `.m` occurrence below.
    final groups = scopeStmtGroups(
      dest,
      ownStmts,
      libStmts,
      libBody == null ? null : lib,
    );
    // (uri, alias, base) import edges with provenance for resolution.
    final importEdges = <({String uri, String? alias, String base})>[];
    void collect(List<_DirectiveStmt> stmts, String base) {
      for (final stmt in stmts) {
        if (stmt.kind != 'import') continue;
        for (final uri in stmt.uris) {
          importEdges.add((uri: uri, alias: stmt.alias, base: base));
          if (uri.startsWith('dart:') || uri.startsWith('package:')) {
            sdkUris.add(uri);
            if (stmt.alias != null) {
              sdkPrefixes.putIfAbsent(uri, () => <String>{}).add(
                    stmt.alias!,
                  );
              // Pass (S) provenance: which SDK prefixes this file's scope
              // (own plus, for parts, library imports) actually binds.
              // Keyed by the rewritten file [dest], not [base].
              scopeSdk
                  .putIfAbsent(dest, () => <String, Set<String>>{})
                  .putIfAbsent(uri, () => <String>{})
                  .add(stmt.alias!);
            }
          }
        }
      }
    }

    collect(ownStmts, dest);
    if (libBody != null) collect(libStmts, lib!);

    // (D) relative prefixes whose target is claimed: the qualification is
    // dead weight once the target is inlined in scope.
    final strip = <String>{};
    for (final edge in importEdges) {
      final alias = edge.alias;
      if (alias == null) continue;
      if (edge.uri.startsWith('dart:') || edge.uri.startsWith('package:')) {
        continue;
      }
      final target = _resolveRelativeDest(edge.base, edge.uri, combined);
      if (target != null && bodies.containsKey(target)) strip.add(alias);
    }

    // (E) shadow qualify: bare SDK uses hidden by kit declarations.
    // Carved bodies are already stripped.
    var stripped = carvedBodies[dest]!;
    // (G2) home member declarations: line-targeted, before any span-shifting
    // cut below (spans were computed on the carved text).
    final homeSites = homeDeclRenames[dest];
    if (homeSites != null) {
      stripped = _renameMemberDecls(stripped, homeSites);
    }
    // (D2) self-cycle typedefs: `typedef N = prefix.N;` becomes `typedef N =
    // N;` once the prefix is stripped — a meaningless self-alias (the kit
    // cannot contain `typedef N = N;` and still compile, so any occurrence
    // is ours to drop; the target declaration serves directly). Matched on
    // the pre-strip text (qualifier present and stripped, or absent) and
    // span-carved by a fresh parse so neighbors keep byte-identical text.
    // Dupe-renamed typedefs are exempt: their declaration must survive as a
    // keeper-alias (repaired in (D2b) below) — cutting it while uses rebind
    // to the new name would leave a dangling reference.
    if (strip.isNotEmpty && stripped.contains('typedef')) {
      final dupeRenamed =
          renameByDest[dest]?.keys.toSet() ?? const <String>{};
      final recs = _topLevelDecls(stripped);
      if (recs != null) {
        final cuts = <({int s, int e})>[];
        for (final record in recs) {
          final m = RegExp(
            r'^typedef\s+(\w+)\s*=\s*(?:(\w+)\s*\.\s*)?(\w+)\s*;$',
          ).firstMatch(record.text);
          if (m != null &&
              m.group(1) == m.group(3) &&
              (m.group(2) == null || strip.contains(m.group(2))) &&
              !dupeRenamed.contains(m.group(1))) {
            cuts.add((s: record.start, e: record.end));
          }
        }
        if (cuts.isNotEmpty) {
          cuts.sort((a, b) => b.s.compareTo(a.s));
          for (final cut in cuts) {
            stripped =
                stripped.substring(0, cut.s) + stripped.substring(cut.e);
          }
        }
      }
    }
    final qualify = <String, String>{};
    final qualifyUris = <String, String>{};
    for (final entry in _kShadowSdk.entries) {
      final name = entry.key;
      String? chosen;
      for (final uri in entry.value) {
        if (sdkExposes(groups, uri, name)) {
          chosen = uri;
          break;
        }
      }
      if (chosen == null) continue;
      if (kitExposes(dest, groups, name)) continue;
      qualify[name] = _shadowAliasFor(chosen);
      qualifyUris[name] = chosen;
    }

    // (G3) scope-gated member renames for this file: rewrite `.m` only
    // where this file's import scope exposes the RENAMED (loser) party
    // without the keeper (single-exposure: the use unambiguously meant the
    // loser, whose declaration was suffixed). Keeper-only scopes keep the
    // name; scopes exposing both stay untouched (genuinely ambiguous —
    // rewriting would corrupt keeper intent; documented residual). Members
    // without a keeper (no qualifying Widget-typed use observed anywhere)
    // never rewrite — there is no manifest collision to disambiguate. Each
    // surviving `.m` is additionally receiver-gated ([qualifiesForRewrite]):
    // only Widget-typed receivers rewrite, so `Typography` fields, enum
    // values, `Future.then`, and `this.then` formals never suffix.
    final memberRename = <String, String>{};
    final exposures = exposuresCache[dest];
    if (exposures != null) {
      for (final mEntry in exposures.entries) {
        final m = mEntry.key;
        if (!rivals.containsKey(m)) continue;
        for (final tEntry in mEntry.value.entries) {
          final keeper = keeperOf[m]?[tEntry.key];
          if (keeper == null) continue;
          if (tEntry.value.contains(keeper)) continue;
          for (final p in tEntry.value) {
            final sfx = suffixOfParty[p];
            if (sfx == null) continue;
            memberRename[m] = '$m$sfx';
          }
        }
      }
    }
    rewritten[dest] = _rewriteNames(
      stripped,
      strip,
      renameByDest[dest] ?? const <String, String>{},
      memberRename,
      qualify,
      chainNames: suffixedNames,
      shouldRewriteMember: (b, dot, m) => qualifiesForRewrite(b, dest, dot, m),
    );
    // (D2b) typedef-alias repair: a dupe-renamed `typedef N = Q.N` whose
    // qualifier was stripped rewrote to the self-cycle `typedef N__dupK =
    // N__dupK;` (the bare rename maps every occurrence, including the RHS).
    // Repoint the RHS at the keeper (`N`), restoring the kit alias's meaning
    // (`N__dupK` names the same type everywhere). A `typedef X = X;` cannot
    // come from the kit (it would not compile), so any occurrence is ours.
    final destRenames = renameByDest[dest];
    if (destRenames != null && destRenames.isNotEmpty) {
      final inverse = <String, String>{};
      destRenames.forEach((k, v) => inverse[v] = k);
      rewritten[dest] = rewritten[dest]!.replaceAllMapped(
        RegExp(r'typedef\s+(\w+__dup\d+)\s*=\s*(\w+)\s*;'),
        (m) => m.group(1) == m.group(2) && inverse.containsKey(m.group(1))
            ? 'typedef ${m.group(1)} = ${inverse[m.group(1)]};'
            : m.group(0)!,
      );
    }
    // Shadow imports are emitted only for aliases the rewrite actually
    // used (a firing rule with no occurrences must not drag an import in).
    for (final entry in qualify.entries) {
      if (rewritten[dest]!.contains('${entry.value}.')) {
        shadowImports[qualifyUris[entry.key]!] = entry.value;
      }
    }
  }

  // (S) SDK-prefix canonicalization: at most one `as` alias per URI survives
  // into the header (plus the bare import and the distinct shadow alias).
  // Multi-prefix URIs (the kit uses `m`/`mat`/`material` for material.dart)
  // elect the lexicographically smallest prefix as keeper and rebind safe
  // loser uses to it; prefixes with no surviving qualified use are dropped
  // from the header. See [_rebindSdkPrefix] for the safety rule.
  final canonPrefixes = _canonicalSdkPrefixes(
    sdkPrefixes,
    rewritten,
    scopeSdk,
    shadowImports.values.toSet(),
  );

  return _ClosureModel(
    grouped: survivors,
    bodies: rewritten,
    // Bare imports are never pruned: proving one unused is out of scope, and
    // an unused bare import is only an info-level lint, silenced in the
    // header.
    sdkUris: sdkUris,
    sdkPrefixes: canonPrefixes,
    shadowImports: shadowImports,
    missingKinds: missingKinds,
  );
}

/// Canonicalizes multi-prefix SDK URIs to a single surviving alias per URI.
///
/// For each URI with 2+ observed prefixes (shadow aliases excluded — they are
/// a separate mechanism and are never elected, rewritten, or dropped here),
/// the lexicographically smallest prefix is the keeper (deterministic and
/// stable; e.g. material.dart keeps `m` over `mat`/`material`). Every other
/// prefix is a loser: files whose scope binds the loser get [_rebindSdkPrefix]
/// treatment, and afterwards a prefix survives iff it still has a
/// qualifier-shaped use anywhere in the emitted bodies (raw text:
/// strings/comments over-keep, which is the safe direction) or it is the
/// keeper of at least one performed rebind.
///
/// Never throws: unknown shapes keep their imports (honest output over
/// clever breakage).
Map<String, Set<String>> _canonicalSdkPrefixes(
  Map<String, Set<String>> sdkPrefixes,
  Map<String, String> bodies,
  Map<String, Map<String, Set<String>>> scopeSdk,
  Set<String> shadowAliases,
) {
  final out = <String, Set<String>>{};
  for (final entry in sdkPrefixes.entries) {
    final uri = entry.key;
    final cands =
        entry.value.where((p) => !shadowAliases.contains(p)).toSet();
    if (cands.length < 2) {
      out[uri] = Set<String>.of(entry.value);
      continue;
    }
    final ranked = cands.toList()..sort();
    final keeper = ranked.first;
    var reboundToKeeper = false;
    for (final loser in cands) {
      if (loser == keeper) continue;
      for (final dest in bodies.keys) {
        if (!(scopeSdk[dest]?[uri]?.contains(loser) ?? false)) continue;
        final next = _rebindSdkPrefix(bodies[dest]!, loser, keeper);
        // Null = unsafe body (a bare/local/member `loser` or `keeper`
        // shadows the import there): left untouched, loser import stays.
        if (next == null) continue;
        if (next != bodies[dest]) {
          bodies[dest] = next;
          reboundToKeeper = true;
        }
      }
    }
    // Survivors: prefixes with a remaining qualifier-shaped use (raw text,
    // so interpolation code and even strings/comments keep the import —
    // safe direction), plus the keeper when a rebind landed on it.
    final keep = <String>{};
    for (final p in entry.value) {
      if (shadowAliases.contains(p)) {
        keep.add(p);
        continue;
      }
      var remaining = 0;
      for (final body in bodies.values) {
        remaining += _qualifierUses(body, p);
      }
      if (remaining > 0) keep.add(p);
    }
    if (reboundToKeeper) keep.add(keeper);
    out[uri] = keep;
  }
  return out;
}

/// Counts qualifier-shaped uses of import prefix [p] in [text]: occurrences
/// of the word [p] (identifier-boundary aware, so `format.` never poses as
/// `mat.`) immediately followed by `.` and not preceded by `.` (member
/// accesses like `x.mat` never count).
int _qualifierUses(String text, String p) {
  final pat = RegExp(
    '(?<![A-Za-z0-9_\$.])${RegExp.escape(p)}\\.',
  );
  return pat.allMatches(text).length;
}

/// Rebinds qualifier uses of SDK import-prefix [loser] to [keeper] in [body]
/// (code positions only: comments/strings keep their text), or returns null
/// when the body is unsafe to rewrite.
///
/// Unsafe (returns null, caller keeps the loser import) when any code word
/// occurrence of [loser] or [keeper] is NOT qualifier-shaped: a bare
/// occurrence means a declaration, local, parameter, field formal, named
/// argument, or label by that name shadows (or simply reuses) the word, so
/// rebinding could corrupt it. Member-position uses (`x.mat`) never match
/// the boundary pattern and are left untouched without vetoing.
///
/// Residual risk (documented, pathological): a same-scope keeper-named value
/// with members used only in qualifier shape alongside loser import-prefix
/// uses (the kit would still compile). The export harness (`flutter analyze`,
/// 0 errors) guards it empirically.
String? _rebindSdkPrefix(String body, String loser, String keeper) {
  final clean = _stripStrings(_stripComments(body));
  final pat = RegExp(
    '(?<![A-Za-z0-9_\$.])(?:${RegExp.escape(loser)}|${RegExp.escape(keeper)})(?![A-Za-z0-9_\$])',
  );
  final starts = <int>[];
  for (final m in pat.allMatches(clean)) {
    if (m.end >= clean.length || clean[m.end] != '.') return null;
    if (clean.substring(m.start, m.end) == loser) starts.add(m.start);
  }
  // Back-to-front splice: replacement lengths differ, so earlier offsets
  // must not shift. Length-preserving cleaning guarantees these offsets are
  // valid in the original body.
  starts.sort((a, b) => b.compareTo(a));
  var out = body;
  for (final s in starts) {
    out = out.substring(0, s) + keeper + out.substring(s + loser.length);
  }
  return out;
}

/// Writes the resolved closure: TODOs for missing kinds, then survivor
/// bodies. A final whole-hash guard stays (two survivors can only collide
/// when rewrites converge them — kept, never skipped-on-doubt otherwise).
void _writeClosureBodies(StringBuffer out, _ClosureModel model) {
  for (final kind in model.missingKinds) {
    out.writeln();
    out.writeln('// TODO(canvas): no source for kind "$kind"');
  }
  final seenFiles = <String>{};
  for (final dest in model.grouped) {
    final body = model.bodies[dest]!;
    final norm = _normalizeBody(body);
    if (norm.isEmpty) continue;
    if (!seenFiles.add(norm)) continue;
    out
      ..writeln()
      ..writeln('// from: $dest')
      ..writeln(body);
  }
}

/// Drops `// ignore_for_file` lines (closure path only: the merged header
/// carries the codes once; inlining repeats them per file). Tolerant of the
/// missing space (`//ignore_for_file`).
String _stripIgnoreForFile(String body) {
  final kept = <String>[];
  for (final line in body.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') &&
        trimmed.substring(2).trimLeft().startsWith('ignore_for_file')) {
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n');
}

/// Normalizes a stripped body for equality: drops comments, collapses
/// whitespace runs. Used for whole-file and per-declaration identity.
String _normalizeBody(String text) =>
    _stripComments(text).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Drops `//…` and `/*…*/` comments with string awareness (interpolation
/// braces inside strings stay opaque so they never unbalance the caller).
/// Fully length-preserving (blanks and newlines): offsets and line numbers
/// in the cleaned text map 1:1 to the original, so line-targeted passes can
/// match on cleaned lines and substitute in original lines. Returns the
/// input unchanged when a block comment is unterminated.
String _stripComments(String text) {
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
      final end = text.indexOf('\n', i + 2);
      final stop = end < 0 ? text.length : end;
      for (var k = i; k < stop; k++) {
        out.write(' ');
      }
      if (end < 0) break;
      out.write('\n');
      i = end + 1;
      continue;
    }
    if (c == '/' && i + 1 < text.length && text[i + 1] == '*') {
      final end = text.indexOf('*/', i + 2);
      if (end < 0) return text;
      // Length-preserving blanks (newlines kept): offsets stay aligned for
      // line-targeted passes over cleaned text.
      for (var k = i; k < end + 2; k++) {
        out.write(text[k] == '\n' ? '\n' : ' ');
      }
      i = end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final end = _stringEnd(text, i);
      if (end < 0) {
        out.write(text.substring(i));
        break;
      }
      out.write(text.substring(i, end));
      i = end;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// End offset (exclusive) of the string starting at [start], or -1 when
/// unterminated. Triple-quoted and raw (`r'…'`) aware. `${…}` interpolation
/// is skipped as nested code (brace- and string-aware): quotes and braces
/// inside interpolation never disturb the caller.
int _stringEnd(String text, int start) {
  final quote = text[start];
  var end = start + 1;
  var triple = false;
  if (text.startsWith(quote * 3, start)) {
    triple = true;
    end = start + 3;
  }
  // Raw prefix: a bare `r` immediately before the quote that is not itself
  // part of a longer identifier (valid Dart only opens a string there).
  // Raw strings admit no escapes and no interpolation.
  final raw = start > 0 &&
      text[start - 1] == 'r' &&
      (start < 2 || !_isIdentChar(text[start - 2]));
  while (end < text.length) {
    final c = text[end];
    if (!raw && c == '\\') {
      end += 2;
      continue;
    }
    if (!raw &&
        c == r'$' &&
        end + 1 < text.length &&
        text[end + 1] == '{') {
      end = _balancedEnd(text, end + 1);
      if (end < 0) return -1;
      continue;
    }
    if (c == quote) {
      if (!triple) return end + 1;
      if (text.startsWith(quote * 3, end)) return end + 3;
    }
    end++;
  }
  return -1;
}

/// End offset (exclusive) of the `{…}` block opening at [open] (which must
/// point at `{`), or -1 when unbalanced. String-, comment- and
/// interpolation-aware: nested quotes, `${…}` and comments never disturb
/// the depth count.
int _balancedEnd(String text, int open) {
  var depth = 0;
  var i = open;
  while (i < text.length) {
    final c = text[i];
    if (c == "'" || c == '"') {
      final end = _stringEnd(text, i);
      if (end < 0) return -1;
      i = end;
      continue;
    }
    if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
      final end = text.indexOf('\n', i + 2);
      if (end < 0) return text.length;
      i = end + 1;
      continue;
    }
    if (c == '/' && i + 1 < text.length && text[i + 1] == '*') {
      final end = text.indexOf('*/', i + 2);
      if (end < 0) return -1;
      i = end + 2;
      continue;
    }
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
    i++;
  }
  return -1;
}

/// The text with every string literal blanked (length-preserving spaces,
/// newlines kept, so offsets and line numbers survive). Spans located with
/// [_stringEnd], so interpolation nesting is honored. Used before
/// structural passes so words inside strings can never pose as code.
String _stripStrings(String text) {
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (c == "'" || c == '"') {
      final end = _stringEnd(text, i);
      if (end < 0) {
        out.write(text.substring(i));
        break;
      }
      for (var k = i; k < end; k++) {
        out.write(text[k] == '\n' ? '\n' : ' ');
      }
      i = end;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

bool _isIdentChar(String c) =>
    (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) ||
    (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) ||
    (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) ||
    c == '_' ||
    c == r'$';

/// One top-level declaration: normalized [text] plus the [start]/[end]
/// offsets of its span in the scanned body (annotations included, surrounding
/// trivia excluded) for exact carving.
class _Decl {
  final String text;
  final int start;
  final int end;

  const _Decl(this.text, this.start, this.end);
}

/// Top-level declarations of a stripped [body], or `null` when the body
/// holds top-level content this scanner cannot attribute.
///
/// After directive stripping, every remaining top-level statement is a
/// declaration, so no name patterns are needed: a column-0 code line starts
/// a declaration and the span runs to the depth-0 `;` (no brace seen) or the
/// matching `}`. Leading `@…` annotations join their declaration; comments
/// are excluded from the span (copies often reword docs). Callers must emit
/// `null` bodies whole and let them contribute nothing — never skip on
/// doubt.
List<_Decl>? _topLevelDecls(String body) {
  final decls = <_Decl>[];
  final annotations = StringBuffer();
  var annotationsStart = 0;
  var pos = 0;

  int skipTrivia(int from) {
    var i = from;
    while (i < body.length) {
      final c = body[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        i++;
        continue;
      }
      if (c == ';') {
        i++; // stray semicolon: semantically void.
        continue;
      }
      if (c == '/' && i + 1 < body.length && body[i + 1] == '/') {
        final end = body.indexOf('\n', i + 2);
        if (end < 0) return body.length;
        i = end + 1;
        continue;
      }
      if (c == '/' && i + 1 < body.length && body[i + 1] == '*') {
        final end = body.indexOf('*/', i + 2);
        if (end < 0) return -1;
        i = end + 2;
        continue;
      }
      break;
    }
    return i;
  }

  // End offset (exclusive) of the `@…` annotation at [from], or -1.
  int annotationEnd(int from) {
    var i = from + 1;
    if (i >= body.length || !_isIdentChar(body[i]) && body[i] != '_') {
      return -1;
    }
    while (i < body.length && (_isIdentChar(body[i]))) {
      i++;
    }
    while (true) {
      var j = i;
      while (j < body.length &&
          (body[j] == ' ' || body[j] == '\t' || body[j] == '\n' ||
              body[j] == '\r')) {
        j++;
      }
      if (j < body.length && (body[j] == '(' || body[j] == '[')) {
        final close = body[j] == '(' ? ')' : ']';
        var depth = 0;
        var k = j;
        while (k < body.length) {
          final c = body[k];
          if (c == "'" || c == '"') {
            final end = _stringEnd(body, k);
            if (end < 0) return -1;
            k = end;
            continue;
          }
          if (c == '/' && k + 1 < body.length && body[k + 1] == '/') {
            final end = body.indexOf('\n', k + 2);
            if (end < 0) return -1;
            k = end + 1;
            continue;
          }
          if (c == '/' && k + 1 < body.length && body[k + 1] == '*') {
            final end = body.indexOf('*/', k + 2);
            if (end < 0) return -1;
            k = end + 2;
            continue;
          }
          if (c == '(' || c == '[') depth++;
          if (c == ')' || c == ']') {
            depth--;
            if (depth == 0) {
              if ((close == ')' && c == ')') ||
                  (close == ']' && c == ']')) {
                i = k + 1;
                break;
              }
              return -1;
            }
            if (depth < 0) return -1;
          }
          k++;
        }
        if (k >= body.length) return -1;
        continue;
      }
      i = j;
      break;
    }
    return i;
  }

  // End offset (exclusive) of the declaration starting at [from], or -1.
  int declEnd(int from) {
    var curly = 0;
    var paren = 0;
    var square = 0;
    var seenBrace = false;
    var i = from;
    while (i < body.length) {
      final c = body[i];
      if (c == '/' && i + 1 < body.length && body[i + 1] == '/') {
        final end = body.indexOf('\n', i + 2);
        if (end < 0) return body.length;
        i = end + 1;
        continue;
      }
      if (c == '/' && i + 1 < body.length && body[i + 1] == '*') {
        final end = body.indexOf('*/', i + 2);
        if (end < 0) return -1;
        i = end + 2;
        continue;
      }
      if (c == "'" || c == '"') {
        final end = _stringEnd(body, i);
        if (end < 0) return -1;
        i = end;
        continue;
      }
      if (c == '{') {
        curly++;
        seenBrace = true;
      } else if (c == '}') {
        curly--;
        if (curly < 0) return -1;
        if (curly == 0 && seenBrace && paren == 0 && square == 0) {
          return i + 1;
        }
      } else if (c == '(') {
        paren++;
      } else if (c == ')') {
        paren--;
        if (paren < 0) return -1;
      } else if (c == '[') {
        square++;
      } else if (c == ']') {
        square--;
        if (square < 0) return -1;
      } else if (c == ';' &&
          !seenBrace &&
          curly == 0 &&
          paren == 0 &&
          square == 0) {
        return i + 1;
      }
      i++;
    }
    return -1;
  }

  pos = skipTrivia(pos);
  while (pos < body.length) {
    if (pos < 0) return null;
    final c = body[pos];
    if (c == '}') return null; // stray close: unattributable.
    if (c == '@') {
      final end = annotationEnd(pos);
      if (end < 0) return null;
      if (annotations.isEmpty) annotationsStart = pos;
      annotations.write(body.substring(pos, end));
      annotations.write(' ');
      pos = skipTrivia(end);
      continue;
    }
    final end = declEnd(pos);
    if (end < 0) return null;
    final spanStart = annotations.isEmpty ? pos : annotationsStart;
    final span = annotations.toString() + body.substring(pos, end);
    annotations.clear();
    final norm = _normalizeBody(span);
    if (norm.isNotEmpty) decls.add(_Decl(norm, spanStart, end));
    pos = skipTrivia(end);
  }
  return decls;
}

/// Root flow children for [screenId] in document (insertion) order.
///
/// Nodes whose `parentId` points at a missing node are treated as roots so
/// codegen never silently drops nodes. Row children stay nested under their
/// row via [_writeFlowChild] and are excluded here.
List<CanvasNode> _rootNodes(ScreenDoc doc, String screenId) {
  final ids = {for (final n in doc.nodes) n.id};
  return [
    for (final node in doc.nodes)
      if (node.screenId == screenId &&
          (node.parentId == null || !ids.contains(node.parentId))) node,
  ];
}

/// Track C3 (COMPOSITION.md §2): kinds whose child slot codegen splices
/// recursively generated children into. The `row` pseudo-kind is structural
/// (`isRow == true`, handled by the Row emitters) and is NOT listed here.
/// Every other kind is a leaf: children use the below-fallback (§1).
const _kContainerKinds = {
  'card',
  'outlined_container',
  'scaffold',
  'dialog',
  'alert_dialog',
  'drawer',
  'form',
  'hidden',
  'clickable',
  'scrollbar',
  'chat',
  'toast',
  'validated',
  'refresh_trigger',
};

/// Cycle marker for corrupt docs (mirrors the `validateNesting` message, with
/// the codegen action appended): emitted as a comment where the revisit would
/// recurse, then the subtree is skipped — never a hang, never a crash.
String _cycleNote(String nodeId) =>
    'cycle: node $nodeId is its own ancestor (skipped)';

/// Splices recursively emitted child [units] (unindented multi-line statement
/// strings from [_childUnits]) into a container slot whose children sit at
/// [slotIndent] in the unindented composer output. Units join with
/// `kFlowScreenGap` separators, with a leading separator from the chrome
/// above (vertical-stack rule, COMPOSITION.md §5).
String _spliceSlotChildren(List<String> units, String slotIndent) {
  final gap =
      '${slotIndent}const SizedBox(height: ${_flowNum(kFlowScreenGap)}),';
  final buf = StringBuffer();
  for (final unit in units) {
    buf.writeln(gap);
    for (final line in unit.split('\n')) {
      if (line.isEmpty) continue;
      buf.writeln('$slotIndent$line');
    }
  }
  return buf.toString();
}

/// Unindented statement strings for [kids] (each: tap comments, tap wraps,
/// and its own responsive wrapper when responsive), skipping kids that emit
/// nothing (e.g. empty leaves). Recursion funnels through [_writeFlowChild],
/// which is cycle-guarded via [visited].
List<String> _childUnits(
  ScreenDoc doc,
  List<CanvasNode> kids,
  Set<String> visited,
) {
  final units = <String>[];
  for (final kid in kids) {
    final buf = StringBuffer();
    _writeFlowChild(buf, doc, kid, '', visited);
    final text = buf.toString().trimRight();
    if (text.isNotEmpty) units.add(text);
  }
  return units;
}

/// Unindented single-statement strings for [items] (tap `// taps -> …`
/// comment plus the bundle-equivalent `GestureDetector` wrap for known
/// targets). Statement-for-statement identical to [_writeItemBlock].
List<String> _ownItemUnits(ScreenDoc doc, List<CanvasItem> items) {
  final taps = _tapTargets(doc);
  final units = <String>[];
  for (final item in items) {
    final lines = <String>[];
    final comment = _tapCommentLine(item);
    if (comment != null) lines.add(comment);
    final expr = _itemExpression(item);
    lines.addAll((_tapWrapStatement(expr, item, taps) ?? expr).split('\n'));
    units.add(lines.join('\n'));
  }
  return units;
}

/// W3 alignment names: row `mainAxis` strings to `MainAxisAlignment` const
/// names (`null`/unknown → start, preserving the pre-W3 default output).
String _mainAxisName(String? value) {
  switch (value) {
    case 'center':
      return 'MainAxisAlignment.center';
    case 'end':
      return 'MainAxisAlignment.end';
    case 'spaceBetween':
      return 'MainAxisAlignment.spaceBetween';
    case 'spaceAround':
      return 'MainAxisAlignment.spaceAround';
    case 'spaceEvenly':
      return 'MainAxisAlignment.spaceEvenly';
    case 'start':
    case null:
      return 'MainAxisAlignment.start';
    default:
      return 'MainAxisAlignment.start';
  }
}

/// W3 alignment names: row `crossAxis` strings to `CrossAxisAlignment` const
/// names (`null`/unknown → center, preserving the pre-W3 default output).
String _crossAxisName(String? value) {
  switch (value) {
    case 'start':
      return 'CrossAxisAlignment.start';
    case 'end':
      return 'CrossAxisAlignment.end';
    case 'stretch':
      return 'CrossAxisAlignment.stretch';
    case 'center':
    case null:
      return 'CrossAxisAlignment.center';
    default:
      return 'CrossAxisAlignment.center';
  }
}

/// Whether [node] needs a responsive wrapper: a known `hiddenOn` tier or a
/// known-tier `breakpointValues` entry. Unknown tier strings are inert
/// (rejected at parse time by `CanvasNode.fromJson`), so they never wrap —
/// docs without responsive fields keep byte-identical output.
bool _isResponsive(CanvasNode node) =>
    _hiddenTiers(node).isNotEmpty || _overrideTiers(node).isNotEmpty;

/// Whether [node] carries an explicit size (Track U2): gates ALL size
/// emission, so unsized docs keep byte-identical output.
bool _isSized(CanvasNode node) => node.w != null || node.h != null;

/// Single-expression content for a sized node (Track U2 — [node.id] is
/// already in [visited]): the responsive `LayoutBuilder` capture when the
/// node is responsive (size stays OUTSIDE the tier conditional — the layout
/// role is tier-independent, like the flex wrappers), else
/// [_nodeContentExpr] (already one expression for every shape: single item,
/// multi-item `Column`, row, container slot, below-fallback — tap wraps
/// inside, comments below).
String _sizedInnerExpr(ScreenDoc doc, CanvasNode node, Set<String> visited) {
  if (_isResponsive(node)) {
    final buf = StringBuffer();
    _writeResponsiveFlowChild(buf, doc, node, '', visited);
    return _stripTrailingComma(buf.toString());
  }
  return _nodeContentExpr(doc, node, visited);
}

/// Writes `SizedBox([width][height]child: <content>)` for the single
/// [content] expression (unindented, no trailing comma) at [indent] —
/// the canvas `applyNodeSize` idiom in generated code.
void _writeSizedBox(
  StringBuffer out,
  double? w,
  double? h,
  String content,
  String indent,
) {
  final lines = [
    for (final line in content.split('\n')) if (line.isNotEmpty) line,
  ];
  out.writeln('${indent}SizedBox(');
  if (w != null) out.writeln('$indent  width: ${_flowNum(w)},');
  if (h != null) out.writeln('$indent  height: ${_flowNum(h)},');
  if (lines.isEmpty) {
    out.writeln('${indent}  child: SizedBox.shrink(),');
  } else {
    out.writeln('$indent  child: ${lines.first}');
    for (final line in lines.skip(1)) {
      out.writeln('$indent  $line');
    }
  }
  out.writeln('$indent),');
}

/// Tap comment for a childless single-item node with an action, or null
/// (shared by [_writeBranch] and the Track U2 sized path so comments stay
/// consistent: nodes with children carry theirs inside the capture).
String? _tapCommentFor(ScreenDoc doc, CanvasNode node) {
  if (!node.isRow &&
      node.items.length == 1 &&
      node.items.single.action != null &&
      childrenOf(doc, node.id).isEmpty) {
    return _tapCommentLine(node.items.single);
  }
  return null;
}

/// Known `hiddenOn` tiers, sorted (deterministic conditions/comments).
List<String> _hiddenTiers(CanvasNode node) =>
    (node.hiddenOn.where(kResponsiveTiers.contains).toList()..sort());

/// Known `breakpointValues` tiers, sorted (deterministic branch order).
List<String> _overrideTiers(CanvasNode node) =>
    (node.breakpointValues.keys.where(kResponsiveTiers.contains).toList()
      ..sort());

/// Copy of [node] with [overrides] merged over every item's props.
CanvasNode _withProps(CanvasNode node, Map<String, dynamic> overrides) =>
    CanvasNode(
      id: node.id,
      screenId: node.screenId,
      x: node.x,
      y: node.y,
      items: [
        for (final item in node.items)
          item.copyWith(props: {...item.props, ...overrides}),
      ],
      parentId: node.parentId,
      isRow: node.isRow,
      gap: node.gap,
      mainAxis: node.mainAxis,
      crossAxis: node.crossAxis,
      expand: node.expand,
      flex: node.flex,
      // Track U2: sizes are node-level, never item props — tier branches
      // carry them so responsive + sized nodes keep their size per branch.
      w: node.w,
      h: node.h,
      hiddenOn: node.hiddenOn,
      breakpointValues: node.breakpointValues,
      slots: node.slots,
    );

/// Renders [node]'s content as a single widget expression (unindented, no
/// trailing comma) for responsive `LayoutBuilder` branch returns: a row
/// renders its `Row` (or `IntrinsicHeight`) construction via the
/// non-responsive core (nested responsive children keep their own builders
/// through the dispatcher); a single-item leaf renders that item; a
/// multi-item leaf renders a `Column`; an empty leaf renders
/// `SizedBox.shrink()`. Tap `// taps -> ...` comments are NOT included —
/// [_writeBranch] emits those above the return — but known-target items ARE
/// GestureDetector-wrapped here (see [_wrapTapExpr]) so responsive branch
/// returns navigate like the non-responsive paths.
///
/// Track C3: nodes WITH children capture their statement form (container slot
/// splice or below-fallback, see [_writeNonRowCore]) through a buffer and
/// strip the trailing comma, so every branch carries the whole subtree.
/// [visited] guards the capture (the node's own id is already a member —
/// [_writeFlowChild] adds it before dispatching here).
String _nodeContentExpr(ScreenDoc doc, CanvasNode node, Set<String> visited) {
  final kids = childrenOf(doc, node.id);
  if (!node.isRow) {
    if (kids.isEmpty) {
      if (node.items.length == 1) {
        final item = node.items.single;
        final expr = _itemExpression(item);
        final action = item.action;
        if (action != null && action.steps.isNotEmpty) {
          return _wrapMethodTapExpr(expr, item);
        }
        final route = _tapTargets(doc).routeFor(item);
        if (route == null) return _stripTrailingComma(expr);
        return _wrapTapExpr(expr, action!, route);
      }
      if (node.items.isEmpty) return 'SizedBox.shrink()';
      final buf = StringBuffer()
        ..writeln('Column(')
        ..writeln('mainAxisSize: MainAxisSize.min,')
        ..writeln('crossAxisAlignment: CrossAxisAlignment.start,')
        ..writeln('children: [');
      _writeItemBlock(buf, doc, node.items, '  ');
      buf
        ..writeln('],')
        ..write(')');
      return buf.toString();
    }
    final buf = StringBuffer();
    _writeNonRowCore(buf, doc, node, kids, '', visited);
    return _stripTrailingComma(buf.toString());
  }
  final buf = StringBuffer();
  _writeFlowChildCore(buf, doc, node, '', visited);
  return _stripTrailingComma(buf.toString());
}

/// Drops one trailing comma (plus surrounding whitespace) from emitted
/// statement text so it can follow `return`.
String _stripTrailingComma(String text) {
  var out = text.trimRight();
  if (out.endsWith(',')) out = out.substring(0, out.length - 1);
  return out;
}

/// Writes `return <expr>;` for [expr] (an unindented [_nodeContentExpr])
/// under [indent]; [firstPrefix] starts the first line (`'return '` or a
/// tier guard like `"if (tier == 'tablet') return "`).
void _writeReturn(
  StringBuffer out,
  String expr,
  String indent,
  String firstPrefix,
) {
  final lines = [
    for (final line in expr.split('\n')) if (line.isNotEmpty) line,
  ];
  for (var i = 0; i < lines.length; i++) {
    final tail = i == lines.length - 1 ? ';' : '';
    if (i == 0) {
      out.writeln('$indent$firstPrefix${lines[i]}$tail');
    } else {
      out.writeln('$indent${lines[i]}$tail');
    }
  }
}

/// Writes one tier branch (or the default branch when [guard] is null) for
/// [node]'s content, preserving the `// taps -> ...` comment for
/// single-item leaves.
///
/// Track C3: nodes with children carry their tap comments inside the captured
/// subtree expression, so the outer comment is childless-only (no duplicates).
void _writeBranch(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode node,
  String indent,
  String? guard,
  Set<String> visited,
) {
  if (!node.isRow &&
      node.items.length == 1 &&
      node.items.single.action != null &&
      childrenOf(doc, node.id).isEmpty) {
    out.writeln('$indent${_tapCommentLine(node.items.single)}');
  }
  _writeReturn(
    out,
    _nodeContentExpr(doc, node, visited),
    indent,
    guard == null ? 'return ' : 'if ($guard) return ',
  );
}

/// Writes a responsive node: a `LayoutBuilder` resolving the tier from the
/// layout width (mirroring `tierForWidth` in canvas_app — <600 mobile, <1024
/// tablet, else desktop), hiding the node on its `hiddenOn` tiers and
/// selecting per-tier item props from `breakpointValues` (statically merged
/// per branch, so every branch reuses the plain item emitters).
///
/// `theme.chrome` is editor-only and never emitted (there is no chrome input
/// here — codegen reads screens/nodes only). `slots` has no widget semantics
/// in single-file output and is ignored.
///
/// A node hidden on every tier emits a bare `SizedBox.shrink()` — no builder,
/// nothing to resolve at runtime.
void _writeResponsiveFlowChild(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode node,
  String indent,
  Set<String> visited,
) {
  final hidden = _hiddenTiers(node);
  final tiers = _overrideTiers(node);
  if (hidden.length == kResponsiveTiers.length) {
    out
      ..writeln('$indent// hidden on: ${hidden.join(', ')} (all tiers)')
      ..writeln('${indent}const SizedBox.shrink(),');
    return;
  }
  final summary = [
    if (hidden.isNotEmpty) 'hidden on ${hidden.join(', ')}',
    if (tiers.isNotEmpty) 'overrides on ${tiers.join(', ')}',
  ].join('; ');
  out
    ..writeln('$indent// responsive ($summary)')
    ..writeln('${indent}LayoutBuilder(')
    ..writeln('$indent  builder: (context, constraints) {')
    ..writeln(
      "$indent    final tier = constraints.maxWidth >= 1024 "
      "? 'desktop' : constraints.maxWidth >= 600 ? 'tablet' : 'mobile';",
    );
  if (hidden.isNotEmpty) {
    final cond = hidden.map((t) => "tier == '$t'").join(' || ');
    out.writeln('$indent    if ($cond) return const SizedBox.shrink();');
  }
  for (final tier in tiers) {
    _writeBranch(
      out,
      doc,
      _withProps(node, node.breakpointValues[tier]!),
      '$indent    ',
      "tier == '$tier'",
      visited,
    );
  }
  _writeBranch(out, doc, node, '$indent    ', null, visited);
  out
    ..writeln('$indent  },')
    ..writeln('$indent),');
}

/// Responsive row child: the W3 flex wrapper stays OUTSIDE the tier
/// conditional (the layout role is tier-independent), so only the content
/// re-resolves per tier.
void _writeResponsiveRowChild(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode child,
  String indent,
  Set<String> visited,
) {
  final expand = child.expand;
  if (expand != 'expanded' && expand != 'flex') {
    _writeResponsiveFlowChild(out, doc, child, indent, visited);
    return;
  }
  final flex = child.flex ?? 1;
  final wrapper = expand == 'expanded' ? 'Expanded' : 'Flexible';
  out
    ..writeln('$indent$wrapper(')
    ..writeln('$indent  flex: $flex,')
    ..writeln('$indent  child:');
  _writeResponsiveFlowChild(out, doc, child, '$indent    ', visited);
  out.writeln('$indent),');
}

/// Writes one root flow child: a leaf's items inline, or a [Row] for a row
/// container whose children are the row's own items plus each child node's
/// items (recurses for nested rows), separated by `SizedBox(width: gap)`.
///
/// Responsive nodes (`hiddenOn`/`breakpointValues`) route to
/// [_writeResponsiveFlowChild]; everything else uses the non-responsive core
/// below, unchanged.
///
/// Track C3: the cycle-guarded entry — [visited] holds the ancestor path
/// (added here, removed when this subtree is done). A revisit means a corrupt
/// `parentId` cycle: comment + skip, never a hang. Roots start with an empty
/// set (see [buildSingleFile]); every deeper recursion funnels through here.

void _writeFlowChild(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode node,
  String indent,
  Set<String> visited,
) {
  if (!visited.add(node.id)) {
    out.writeln('$indent// ${_cycleNote(node.id)}');
    return;
  }
  try {
    // Track U2: size wraps the whole subtree (responsive conditional inside
    // when responsive — see [_sizedInnerExpr]).
    if (_isSized(node)) {
      final comment = _tapCommentFor(doc, node);
      if (comment != null) out.writeln('$indent$comment');
      _writeSizedBox(
        out,
        node.w,
        node.h,
        _sizedInnerExpr(doc, node, visited),
        indent,
      );
      return;
    }
    if (_isResponsive(node)) {
      _writeResponsiveFlowChild(out, doc, node, indent, visited);
      return;
    }
    _writeFlowChildCore(out, doc, node, indent, visited);
  } finally {
    visited.remove(node.id);
  }
}

/// Writes one root flow child — non-responsive core (see [_writeFlowChild]
/// for the responsive dispatcher).
///
/// W3: the row emits its `mainAxisAlignment`/`crossAxisAlignment` from the
/// mapped `mainAxis`/`crossAxis` (null → the pre-W3 start/center defaults, so
/// old docs generate byte-identical output). Each child node with
/// `expand == 'expanded'` wraps in `Expanded(flex: n, child: ...)` and
/// `expand == 'flex'` in `Flexible(flex: n, child: ...)` (`flex ?? 1`);
/// null/none/unknown emit unwrapped (pre-W3 output). Row-own items are never
/// wrapped. Deterministic doc order; separators unchanged.
///
/// `crossAxis == stretch` wraps the Row in `IntrinsicHeight`: a stretch Row
/// inside the screen Column (unbounded height) asserts without it, in both
/// the renderer and the generated app.
///
/// Track C3: non-row nodes WITH children take the composition branches
/// ([_writeNonRowCore]) — container slot splice or below-fallback; childless
/// nodes keep the historical [_writeItemBlock] path byte-identically.
/// [visited] already contains [node.id] (added by [_writeFlowChild]).
void _writeFlowChildCore(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode node,
  String indent,
  Set<String> visited,
) {
  if (!node.isRow) {
    final kids = childrenOf(doc, node.id);
    if (kids.isEmpty) {
      _writeItemBlock(out, doc, node.items, indent);
      return;
    }
    _writeNonRowCore(out, doc, node, kids, indent, visited);
    return;
  }
  final stretch = node.crossAxis == 'stretch';
  final rowIndent = stretch ? '$indent  ' : indent;
  final childIndent = '$rowIndent    ';
  if (stretch) out.writeln('${indent}IntrinsicHeight(');
  out
    ..writeln('${rowIndent}Row(')
    ..writeln('$rowIndent  mainAxisAlignment: ${_mainAxisName(node.mainAxis)},')
    ..writeln(
        '$rowIndent  crossAxisAlignment: ${_crossAxisName(node.crossAxis)},')
    ..writeln('$rowIndent  children: [');
  var first = true;
  void separator() {
    if (!first) {
      out.writeln(
          '${childIndent}const SizedBox(width: ${_flowNum(node.gap)}),');
    }
    first = false;
  }

  var empty = true;
  if (node.items.isNotEmpty) {
    empty = false;
    separator();
    _writeItemBlock(out, doc, node.items, childIndent);
  }
  for (final child in childrenOf(doc, node.id)) {
    empty = false;
    separator();
    _writeRowChild(out, doc, child, childIndent, visited);
  }
  if (empty) {
    out.writeln('${childIndent}// (empty row)');
  }
  out
    ..writeln('$rowIndent  ],')
    ..writeln('$rowIndent),');
  if (stretch) out.writeln('$indent),');
}

/// Writes one row child with W3 flex wrapping: nested rows recurse inside
/// the wrapper; leaves wrap each item expression (single-item nodes — the
/// common drop path — yield one wrapper; multi-item nodes wrap each item
/// with the same flex to stay deterministic without regrouping).
///
/// Responsive children route to [_writeResponsiveRowChild]; everything else
/// uses the non-responsive core below, unchanged.
///
/// Track U2: sized children take the sized path FIRST (fixed `w` beats flex —
/// the documented precedence on [CanvasNode]; `h`-only keeps the flex role
/// outside the fixed height, mirroring the canvas cell). Unsized children
/// keep the historical paths byte-identically.
///
/// Track C3: non-row children WITH children recurse through [_writeFlowChild]
/// (container slot splice / below-fallback / nested rows at any depth, with
/// the flex wrapper outside the whole subtree); childless children keep the
/// historical paths byte-identically.
void _writeRowChild(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode child,
  String indent,
  Set<String> visited,
) {
  if (child.w == null && child.h == null) {
    if (_isResponsive(child)) {
      _writeResponsiveRowChild(out, doc, child, indent, visited);
      return;
    }
    _writeRowChildCore(out, doc, child, indent, visited);
    return;
  }
  // Sized row child: own cycle guard (this dispatcher never adds; the content
  // builders below assume [child.id] is already a member — see
  // [_writeFlowChild]).
  if (!visited.add(child.id)) {
    out.writeln('$indent// ${_cycleNote(child.id)}');
    return;
  }
  try {
    final comment = _tapCommentFor(doc, child);
    if (comment != null) out.writeln('$indent$comment');
    final content = _sizedInnerExpr(doc, child, visited);
    final expand = child.expand;
    if (child.w != null || (expand != 'expanded' && expand != 'flex')) {
      _writeSizedBox(out, child.w, child.h, content, indent);
      return;
    }
    final flex = child.flex ?? 1;
    final wrapper = expand == 'expanded' ? 'Expanded' : 'Flexible';
    out
      ..writeln('$indent$wrapper(')
      ..writeln('$indent  flex: $flex,');
    _writeSizedBox(out, null, child.h, content, '$indent  ');
    out.writeln('$indent),');
  } finally {
    visited.remove(child.id);
  }
}

/// Writes one row child — non-responsive core (see [_writeRowChild] for the
/// responsive dispatcher).
void _writeRowChildCore(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode child,
  String indent,
  Set<String> visited,
) {
  final expand = child.expand;
  if (expand != 'expanded' && expand != 'flex') {
    if (child.isRow || childrenOf(doc, child.id).isNotEmpty) {
      _writeFlowChild(out, doc, child, indent, visited);
    } else {
      _writeItemBlock(out, doc, child.items, indent);
    }
    return;
  }
  final flex = child.flex ?? 1;
  final wrapper = expand == 'expanded' ? 'Expanded' : 'Flexible';
  if (child.isRow) {
    out
      ..writeln('${indent}$wrapper(')
      ..writeln('$indent  flex: $flex,')
      ..writeln('${indent}  child:');
    final nestedIndent = '$indent    ';
    final nested = StringBuffer();
    _writeFlowChild(nested, doc, child, nestedIndent, visited);
    for (final line in nested.toString().split('\n')) {
      if (line.isEmpty) continue;
      out.writeln(line);
    }
    out.writeln('$indent),');
    return;
  }
  final kids = childrenOf(doc, child.id);
  if (kids.isNotEmpty) {
    // Flex stays outside the whole subtree (the layout role is
    // tap-independent and tier-independent, like the row/responsive
    // wrappers); the subtree carries its own tap wraps and conditionals.
    final nested = StringBuffer();
    _writeFlowChild(nested, doc, child, '', visited);
    var text = nested.toString().trimRight();
    if (text.isEmpty) text = 'SizedBox.shrink()';
    final exprLines = text.split('\n');
    out
      ..writeln('${indent}$wrapper(')
      ..writeln('$indent  flex: $flex,')
      ..writeln('${indent}  child: ${exprLines.first}');
    for (final line in exprLines.skip(1)) {
      out.writeln('$indent  $line');
    }
    out.writeln('$indent),');
    return;
  }
  for (final item in child.items) {
    final comment = _tapCommentLine(item);
    if (comment != null) {
      out.writeln('$indent$comment');
    }
    // Tap wraps stay inside the flex wrapper so the layout role is
    // tap-independent (see [_wrapTapExpr]/[_wrapMethodTapExpr]).
    var expr = _itemExpression(item);
    expr = _tapWrapStatement(expr, item, _tapTargets(doc)) ?? expr;
    final exprLines = expr.split('\n');
    out
      ..writeln('${indent}$wrapper(')
      ..writeln('$indent  flex: $flex,')
      ..writeln('${indent}  child: ${exprLines.first}');
    for (final line in exprLines.skip(1)) {
      out.writeln('${indent}  $line');
    }
    out.writeln('$indent),');
  }
  if (child.items.isEmpty) {
    out.writeln('$indent$wrapper(flex: $flex, child: SizedBox.shrink()),');
  }
}

/// Writes item constructor expressions (with tap comments) at [indent].
///
/// Items whose tap action targets a known screen are wrapped in the
/// bundle-equivalent `GestureDetector` navigation (see [_wrapTapExpr]);
/// unknown targets (and action-less items) render the bare expression — the
/// `// taps -> ...` comment above is always kept, never a crash.
void _writeItemBlock(
  StringBuffer out,
  ScreenDoc doc,
  List<CanvasItem> items,
  String indent,
) {
  for (final unit in _ownItemUnits(doc, items)) {
    for (final line in unit.split('\n')) {
      out.writeln('$indent$line');
    }
  }
}

/// Writes a non-row node WITH children ([kids] is non-empty; [node.id] is
/// already in [visited]): a single-item container node splices the children
/// into its §2 slot ([_writeContainerNode]); anything else (multi-item,
/// leaf-kind, empty, or unknown-kind nodes) stacks the children BELOW the
/// node's own widget ([_writeLeafFallback], COMPOSITION.md §1).
void _writeNonRowCore(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode node,
  List<CanvasNode> kids,
  String indent,
  Set<String> visited,
) {
  if (node.items.length == 1 &&
      _kContainerKinds.contains(node.items.single.kind)) {
    _writeContainerNode(out, doc, node.items.single, kids, indent, visited);
    return;
  }
  _writeLeafFallback(out, doc, node, kids, indent, visited);
}

/// Writes a container node: its item expression with recursively emitted
/// children spliced into the §2 slot (see [_spliceSlotChildren]). The whole
/// expression — chrome plus spliced children — keeps the item's tap comment
/// and `GestureDetector` navigation (tap wraps apply per item at every
/// level, COMPOSITION.md §5).
void _writeContainerNode(
  StringBuffer out,
  ScreenDoc doc,
  CanvasItem item,
  List<CanvasNode> kids,
  String indent,
  Set<String> visited,
) {
  final taps = _tapTargets(doc);
  final comment = _tapCommentLine(item);
  if (comment != null) {
    out.writeln('$indent$comment');
  }
  var expr = _itemExpression(item, _childUnits(doc, kids, visited));
  expr = _tapWrapStatement(expr, item, taps) ?? expr;
  for (final line in expr.split('\n')) {
    out.writeln('$indent$line');
  }
}

/// Writes the leaf fallback for a node WITH children: `Column([own, ...])`
/// — the node's own item expressions first, then one subtree per child node
/// below them, all joined with `kFlowScreenGap` separators (COMPOSITION.md
/// §§1/5). Each level keeps its own tap comments/wraps and responsive
/// wrappers (see [_childUnits]).
void _writeLeafFallback(
  StringBuffer out,
  ScreenDoc doc,
  CanvasNode node,
  List<CanvasNode> kids,
  String indent,
  Set<String> visited,
) {
  final units = [
    ..._ownItemUnits(doc, node.items),
    ..._childUnits(doc, kids, visited),
  ];
  if (units.isEmpty) {
    out.writeln('${indent}SizedBox.shrink(),');
    return;
  }
  final childIndent = '$indent    ';
  final gap = '$childIndent'
      'const SizedBox(height: ${_flowNum(kFlowScreenGap)}),';
  out
    ..writeln('${indent}Column(')
    ..writeln('${indent}  mainAxisSize: MainAxisSize.min,')
    ..writeln('${indent}  crossAxisAlignment: CrossAxisAlignment.start,')
    ..writeln('${indent}  children: [');
  var first = true;
  for (final unit in units) {
    if (!first) out.writeln(gap);
    first = false;
    for (final line in unit.split('\n')) {
      if (line.isEmpty) continue;
      out.writeln('$childIndent$line');
    }
  }
  out
    ..writeln('$indent  ],')
    ..writeln('$indent),');
}

/// Tap-action navigation targets for [doc]: screen id → route plus the id
/// set, mirroring `codegen_bundle.dart` (`_routeOf`/`routes`/`ids` there).
/// A `to` that matches no screen id is unknown: comment-only, never a crash.
class _TapTargets {
  final Map<String, String> routes;
  final Set<String> ids;

  const _TapTargets(this.routes, this.ids);

  /// Route for [item]'s tap action, or null when action-less or unknown.
  String? routeFor(CanvasItem item) {
    final to = item.action?.to;
    if (to == null) return null;
    return ids.contains(to) ? routes[to] : null;
  }
}

/// Builds the tap targets for [doc] (cheap: two small collections over the
/// screen list; callers derive once per emission block).
_TapTargets _tapTargets(ScreenDoc doc) => _TapTargets(
      {for (final s in doc.screens) s.id: _tapRouteOf(s.name)},
      {for (final s in doc.screens) s.id},
    );

/// Route slug for a screen name — the same mapping the bundle exporter uses
/// for `pushNamed`, so single-file taps navigate to the bundle's routes.
String _tapRouteOf(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-\$'), '');
  return '/${slug.isEmpty ? 'screen' : slug}';
}

/// Wraps item expression [expr] (an unindented [_itemExpression] with
/// trailing comma) in the bundle-equivalent tap navigation: a
/// `GestureDetector` pushing the route by name. The transition rides along
/// as a comment — `pushNamed` carries none. Returns the wrapped expression
/// with NO trailing comma (mirrors [_nodeContentExpr]); statement contexts
/// add their own comma.
String _wrapTapExpr(String expr, NodeAction action, String route) {  final lines = _stripTrailingComma(expr).split('\n');
  // Restore the inner trailing comma (statement style is comma-terminated,
  // whatever the input had); the outer close below stays comma-free for
  // expression contexts, statement callers add their own comma.
  lines[lines.length - 1] = '${lines.last},';
  final buf = StringBuffer()
    ..writeln('GestureDetector(')
    ..writeln(
      "  onTap: () => Navigator.of(context).pushNamed('$route'), "
      '// transition: ${action.transition}',
    )
    ..writeln('  child: ${lines.first}');
  for (final line in lines.skip(1)) {
    buf.writeln('  $line');
  }
  buf.write(')');
  return buf.toString();
}

/// Track R1 per-emission state tables (set by [buildSingleFile]; empty for
/// legacy docs so [_str] and the tap helpers behave exactly as before).
///
/// [_stateFields] maps var name → state field (`count` → `_count`);
/// [_stateVars] maps var name → its declaration (types/defaults).
Map<String, String> _stateFields = const {};
Map<String, AppStateVar> _stateVars = const {};

/// Whether [doc] uses app state at all (vars declared or steps present).
bool _hasAppState(ScreenDoc doc) {
  if (doc.states.isNotEmpty) return true;
  for (final node in doc.nodes) {
    for (final item in node.items) {
      if (item.action != null && item.action!.steps.isNotEmpty) return true;
    }
  }
  return false;
}

/// Whether [screen] emits stateful: the doc declares vars (app-wide state
/// lives on every screen) or one of its items carries action steps (the
/// tap methods need a `State`). All other screens keep the historical
/// stateless output byte-identically.
bool _screenIsStateful(ScreenDoc doc, CanvasScreen screen) {
  if (doc.states.isNotEmpty) return true;
  for (final node in doc.nodes) {
    if (node.screenId != screen.id) continue;
    for (final item in node.items) {
      if (item.action != null && item.action!.steps.isNotEmpty) return true;
    }
  }
  return false;
}

/// Whether any step in [doc] needs material-only APIs (see
/// [stepsNeedMaterial]): those docs import material instead of widgets.
bool _docNeedsMaterialSteps(ScreenDoc doc) {
  for (final node in doc.nodes) {
    for (final item in node.items) {
      final steps = item.action?.steps;
      if (steps != null &&
          steps.isNotEmpty &&
          stepsNeedMaterial(steps)) {
        return true;
      }
    }
  }
  return false;
}

/// Whether any step in [doc] is an `apiCall` (see [stepsNeedHttp]): those
/// docs gain the `package:http` import, an `http` pubspec dep, and `async`
/// tap methods.
bool _docNeedsHttp(ScreenDoc doc) {
  for (final node in doc.nodes) {
    for (final item in node.items) {
      final steps = item.action?.steps;
      if (steps != null && steps.isNotEmpty && stepsNeedHttp(steps)) {
        return true;
      }
    }
  }
  return false;
}

/// Comment line for [item]'s tap behavior, or null when action-less:
/// the legacy `// taps -> <to>` or the R1 `// steps (N): ...` summary.
/// Shared by every emission site so comments stay consistent.
String? _tapCommentLine(CanvasItem item) {
  final action = item.action;
  if (action == null) return null;
  if (action.steps.isNotEmpty) {
    final summary = action.steps.map(stepSummary).join(', ');
    return '// steps (${action.steps.length}): $summary';
  }
  return '// taps -> ${action.to}';
}

/// Wraps [expr] (an unindented [_itemExpression] WITH trailing comma) per
/// [item]'s tap semantics, or null when no wrap applies: legacy known-target
/// actions use the bundle-equivalent navigation ([_wrapTapExpr]); R1 step
/// flows call their generated method ([_wrapMethodTapExpr]). Unknown legacy
/// targets and action-less items render the bare expression.
String? _tapWrapStatement(
  String expr,
  CanvasItem item,
  _TapTargets taps,
) {
  final action = item.action;
  if (action == null) return null;
  if (action.steps.isNotEmpty) {
    return '${_wrapMethodTapExpr(expr, item)},';
  }
  final route = taps.routeFor(item);
  if (route == null) return null;
  return '${_wrapTapExpr(expr, action, route)},';
}

/// Wraps [expr] (an unindented [_itemExpression] with trailing comma) in a
/// `GestureDetector` calling the item's generated action method (see
/// [_writeActionMethods]). Mirrors [_wrapTapExpr]'s comma contract: returns
/// the wrapped expression with NO trailing comma.
String _wrapMethodTapExpr(String expr, CanvasItem item) {
  final method = methodNameFor('_onTap', item.id);
  final lines = _stripTrailingComma(expr).split('\n');
  lines[lines.length - 1] = '${lines.last},';
  final buf = StringBuffer()
    ..writeln('GestureDetector(')
    ..writeln('  onTap: () => $method(context),')
    ..writeln('  child: ${lines.first}');
  for (final line in lines.skip(1)) {
    buf.writeln('  $line');
  }
  buf.write(')');
  return buf.toString();
}

/// Writes a stateful screen: the same flow body as the stateless path, but
/// as a `StatefulWidget` holding one field per state var plus one tap
/// method per stepped item on this screen (see [_writeActionMethods]).
void _writeStatefulScreen(
  StringBuffer out,
  ScreenDoc doc,
  CanvasScreen screen,
  _TapTargets taps,
) {
  final cls = _classNameFor(screen.name);
  out
    ..writeln()
    ..writeln('class $cls extends StatefulWidget {')
    ..writeln('  const $cls({super.key});')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  State<$cls> createState() => _${cls}State();')
    ..writeln('}')
    ..writeln()
    ..writeln('class _${cls}State extends State<$cls> {');
  for (final v in doc.states) {
    out.writeln('  ${stateFieldDecl(v)}');
  }
  _writeActionMethods(out, doc, screen, taps);
  out
    ..writeln('  @override')
    ..writeln('  Widget build(BuildContext context) {')
    // Same flow root as the stateless path (padding/column/gap literals
    // track kFlowScreenGap/kFlowScreenPadding there too).
    ..writeln('    return Padding(')
    ..writeln(
        '      padding: const EdgeInsets.all(${_flowNum(kFlowScreenPadding)}),')
    ..writeln('      child: Column(')
    ..writeln('        crossAxisAlignment: CrossAxisAlignment.start,')
    ..writeln('        children: [');
  final roots = _rootNodes(doc, screen.id);
  if (roots.isEmpty) {
    out.writeln('          // (empty screen)');
  }
  var first = true;
  for (final root in roots) {
    if (!first) {
      out.writeln(
          '          const SizedBox(height: ${_flowNum(kFlowScreenGap)}),');
    }
    first = false;
    _writeFlowChild(out, doc, root, '          ', <String>{});
  }
  out
    ..writeln('        ],')
    ..writeln('      ),')
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}');
}

/// Writes one tap method per stepped item on [screen] (doc order; method
/// names derive from item ids, unique doc-wide). Bodies come from
/// [emitStepStatements] with routes resolved against [taps] (unknown targets
/// become comments, never a crash). Methods with an `apiCall` step are
/// `Future<void> ... async` (they `await` `package:http`); all others keep
/// the historical `void` signature byte-identically.
void _writeActionMethods(
  StringBuffer out,
  ScreenDoc doc,
  CanvasScreen screen,
  _TapTargets taps,
) {
  final seen = <String>{};
  for (final node in doc.nodes) {
    if (node.screenId != screen.id) continue;
    for (final item in node.items) {
      final steps = item.action?.steps;
      if (steps == null || steps.isEmpty) continue;
      final name = methodNameFor('_onTap', item.id);
      if (!seen.add(name)) continue;
      final async = stepsNeedHttp(steps);
      out.writeln();
      out.writeln(
        async
            ? '  Future<void> $name(BuildContext context) async {'
            : '  void $name(BuildContext context) {',
      );
      for (final line in emitStepStatements(
        steps: steps,
        vars: _stateVars,
        fields: _stateFields,
        routeOf: (to) => taps.ids.contains(to) ? taps.routes[to] : null,
      )) {
        out.writeln('  $line');
      }
      out.writeln('  }');
    }
  }
}

/// Flow number literal: whole values print without `.0` to match the
/// existing generated style (`EdgeInsets.all(16)`, `SizedBox(height: 12)`).
String _flowNum(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

/// Used kinds in first-seen order.
List<String> _usedKinds(ScreenDoc doc) {
  final kinds = <String>[];
  for (final node in doc.nodes) {
    for (final item in node.items) {
      if (!kinds.contains(item.kind)) kinds.add(item.kind);
    }
  }
  return kinds;
}

/// Component id for a registry destination, or null when the path has no
/// component-id shape.
///
/// Real destinations look like `{installPath}/components/<category>/<id>/…`
/// (the id is the segment after the category); test stubs look like
/// `registry/components/<id>/<file>` (no category level). Category names
/// (`control`, `form`, `overlay`, …) are NOT ids: a palette kind like
/// `control` must not inline every control-category body. The previous
/// substring `contains('/$kind/')` match did exactly that (a `control` node
/// re-inlined all 63 button files, duplicating every class), and `form` /
/// `overlay` likewise duplicated the whole form/overlay categories.
String? _idOfDest(String dest) {
  final parts = dest.split('/');
  final ci = parts.indexOf('components');
  if (ci < 0) return null;
  final rest = parts.sublist(ci + 1);
  if (rest.isEmpty) return null;
  // Real destinations carry a category level (3+ tail segments):
  // components/<category>/<id>/… → the id is second.
  if (rest.length >= 3) return rest[1];
  // Short tails (test stubs): components/<id>/<file> → the id is first.
  return rest[0];
}

/// Kind → pubspec deps table, mirroring the bundle exporter's per-kind
/// `pubspec.dependencies` (gap-first ordering matches the pre-existing
/// button/card/input rows, so established goldens keep byte-identical pubspec
/// comments). Entries beyond the original 20 snapshot the bundle `_kinds`
/// table verbatim; kinds with no deps (`validated`, `triple_dots`) are absent
/// (same as having none).
const Map<String, List<String>> _kKindDeps = {
  'button': ['gap', 'data_widget'],
  'card': ['gap', 'data_widget'],
  'input': ['gap', 'data_widget'],
  'badge': ['gap'],
  'switch': ['gap', 'data_widget'],
  'avatar': ['gap'],
  'checkbox': ['gap', 'data_widget', 'animation_kit'],
  'divider': ['gap', 'data_widget'],
  'progress': ['gap'],
  'tabs': ['gap', 'data_widget'],
  'accordion': ['gap', 'data_widget'],
  'select': ['gap', 'data_widget'],
  'radio_group': ['gap', 'data_widget'],
  'skeleton': ['gap', 'skeletonizer'],
  'breadcrumb': ['gap', 'data_widget'],
  'dialog': ['gap', 'data_widget'],
  'tooltip': ['gap', 'data_widget'],
  'toast': ['gap'],
  'drawer': ['gap', 'data_widget'],
  'form': ['gap', 'data_widget', 'email_validator'],
  'basic': ['gap', 'data_widget'],
  'card_image': ['gap'],
  'scaffold': ['gap', 'data_widget'],
  'collapsible': ['gap', 'data_widget'],
  'steps': ['gap', 'data_widget'],
  'timeline': ['gap', 'data_widget'],
  'outlined_container': ['gap'],
  'hidden': ['gap'],
  'keyboard_shortcut': ['gap', 'data_widget'],
  'tracker': ['gap', 'data_widget'],
  'chat': ['gap', 'data_widget'],
  'selectable': ['gap'],
  'star_rating': ['gap', 'data_widget'],
  'clickable': ['gap', 'data_widget'],
  'scrollbar': ['gap'],
  'pagination': ['gap'],
  'alert_dialog': ['gap', 'data_widget'],
  'menu': ['gap', 'data_widget'],
  'popover': ['gap', 'data_widget'],
  'popup': ['gap', 'data_widget'],
  'menubar': ['gap', 'data_widget'],
  'dropdown_menu': ['gap', 'data_widget'],
  'context_menu': ['gap', 'data_widget'],
  'hover_card': ['gap', 'data_widget'],
  'command': ['gap', 'data_widget'],
  'swiper': ['gap'],
  'refresh_trigger': ['gap', 'data_widget'],
  'tab_container': ['gap', 'data_widget'],
  'tab_list': ['gap'],
  'tab_pane': ['gap', 'data_widget'],
  'stepper': ['gap', 'data_widget'],
  'slider': ['gap', 'data_widget'],
  'input_otp': ['gap', 'data_widget'],
  'calendar': ['gap', 'data_widget'],
  'date_picker': ['gap'],
  'time_picker': ['gap', 'data_widget'],
  'carousel': ['gap'],
  'tree': ['gap', 'data_widget'],
  'table': ['gap', 'data_widget'],
  'form_field': ['gap', 'data_widget'],
  'formatted_input': ['gap', 'data_widget'],
  'color_picker': ['gap', 'data_widget'],
  'color_input': ['gap', 'data_widget'],
  'hsl': ['gap'],
  'hsv': ['gap'],
  'history': ['gap', 'data_widget'],
  'feature_carousel': ['gap'],
  'alert': ['gap'],
  'chip': ['gap'],
  'circular_progress_indicator': ['gap'],
  'linear_progress_indicator': ['gap', 'data_widget'],
  'dot_indicator': ['gap', 'data_widget'],
  'empty_state': ['gap'],
  'code_snippet': ['gap', 'data_widget'],
  'number_ticker': ['gap', 'intl'],
  'text_area': ['gap'],
};

/// Merged deps for [kinds], deduped, first-seen order. When [doc] carries an
/// `apiCall` step, `http` is appended (step-driven, not kind-driven — the
/// per-kind table above has no apiCall row, so the dep rides this same
/// mechanism explicitly; legacy docs never contain it).
List<String> _mergedDeps(List<String> kinds, [ScreenDoc? doc]) {
  final deps = <String>[];
  for (final kind in kinds) {
    for (final dep in _kKindDeps[kind] ?? const <String>[]) {
      if (!deps.contains(dep)) deps.add(dep);
    }
  }
  if (doc != null && _docNeedsHttp(doc) && !deps.contains('http')) {
    deps.add('http');
  }
  return deps;
}

/// `Pay` → `CanvasScreen_Pay`; always a valid identifier.
String _classNameFor(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  final safe = cleaned.isEmpty ? 'Screen' : cleaned;
  final prefixed = RegExp(r'^[0-9]').hasMatch(safe) ? 'S_$safe' : safe;
  return 'CanvasScreen_${prefixed[0].toUpperCase()}${prefixed.substring(1)}';
}

/// Dart single-quoted string literal for [value]; never crashes on input.
///
/// Track R1: a `=var` binding to a known state var emits a field
/// interpolation (`'${_count}'`, always String-typed) instead of the quoted
/// literal — text props read live state. Unknown vars (and legacy docs,
/// whose [_stateFields] is empty) keep the historical quoted literal,
/// exactly like preview's raw fallback.
String _str(Object? value) {
  if (value is String) {
    final name = bindingNameOf(value);
    if (name != null && _stateFields.containsKey(name)) {
      return boundTextExpr(_stateFields[name]!);
    }
  }
  final escaped = '$value'
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
  return "'$escaped'";
}

bool _bool(Map<String, dynamic> props, String key) =>
    props[key] == true;

/// Coerces a canvas prop to double. Catalog builders cast `as num?` (missing
/// keys fall back); codegen must never crash on hand-written docs, so strings
/// try-parse and anything else falls back.
double _num(Map<String, dynamic> props, String key, double fallback) {
  final v = props[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// Coerces a canvas prop to int (same crash-free policy as [_num]).
int _int(Map<String, dynamic> props, String key, int fallback) {
  final v = props[key];
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// Canvas string prop with a fallback (non-strings fall back instead of
/// throwing, unlike the catalog's `as String` casts).
String _prop(Map<String, dynamic> props, String key, String fallback) {
  final v = props[key];
  return v is String ? v : fallback;
}

/// Bool prop defaulting to true when absent (mirrors the catalog's
/// `(props[x] ?? true)` props: `showLeading`, `showTrailing`, `showActions`,
/// `enabled` on skeleton).
bool _boolT(Map<String, dynamic> props, String key) =>
    props[key] == null || props[key] == true;

/// Nullable text slot expression: empty canvas strings collapse to `null`
/// (mirrors the catalog's `_textOrNull`).
String _slotText(Map<String, dynamic> props, String key, String fallback) {
  final v = _prop(props, key, fallback);
  return v.isEmpty ? 'null' : 'Text(${_str(v)})';
}

/// Parses a canvas hex color (`'#2196F3'`, `'2196F3'`, `'80FFFFFF'`,
/// 3-digit shorthand) into an 8-digit ARGB hex string for `Color(0x…)`
/// literals, mirroring the catalog's `_parseHexColor` (same default blue,
/// so default rendering matches the canvas).
String _hexArgb(String raw) {
  var hex = raw.trim().replaceAll('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  if (value == null || hex.length != 8) return 'FF2196F3';
  return hex.toUpperCase();
}

/// Maps one shortcut token to its `LogicalKeyboardKey` expression, or null
/// when unknown (mirrors the catalog's `_shortcutToken`).
String? _shortcutKeyName(String token) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty) return null;
  switch (t) {
    case 'ctrl':
    case 'control':
      return 'LogicalKeyboardKey.controlLeft';
    case 'shift':
      return 'LogicalKeyboardKey.shiftLeft';
    case 'alt':
    case 'option':
      return 'LogicalKeyboardKey.altLeft';
    case 'meta':
    case 'cmd':
    case 'command':
    case 'win':
      return 'LogicalKeyboardKey.metaLeft';
    case 'enter':
    case 'return':
      return 'LogicalKeyboardKey.enter';
    case 'space':
      return 'LogicalKeyboardKey.space';
    case 'tab':
      return 'LogicalKeyboardKey.tab';
    case 'esc':
    case 'escape':
      return 'LogicalKeyboardKey.escape';
    case 'backspace':
      return 'LogicalKeyboardKey.backspace';
    case 'delete':
    case 'del':
      return 'LogicalKeyboardKey.delete';
  }
  if (t.length == 1) {
    final c = t.codeUnitAt(0);
    if ((c >= 97 && c <= 122) || (c >= 48 && c <= 57)) {
      return 'LogicalKeyboardKey($c)';
    }
  }
  return null;
}

/// Parses a canvas shortcut string (`'Ctrl+K'`) into `LogicalKeyboardKey`
/// expressions (mirrors the catalog's `_parseShortcutKeys`, including the
/// `keyK` fallback for fully-unknown input).
List<String> _shortcutKeys(String raw) {
  final names = <String>[];
  for (final token in raw.split(RegExp(r'[+\s]+'))) {
    final name = _shortcutKeyName(token);
    if (name != null) names.add(name);
  }
  return names.isEmpty ? ['LogicalKeyboardKey.keyK'] : names;
}

/// Stateful helper emitted when the doc uses `stepper`: the kit `Stepper`
/// requires a lifecycle-owned `StepperController` (mirroring the catalog's
/// `_StepperCell`), so static emission cannot construct it. Steps/details
/// ride constructor params, so one shared class serves every stepper node.
const _kStepperHelper = '''
class CanvasStepperCell extends StatefulWidget {
  final int initialStep;
  final List<String> steps;
  final List<String> details;

  const CanvasStepperCell({
    super.key,
    required this.initialStep,
    required this.steps,
    required this.details,
  });

  @override
  State<CanvasStepperCell> createState() => _CanvasStepperCellState();
}

class _CanvasStepperCellState extends State<CanvasStepperCell> {
  late final StepperController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StepperController(currentStep: widget.initialStep);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stepper(
      controller: _controller,
      direction: Axis.vertical,
      steps: [
        for (var i = 0; i < widget.steps.length; i++)
          Step(
            title: Flexible(
              child: Text(
                widget.steps[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            contentBuilder: (_) => Text(widget.details[i]),
          ),
      ],
    );
  }
}
''';

/// Track C3 container composers (COMPOSITION.md §2): each takes the item
/// props plus recursively emitted child units ([nested], see
/// [_spliceSlotChildren]) and splices them into the kind's documented child
/// slot. Empty [nested] reproduces the historical childless emission
/// byte-identically.
///
/// Two deliberate slot readings (spec-literal, reported in the C3 notes):
/// * `outlined_container`/`hidden`/`clickable`: the spec names `child` as
///   `Column([label, ...children])`; the historical emission wraps the label
///   in its chrome (`Padding`/`Hidden`/`Clickable`), so children splice into
///   a `Column` placed INSIDE that chrome — childless output unchanged.
/// * `alert_dialog`/`scrollbar`: the historical emission has no `Column`
///   (`content:`/`SizedBox` directly hold the label), so children splice into
///   a `Column` that keeps the label first — childless output unchanged.
String _cardExpr(Map<String, dynamic> props, List<String> nested) {
  final footer = _bool(props, 'showFooter')
      ? '    const SizedBox(height: 12),\n'
          '    PrimaryButton(\n'
          "      size: ButtonSize.small,\n"
          '      onPressed: () {},\n'
          "      child: Text('Action'),\n"
          '    ),\n'
      : '';
  // Slot: inner Column after description, before the footer action.
  final slot =
      nested.isEmpty ? '' : _spliceSlotChildren(nested, '      ');
  return 'Card(\n'
      '  padding: const EdgeInsets.all(16),\n'
      '  child: Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    crossAxisAlignment: CrossAxisAlignment.start,\n'
      '    children: [\n'
      '      Text(${_str(props['title'] ?? 'Card Title')}),\n'
      '      const SizedBox(height: 4),\n'
      '      Text(${_str(props['description'] ?? 'Card description')}),\n'
      '$slot$footer'
      '    ],\n'
      '  ),\n'
      '),';
}

String _outlinedContainerExpr(
  Map<String, dynamic> props,
  List<String> nested,
) {
  final label = 'Text(${_str(_prop(props, 'label', 'Outlined'))})';
  if (nested.isEmpty) {
    return 'OutlinedContainer(\n'
        '  child: Padding(\n'
        '    padding: const EdgeInsets.all(12),\n'
        '    child: $label,\n'
        '  ),\n'
        '),';
  }
  // Slot: OutlinedContainer.child (Column([label, ...children])), kept inside
  // the historical Padding chrome.
  return 'OutlinedContainer(\n'
      '  child: Padding(\n'
      '    padding: const EdgeInsets.all(12),\n'
      '    child: Column(\n'
      '      mainAxisSize: MainAxisSize.min,\n'
      '      crossAxisAlignment: CrossAxisAlignment.start,\n'
      '      children: [\n'
      '        $label,\n'
      '${_spliceSlotChildren(nested, '        ')}'
      '      ],\n'
      '    ),\n'
      '  ),\n'
      '),';
}

String _scaffoldExpr(Map<String, dynamic> props, List<String> nested) {
  final body = 'Text(${_str(_prop(props, 'body', 'Welcome'))})';
  final padded = nested.isEmpty
      ? '    child: Padding(\n'
          '      padding: const EdgeInsets.all(16),\n'
          '      child: $body,\n'
          '    ),\n'
      // Slot: body Padding column under the body text.
      : '    child: Padding(\n'
          '      padding: const EdgeInsets.all(16),\n'
          '      child: Column(\n'
          '        mainAxisSize: MainAxisSize.min,\n'
          '        crossAxisAlignment: CrossAxisAlignment.start,\n'
          '        children: [\n'
          '          $body,\n'
          '${_spliceSlotChildren(nested, '          ')}'
          '        ],\n'
          '      ),\n'
          '    ),\n';
  return 'SizedBox(\n'
      '  height: 320,\n'
      '  child: Scaffold(\n'
      '    headers: [AppBar(title: Text(${_str(_prop(props, 'title', 'My App'))}))],\n'
      '$padded'
      '  ),\n'
      '),';
}

String _dialogExpr(Map<String, dynamic> props, List<String> nested) {
  final dActions = _boolT(props, 'showActions')
      ? '      const SizedBox(height: 20),\n'
          '      Row(\n'
          '        children: [\n'
          '          const Spacer(),\n'
          '          OutlineButton(\n'
          '            onPressed: () {},\n'
          "            child: const Text('Close'),\n"
          '          ),\n'
          '        ],\n'
          '      ),\n'
      : '';
  // Slot: ModalContainer column after message, before the action row.
  final slot =
      nested.isEmpty ? '' : _spliceSlotChildren(nested, '      ');
  return 'ModalContainer(\n'
      '  filled: true,\n'
      '  padding: const EdgeInsets.all(24),\n'
      '  child: Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    crossAxisAlignment: CrossAxisAlignment.start,\n'
      '    children: [\n'
      '      Text(${_str(_prop(props, 'title', 'Dialog title'))}),\n'
      '      const SizedBox(height: 12),\n'
      '      Text(${_str(_prop(props, 'message', 'Use dialogs for important confirmations.'))}),\n'
      '$slot$dActions'
      '    ],\n'
      '  ),\n'
      '),';
}

String _alertDialogExpr(Map<String, dynamic> props, List<String> nested) {
  final adActions = _boolT(props, 'showActions')
      ? "    OutlineButton(onPressed: () {}, child: const Text('Close')),\n"
      : '';
  final content = nested.isEmpty
      ? '  content: Text(${_str(_prop(props, 'message', 'This action cannot be undone.'))}),\n'
      // Slot: content area after message, before actions.
      : '  content: Column(\n'
          '    mainAxisSize: MainAxisSize.min,\n'
          '    crossAxisAlignment: CrossAxisAlignment.start,\n'
          '    children: [\n'
          '      Text(${_str(_prop(props, 'message', 'This action cannot be undone.'))}),\n'
          '${_spliceSlotChildren(nested, '      ')}'
          '    ],\n'
          '  ),\n';
  return 'AlertDialog(\n'
      '  title: Text(${_str(_prop(props, 'title', 'Are you sure?'))}),\n'
      '$content'
      '  actions: [\n'
      '$adActions'
      '  ],\n'
      '),';
}

String _drawerExpr(Map<String, dynamic> props, List<String> nested) {
  final drawerPos = switch (props['position']) {
    'left' => 'OverlayPosition.left',
    'right' => 'OverlayPosition.right',
    'top' => 'OverlayPosition.top',
    'bottom' => 'OverlayPosition.bottom',
    'start' => 'OverlayPosition.start',
    _ => 'OverlayPosition.end',
  };
  // Slot: panel column after the content text.
  final slot =
      nested.isEmpty ? '' : _spliceSlotChildren(nested, '        ');
  return 'DrawerWrapper(\n'
      '  position: $drawerPos,\n'
      '  size: const Size(240, 480),\n'
      '  stackIndex: 0,\n'
      '  draggable: false,\n'
      '  showDragHandle: false,\n'
      '  child: SizedBox(\n'
      '    width: 240,\n'
      '    child: Column(\n'
      '      mainAxisSize: MainAxisSize.min,\n'
      '      crossAxisAlignment: CrossAxisAlignment.start,\n'
      '      children: [\n'
      '        Text(${_str(_prop(props, 'title', 'Drawer'))}),\n'
      '        const SizedBox(height: 16),\n'
      '        Text(${_str(_prop(props, 'content', 'Drawer content'))}),\n'
      '$slot'
      '      ],\n'
      '    ),\n'
      '  ),\n'
      '),';
}

String _formExpr(Map<String, dynamic> props, List<String> nested) {
  // Slot: inner Column after the field layout, before submit.
  final slot = nested.isEmpty ? '' : _spliceSlotChildren(nested, '      ');
  return 'Form(\n'
      '  child: Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    children: [\n'
      '      FormTableLayout(\n'
      '        rows: [\n'
      '          FormField<String>(\n'
      '            key: const FormKey<String>(#name),\n'
      '            label: Text(${_str(_prop(props, 'label', 'Name'))}),\n'
      '            child: TextField(placeholder: Text(${_str(_prop(props, 'placeholder', 'Jane Doe'))})),\n'
      '          ),\n'
      '        ],\n'
      '      ),\n'
      '$slot'
      '      const SizedBox(height: 16),\n'
      '      PrimaryButton(\n'
      '        onPressed: () {},\n'
      '        child: Text(${_str(_prop(props, 'submitLabel', 'Submit'))}),\n'
      '      ),\n'
      '    ],\n'
      '  ),\n'
      '),';
}

String _hiddenExpr(Map<String, dynamic> props, List<String> nested) {
  final label = 'Text(${_str(_prop(props, 'label', 'Hidden content'))})';
  if (nested.isEmpty) {
    return 'Hidden(hidden: ${_bool(props, 'hidden')}, child: $label),';
  }
  // Slot: Hidden.child (Column([label, ...children])).
  return 'Hidden(\n'
      '  hidden: ${_bool(props, 'hidden')},\n'
      '  child: Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    crossAxisAlignment: CrossAxisAlignment.start,\n'
      '    children: [\n'
      '      $label,\n'
      '${_spliceSlotChildren(nested, '      ')}'
      '    ],\n'
      '  ),\n'
      '),';
}

String _clickableExpr(Map<String, dynamic> props, List<String> nested) {
  final label = 'Text(${_str(_prop(props, 'label', 'Tap me'))})';
  if (nested.isEmpty) {
    return 'Clickable(onPressed: () {}, child: $label),';
  }
  // Slot: Clickable.child (Column([label, ...children])).
  return 'Clickable(\n'
      '  onPressed: () {},\n'
      '  child: Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    crossAxisAlignment: CrossAxisAlignment.start,\n'
      '    children: [\n'
      '      $label,\n'
      '${_spliceSlotChildren(nested, '      ')}'
      '    ],\n'
      '  ),\n'
      '),';
}

String _scrollbarExpr(Map<String, dynamic> props, List<String> nested) {
  final label = 'Text(${_str(_prop(props, 'label', 'Scrollable content'))})';
  if (nested.isEmpty) {
    return 'Scrollbar(child: SizedBox(height: 64, child: $label)),';
  }
  // Slot: box column under the label.
  return 'Scrollbar(\n'
      '  child: SizedBox(\n'
      '    height: 64,\n'
      '    child: Column(\n'
      '      mainAxisSize: MainAxisSize.min,\n'
      '      crossAxisAlignment: CrossAxisAlignment.start,\n'
      '      children: [\n'
      '        $label,\n'
      '${_spliceSlotChildren(nested, '        ')}'
      '      ],\n'
      '    ),\n'
      '  ),\n'
      '),';
}

String _chatExpr(Map<String, dynamic> props, List<String> nested) {
  final message = 'Text(${_str(_prop(props, 'message', 'Hello!'))})';
  if (nested.isEmpty) {
    return 'ChatBubble(child: $message),';
  }
  // Slot: ChatBubble.child (Column([message, ...children])).
  return 'ChatBubble(\n'
      '  child: Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    crossAxisAlignment: CrossAxisAlignment.start,\n'
      '    children: [\n'
      '      $message,\n'
      '${_spliceSlotChildren(nested, '      ')}'
      '    ],\n'
      '  ),\n'
      '),';
}

String _toastExpr(Map<String, dynamic> props, List<String> nested) {
  // Slot: message Column after the message, before the close (card pattern).
  // Childless form keeps the historical Column chrome byte-identically (the
  // catalog/bundle Row+Icon shell is a deliberate non-mirror here — see the
  // C3 notes above).
  final slot = nested.isEmpty ? '' : _spliceSlotChildren(nested, '      ');
  return 'ToastEntry(\n'
      '  duration: const Duration(seconds: 3),\n'
      '  animationDuration: const Duration(milliseconds: 200),\n'
      '  animationCurve: Curves.easeOut,\n'
      '  onDismissed: () {},\n'
      '  autoDismiss: ${_bool(props, 'autoDismiss')},\n'
      '  child: Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    crossAxisAlignment: CrossAxisAlignment.start,\n'
      '    children: [\n'
      '      Text(${_str(_prop(props, 'title', 'Saved'))}),\n'
      '      Text(${_str(_prop(props, 'message', 'Saved successfully'))}),\n'
      '$slot'
      '    ],\n'
      '  ),\n'
      '),';
}

String _validatedExpr(Map<String, dynamic> props, List<String> nested) {
  // Slot: builder Column after the field, before the error gap.
  final slot = nested.isEmpty ? '' : _spliceSlotChildren(nested, '      ');
  return 'Validated<String>(\n'
      '  validator: ValidatorBuilder<String>((value) {\n'
      '    if (value == null || value.isEmpty) {\n'
      '      return InvalidResult(${_str(_prop(props, 'errorText', 'Required'))}, state: FormValidationMode.initial);\n'
      '    }\n'
      '    return null;\n'
      '  }),\n'
      '  builder: (context, error, child) => Column(\n'
      '    mainAxisSize: MainAxisSize.min,\n'
      '    crossAxisAlignment: CrossAxisAlignment.start,\n'
      '    children: [\n'
      '      child!,\n'
      '$slot'
      '      const SizedBox(height: 6),\n'
      '      Text(error is InvalidResult ? error.message : ${_str(_prop(props, 'errorText', 'Required'))}),\n'
      '    ],\n'
      '  ),\n'
      '  child: TextField(placeholder: Text(${_str(_prop(props, 'placeholder', 'Name'))})),\n'
      '),';
}

String _refreshTriggerExpr(Map<String, dynamic> props, List<String> nested) {
  // Slot: ListView children after the prop rows.
  final slot = nested.isEmpty ? '' : _spliceSlotChildren(nested, '        ');
  return 'RefreshTrigger(\n'
      '  onRefresh: () async {},\n'
      '  child: SizedBox(\n'
      '    height: 140,\n'
      '    child: ListView(\n'
      '      children: [\n'
      '        Padding(padding: const EdgeInsets.all(12), child: Text(${_str(_prop(props, 'item1', 'Row 1'))})),\n'
      '        Padding(padding: const EdgeInsets.all(12), child: Text(${_str(_prop(props, 'item2', 'Row 2'))})),\n'
      '        Padding(padding: const EdgeInsets.all(12), child: Text(${_str(_prop(props, 'item3', 'Row 3'))})),\n'
      '$slot'
      '      ],\n'
      '    ),\n'
      '  ),\n'
      '),';
}

/// Catalog-equivalent constructor call as text, mirroring
/// `component_catalog.dart` prop→parameter mapping.
///
/// Track C3: container kinds (see [_kContainerKinds]) accept recursively
/// emitted child units in [nested] (unindented statement strings from
/// [_childUnits]), spliced into their COMPOSITION.md §2 slot. Empty [nested]
/// emits the historical childless form byte-identically; every other kind
/// ignores [nested] (leaf children use the [_writeLeafFallback] branch, never
/// the item expression).
String _itemExpression(CanvasItem item, [List<String> nested = const []]) {
  final props = item.props;
  switch (item.kind) {
    case 'button':
      final constructor = switch (props['variant']) {
        'secondary' => 'SecondaryButton',
        'outline' => 'OutlineButton',
        'ghost' => 'GhostButton',
        'destructive' => 'DestructiveButton',
        'link' => 'LinkButton',
        // `text` renders `TextButton` on canvas (the kit's `ButtonVariance.text`
        // member); previously codegen fell through to `PrimaryButton`.
        'text' => 'TextButton',
        _ => 'PrimaryButton',
      };
      final size = switch (props['size']) {
        'sm' => 'ButtonSize.small',
        'lg' => 'ButtonSize.large',
        _ => 'ButtonSize.normal',
      };
      return '$constructor(\n'
          '  onPressed: () {},\n'
          '  enabled: ${!_bool(props, 'disabled')},\n'
          '  size: $size,\n'
          '  child: Text(${_str(props['label'] ?? 'Button')}),\n'
          '),';
    case 'card':
      return _cardExpr(props, nested);
    case 'input':
      // `initialValue`/`readOnly` wire into the kit's `TextField` super params
      // (mirroring the catalog builder); emitted only when non-default so docs
      // without them keep byte-identical output.
      final iv = props['initialValue'];
      final ivLine = iv is String && iv.isNotEmpty
          ? '  initialValue: ${_str(iv)},\n'
          : '';
      final roLine =
          _bool(props, 'readOnly') ? '  readOnly: true,\n' : '';
      final field = 'TextField(\n'
          '  placeholder: Text(${_str(props['placeholder'] ?? 'Type here')}),\n'
          '  enabled: ${!_bool(props, 'disabled')},\n'
          '  obscureText: ${_bool(props, 'obscure')},\n'
          '$ivLine$roLine'
          '),';
      final label = '${props['label'] ?? ''}';
      if (label.isEmpty) return field;
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    Text(${_str(label)}),\n'
          '    const SizedBox(height: 6),\n'
          '    $field\n'
          '  ],\n'
          '),';
    case 'badge':
      final constructor = switch (props['variant']) {
        'secondary' => 'SecondaryBadge',
        'destructive' => 'DestructiveBadge',
        'outline' => 'OutlineBadge',
        _ => 'PrimaryBadge',
      };
      return '$constructor(child: Text(${_str(props['label'] ?? 'Badge')})),';
    case 'switch':
      final onChanged =
          _bool(props, 'disabled') ? 'null' : '(v) {}';
      return 'Switch(value: ${_bool(props, 'value')}, onChanged: $onChanged),';
    case 'accordion':
      return 'Accordion(\n'
          '  items: [\n'
          '    AccordionItem(\n'
          '      trigger: AccordionTrigger(child: Text(${_str(_prop(props, 'title', 'Section 1'))})),\n'
          '      content: Text(${_str(_prop(props, 'content', 'Content 1'))}),\n'
          '      expanded: ${_bool(props, 'expanded')},\n'
          '    ),\n'
          '  ],\n'
          '),';
    case 'alert':
      return 'Alert(\n'
          '  title: Text(${_str(_prop(props, 'title', 'Alert'))}),\n'
          '  content: Text(${_str(_prop(props, 'content', 'Something happened.'))}),\n'
          '  destructive: ${_bool(props, 'destructive')},\n'
          '),';
    case 'alert_dialog':
      return _alertDialogExpr(props, nested);
    case 'avatar':
      final avatarSize = _num(props, 'size', 40.0).clamp(16.0, 96.0).toDouble();
      return 'Avatar(initials: ${_str(_prop(props, 'initials', 'AB'))}, size: ${_flowNum(avatarSize)}),';
    case 'basic':
      return 'Basic(\n'
          "  leading: ${_boolT(props, 'showLeading') ? "Text('•')" : 'null'},\n"
          "  title: ${_slotText(props, 'title', 'Title')},\n"
          "  subtitle: ${_slotText(props, 'subtitle', 'Subtitle')},\n"
          "  content: ${_slotText(props, 'content', 'Content')},\n"
          "  trailing: ${_boolT(props, 'showTrailing') ? "Text('›')" : 'null'},\n"
          '),';
    case 'breadcrumb':
      final separator = props['separator'] == 'slash'
          ? 'Breadcrumb.slashSeparator'
          : 'Breadcrumb.arrowSeparator';
      return 'Breadcrumb(\n'
          '  separator: $separator,\n'
          '  children: [\n'
          '    Text(${_str(_prop(props, 'home', 'Home'))}),\n'
          '    Text(${_str(_prop(props, 'current', 'Page'))}),\n'
          '  ],\n'
          '),';
    case 'calendar':
      final calMode = switch (props['mode']) {
        'range' => 'CalendarSelectionMode.range',
        'multi' => 'CalendarSelectionMode.multi',
        'none' => 'CalendarSelectionMode.none',
        _ => 'CalendarSelectionMode.single',
      };
      return 'Calendar(\n'
          '  view: CalendarView.now(),\n'
          '  selectionMode: $calMode,\n'
          '  onChanged: (_) {},\n'
          '),';
    case 'card_image':
      return 'SizedBox(\n'
          '  height: 240,\n'
          '  child: CardImage(\n'
          "    image: SizedBox(height: 120, child: Center(child: Text('Image'))),\n"
          "    title: ${_slotText(props, 'title', 'Card title')},\n"
          "    subtitle: ${_slotText(props, 'subtitle', 'Card subtitle')},\n"
          '  ),\n'
          '),';
    case 'carousel':
      final slides = _int(props, 'slides', 3).clamp(1, 5).toInt();
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  children: [\n'
          '    SizedBox(\n'
          '      height: 160,\n'
          '      child: Carousel(\n'
          '        transition: const CarouselTransition.sliding(),\n'
          '        itemCount: $slides,\n'
          // Runtime interpolation in the GENERATED code (not the generator):
          // each slide shows its 1-based index.
          "        itemBuilder: (context, index) => Center(child: Text('Slide \${index + 1}')),\n"
          '      ),\n'
          '    ),\n'
          '    const SizedBox(height: 8),\n'
          '    DotIndicator(index: 0, length: $slides),\n'
          '  ],\n'
          '),';
    case 'chat':
      return _chatExpr(props, nested);
    case 'checkbox':
      final cbState = _bool(props, 'value')
          ? 'CheckboxState.checked'
          : 'CheckboxState.unchecked';
      final cbChanged = _bool(props, 'disabled') ? 'null' : '(s) {}';
      return 'Checkbox(state: $cbState, tristate: ${_bool(props, 'tristate')}, onChanged: $cbChanged),';
    case 'chip':
      return 'Chip(child: Text(${_str(_prop(props, 'label', 'Chip'))})),';
    case 'circular_progress_indicator':
      final cpiValue = _num(props, 'value', 0.6).clamp(0.0, 1.0).toDouble();
      return 'CircularProgressIndicator(value: ${_flowNum(cpiValue)}),';
    case 'clickable':
      return _clickableExpr(props, nested);
    case 'code_snippet':
      return 'CodeSnippet(code: Text(${_str(_prop(props, 'code', 'const x = 1;'))})),';
    case 'collapsible':
      return 'Collapsible(\n'
          '  isExpanded: ${_bool(props, 'expanded')},\n'
          '  children: [\n'
          '    CollapsibleTrigger(child: Text(${_str(_prop(props, 'trigger', 'Show more'))})),\n'
          '    CollapsibleContent(child: Text(${_str(_prop(props, 'content', 'Hidden details'))})),\n'
          '  ],\n'
          '),';
    case 'color_input':
      final ciHex = _prop(props, 'hex', '#2196F3');
      final ciColor = 'Color(0x${_hexArgb(ciHex)})';
      return 'RecentColorsScope(\n'
          '  initialRecentColors: [$ciColor],\n'
          '  child: ColorInput(\n'
          '    value: ColorDerivative.fromColor($ciColor),\n'
          '    onChanged: (_) {},\n'
          '    placeholder: Text(${_str(ciHex)}),\n'
          '    showLabel: true,\n'
          '    enableEyeDropper: false,\n'
          '    showHistory: false,\n'
          '  ),\n'
          '),';
    case 'color_picker':
      final cpHex = _prop(props, 'hex', '#2196F3');
      final cpColor = 'Color(0x${_hexArgb(cpHex)})';
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    RecentColorsScope(\n'
          '      initialRecentColors: [$cpColor],\n'
          '      child: ColorPicker(\n'
          '        value: ColorDerivative.fromColor($cpColor),\n'
          '        showHistoryButton: false,\n'
          '        initialShowHistory: false,\n'
          '        enableEyeDropper: false,\n'
          '      ),\n'
          '    ),\n'
          '    const SizedBox(height: 8),\n'
          '    Text(${_str(cpHex)}),\n'
          '  ],\n'
          '),';
    case 'command':
      return 'SizedBox(\n'
          '  width: 300,\n'
          '  child: MenuPopup(\n'
          '    children: [\n'
          '      TextField(placeholder: Text(${_str(_prop(props, 'hint', 'Search commands...'))})),\n'
          '      CommandCategory(\n'
          "        title: const Text('Suggestions'),\n"
          '        children: [\n'
          '          CommandItem(title: Text(${_str(_prop(props, 'item1', 'Calendar'))}), onTap: () {}),\n'
          '          CommandItem(title: Text(${_str(_prop(props, 'item2', 'Settings'))}), onTap: () {}),\n'
          '        ],\n'
          '      ),\n'
          '    ],\n'
          '  ),\n'
          '),';
    case 'context_menu':
      return 'ContextMenu(\n'
          '  items: [\n'
          '    MenuButton(child: Text(${_str(_prop(props, 'item1', 'Back'))})),\n'
          '    MenuButton(child: Text(${_str(_prop(props, 'item2', 'Reload'))})),\n'
          '  ],\n'
          '  child: OutlineButton(onPressed: () {}, child: Text(${_str(_prop(props, 'hint', 'Right-click me'))})),\n'
          '),';
    case 'date_picker':
      final dpField = 'DatePicker(\n'
          '  value: null,\n'
          '  onChanged: (_) {},\n'
          '  placeholder: Text(${_str(_prop(props, 'placeholder', 'Select date'))}),\n'
          '),';
      final dpLabel = _prop(props, 'label', '');
      if (dpLabel.isEmpty) return dpField;
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    Text(${_str(dpLabel)}),\n'
          '    const SizedBox(height: 6),\n'
          '    $dpField\n'
          '  ],\n'
          '),';
    case 'dialog':
      return _dialogExpr(props, nested);
    case 'divider':
      final thickness =
          _num(props, 'thickness', 1.0).clamp(1.0, 8.0).toDouble();
      final divLabel = _prop(props, 'label', '');
      if (divLabel.isEmpty) {
        return 'Divider(thickness: ${_flowNum(thickness)}),';
      }
      return 'LayoutBuilder(\n'
          '  builder: (context, constraints) {\n'
          '    final available = constraints.maxWidth.isFinite\n'
          '        ? constraints.maxWidth\n'
          '        : (MediaQuery.maybeSizeOf(context)?.width ?? 320.0);\n'
          '    return Divider(\n'
          '      thickness: ${_flowNum(thickness)},\n'
          '      child: ConstrainedBox(\n'
          '        constraints: BoxConstraints(maxWidth: available * 0.6),\n'
          '        child: Text(${_str(divLabel)}, maxLines: 1, overflow: TextOverflow.ellipsis),\n'
          '      ),\n'
          '    );\n'
          '  },\n'
          '),';
    case 'dot_indicator':
      final diLength = _int(props, 'length', 3).clamp(1, 9).toInt();
      final diIndex = _int(props, 'index', 0).clamp(0, diLength - 1).toInt();
      return 'DotIndicator(index: $diIndex, length: $diLength),';
    case 'drawer':
      return _drawerExpr(props, nested);
    case 'dropdown_menu':
      return 'DropdownMenu(\n'
          '  children: [\n'
          '    MenuLabel(child: Text(${_str(_prop(props, 'heading', 'My Account'))})),\n'
          '    const MenuDivider(),\n'
          '    MenuButton(child: Text(${_str(_prop(props, 'item1', 'Profile'))})),\n'
          '    MenuButton(child: Text(${_str(_prop(props, 'item2', 'Settings'))})),\n'
          '  ],\n'
          '),';
    case 'empty_state':
      return 'EmptyState(\n'
          '  title: Text(${_str(_prop(props, 'title', 'No results'))}),\n'
          '  description: Text(${_str(_prop(props, 'description', 'Try adjusting your search.'))}),\n'
          '),';
    case 'feature_carousel':
      return 'FeatureCardCarousel(\n'
          '  controller: FeatureCarouselController(autoPlay: false, showCta: false),\n'
          '  width: 320,\n'
          '  items: [\n'
          '    FeatureCarouselItem(\n'
          '      title: ${_str(_prop(props, 'title1', 'Palette Selector'))},\n'
          '      description: ${_str(_prop(props, 'description1', 'Pick a palette to refine results.'))},\n'
          "      iconBuilder: (context, accentColor, size) => Text('★', style: TextStyle(fontSize: size, color: accentColor)),\n"
          '      accentColor: const Color(0xFF7EA3FF),\n'
          '    ),\n'
          '    FeatureCarouselItem(\n'
          '      title: ${_str(_prop(props, 'title2', 'Style Presets'))},\n'
          '      description: ${_str(_prop(props, 'description2', 'Choose a curated style preset.'))},\n'
          "      iconBuilder: (context, accentColor, size) => Text('◆', style: TextStyle(fontSize: size, color: accentColor)),\n"
          '      accentColor: const Color(0xFF9B87FF),\n'
          '    ),\n'
          '  ],\n'
          '),';
    case 'form':
      return _formExpr(props, nested);
    case 'form_field':
      final ffValue = _prop(props, 'value', '');
      return 'ObjectFormField<String>(\n'
          '  value: ${ffValue.isEmpty ? 'null' : _str(ffValue)},\n'
          '  onChanged: (_) {},\n'
          '  placeholder: Text(${_str(_prop(props, 'placeholder', 'Select item'))}),\n'
          '  builder: (context, selected) => Text(selected),\n'
          '  editorBuilder: (context, _) => TextField(\n'
          "    placeholder: const Text('Search...'),\n"
          '  ),\n'
          '),';
    case 'formatted_input':
      final fiField = 'FormattedInput(\n'
          '  onChanged: (_) {},\n'
          '  initialValue: FormattedValue([\n'
          "    InputPart.editable(length: 2, width: 40, placeholder: const Text('MM')).withValue('01'),\n"
          "    InputPart.static('/'),\n"
          "    InputPart.editable(length: 2, width: 40, placeholder: const Text('DD')).withValue('02'),\n"
          "    InputPart.static('/'),\n"
          "    InputPart.editable(length: 4, width: 60, placeholder: const Text('YYYY')).withValue('2021'),\n"
          '  ]),\n'
          '),';
      final fiLabel = _prop(props, 'label', '');
      if (fiLabel.isEmpty) return fiField;
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    Text(${_str(fiLabel)}),\n'
          '    const SizedBox(height: 6),\n'
          '    $fiField\n'
          '  ],\n'
          '),';
    case 'hidden':
      return _hiddenExpr(props, nested);
    case 'history':
      final columns = _int(props, 'columns', 6).clamp(2, 10).toInt();
      return 'RecentColorsScope(\n'
          '  initialRecentColors: const [Color(0xFF2196F3), Color(0xFF9C27B0)],\n'
          '  child: Builder(\n'
          '    builder: (context) => ColorHistoryGrid(\n'
          '      storage: ColorHistoryStorage.of(context),\n'
          '      onColorPicked: (_) {},\n'
          '      crossAxisCount: $columns,\n'
          '    ),\n'
          '  ),\n'
          '),';
    case 'hover_card':
      return 'HoverCard(\n'
          '  hoverBuilder: (context) => SizedBox(\n'
          '    width: 240,\n'
          '    child: Card(\n'
          '      padding: const EdgeInsets.all(16),\n'
          '      child: Column(\n'
          '        mainAxisSize: MainAxisSize.min,\n'
          '        crossAxisAlignment: CrossAxisAlignment.start,\n'
          '        children: [\n'
          '          Text(${_str(_prop(props, 'title', 'Hover title'))}),\n'
          '          const SizedBox(height: 4),\n'
          '          Text(${_str(_prop(props, 'body', 'Rich preview content.'))}),\n'
          '        ],\n'
          '      ),\n'
          '    ),\n'
          '  ),\n'
          '  child: OutlineButton(onPressed: () {}, child: Text(${_str(_prop(props, 'handle', 'Hover card'))})),\n'
          '),';
    case 'hsl':
      final hslMode = switch (props['mode']) {
        'sat' => 'HSLColorSliderType.sat',
        'lum' => 'HSLColorSliderType.lum',
        'alpha' => 'HSLColorSliderType.alpha',
        _ => 'HSLColorSliderType.hue',
      };
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    SizedBox(\n'
          '      height: 32,\n'
          '      child: HSLColorSlider(\n'
          '        color: HSLColor.fromColor(const Color(0xFF2196F3)),\n'
          '        sliderType: $hslMode,\n'
          '        onChanged: (c) {},\n'
          '      ),\n'
          '    ),\n'
          '    const SizedBox(height: 8),\n'
          '    Row(\n'
          '      mainAxisSize: MainAxisSize.min,\n'
          '      children: [\n'
          '        Container(width: 24, height: 24, color: const Color(0xFF2196F3)),\n'
          '        const SizedBox(width: 8),\n'
          "        Text('#2196F3'),\n"
          '      ],\n'
          '    ),\n'
          '  ],\n'
          '),';
    case 'hsv':
      final hsvMode = switch (props['mode']) {
        'sat' => 'HSVColorSliderType.sat',
        'val' => 'HSVColorSliderType.val',
        'alpha' => 'HSVColorSliderType.alpha',
        _ => 'HSVColorSliderType.hue',
      };
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    SizedBox(\n'
          '      height: 32,\n'
          '      child: HSVColorSlider(\n'
          '        value: HSVColor.fromColor(const Color(0xFF2196F3)),\n'
          '        sliderType: $hsvMode,\n'
          '        onChanged: (c) {},\n'
          '      ),\n'
          '    ),\n'
          '    const SizedBox(height: 8),\n'
          '    Row(\n'
          '      mainAxisSize: MainAxisSize.min,\n'
          '      children: [\n'
          '        Container(width: 24, height: 24, color: const Color(0xFF2196F3)),\n'
          '        const SizedBox(width: 8),\n'
          "        Text('#2196F3'),\n"
          '      ],\n'
          '    ),\n'
          '  ],\n'
          '),';
    case 'input_otp':
      final otpLength = _int(props, 'length', 6).clamp(4, 8).toInt();
      final otpChildren = StringBuffer();
      for (var i = 0; i < otpLength; i++) {
        otpChildren.writeln('    InputOTPChild.character(allowDigit: true),');
      }
      return 'InputOTP(\n'
          '  onChanged: (_) {},\n'
          '  children: [\n'
          '${otpChildren}  ],\n'
          '),';
    case 'keyboard_shortcut':
      final ksKeys =
          _shortcutKeys(_prop(props, 'keys', 'Ctrl+K')).join(', ');
      return 'KeyboardShortcutDisplayMapper(\n'
          '  child: KeyboardDisplay(keys: [$ksKeys]),\n'
          '),';
    case 'linear_progress_indicator':
      final lpiValue = _num(props, 'value', 0.6).clamp(0.0, 1.0).toDouble();
      return 'LinearProgressIndicator(value: ${_flowNum(lpiValue)}),';
    case 'menu':
      return 'MenuGroup(\n'
          '  direction: Axis.vertical,\n'
          '  autofocus: false,\n'
          '  builder: (context, children) => MenuPopup(children: children),\n'
          '  children: [\n'
          '    MenuLabel(child: Text(${_str(_prop(props, 'heading', 'File'))})),\n'
          '    MenuButton(child: Text(${_str(_prop(props, 'item1', 'New'))})),\n'
          '    MenuButton(child: Text(${_str(_prop(props, 'item2', 'Open'))})),\n'
          '  ],\n'
          '),';
    case 'menubar':
      return 'SizedBox(\n'
          '  height: 42,\n'
          '  child: SingleChildScrollView(\n'
          '    scrollDirection: Axis.horizontal,\n'
          '    child: Menubar(\n'
          '      border: true,\n'
          '      children: [\n'
          '        MenuButton(\n'
          '          subMenu: const [\n'
          "            MenuButton(child: Text('New')),\n"
          "            MenuButton(child: Text('Open')),\n"
          '          ],\n'
          '          child: Text(${_str(_prop(props, 'menu1', 'File'))}),\n'
          '        ),\n'
          '        MenuButton(\n'
          '          subMenu: const [\n'
          "            MenuButton(child: Text('Cut')),\n"
          "            MenuButton(child: Text('Copy')),\n"
          '          ],\n'
          '          child: Text(${_str(_prop(props, 'menu2', 'Edit'))}),\n'
          '        ),\n'
          '      ],\n'
          '    ),\n'
          '  ),\n'
          '),';
    case 'number_ticker':
      final ntValue = _num(props, 'value', 42);
      return 'NumberTicker(\n'
          '  number: ${_flowNum(ntValue)},\n'
          '  formatter: (v) => v.toStringAsFixed(0),\n'
          '),';
    case 'outlined_container':
      return _outlinedContainerExpr(props, nested);
    case 'pagination':
      final pgTotal = _int(props, 'totalPages', 5).clamp(1, 20).toInt();
      final pgPage = _int(props, 'page', 1).clamp(1, pgTotal).toInt();
      return 'FittedBox(\n'
          '  fit: BoxFit.scaleDown,\n'
          '  alignment: Alignment.centerLeft,\n'
          '  child: Pagination(\n'
          '    page: $pgPage,\n'
          '    totalPages: $pgTotal,\n'
          '    showLabel: false,\n'
          '    onPageChanged: (p) {},\n'
          '  ),\n'
          '),';
    case 'popover':
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    PrimaryButton(onPressed: () {}, child: Text(${_str(_prop(props, 'trigger', 'Open Popover'))})),\n'
          '    const SizedBox(height: 8),\n'
          '    ModalContainer(\n'
          '      filled: true,\n'
          '      padding: const EdgeInsets.all(16),\n'
          '      child: Column(\n'
          '        mainAxisSize: MainAxisSize.min,\n'
          '        crossAxisAlignment: CrossAxisAlignment.start,\n'
          '        children: [\n'
          '          Text(${_str(_prop(props, 'title', 'Popover title'))}),\n'
          '          const SizedBox(height: 8),\n'
          '          Text(${_str(_prop(props, 'body', 'Use popovers for contextual helper content.'))}),\n'
          '        ],\n'
          '      ),\n'
          '    ),\n'
          '  ],\n'
          '),';
    case 'popup':
      return 'MenuPopup(\n'
          '  children: [\n'
          '    Padding(padding: const EdgeInsets.all(8), child: Text(${_str(_prop(props, 'item1', 'Profile'))})),\n'
          '    Padding(padding: const EdgeInsets.all(8), child: Text(${_str(_prop(props, 'item2', 'Settings'))})),\n'
          '    const Divider(height: 1),\n'
          '    Padding(padding: const EdgeInsets.all(8), child: Text(${_str(_prop(props, 'item3', 'Sign out'))})),\n'
          '  ],\n'
          '),';
    case 'progress':
      final pgValue = _num(props, 'progress', 0.5).clamp(0.0, 1.0).toDouble();
      return 'Progress(progress: ${_flowNum(pgValue)}),';
    case 'radio_group':
      final rgOpt1 = _prop(props, 'option1', 'Option 1');
      final rgOpt2 = _prop(props, 'option2', 'Option 2');
      final rgValue = _prop(props, 'value', 'Option 1');
      final rgDisabled = _bool(props, 'disabled');
      return 'RadioGroup<String>(\n'
          '  value: ${rgValue.isEmpty ? 'null' : _str(rgValue)},\n'
          '  enabled: ${!rgDisabled},\n'
          '  onChanged: ${rgDisabled ? 'null' : '(v) {}'},\n'
          '  child: Column(\n'
          '    mainAxisSize: MainAxisSize.min,\n'
          '    children: [\n'
          '      RadioItem<String>(\n'
          '        value: ${_str(rgOpt1)},\n'
          '        leading: Flexible(child: Text(${_str(rgOpt1)}, maxLines: 1, overflow: TextOverflow.ellipsis)),\n'
          '      ),\n'
          '      const SizedBox(height: 8),\n'
          '      RadioItem<String>(\n'
          '        value: ${_str(rgOpt2)},\n'
          '        leading: Flexible(child: Text(${_str(rgOpt2)}, maxLines: 1, overflow: TextOverflow.ellipsis)),\n'
          '      ),\n'
          '    ],\n'
          '  ),\n'
          '),';
    case 'refresh_trigger':
      return _refreshTriggerExpr(props, nested);
    case 'scaffold':
      return _scaffoldExpr(props, nested);
    case 'scrollbar':
      return _scrollbarExpr(props, nested);
    case 'select':
      final selOpt1 = _prop(props, 'option1', 'Option 1');
      final selOpt2 = _prop(props, 'option2', 'Option 2');
      final selValue = _prop(props, 'value', '');
      final selShown =
          selValue.isNotEmpty && (selValue == selOpt1 || selValue == selOpt2)
              ? _str(selValue)
              : 'null';
      final selDisabled = _bool(props, 'disabled');
      return 'Select<String>(\n'
          '  value: $selShown,\n'
          '  placeholder: Text(${_str(_prop(props, 'placeholder', 'Select an option'))}),\n'
          '  itemBuilder: (context, item) => Text(item),\n'
          '  enabled: ${!selDisabled},\n'
          '  onChanged: ${selDisabled ? 'null' : '(v) {}'},\n'
          '  popup: SelectPopup(\n'
          '    items: SelectItemList(\n'
          '      children: [\n'
          '        SelectItemButton(value: ${_str(selOpt1)}, child: Text(${_str(selOpt1)})),\n'
          '        SelectItemButton(value: ${_str(selOpt2)}, child: Text(${_str(selOpt2)})),\n'
          '      ],\n'
          '    ),\n'
          '  ).call,\n'
          '),';
    case 'selectable':
      return 'SelectableText(${_str(_prop(props, 'text', 'Select me'))}),';
    case 'skeleton':
      return 'Text(${_str(_prop(props, 'label', 'Loading'))}).asSkeleton(enabled: ${_boolT(props, 'enabled')}),';
    case 'slider':
      final sliderValue = _num(props, 'value', 0.6).clamp(0.0, 1.0).toDouble();
      return 'Slider(value: ${_flowNum(sliderValue)}, onChanged: (v) {}),';
    case 'star_rating':
      final srMax =
          (_num(props, 'max', 5.0)).clamp(1.0, 10.0).toDouble();
      final srValue =
          (_num(props, 'value', 3.0)).clamp(0.0, srMax).toDouble();
      return 'StarRating(value: ${_flowNum(srValue)}, max: ${_flowNum(srMax)}, onChanged: (v) {}),';
    case 'stepper':
      final stSteps = [
        _prop(props, 'step1', 'Details'),
        _prop(props, 'step2', 'Payment'),
        _prop(props, 'step3', 'Confirm'),
      ];
      final stDetails = [
        _prop(props, 'detail1', 'Provide your details.'),
        _prop(props, 'detail2', 'Choose a payment method.'),
        _prop(props, 'detail3', 'Review and submit.'),
      ];
      final stStep = _int(props, 'step', 0).clamp(0, stSteps.length - 1).toInt();
      return 'CanvasStepperCell(\n'
          '  initialStep: $stStep,\n'
          '  steps: [${stSteps.map(_str).join(', ')}],\n'
          '  details: [${stDetails.map(_str).join(', ')}],\n'
          '),';
    case 'steps':
      return 'Steps(\n'
          '  children: [\n'
          '    StepItem(title: Text(${_str(_prop(props, 'step1', 'Step 1'))}), content: [Text(${_str(_prop(props, 'detail1', 'First step details'))})]),\n'
          '    StepItem(title: Text(${_str(_prop(props, 'step2', 'Step 2'))}), content: [Text(${_str(_prop(props, 'detail2', 'Second step details'))})]),\n'
          '  ],\n'
          '),';
    case 'swiper':
      return 'Swiper(\n'
          '  handler: SwiperHandler.sheet,\n'
          '  position: OverlayPosition.bottom,\n'
          '  builder: (context) => Padding(\n'
          '    padding: const EdgeInsets.all(24),\n'
          '    child: Text(${_str(_prop(props, 'content', 'Swipe content'))}),\n'
          '  ),\n'
          '  child: SizedBox(\n'
          '    height: 96,\n'
          '    child: Center(\n'
          '      child: OutlinedContainer(\n'
          '        child: Padding(\n'
          '          padding: const EdgeInsets.all(12),\n'
          '          child: Text(${_str(_prop(props, 'hint', 'Swipe up from the bottom'))}),\n'
          '        ),\n'
          '      ),\n'
          '    ),\n'
          '  ),\n'
          '),';
    case 'tab_container':
      final tcTabs = [
        _prop(props, 'tab1', 'Overview'),
        _prop(props, 'tab2', 'Details'),
        _prop(props, 'tab3', 'Reviews'),
      ];
      final tcIndex =
          _int(props, 'index', 0).clamp(0, tcTabs.length - 1).toInt();
      final tcChildren = StringBuffer();
      for (final label in tcTabs) {
        tcChildren.writeln(
            '    TabItem(child: Text(${_str(label)}, maxLines: 1, overflow: TextOverflow.ellipsis)),');
      }
      return 'TabContainer(\n'
          '  selected: $tcIndex,\n'
          '  onSelect: (i) {},\n'
          '  builder: (context, children) => Column(\n'
          '    mainAxisSize: MainAxisSize.min,\n'
          '    children: [\n'
          '      Row(\n'
          '        mainAxisAlignment: MainAxisAlignment.center,\n'
          '        children: [for (final child in children) Flexible(child: child)],\n'
          '      ),\n'
          '      const SizedBox(height: 8),\n'
          "      Text('Selected tab: ${tcIndex + 1}'),\n"
          '    ],\n'
          '  ),\n'
          '  childBuilder: (context, data, child) {\n'
          '    final selected = data.selected == data.index;\n'
          '    return GestureDetector(\n'
          '      onTap: () => data.onSelect?.call(data.index),\n'
          '      child: Padding(\n'
          '        padding: const EdgeInsets.symmetric(horizontal: 12),\n'
          '        child: DefaultTextStyle.merge(\n'
          '          style: TextStyle(\n'
          '            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,\n'
          '          ),\n'
          '          child: child,\n'
          '        ),\n'
          '      ),\n'
          '    );\n'
          '  },\n'
          '  children: [\n'
          '$tcChildren'
          '  ],\n'
          '),';
    case 'tab_list':
      final tlIndex = _int(props, 'index', 0).clamp(0, 1).toInt();
      return 'SizedBox(\n'
          '  height: 37,\n'
          '  child: SingleChildScrollView(\n'
          '    scrollDirection: Axis.horizontal,\n'
          '    child: TabList(\n'
          '      index: $tlIndex,\n'
          '      onChanged: (i) {},\n'
          '      children: [\n'
          '        TabItem(child: Text(${_str(_prop(props, 'tab1', 'Tab 1'))})),\n'
          '        TabItem(child: Text(${_str(_prop(props, 'tab2', 'Tab 2'))})),\n'
          '      ],\n'
          '    ),\n'
          '  ),\n'
          '),';
    case 'tab_pane':
      final tpTabs = [
        _prop(props, 'tab1', 'Overview'),
        _prop(props, 'tab2', 'Analytics'),
        _prop(props, 'tab3', 'Settings'),
      ];
      final tpFocused =
          _int(props, 'focused', 0).clamp(0, tpTabs.length - 1).toInt();
      final tpItems = StringBuffer();
      for (final label in tpTabs) {
        tpItems.writeln('    TabPaneData(${_str(label)}),');
      }
      return 'TabPane<String>(\n'
          '  items: [\n'
          '$tpItems'
          '  ],\n'
          '  focused: $tpFocused,\n'
          '  onFocused: (i) {},\n'
          '  itemBuilder: (context, item, index) => TabChildWidget(indexed: true, child: Text(item.data)),\n'
          '  child: Padding(\n'
          '    padding: const EdgeInsets.all(16),\n'
          "    child: Text(${_str('Content: ${tpTabs[tpFocused]}')}),\n"
          '  ),\n'
          '),';
    case 'table':
      return 'Table(\n'
          '  rows: [\n'
          '    TableHeader(\n'
          '      cells: [\n'
          '        TableCell(child: Text(${_str(_prop(props, 'header1', 'Name'))})),\n'
          '        TableCell(child: Text(${_str(_prop(props, 'header2', 'Role'))})),\n'
          '      ],\n'
          '    ),\n'
          '    TableRow(\n'
          '      cells: [\n'
          '        TableCell(child: Text(${_str(_prop(props, 'name1', 'Avery'))})),\n'
          '        TableCell(child: Text(${_str(_prop(props, 'role1', 'Designer'))})),\n'
          '      ],\n'
          '    ),\n'
          '    TableRow(\n'
          '      cells: [\n'
          '        TableCell(child: Text(${_str(_prop(props, 'name2', 'Jordan'))})),\n'
          '        TableCell(child: Text(${_str(_prop(props, 'role2', 'Engineer'))})),\n'
          '      ],\n'
          '    ),\n'
          '  ],\n'
          '),';
    case 'tabs':
      final tabsIndex = _int(props, 'index', 0).clamp(0, 1).toInt();
      return 'Tabs(\n'
          '  index: $tabsIndex,\n'
          '  expand: ${_bool(props, 'expand')},\n'
          '  onChanged: (i) {},\n'
          '  children: [\n'
          '    TabItem(child: Text(${_str(_prop(props, 'tab1', 'Tab 1'))})),\n'
          '    TabItem(child: Text(${_str(_prop(props, 'tab2', 'Tab 2'))})),\n'
          '  ],\n'
          '),';
    case 'text_area':
      final taField = 'TextArea(\n'
          '  placeholder: Text(${_str(_prop(props, 'placeholder', 'Type here'))}),\n'
          '  enabled: ${!_bool(props, 'disabled')},\n'
          '),';
      final taLabel = _prop(props, 'label', '');
      if (taLabel.isEmpty) return taField;
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    Text(${_str(taLabel)}),\n'
          '    const SizedBox(height: 6),\n'
          '    $taField\n'
          '  ],\n'
          '),';
    case 'time_picker':
      final tpField = 'TimePicker(\n'
          '  value: null,\n'
          '  onChanged: (_) {},\n'
          '  placeholder: Text(${_str(_prop(props, 'placeholder', 'Select time'))}),\n'
          '),';
      final tpLabel = _prop(props, 'label', '');
      if (tpLabel.isEmpty) return tpField;
      return 'Column(\n'
          '  mainAxisSize: MainAxisSize.min,\n'
          '  crossAxisAlignment: CrossAxisAlignment.start,\n'
          '  children: [\n'
          '    Text(${_str(tpLabel)}),\n'
          '    const SizedBox(height: 6),\n'
          '    $tpField\n'
          '  ],\n'
          '),';
    case 'timeline':
      return 'Timeline(\n'
          '  data: [\n'
          '    TimelineData(\n'
          '      time: Text(${_str(_prop(props, 'time1', '9:00 AM'))}),\n'
          '      title: Text(${_str(_prop(props, 'title1', 'Kickoff'))}),\n'
          "      content: ${_slotText(props, 'detail1', 'Project kickoff meeting')},\n"
          '    ),\n'
          '    TimelineData(\n'
          '      time: Text(${_str(_prop(props, 'time2', '2:00 PM'))}),\n'
          '      title: Text(${_str(_prop(props, 'title2', 'Review'))}),\n'
          "      content: ${_slotText(props, 'detail2', 'Design review session')},\n"
          '    ),\n'
          '  ],\n'
          '),';
    case 'toast':
      return _toastExpr(props, nested);
    case 'tooltip':
      return 'Tooltip(\n'
          '  tooltip: (context) => TooltipContainer(child: Text(${_str(_prop(props, 'tip', 'Helpful context'))})),\n'
          '  child: OutlineButton(onPressed: () {}, child: Text(${_str(_prop(props, 'label', 'Hover me'))})),\n'
          '),';
    case 'tracker':
      final trSegments = _int(props, 'segments', 3).clamp(1, 5).toInt();
      final trLevel = switch (props['level']) {
        'warning' => 'TrackerLevel.warning',
        'critical' => 'TrackerLevel.critical',
        'unknown' => 'TrackerLevel.unknown',
        _ => 'TrackerLevel.fine',
      };
      final trData = StringBuffer();
      for (var i = 0; i < trSegments; i++) {
        trData.writeln(
            "    TrackerData(tooltip: Text('Segment ${i + 1}'), level: $trLevel),");
      }
      return 'Tracker(\n'
          '  data: [\n'
          '$trData'
          '  ],\n'
          '),';
    case 'tree':
      return 'TreeView<String>(\n'
          '  shrinkWrap: true,\n'
          '  nodes: [\n'
          '    TreeItem(\n'
          '      data: ${_str(_prop(props, 'node1', 'Design'))},\n'
          '      expanded: true,\n'
          '      children: [\n'
          '        TreeItem(data: ${_str(_prop(props, 'child1', 'Research'))}),\n'
          '        TreeItem(data: ${_str(_prop(props, 'child2', 'Wireframes'))}),\n'
          '      ],\n'
          '    ),\n'
          '    TreeItem(data: ${_str(_prop(props, 'node2', 'Launch'))}),\n'
          '  ],\n'
          '  builder: (context, item) => Text(item.data),\n'
          '),';
    case 'triple_dots':
      final tdCount = _int(props, 'count', 3).clamp(1, 9).toInt();
      return 'MoreDots(count: $tdCount),';
    case 'validated':
      return _validatedExpr(props, nested);
    default:
      return "Text('unknown: ${item.kind}'),";
  }
}

/// Strips `import`/`export`/`part`/`part of`/`library` directives so the
/// body can live in a single file. Directives must precede declarations,
/// so mid-file copies would break validity; relative-URI ones would also
/// dangle. Handles multi-line directives by skipping through `;`. The
/// keyword must open a real directive (see [_isDirectiveStart]): a code
/// line like `part == other.part &&` is kept.
String _stripDirectives(String body) {
  final kept = <String>[];
  var skipping = false;
  for (final line in body.split('\n')) {
    final trimmed = line.trimLeft();
    if (!skipping && _isDirectiveStart(trimmed)) {
      if (!line.contains(';')) skipping = true;
      continue;
    }
    if (skipping) {
      if (line.contains(';')) skipping = false;
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n').trimRight();
}
