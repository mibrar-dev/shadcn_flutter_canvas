// Render-vs-codegen screenshot-diff harness — SKELETON (Track H0 prep).
//
// BUILD_SPEC §10: "Per fixture: screenshot the canvas render, compile +
// screenshot the generated output, diff. This is the highest-value test in
// the project and the one everyone skips."
//
// Three-stage pipeline:
//
//   Stage A (canvas render):  fixture .json -> canvas_app renders it ->
//                             screenshot  -> <base>.canvas.png
//   Stage B (generated out):  fixture .json -> codegen_bundle project ->
//                             `flutter build web` -> headless-Chrome
//                             screenshot    -> <base>.codegen.png
//   Stage C (diff):           pixel-compare A vs B -> <base>.diff.png +
//                             <base>.report.md, exit code per verdict.
//
// H0 STATUS: stages A and B need a browser / Flutter toolchain at run time
// and are DOCUMENTED STUBS here (see [h0StageAInstructions] /
// [h0StageBInstructions]). Everything that does NOT need a browser is
// IMPLEMENTED and unit-tested by
// `canvas_app/test/h0_diff_harness_test.dart`:
// fixture discovery, golden-path resolution, diff-threshold math, verdict,
// report format, exit codes.
//
// Usage (pure stages only — works today, no browser):
//   `dart run tool/render_codegen_diff.dart --stage pure \
//      --fixtures ../canvas_core/test/fixtures --out /tmp/h0diff`
//
// Full pipeline (after H-final implements the browser stages):
//   `dart run tool/render_codegen_diff.dart --stage all \
//      --fixtures ../canvas_core/test/fixtures --out /tmp/h0diff`
//
// Do NOT wire into CI as a required check yet (cutover is after the FF7
// cutover per §10). See `docs/BUILD_H0_HARDENING_PREP.md` for the manual
// runbook and the future CI snippet.
//
// Plain `dart run` (no Flutter imports): like tool/gen_registry.dart this
// file imports only dart:* plus package:canvas_core.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// CLI exit codes (stable contract — CI will switch on these).
class H0Exit {
  H0Exit._();
  static const int pass = 0;
  static const int diffOverThreshold = 1;
  static const int infraError = 2;
  static const int stageNotImplemented = 3;
}

/// Per-pixel channel tolerance default (0-255 scale).
const int h0DefaultPerPixelTolerance = 8;

/// Maximum fraction of differing pixels before the verdict fails.
const double h0DefaultMaxDiffFraction = 0.01;

/// Discovers diff fixtures: `*.json` files (sorted) directly under [dir].
///
/// Only ScreenDoc JSON fixtures count; `*.expected.dart` goldens and helper
/// files (e.g. `two_screen_doc.dart`) are excluded by the extension filter.
List<File> h0DiscoverFixtures(Directory dir) {
  if (!dir.existsSync()) return <File>[];
  final out = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return out;
}

/// Resolved output paths for one fixture through the 3-stage pipeline.
class H0GoldenPaths {
  const H0GoldenPaths({
    required this.canvasPng,
    required this.codegenPng,
    required this.diffPng,
    required this.reportMd,
  });
  final String canvasPng;
  final String codegenPng;
  final String diffPng;
  final String reportMd;
}

/// Maps `…/<base>.json` + [outDir] to the four stage artifacts.
///
/// `<base>` is the fixture file name without extension.
H0GoldenPaths h0GoldenPaths(String fixturePath, String outDir) {
  final base = fixturePath.split(Platform.pathSeparator).last.replaceAll(
        RegExp(r'\.json$'),
        '',
      );
  String join(String name) => outDir.endsWith(Platform.pathSeparator)
      ? '$outDir$name'
      : '$outDir${Platform.pathSeparator}$name';
  return H0GoldenPaths(
    canvasPng: join('$base.canvas.png'),
    codegenPng: join('$base.codegen.png'),
    diffPng: join('$base.diff.png'),
    reportMd: join('$base.report.md'),
  );
}

/// Summary statistics of a raw-RGBA pixel comparison.
class H0DiffStats {
  const H0DiffStats({
    required this.pixelsCompared,
    required this.pixelsDifferent,
    required this.maxChannelDelta,
    required this.meanAbsDelta,
  });
  final int pixelsCompared;
  final int pixelsDifferent;
  final int maxChannelDelta;
  final double meanAbsDelta;

  double get diffFraction =>
      pixelsCompared == 0 ? 1.0 : pixelsDifferent / pixelsCompared;

  Map<String, Object> toJson() => <String, Object>{
        'pixelsCompared': pixelsCompared,
        'pixelsDifferent': pixelsDifferent,
        'diffFraction': diffFraction,
        'maxChannelDelta': maxChannelDelta,
        'meanAbsDelta': meanAbsDelta,
      };
}

/// Compares two raw RGBA buffers ([a] vs [b], 4 bytes/pixel).
///
/// A pixel "differs" when any channel differs by more than [perPixelTolerance]
/// (anti-aliasing / compositor noise guard). Length mismatch compares the
/// overlap and counts every extra pixel as different. Alpha is compared like
/// any other channel — a backdrop change must fail the diff, not hide in it.
H0DiffStats h0PixelDiff(
  Uint8List a,
  Uint8List b, {
  int perPixelTolerance = h0DefaultPerPixelTolerance,
}) {
  final pixelCount = math.max(a.length, b.length) ~/ 4;
  if (pixelCount == 0) {
    return const H0DiffStats(
      pixelsCompared: 0,
      pixelsDifferent: 0,
      maxChannelDelta: 0,
      meanAbsDelta: 0,
    );
  }
  var different = 0;
  var maxDelta = 0;
  var absSum = 0;
  var samples = 0;
  for (var p = 0; p < pixelCount; p++) {
    var pixelDiffers = false;
    for (var c = 0; c < 4; c++) {
      final i = p * 4 + c;
      final va = i < a.length ? a[i] : 0;
      final vb = i < b.length ? b[i] : 0;
      final d = (va - vb).abs();
      absSum += d;
      samples++;
      if (d > maxDelta) maxDelta = d;
      if (d > perPixelTolerance) pixelDiffers = true;
    }
    if (pixelDiffers) different++;
  }
  return H0DiffStats(
    pixelsCompared: pixelCount,
    pixelsDifferent: different,
    maxChannelDelta: maxDelta,
    meanAbsDelta: samples == 0 ? 0 : absSum / samples,
  );
}

/// PASS when the differing-pixel fraction is at or under [maxDiffFraction].
bool h0Verdict(
  H0DiffStats stats, {
  double maxDiffFraction = h0DefaultMaxDiffFraction,
}) =>
    stats.diffFraction <= maxDiffFraction;

/// Renders the per-fixture markdown report (stable schema — CI parses the
/// `| key | value |` rows; keep the keys byte-stable).
String h0RenderReport({
  required String fixture,
  required H0GoldenPaths paths,
  required H0DiffStats stats,
  required bool passed,
  required int perPixelTolerance,
  required double maxDiffFraction,
}) {
  final buf = StringBuffer()
    ..writeln('# H0 render-vs-codegen diff — $fixture')
    ..writeln()
    ..writeln('Verdict: ${passed ? 'PASS' : 'FAIL'}')
    ..writeln()
    ..writeln('| key | value |')
    ..writeln('|---|---|')
    ..writeln('| fixture | $fixture |')
    ..writeln('| canvasPng | ${paths.canvasPng} |')
    ..writeln('| codegenPng | ${paths.codegenPng} |')
    ..writeln('| diffPng | ${paths.diffPng} |')
    ..writeln('| pixelsCompared | ${stats.pixelsCompared} |')
    ..writeln('| pixelsDifferent | ${stats.pixelsDifferent} |')
    ..writeln('| diffFraction | ${stats.diffFraction} |')
    ..writeln('| maxChannelDelta | ${stats.maxChannelDelta} |')
    ..writeln('| meanAbsDelta | ${stats.meanAbsDelta} |')
    ..writeln('| perPixelTolerance | $perPixelTolerance |')
    ..writeln('| maxDiffFraction | $maxDiffFraction |');
  return buf.toString();
}

/// Stage A stub — manual steps until H-final automates the screenshot.
///
/// Why manual: screenshotting the canvas render needs a running canvas_app
/// (Flutter Web) plus a capture driver (integration_test + headless Chrome);
/// neither is wired in H0. The operator runs these steps and drops the PNG
/// at [paths.canvasPng], then re-runs with `--stage pure`.
String h0StageAInstructions(H0GoldenPaths paths, String fixturePath) =>
    'STAGE A (manual in H0): `flutter run -d chrome` in canvas_app/, load '
    'fixture $fixturePath in the gallery/seed view, screenshot the device '
    'frame content only (no chrome), save as ${paths.canvasPng}.';

/// Stage B stub — manual steps until H-final automates the build+screenshot.
///
/// Why manual: needs the G-track project writer (§8.4 output shape) plus
/// `flutter build web` on the generated project plus headless-Chrome capture.
String h0StageBInstructions(H0GoldenPaths paths, String fixturePath) =>
    'STAGE B (manual in H0): export fixture $fixturePath via codegen_bundle '
    'to a scratch project, `flutter build web`, serve + screenshot with '
    'headless Chrome at the same device size as Stage A, save as '
    '${paths.codegenPng}.';

void _usage() {
  stdout.writeln('''
render_codegen_diff.dart — H0 render-vs-codegen diff skeleton.

  --fixtures <dir>        fixture dir (default: ../canvas_core/test/fixtures)
  --out <dir>             artifact dir (default: <system-temp>/h0diff)
  --stage pure|all        pure = discovery + report scaffolding only (works
                          today); all = also require stage PNGs + diff them
  --per-pixel-tolerance N channel tolerance 0-255 (default $h0DefaultPerPixelTolerance)
  --max-diff-fraction F   fail threshold 0-1 (default $h0DefaultMaxDiffFraction)
  --help                  this text

Exit codes: ${H0Exit.pass}=pass ${H0Exit.diffOverThreshold}=diff-over-threshold
${H0Exit.infraError}=infra-error ${H0Exit.stageNotImplemented}=stage-unimplemented
''');
}

/// Minimal `--key value` / `--flag` parsing (no package:args — zero deps).
Map<String, String> h0ParseArgs(List<String> args) {
  final out = <String, String>{
    'fixtures': '../canvas_core/test/fixtures',
    'out': '${Directory.systemTemp.path}${Platform.pathSeparator}h0diff',
    'stage': 'pure',
    'per-pixel-tolerance': '$h0DefaultPerPixelTolerance',
    'max-diff-fraction': '$h0DefaultMaxDiffFraction',
  };
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--help' || a == '-h') {
      out['help'] = 'true';
      continue;
    }
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    if (!out.containsKey(key)) {
      out['error'] = 'unknown flag: $a';
      return out;
    }
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      out['error'] = 'flag $a needs a value';
      return out;
    }
    out[key] = args[++i];
  }
  return out;
}

Future<int> main(List<String> args) async {
  final opts = h0ParseArgs(args);
  if (opts.containsKey('help')) {
    _usage();
    return H0Exit.pass;
  }
  if (opts.containsKey('error')) {
    stderr.writeln(opts['error']);
    _usage();
    return H0Exit.infraError;
  }
  final perPixelTolerance =
      int.tryParse(opts['per-pixel-tolerance']!) ?? h0DefaultPerPixelTolerance;
  final maxDiffFraction =
      double.tryParse(opts['max-diff-fraction']!) ?? h0DefaultMaxDiffFraction;
  final fixtures = h0DiscoverFixtures(Directory(opts['fixtures']!));
  if (fixtures.isEmpty) {
    stderr.writeln('no fixtures in ${opts['fixtures']}');
    return H0Exit.infraError;
  }
  await Directory(opts['out']!).create(recursive: true);
  var worst = H0Exit.pass;
  for (final fixture in fixtures) {
    final paths = h0GoldenPaths(fixture.path, opts['out']!);
    final canvas = File(paths.canvasPng);
    final codegen = File(paths.codegenPng);
    if (opts['stage'] == 'pure' ||
        !canvas.existsSync() ||
        !codegen.existsSync()) {
      stdout.writeln(h0StageAInstructions(paths, fixture.path));
      stdout.writeln(h0StageBInstructions(paths, fixture.path));
      // Scaffold an empty report so the artifact layout is reviewable.
      await File(paths.reportMd).writeAsString(
        '# H0 render-vs-codegen diff — ${fixture.path}\n\n'
        'Verdict: NOT-RUN (stage PNGs absent; see stage instructions above)\n',
      );
      worst = H0Exit.stageNotImplemented;
      continue;
    }
    final stats = h0PixelDiff(
      Uint8List.fromList(await canvas.readAsBytes()),
      Uint8List.fromList(await codegen.readAsBytes()),
      perPixelTolerance: perPixelTolerance,
    );
    final passed = h0Verdict(stats, maxDiffFraction: maxDiffFraction);
    await File(paths.reportMd).writeAsString(
      h0RenderReport(
        fixture: fixture.path,
        paths: paths,
        stats: stats,
        passed: passed,
        perPixelTolerance: perPixelTolerance,
        maxDiffFraction: maxDiffFraction,
      ),
    );
    stdout.writeln(
      jsonEncode({
        'fixture': fixture.path,
        'passed': passed,
        ...stats.toJson(),
      }),
    );
    if (!passed) worst = H0Exit.diffOverThreshold;
  }
  return worst;
}
