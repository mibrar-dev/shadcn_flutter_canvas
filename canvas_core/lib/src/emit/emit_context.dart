/// G1 scaffold (Track G prep): emitter context per BUILD_SPEC §6.4.
///
/// `EmitContext` carries what every [WidgetEmitter] needs: an import
/// collector, the theme accessor, the current responsive tier, a name
/// allocator (controllers/keys), and the recursion entry point. Flutter-free
/// and dependency-free; G2 keeps this shape and only changes the emitted
/// value type from `String` to `code_builder` expressions.
library;

import '../screen_doc.dart';

/// Responsive tier the current emission targets.
///
/// Leaf-value rule (§8.4): responsive differences collapse to
/// `responsiveValue(context, base:, md:)` at the leaf — subtrees are never
/// duplicated per tier, so emitters read [EmitContext.tier] only to decide
/// which override map supplies the leaf value.
enum ResponsiveTier {
  /// Default (no override): the authored base value.
  base,

  /// Doc-model tiers (`kResponsiveTiers` in screen_doc.dart).
  mobile,
  tablet,
  desktop,
}

/// Collects Dart imports while emitters run; renders the sorted, deduped
/// import block for the emitted file header.
///
/// Combinators (§8.4 clash hygiene, ported from the legacy `_screenFile` H2
/// convention): an entry may carry an `as` prefix and/or `show`/`hide`
/// name lists, rendered as
/// `import 'url' as prefix show A hide B, C;`. Re-adding the same url
/// unions the combinator sets (a conflicting prefix keeps the first
/// registration) so per-kind `collectImports` calls compose without a
/// central import table.
class ImportCollector {
  final Map<String, _ImportSpec> _imports = {};

  /// Adds `import 'url'` (optionally `as prefix`, `show`/`hide` [hide]).
  /// Re-adding the same url unions the combinator sets; a conflicting
  /// prefix keeps the first registration.
  void add(
    String url, {
    String? asPrefix,
    Iterable<String> hide = const [],
    Iterable<String> show = const [],
  }) {
    final existing = _imports[url];
    if (existing == null) {
      _imports[url] = _ImportSpec(
        asPrefix,
        {...hide},
        {...show},
      );
      return;
    }
    existing.hide.addAll(hide);
    existing.show.addAll(show);
  }

  /// Names hidden on the import of [url] (empty when unregistered): the
  /// page shell reads this for the shell-owned material import so the
  /// collector stays the single source of clash knowledge.
  Set<String> hideFor(String url) =>
      Set.unmodifiable(_imports[url]?.hide ?? const <String>{});

  /// `dart:` first, then `package:`, then relative — each group sorted.
  List<String> get lines {
    final urls = _imports.keys.toList();
    urls.sort((a, b) {
      int rank(String u) {
        if (u.startsWith('dart:')) return 0;
        if (u.startsWith('package:')) return 1;
        return 2;
      }

      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.compareTo(b);
    });
    return [for (final url in urls) _render(url, _imports[url]!)];
  }

  /// Single import line: combinators render in canonical Dart order
  /// (`as`, then `show`, then `hide`), each name list sorted. Lines
  /// overflowing 80 columns wrap before each combinator clause (4-space
  /// continuation) — exactly how `dart format` splits long import
  /// directives, so emitted headers are formatter fixpoints (gate 3) even
  /// with the gates 4–5 kit-side hide list.
  String _render(String url, _ImportSpec spec) {
    final head = "import '$url'";
    final clauses = <String>[];
    if (spec.prefix != null) clauses.add('as ${spec.prefix}');
    if (spec.show.isNotEmpty) {
      clauses.add('show ${(spec.show.toList()..sort()).join(', ')}');
    }
    if (spec.hide.isNotEmpty) {
      clauses.add('hide ${(spec.hide.toList()..sort()).join(', ')}');
    }
    if (clauses.isEmpty) return '$head;';
    final single = '$head ${clauses.join(' ')};';
    if (single.length <= 80) return single;
    return '$head\n    ${clauses.join('\n    ')};';
  }

  bool get isEmpty => _imports.isEmpty;
}

/// One collected import: the optional `as` prefix plus the combinator sets.
class _ImportSpec {
  final String? prefix;
  final Set<String> hide;
  final Set<String> show;

  _ImportSpec(this.prefix, this.hide, this.show);
}

/// Clash-hygiene tables (gates 4–5 DEFECT-1): the G3 emitters keep the kit
/// GLOBAL barrel (one import, the §8.1 package-dep contract, no per-kind
/// barrel-path table to drift against kit renames) and disambiguate with
/// computed `hide` lists on BOTH imports. This ports the legacy
/// `_screenFile` H2 convention (`codegen_bundle.dart`) and extends it:
/// legacy screens never import the global barrel, so the kit-side rows
/// below (`Column`/`Expanded`/`Theme`/…) have no legacy rows. They live
/// HERE (not in `g3_emitters.dart`) because the page walker also reads
/// [kKitImportHide] for its material-necessity scan — and the walker cannot
/// import the G3 module (which imports the walker).
///
/// * [kKitImportHide]: names the global barrel declares that shadow the
///   Flutter SDK, where generated bodies always mean Flutter's — the kit's
///   own `flex.dart` layout primitives (`Column`, `Row`, `Stack`, `Flex`,
///   `Flexible`, `Expanded`, `Positioned`: verified declarations in the
///   flex `_impl/core` parts, re-exported through the global barrel) and
///   the kit `Theme` (`shared/theme/theme.dart`, which the kit's own
///   `alert.dart` hides on ITS material import — same trap). Hidden on the
///   kit import whenever any G3 kind is used: hiding an exported-but-unused
///   name is warning-free, so one unconditional list beats per-kind
///   subsets (and every clause below names a verified barrel export — a
///   stale entry would warn `undefined_hidden_name`, caught by gate 4).
/// * [kG3FlutterHideByKind]: the reverse direction — G3 kit constructors
///   sharing a name with `package:flutter/material.dart` (`Chip`,
///   `CircularProgressIndicator`, `LinearProgressIndicator`; verified
///   material exports). Hidden on the FLUTTER import, but ONLY on pages
///   using that kind (the legacy rule: only names the page's own kit
///   surface provides are hidden).
const kKitImportHide = [
  'Column',
  'Expanded',
  'Flex',
  'Flexible',
  'Positioned',
  'Row',
  'Stack',
  'Theme',
];

/// Per-kind names to `hide` on the page's Flutter import (kit wins).
/// Kinds absent here declare no material-colliding constructor.
const kG3FlutterHideByKind = {
  'chip': ['Chip'],
  'circular_progress_indicator': ['CircularProgressIndicator'],
  'linear_progress_indicator': ['LinearProgressIndicator'],
};

/// Hands out collision-free Dart identifiers for generated state
/// (controllers, focus nodes, keys): `emailController`,
/// `emailController2`, … Sanitizes to `[A-Za-z0-9_$]`, guards leading
/// digits, and never returns a Dart reserved word bare.
class NameAllocator {
  final Set<String> _taken = {};
  static const _reserved = {
    'class',
    'enum',
    'extends',
    'import',
    'return',
    'if',
    'else',
    'for',
    'while',
    'switch',
    'case',
    'default',
    'do',
    'new',
    'null',
    'true',
    'false',
    'this',
    'super',
    'void',
    'final',
    'const',
    'var',
    'late',
    'required',
    'with',
    'is',
    'in',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'continue',
    'try',
    'catch',
    'finally',
    'throw',
    'typedef',
    'function',
  };

  /// Allocates a unique identifier derived from [base].
  String allocate(String base) {
    var candidate = base.replaceAll(RegExp(r'[^A-Za-z0-9_$]'), '');
    if (candidate.isEmpty) candidate = 'name';
    if (RegExp(r'^[0-9]').hasMatch(candidate)) candidate = '_$candidate';
    if (_reserved.contains(candidate)) candidate = '${candidate}_';
    if (_taken.add(candidate)) return candidate;
    var i = 2;
    while (!_taken.add('$candidate$i')) {
      i++;
    }
    return '$candidate$i';
  }

  /// Reserves [name] without allocating (e.g. page-class names).
  void reserve(String name) => _taken.add(name);

  bool isTaken(String name) => _taken.contains(name);
}

/// Recursion entry point: emits the widget expression for [node].
///
/// G1 types this as `String`; G2 retypes to `code_builder Expression`
/// without changing the call shape (`ctx.emitNode(child)`).
typedef EmitNodeFn = String Function(CanvasNode node);

/// Per-emission shared state (§6.4).
class EmitContext {
  /// Collects imports referenced by emitters.
  final ImportCollector imports = ImportCollector();

  /// Allocates controller/key identifiers.
  final NameAllocator names = NameAllocator();

  /// Theme accessor expression used for token-bound values
  /// (default `Theme.of(context)` — see §6.1 rule).
  final String themeExpr;

  /// Tier being emitted (leaf-value responsive rule).
  ResponsiveTier tier;

  /// Bound by the driver (page writer): recurse into child nodes here.
  /// Null until bound; [emitChild] throws a descriptive [StateError] when
  /// unbound so scaffold misuse fails loudly, never silently empty.
  EmitNodeFn? emitNode;

  EmitContext({this.themeExpr = 'Theme.of(context)', this.tier = ResponsiveTier.base});

  /// Emits [child] via the bound driver.
  String emitChild(CanvasNode child) {
    final fn = emitNode;
    if (fn == null) {
      throw StateError(
        'EmitContext.emitNode is unbound: the page driver must set it '
        'before emitters recurse (node ${child.id}).',
      );
    }
    return fn(child);
  }
}
