/// Track H0 (BUILD_SPEC §10): unit tests for the render-vs-codegen
/// screenshot-diff HARNESS pieces that do not need a browser.
///
/// Covers: fixture discovery, golden-path resolution, diff-threshold math,
/// verdict, report-format stability, CLI arg parsing, exit-code contract.
///
/// Browser stages (canvas screenshot, generated-project screenshot) are
/// intentionally NOT covered here — see
/// `tool/render_codegen_diff.dart` stage stubs + `docs/BUILD_H0_*`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/render_codegen_diff.dart' as h0;

void main() {
  group('H0 harness: fixture discovery', () {
    test('finds the json fixtures, sorted, excluding dart helpers', () {
      final dir = Directory(
        '../canvas_core/test/fixtures',
      ); // relative to canvas_app/
      // When run from canvas_app/ the relative dir exists; otherwise skip
      // rather than fail (harness must stay runnable from CI checkouts).
      if (!dir.existsSync()) return;
      final found = h0.h0DiscoverFixtures(dir);
      expect(found, isNotEmpty);
      expect(
        found.every((f) => f.path.endsWith('.json')),
        isTrue,
        reason: 'only *.json count as fixtures',
      );
      final paths = found.map((f) => f.path).toList();
      expect(paths, orderedEquals(paths..sort()));
      expect(
        paths.any((p) => p.endsWith('primitives_screen.json')),
        isTrue,
        reason: '§15 first-task fixture must be in the diff set',
      );
    });

    test('missing dir yields empty list, not an exception', () {
      expect(
        h0.h0DiscoverFixtures(Directory('/nonexistent-h0-fixtures')),
        isEmpty,
      );
    });
  });

  group('H0 harness: golden-path resolution', () {
    test('four artifacts per fixture, base name preserved', () {
      final sep = Platform.pathSeparator;
      final paths = h0.h0GoldenPaths(
        '${sep}tmp${sep}fx${sep}primitives_screen.json',
        '${sep}tmp${sep}out',
      );
      expect(paths.canvasPng,
          '${sep}tmp${sep}out${sep}primitives_screen.canvas.png');
      expect(paths.codegenPng,
          '${sep}tmp${sep}out${sep}primitives_screen.codegen.png');
      expect(
          paths.diffPng, '${sep}tmp${sep}out${sep}primitives_screen.diff.png');
      expect(paths.reportMd,
          '${sep}tmp${sep}out${sep}primitives_screen.report.md');
    });

    test('distinct fixtures never collide', () {
      final a = h0.h0GoldenPaths('a.json', '/out');
      final b = h0.h0GoldenPaths('b.json', '/out');
      expect(
        {a.canvasPng, a.codegenPng, a.diffPng, a.reportMd}
            .intersection({b.canvasPng, b.codegenPng, b.diffPng, b.reportMd}),
        isEmpty,
      );
    });
  });

  group('H0 harness: diff-threshold math', () {
    Uint8List rgba(List<int> bytes) => Uint8List.fromList(bytes);

    test('identical buffers: zero diff', () {
      final stats = h0.h0PixelDiff(rgba([10, 20, 30, 255, 0, 0, 0, 255]),
          rgba([10, 20, 30, 255, 0, 0, 0, 255]));
      expect(stats.pixelsCompared, 2);
      expect(stats.pixelsDifferent, 0);
      expect(stats.maxChannelDelta, 0);
      expect(stats.meanAbsDelta, 0);
      expect(stats.diffFraction, 0);
    });

    test('sub-tolerance noise does not count as different', () {
      final stats = h0.h0PixelDiff(
        rgba([100, 100, 100, 255]),
        rgba([100 + h0.h0DefaultPerPixelTolerance, 100, 100, 255]),
      );
      expect(stats.pixelsDifferent, 0,
          reason: 'delta == tolerance is noise, not a diff');
      expect(stats.maxChannelDelta, h0.h0DefaultPerPixelTolerance);
    });

    test('over-tolerance delta counts, alpha included', () {
      final stats = h0.h0PixelDiff(
        rgba([10, 10, 10, 255, 50, 50, 50, 255]),
        rgba([10, 10, 10, 200, 50, 50, 50, 255]),
      );
      expect(stats.pixelsDifferent, 1,
          reason: 'backdrop/alpha change must fail the diff, not hide in it');
      expect(stats.diffFraction, 0.5);
    });

    test('length mismatch: extra pixels count as different', () {
      final stats =
          h0.h0PixelDiff(rgba([1, 2, 3, 4]), rgba([1, 2, 3, 4, 9, 9, 9, 9]));
      expect(stats.pixelsCompared, 2);
      expect(stats.pixelsDifferent, 1);
    });

    test('empty buffers compare as zero pixels (caller treats as NOT-RUN)', () {
      final stats = h0.h0PixelDiff(rgba([]), rgba([]));
      expect(stats.pixelsCompared, 0);
      expect(stats.diffFraction, 1.0,
          reason: 'no signal must never read as PASS');
    });
  });

  group('H0 harness: verdict', () {
    test('at-or-under threshold passes, over fails', () {
      const stats = h0.H0DiffStats(
        pixelsCompared: 1000,
        pixelsDifferent: 10,
        maxChannelDelta: 9,
        meanAbsDelta: 0.1,
      );
      expect(h0.h0Verdict(stats, maxDiffFraction: 0.01), isTrue);
      expect(h0.h0Verdict(stats, maxDiffFraction: 0.009), isFalse);
    });
  });

  group('H0 harness: report format (byte-stable keys)', () {
    test('report contains the CI-parsed rows', () {
      const stats = h0.H0DiffStats(
        pixelsCompared: 4,
        pixelsDifferent: 1,
        maxChannelDelta: 55,
        meanAbsDelta: 3.5,
      );
      final report = h0.h0RenderReport(
        fixture: 'fx.json',
        paths: const h0.H0GoldenPaths(
          canvasPng: 'a',
          codegenPng: 'b',
          diffPng: 'c',
          reportMd: 'd',
        ),
        stats: stats,
        passed: false,
        perPixelTolerance: 8,
        maxDiffFraction: 0.01,
      );
      for (final key in [
        'Verdict: FAIL',
        '| pixelsCompared | 4 |',
        '| pixelsDifferent | 1 |',
        '| diffFraction |',
        '| maxChannelDelta | 55 |',
        '| meanAbsDelta | 3.5 |',
        '| perPixelTolerance | 8 |',
        '| maxDiffFraction | 0.01 |',
      ]) {
        expect(report, contains(key));
      }
    });
  });

  group('H0 harness: runHarness exit-code contract (H-FINAL-1)', () {
    test('--help resolves to pass without touching the filesystem', () async {
      expect(await h0.runHarness(['--help']), h0.H0Exit.pass);
    });

    test('unknown flags and missing fixtures resolve to infra-error', () async {
      expect(await h0.runHarness(['--bogus', 'x']), h0.H0Exit.infraError);
      final out = Directory.systemTemp.createTempSync('h0exit').path;
      expect(
        await h0.runHarness([
          '--stage',
          'pure',
          '--fixtures',
          '/nonexistent-h0-fixtures',
          '--out',
          out,
        ]),
        h0.H0Exit.infraError,
      );
    });

    test('pure stage scaffolds reports and resolves stage-unimplemented',
        () async {
      final dir = Directory('../canvas_core/test/fixtures');
      if (!dir.existsSync()) return;
      final out = Directory.systemTemp.createTempSync('h0pure').path;
      expect(
        await h0.runHarness([
          '--stage',
          'pure',
          '--fixtures',
          dir.path,
          '--out',
          out,
        ]),
        h0.H0Exit.stageNotImplemented,
      );
      expect(
        File('$out${Platform.pathSeparator}primitives_screen.report.md')
            .existsSync(),
        isTrue,
        reason: 'pure stage scaffolds one report per fixture',
      );
    });
  });

  group('H0 harness: CLI + exit codes', () {
    test('defaults parse; unknown/valueless flags are infra errors', () {
      final def = h0.h0ParseArgs([]);
      expect(def['stage'], 'pure');
      expect(def['per-pixel-tolerance'], '${h0.h0DefaultPerPixelTolerance}');
      expect(h0.h0ParseArgs(['--bogus', 'x']).containsKey('error'), isTrue);
      expect(h0.h0ParseArgs(['--stage']).containsKey('error'), isTrue);
    });

    test('exit-code contract is stable', () {
      expect(h0.H0Exit.pass, 0);
      expect(h0.H0Exit.diffOverThreshold, 1);
      expect(h0.H0Exit.infraError, 2);
      expect(h0.H0Exit.stageNotImplemented, 3);
    });

    test('stage stubs name their output PNG so operators can fill them', () {
      const paths = h0.H0GoldenPaths(
        canvasPng: 'prim.canvas.png',
        codegenPng: 'prim.codegen.png',
        diffPng: 'prim.diff.png',
        reportMd: 'prim.report.md',
      );
      expect(
        h0.h0StageAInstructions(paths, 'fx.json'),
        contains('prim.canvas.png'),
      );
      expect(
        h0.h0StageBInstructions(paths, 'fx.json'),
        contains('prim.codegen.png'),
      );
    });
  });
}
