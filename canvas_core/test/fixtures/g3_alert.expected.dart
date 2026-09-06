/// Hand-written golden for `g3_alert.json` (Track G3, §6.5 golden-first).
///
/// Written BY HAND before the G3 emitters existed: mirrors the canvas
/// `buildAlertEntry` registry builder prop-for-prop (canvas-level title /
/// content strings render as the title / content `Text`s, `destructive`
/// passes through). Multi-arg invocation, dart-format-canonical full split.
/// The G3 AlertEmitter must produce it.
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
    return Alert(
      title: Text('Heads up'),
      content: Text('Read this first.'),
      destructive: true,
    );
  }
}
