/// Hand-written golden: the `{Page}Model` half of `g3_text_area.json`.
/// See `g3_text_area.expected.dart` for the golden-first note.
/// NOTE: never compiled inside `canvas_core` (Flutter-free, §12 rule 6).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, undefined_function, undefined_identifier, undefined_super_member, creation_with_non_type
library;

import 'package:flutter/material.dart';

class HomeModel extends ChangeNotifier {
  final bioController = TextEditingController();

  @override
  void dispose() {
    bioController.dispose();
    super.dispose();
  }
}
