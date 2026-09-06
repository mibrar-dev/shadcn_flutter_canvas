// Track H FINAL (BUILD_SPEC §11 gate 7): black-box placeholder scanner over
// GENERATED output text ("zero placeholder emissions").
//
// Why a separate tool instead of extending `render_codegen_diff.dart`: that
// file is frozen under other tracks this batch; this extension only READS
// generated output and adds no exporter dependency (dart:* only).
//
// Markers (each cites its emitter — the scan never imports the exporters):
// - `(not yet bridged)` — G2 AST path `placeholderFor` in
//   `canvas_core/lib/src/emit/widget_emitter.dart`.
// - `TODO(canvas): no source for kind` — single-file path in
//   `canvas_core/lib/src/codegen_single.dart` (both inline sites).
// - `Text('<kind>'),` — legacy bundle `_bundleBody` default branch in
//   `canvas_core/lib/src/codegen_bundle.dart`, which emits exactly
//   `Text(<label>),` with the label defaulting to the kind. Needs the kind
//   list (CLI `--kinds`, default [hDefaultLegacyKinds]).
//
// Pure core (`hScanContent` / `hScanFiles`) is unit-tested by
// `test/h_final_gates_test.dart` (no I/O). The CLI walks `--dir` and calls
// `exit()` explicitly — `main`'s return value is NOT a process exit code on
// the Dart VM (see docs/BUILD_H_FINAL.md filed issue H-FINAL-1), so the
// `H0Exit`-style int-return contract is deliberately not repeated here.
//
// Usage:
//   dart run tool/placeholder_scan.dart --dir /tmp/genout
//   dart run tool/placeholder_scan.dart --dir /tmp/genout --kinds chip,alert
//
// Exit codes: 0 = no placeholders, 1 = placeholders found, 2 = infra error.
import 'dart:io';

/// G1's 10-kind gap (BUILD_G1_DESIGN.md §5): registry-ready kinds that render
/// on canvas but still export as legacy `Text` placeholders at H-FINAL time.
const hDefaultLegacyKinds = <String>{
  'chip',
  'alert',
  'circular_progress_indicator',
  'linear_progress_indicator',
  'triple_dots',
  'dot_indicator',
  'empty_state',
  'code_snippet',
  'number_ticker',
  'text_area',
};

/// One placeholder emission found in generated output.
class HPlaceholderHit {
  const HPlaceholderHit({
    required this.path,
    required this.line,
    required this.marker,
    required this.text,
  });

  /// Generated file path (as given in the scanned file map).
  final String path;

  /// 1-based line number.
  final int line;

  /// One of `ast-not-bridged`, `single-no-source`, `legacy-text`.
  final String marker;

  /// Trimmed source line.
  final String text;
}

/// Scans one generated file's [content] for placeholder emissions.
///
/// [legacyKinds] enables the ambiguous legacy-bundle check: only kinds in
/// the set match `Text('<kind>'),` (an honest `Text('chip')` label written
/// by the user would otherwise false-positive — the set bounds that risk
/// to known-gap kinds).
List<HPlaceholderHit> hScanContent(
  String path,
  String content,
  Set<String> legacyKinds,
) {
  final hits = <HPlaceholderHit>[];
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (line.contains('(not yet bridged)')) {
      hits.add(HPlaceholderHit(
        path: path,
        line: i + 1,
        marker: 'ast-not-bridged',
        text: trimmed,
      ));
      continue;
    }
    if (line.contains('TODO(canvas): no source for kind')) {
      hits.add(HPlaceholderHit(
        path: path,
        line: i + 1,
        marker: 'single-no-source',
        text: trimmed,
      ));
      continue;
    }
    for (final kind in legacyKinds) {
      if (line.contains("Text('$kind'),")) {
        hits.add(HPlaceholderHit(
          path: path,
          line: i + 1,
          marker: 'legacy-text',
          text: trimmed,
        ));
        break;
      }
    }
  }
  return hits;
}

/// Scans a generated project ([path] → file text), sorted by path then line.
List<HPlaceholderHit> hScanFiles(
  Map<String, String> files,
  Set<String> legacyKinds,
) {
  final paths = files.keys.toList()..sort();
  final hits = <HPlaceholderHit>[];
  for (final path in paths) {
    hits.addAll(hScanContent(path, files[path]!, legacyKinds));
  }
  return hits;
}

void _usage() {
  stdout.writeln('''
placeholder_scan.dart — H FINAL gate-7 scanner over GENERATED output.

  --dir <dir>             generated project dir to scan (required)
  --kinds a,b,c           legacy Text('<kind>') kinds (default: G1 10-kind gap)
  --ext dart              only scan this extension (default: dart)
  --help                  this text

Exit codes: 0=no placeholders 1=placeholders found 2=infra error
''');
}

/// Minimal `--key value` parsing (no package:args — zero deps, H0 idiom).
Map<String, String> hScanParseArgs(List<String> args) {
  final out = <String, String>{
    'dir': '',
    'kinds': hDefaultLegacyKinds.join(','),
    'ext': 'dart',
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

Future<void> main(List<String> args) async {
  final opts = hScanParseArgs(args);
  if (opts.containsKey('help')) {
    _usage();
    exit(0);
  }
  if (opts.containsKey('error')) {
    stderr.writeln(opts['error']);
    _usage();
    exit(2);
  }
  final dir = Directory(opts['dir']!);
  if (opts['dir']!.isEmpty || !dir.existsSync()) {
    stderr.writeln('generated dir missing: ${opts['dir']}');
    exit(2);
  }
  final kinds = opts['kinds']!
      .split(',')
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty)
      .toSet();
  final ext = opts['ext']!;
  final files = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.$ext')) continue;
    try {
      files[entity.path] = entity.readAsStringSync();
    } on FileSystemException catch (e) {
      stderr.writeln('unreadable file ${entity.path}: $e');
      exit(2);
    }
  }
  if (files.isEmpty) {
    stderr.writeln('no .$ext files under ${opts['dir']}');
    exit(2);
  }
  final hits = hScanFiles(files, kinds);
  for (final hit in hits) {
    stdout.writeln(
      '${hit.path}:${hit.line} [${hit.marker}] ${hit.text}',
    );
  }
  stdout.writeln(
    'placeholder_scan: ${hits.length} hit(s) in ${files.length} file(s)',
  );
  exit(hits.isEmpty ? 0 : 1);
}
