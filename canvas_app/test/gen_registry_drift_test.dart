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
/// canvas-ready set must equal bridges + bare-widget builds + the `row`
/// pseudo-kind exactly. A Track-J-style hand bridge that forgets the
/// generator update (or a stale generator entry) fails loudly here instead
/// of silently reverting on regen.
library;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/gen_registry.dart' as gen;

void main() {
  group('gen_registry drift guard', () {
    test('every catalog kind is a generator bridge kind', () {
      final missing = [
        for (final entry in kCatalog)
          if (!gen.bridgeKindsForTest.contains(entry.kind)) entry.kind,
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
      final expected = <String>{
        ...gen.bridgeKindsForTest,
        ...gen.readyKindsForTest.keys,
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

    test('pinned counts: 68 bridges + 10 bare builders + row = 79 ready', () {
      expect(gen.bridgeKindsForTest, hasLength(68));
      expect(gen.readyKindsForTest, hasLength(10));
      expect(kCatalog, hasLength(68));
      expect(
        [for (final e in kRegistry) if (e.canvasReady) e.kind],
        hasLength(79),
      );
    });
  });
}
