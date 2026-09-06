/// Hand-written golden for `g2_model_split.json` (Track G2).
///
/// Written BY HAND before the Expression emitters existed (§6.5
/// golden-first): the §8.4 Widget/Model split (stateful kinds present →
/// StatefulWidget + LoginModel with controller + bool field, initState /
/// dispose wired). Unknown kinds stay honest placeholders (G3 migrates
/// them). The G2 emitters must produce it.
///
/// NOTE: never compiled inside `canvas_core` (Flutter-free, §12 rule 6).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, undefined_function, undefined_identifier, undefined_super_member, creation_with_non_type
library;

import 'package:flutter/material.dart';
import 'login_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginModel model;

  @override
  void initState() {
    super.initState();
    model = LoginModel();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // text_field 'email'.
      const Text('text_field (not yet bridged)'),
      // switch 'rememberMe'.
      const Text('switch (not yet bridged)'),
      // container 'c1'.
      Container(color: Theme.of(context).colorScheme.secondary)
    ]);
  }
}
