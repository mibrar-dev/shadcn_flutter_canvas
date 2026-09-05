/// Track Q (search-match reconcile) behavior tests for [registryMatchesQuery].
///
/// Decided semantics: KIND-ONLY word-start matching. Every
/// whitespace-separated query token must prefix-match a word start in the
/// entry kind id; manifest descriptions/labels are deliberately NOT matched
/// (palette tiles show humanized kind ids, so kind-word matching is exactly
/// what the user sees).
///
/// These tests pin behavior, not registry contents: another wave is
/// concurrently ADDING entries, so there are no count pins and no exact
/// hit-set pins — only contains / not-contains on long-standing kinds, plus
/// synthetic entries that pin the semantics even if the registry set shifts.
library;

import 'package:canvas_app/canvas/component_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic entry so kind-vs-label semantics hold independent of registry
/// contents (kind set + descriptions may shift under concurrent edits).
RegistryEntry _entry(String kind, String label) => RegistryEntry(
  kind: kind,
  label: label,
  section: 'Display',
  icon: Icons.widgets,
  build: (_) => const SizedBox(),
  canvasReady: false,
);

/// Kinds in the live registry matching [query] (no count pins).
List<String> _hits(String query) => [
  for (final entry in kRegistry)
    if (registryMatchesQuery(entry, query)) entry.kind,
];

void main() {
  group('registryMatchesQuery behavior (Track Q: kind-only)', () {
    test("'card' finds the card kind", () {
      final card = findRegistryEntry('card');
      expect(card, isNotNull, reason: 'card kind exists');
      expect(registryMatchesQuery(card!, 'card'), isTrue);
      expect(_hits('card'), contains('card'));
    });

    test("compound kinds match per word: 'card' hits 'card_image' via kind", () {
      // NOT label over-matching: 'card_image' splits on '_' into
      // [card, image] and its tile shows 'Card Image', so 'card' (and
      // 'image', and 'card image') must match under kind-only semantics.
      final cardImage = findRegistryEntry('card_image');
      final target = cardImage ?? _entry('card_image', 'Interactive card.');
      expect(registryMatchesQuery(target, 'card'), isTrue);
      expect(registryMatchesQuery(target, 'image'), isTrue);
      expect(registryMatchesQuery(target, 'card image'), isTrue);
    });

    test('matching is case-insensitive', () {
      final card = findRegistryEntry('card');
      expect(card, isNotNull, reason: 'card kind exists');
      expect(registryMatchesQuery(card!, 'CARD'), isTrue);
      expect(registryMatchesQuery(card, 'Card'), isTrue);
      expect(registryMatchesQuery(card, 'cArD'), isTrue);
    });

    test('multi-word queries require every token to match', () {
      final radio = findRegistryEntry('radio_group');
      final target = radio ?? _entry('radio_group', 'Exclusive selection.');
      expect(registryMatchesQuery(target, 'radio'), isTrue);
      expect(registryMatchesQuery(target, 'group'), isTrue);
      expect(registryMatchesQuery(target, 'radio group'), isTrue);
      expect(registryMatchesQuery(target, '  radio   group  '), isTrue);
      expect(registryMatchesQuery(target, 'radio button'), isFalse);
    });

    test('prefix matching, not substring', () {
      final button = findRegistryEntry('button');
      expect(button, isNotNull, reason: 'button kind exists');
      expect(registryMatchesQuery(button!, 'but'), isTrue);
      expect(registryMatchesQuery(button, 'utton'), isFalse);
    });

    test('empty / blank query matches everything', () {
      expect(kRegistry, isNotEmpty);
      for (final entry in kRegistry) {
        expect(registryMatchesQuery(entry, ''), isTrue, reason: entry.kind);
        expect(
          registryMatchesQuery(entry, '   '),
          isTrue,
          reason: entry.kind,
        );
      }
    });

    test('non-matching query matches nothing', () {
      expect(_hits('zzz-no-such-part-q'), isEmpty);
    });

    test("kind-only: 'chip' must not hit Filter Bar via its 'chips' blurb", () {
      final synth = _entry(
        'filter_bar',
        'Controlled filter toolbar for list pages with search, sort, chips, '
            'date range, and clear-all.',
      );
      expect(registryMatchesQuery(synth, 'chip'), isFalse);
      final real = findRegistryEntry('filter_bar');
      if (real != null) {
        expect(
          registryMatchesQuery(real, 'chip'),
          isFalse,
          reason: 'live filter_bar description must not match chip',
        );
      }
      expect(_hits('chip'), contains('chip'));
      expect(_hits('chip'), isNot(contains('filter_bar')));
    });

    test("kind-only: 'card' must not hit Feature Carousel via its blurb", () {
      // Tile shows 'Feature Carousel' (no 'card' word); the 'card' in
      // 'Animated feature card carousel ...' must not match. Same class as
      // Tab Pane's '... content card.' blurb.
      final synth = _entry(
        'feature_carousel',
        'Animated feature card carousel with autoplay, swipe, and CTA '
            'support. (WIP)',
      );
      expect(registryMatchesQuery(synth, 'card'), isFalse);
      final real = findRegistryEntry('feature_carousel');
      if (real != null) {
        expect(
          registryMatchesQuery(real, 'card'),
          isFalse,
          reason: 'live feature_carousel description must not match card',
        );
      }
      expect(_hits('card'), isNot(contains('feature_carousel')));
    });
  });
}
