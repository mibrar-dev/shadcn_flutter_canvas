/// Hand-written golden for `g3_code_snippet.json` (Track G3).
///
/// Written BY HAND before the G3 emitters existed (§6.5 golden-first):
/// mirrors the canvas `buildCodeSnippetEntry` registry builder (the
/// canvas-level `code` string renders as the child `Text`, same
/// content-prop pattern as the card catalog builder). Single-arg short
/// invocation, dart-format-canonical.
///
/// NOTE: never compiled inside `canvas_core` (Flutter-free, §12 rule 6).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, undefined_function, undefined_identifier, undefined_super_member, creation_with_non_type
library;

import 'package:flutter/material.dart';
import 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CodeSnippet(code: Text('void main() {}'));
  }
}
