/// Hand-written golden for `g3_dot_indicator.json` (Track G3).
///
/// Written BY HAND before the G3 emitters existed (§6.5 golden-first):
/// mirrors the canvas `buildDotIndicatorEntry` registry builder (`index` +
/// `length` ints parsed via `num`, index clamped into range so hand-written
/// docs never crash). Multi-arg invocation, dart-format-canonical full
/// split.
///
/// NOTE: never compiled inside `canvas_core` (Flutter-free, §12 rule 6).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, undefined_function, undefined_identifier, undefined_super_member, creation_with_non_type
library;

import 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart'
    hide Column, Expanded, Flex, Flexible, Positioned, Row, Stack, Theme;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DotIndicator(
      index: 1,
      length: 4,
    );
  }
}
