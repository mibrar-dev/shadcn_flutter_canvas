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
class ImportCollector {
  final Map<String, String?> _imports = {};

  /// Adds `import 'url'` (optionally `as prefix`). Re-adding the same url
  /// is a no-op; a conflicting prefix keeps the first registration.
  void add(String url, {String? asPrefix}) {
    _imports.putIfAbsent(url, () => asPrefix);
  }

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
    return [
      for (final url in urls)
        "import '$url';".replaceFirst(
          "';",
          _imports[url] == null ? "';" : "' as ${_imports[url]};",
        ),
    ];
  }

  bool get isEmpty => _imports.isEmpty;
}

/// Hands out collision-free Dart identifiers for generated state
/// (controllers, focus nodes, keys): `emailController`,
/// `emailController2`, … Sanitizes to `[A-Za-z0-9_$]`, guards leading
/// digits, and never returns a Dart reserved word bare.
class NameAllocator {
  final Set<String> _taken = {};
  static const _reserved = {
    'class', 'enum', 'extends', 'import', 'return', 'if', 'else', 'for',
    'while', 'switch', 'case', 'default', 'do', 'new', 'null', 'true',
    'false', 'this', 'super', 'void', 'final', 'const', 'var', 'late',
    'required', 'with', 'is', 'in', 'as', 'assert', 'async', 'await',
    'break', 'continue', 'try', 'catch', 'finally', 'throw', 'typedef',
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
