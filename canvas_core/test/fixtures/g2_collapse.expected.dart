/// Hand-written golden for `g2_collapse.json` (Track G2).
///
/// Written BY HAND before the Expression emitters existed (§6.5
/// golden-first): every §6.1 collapse rule in one page (symmetric insets,
/// fromLTRB margin, named + custom alignment), in dart-format-canonical
/// layout. The G2 emitters must produce it.
///
/// NOTE: never compiled inside `canvas_core` (Flutter-free, §12 rule 6).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, undefined_function, undefined_identifier, undefined_super_member, creation_with_non_type
library;

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // align 'a1'.
      Align(alignment: Alignment.topCenter),
      // padding 'p1'.
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
      // container 'c1'.
      Container(margin: const EdgeInsets.fromLTRB(16, 8, 4, 2)),
      // align 'a2'.
      Align(alignment: Alignment(0.5, 0.25))
    ]);
  }
}
