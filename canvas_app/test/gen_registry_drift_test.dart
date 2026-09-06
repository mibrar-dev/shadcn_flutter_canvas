/// Track O regen-drift guard: `tool/gen_registry.dart` must know every
/// catalog-bridged registry kind, or a future regen reverts hand-built
/// bridges to [RegistryPlaceholder]s.
///
/// Mechanism: `tool/gen_registry.dart` is pure Dart (only `dart:convert` /
/// `dart:io`), so this test imports it directly via the test-visible
/// aliases `bridgeKindsForTest` / `readyKindsForTest` (the private
/// `_bridgeKinds` / `_readyKinds` are library-scoped and cannot be imported)
/// and cross-checks them against the importable registry + catalog surface:
/// every catalog kind must be a generator bridge kind, and the registry's
/// canvas-ready set must equal bridges + bare-widget builds exactly (Track F:
/// `row` is a bridge kind now, not a special case). A Track-J-style hand
/// generator update (or a stale generator entry) fails loudly here instead
/// of silently reverting on regen.
///
/// TRACK Y1 EXEMPTION (2026-09-06): `navigation_bar` was promoted to a real
/// catalog bridge while `tool/gen_registry.dart` is frozen for this track, so
/// it is exempted via [kFrozenTrackKinds] below instead of gaining a
/// `_bridgeKinds` entry. DEBT: before the next regen, add `'navigation_bar'`
/// to `_bridgeKinds` in `tool/gen_registry.dart` (one line, Track J/M/P
/// precedent) and delete the exemption — otherwise the regen reverts the
/// registry bridge to a [RegistryPlaceholder].
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/gen_registry.dart' as gen;

/// Catalog kinds with real bridges that the frozen generator does not know
/// yet (see the file header). Track F retired the Track Y1 exemption:
/// `navigation_bar` is a `_bridgeKinds` entry now (a regen preserves it),
/// and the ten layout primitives are bridges too — so this set is empty.
/// Kept (empty) so a future frozen-track exemption still fails loudly if it
/// forgets the generator update.
const kFrozenTrackKinds = <String>{};

void main() {
  group('gen_registry drift guard', () {
    test('every catalog kind is a generator bridge kind', () {
      final missing = [
        for (final entry in kCatalog)
          if (!gen.bridgeKindsForTest.contains(entry.kind) &&
              !kFrozenTrackKinds.contains(entry.kind))
            entry.kind,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'catalog kinds missing from _bridgeKinds in tool/gen_registry.dart '
            '(a regen would revert them to placeholders): $missing',
      );
    });

    test('generator bridge kinds all exist and are canvas-ready', () {
      for (final kind in gen.bridgeKindsForTest) {
        final reg = findRegistryEntry(kind);
        expect(reg, isNotNull, reason: 'stale bridge kind $kind');
        expect(reg!.canvasReady, isTrue, reason: 'bridge kind $kind');
      }
    });

    test('registry canvas-ready set matches generator allowlists exactly', () {
      // Track F: `row` is a bridge kind now (one of the ten primitives), so
      // the literal below is redundant but kept as documentation.
      final expected = <String>{
        ...gen.bridgeKindsForTest,
        ...gen.readyKindsForTest.keys,
        ...kFrozenTrackKinds,
        'row',
      };
      final actual = <String>{
        for (final entry in kRegistry)
          if (entry.canvasReady) entry.kind,
      };
      expect(
        actual,
        expected,
        reason:
            'drift: hand-built registry bridges/bare builders vs generator '
            'allowlists. New bridge? Add it to _bridgeKinds in '
            'tool/gen_registry.dart. Removed kind? Remove it there too. '
            'actual-only: ${actual.difference(expected)}; '
            'generator-only: ${expected.difference(actual)}',
      );
    });

    test('pinned counts: 107 bridges + 10 bare builders = 117 ready', () {
      expect(gen.bridgeKindsForTest, hasLength(107));
      expect(gen.readyKindsForTest, hasLength(10));
      expect(kCatalog, hasLength(107));
      expect(kFrozenTrackKinds, isEmpty);
      expect(
        [for (final e in kRegistry) if (e.canvasReady) e.kind],
        hasLength(117),
      );
    });
  });
}
