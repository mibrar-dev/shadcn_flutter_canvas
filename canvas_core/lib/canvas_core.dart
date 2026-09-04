/// Shared pure-Dart canvas logic (no Flutter imports).
///
/// Reused by `canvas_app` (gallery/export UI) and `shadcn_flutter_cli`
/// (`screen` command) so prompt/codegen behavior stays identical.
library;

export 'src/screen_doc.dart';
export 'src/prompt_builder.dart';
export 'src/share_codec.dart';
export 'src/codegen_single.dart';
export 'src/screen_doc_schema.dart';
export 'src/codegen_bundle.dart';
