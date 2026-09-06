/// Barrel for the Track G emitter layer (BUILD_SPEC §§6.4, 8.2–8.4).
///
/// One import for the registry, the AST emitters, the tagged-value bridge,
/// the shared value codecs, and the project writer — the §8.2 "one
/// registry" surface. Re-exported from `canvas_core.dart`.
library;

export 'emit_context.dart';
export 'expr_emitter.dart';
export 'g3_emitters.dart';
export 'project_writer.dart';
export 'tagged_value.dart';
export 'value_codecs.dart';
export 'widget_emitter.dart';
