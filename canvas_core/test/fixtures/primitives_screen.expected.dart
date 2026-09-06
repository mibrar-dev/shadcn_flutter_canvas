/// Hand-written golden for `primitives_screen.json` (Track F, §7.5).
///
/// Written BY HAND before any primitive emitter existed (§6.5
/// golden-first discipline): this is the Dart a senior developer would
/// ship for the fixture tree, and the F3 emitters must produce it — never
/// the reverse.
///
/// NOTE: this file is never compiled inside `canvas_core` (which is
/// Flutter-free by design, §12 rule 6 — there is no Flutter SDK here to
/// resolve `package:flutter/material.dart` against). The ignore below is
/// the same non-compiled-file mechanism the exporters emit
/// (`// ignore_for_file: unused_import` in bundle screens).
// ignore_for_file: uri_does_not_exist, extends_non_class, super_formal_parameter_without_associated_named, undefined_class, override_on_non_overriding_member, undefined_method, creation_with_non_type, undefined_identifier
///
/// Rule demonstrations to preserve (BUILD_SPEC §6.1–§6.2):
/// * `fromLTRB` → `.all`: the uniform 20px padding collapses to
///   `const EdgeInsets.all(20)`.
/// * Uniform radius → `.circular`: the 16px corners collapse to
///   `BorderRadius.circular(16)`.
/// * Alignment → named constant: the gradient begin/end pairs collapse to
///   `Alignment.centerLeft` / `Alignment.centerRight`.
/// * §6.2 `Container` merge: `color` + `radius` + `gradient` fuse into ONE
///   `BoxDecoration` (a `Container` takes `color:` XOR `decoration:`,
///   never both).
/// * Token accessors, never hexes: `Theme.of(context).colorScheme.*`.
/// * `const` insertion: `const EdgeInsets.all(20)`; the `BoxDecoration`
///   stays non-`const` because it reads the theme.
library;

import 'package:flutter/material.dart';

/// The §7.5 definition-of-done screen, as a shippable widget.
class PrimitivesScreen extends StatelessWidget {
  const PrimitivesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prim')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Avatar(initials: 'AK', size: 40.0),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Text('Ada K'),
                      const SizedBox(height: 4),
                      Text('Engineer'),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  const SizedBox(width: 8),
                  SecondaryBadge(child: Text('Pro')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Column(
                children: [
                  Card(child: Text('Card 1')),
                  const SizedBox(height: 12),
                  Card(child: Text('Card 2')),
                  const SizedBox(height: 12),
                  Card(child: Text('Card 3')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
