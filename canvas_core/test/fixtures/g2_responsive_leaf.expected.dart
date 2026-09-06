/// Hand-written golden for `g2_responsive_leaf.json` (Track G2).
///
/// Written BY HAND before the Expression emitters existed (§6.5
/// golden-first): the §8.4 responsive leaf rule (the per-tier difference
/// branches the VALUE via `responsiveValue`, the subtree is never
/// duplicated) + const elision on responsive leaves. The G2 emitters must
/// produce it.
///
/// NOTE: never compiled inside `canvas_core` (Flutter-free, §12 rule 6).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, undefined_function, undefined_identifier, undefined_super_member, creation_with_non_type
library;

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: responsiveValue(context, base: 48, md: 96));
  }
}
