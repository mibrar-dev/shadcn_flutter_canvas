/// Hand-written golden for `g3_text_area.json` (Track G3).
///
/// Written BY HAND before the G3 emitters existed (§6.5 golden-first):
/// mirrors the canvas `buildTextAreaEntry` registry builder (a non-empty
/// `label` renders as a caption above the field — the same caption rhythm
/// as the input catalog builder; `TextArea` itself takes only
/// `placeholder:` + `enabled:`). `text_area` is a TextField-variant
/// controller kind, so the page is Stateful + model (see the `_model`
/// golden); the body stays a static snapshot with no controller reference
/// (the honesty rule from G1 §1.3.6). Multi-arg invocations,
/// dart-format-canonical full splits.
///
/// NOTE: never compiled inside `canvas_core` (Flutter-free, §12 rule 6).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, undefined_function, undefined_identifier, undefined_super_member, creation_with_non_type
library;

import 'package:flutter/material.dart';
import 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart'
    hide Column, Expanded, Flex, Flexible, Positioned, Row, Stack, Theme;
import 'home_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeModel model;

  @override
  void initState() {
    super.initState();
    model = HomeModel();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About'),
        SizedBox(height: 6),
        TextArea(
          placeholder: Text('Bio'),
          enabled: true,
        ),
      ],
    );
  }
}
