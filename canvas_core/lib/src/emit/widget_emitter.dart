/// G1 scaffold (Track G prep): per-kind emitter contract per §6.4.
///
/// ```dart
/// abstract class WidgetEmitter {
///   String get type;                                    // e.g. "container"
///   Expression emit(CanvasNode node, EmitContext ctx); // recurse via ctx
/// }
/// ```
///
/// G1 keeps the §6.4 shape but types the expression as `String`: the
/// `code_builder` dependency lands in G2 (§8.3), which retypes the return
/// without changing the registry mechanics defined here. Scaffolding only —
/// no existing `_bundleX` function is touched (Track F owns additive bundle
/// changes this session).
library;

import '../screen_doc.dart';
import 'emit_context.dart';

/// One emitter per registry type key. Mirrors the existing `_bundleX(props)`
/// functions 1:1 (mechanical migration in G2, not a redesign).
///
/// Per-widget correctness rules (§6.2 archetype: `Container` color XOR
/// decoration) live in implementations: a naive prop→argument mapping gets
/// them wrong, so each emitter documents its rules and its hand-written
/// golden pins them (§6.5).
abstract class WidgetEmitter {
  /// Registry type key, e.g. `"container"`, `"button"`.
  String get type;

  /// Builds the widget expression for [item], recursing into [node]'s
  /// children via `ctx.emitChild`. [childExprs] are the already-emitted
  /// child expressions in document order.
  String emit(
    CanvasItem item,
    CanvasNode node,
    List<String> childExprs,
    EmitContext ctx,
  );
}

/// Placeholder text emitted for kinds with no real emitter yet.
///
/// Placeholders are honest (`Text('…')` + doc comment at the call site,
/// never a crash) and counted: gate 7 (§11) requires this set to be empty.
/// G3 closes it structurally via §8.2 unified entries, not one-off
/// functions.
String placeholderFor(String kind) => "Text('$kind (not yet bridged)')";

/// Registry of emitters by type key, plus the §8.2 unified-entry shape.
///
/// A kind enters the registry only when it declares BOTH its canvas render
/// and its emit path ([KindBinding.renderDescription] documents the render
/// side until G3 wires the real builder reference). A kind that cannot do
/// both does not enter — that is what makes drift (§4.3) type-enforced
/// instead of test-detected.
class EmitterRegistry {
  final Map<String, WidgetEmitter> _emitters = {};
  final Map<String, KindBinding> _bindings = {};

  /// Registers [emitter] (and its unified [binding] when known).
  void register(WidgetEmitter emitter, {KindBinding? binding}) {
    _emitters[emitter.type] = emitter;
    if (binding != null) _bindings[emitter.type] = binding;
  }

  /// Registers a unified binding for a kind whose emitter migrates in G2.
  void registerBinding(KindBinding binding) => _bindings[binding.type] = binding;

  /// Unified binding for [kind], or null when unbound.
  KindBinding? bindingFor(String kind) => _bindings[kind];

  /// Real emitter for [kind], or null (→ placeholder path).
  WidgetEmitter? lookup(String kind) => _emitters[kind];

  /// Whether [kind] has a real emitter (no placeholder).
  bool hasRealEmitter(String kind) => _emitters.containsKey(kind);

  /// Kinds with a unified §8.2 binding declared.
  Iterable<String> get boundKinds => _bindings.keys;

  /// Kinds with a real emitter.
  Iterable<String> get emitterKinds => _emitters.keys;

  /// Unified bindings whose kind still lacks a real emitter — the
  /// machine-readable drift set. Gate 7 requires this to be empty.
  Iterable<String> get driftKinds =>
      _bindings.keys.where((k) => !_emitters.containsKey(k));

  int get emitterCount => _emitters.length;
}

/// One registry entry declaring BOTH paths for a kind (§8.2).
///
/// G1 specifies the shape; G3 populates it for all kinds (after Track F
/// lands, per §13) and the drift guard asserts
/// `registry.driftKinds.isEmpty`.
class KindBinding {
  /// Registry type key (single source of truth for render + emit).
  final String type;

  /// Whether the kind is a container (takes child nodes).
  final bool isContainer;

  /// Human description of the canvas render path (catalog builder name)
  /// until G3 replaces it with a real builder reference.
  final String renderDescription;

  /// Per-widget correctness rules this kind's emitter must honor
  /// (§6.2 archetype), e.g. `['color XOR decoration']`.
  final List<String> correctnessRules;

  /// Whether any instance needs a `{Page}Model` (any text_field /
  /// switch / checkbox / tabs / page-controller descendant — §8.4).
  final bool needsModel;

  const KindBinding({
    required this.type,
    required this.isContainer,
    required this.renderDescription,
    this.correctnessRules = const [],
    this.needsModel = false,
  });
}
