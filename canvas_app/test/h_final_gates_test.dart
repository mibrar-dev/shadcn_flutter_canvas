/// Track H FINAL (BUILD_SPEC §11 gates 6–7): unit tests for the NEW
/// gate-harness pieces only — `tool/placeholder_scan.dart` pure core plus a
/// structural contract test over the NEW `canvas/.github` workflow.
///
/// Out of scope by allowlist: existing emitters, existing tests, lib/.
/// Placeholder-marker semantics are pinned here so a future emitter change
/// that alters marker text fails loudly instead of silently hollowing gate 7.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/placeholder_scan.dart' as scan;

void main() {
  group('H FINAL scanner: structural markers', () {
    test('AST (not yet bridged) marker hits with path + line', () {
      final hits = scan.hScanContent(
        'lib/pages/home_page.dart',
        'child: Text(\'chip (not yet bridged)\'),\n',
        const {},
      );
      expect(hits, hasLength(1));
      expect(hits.single.marker, 'ast-not-bridged');
      expect(hits.single.line, 1);
      expect(hits.single.path, 'lib/pages/home_page.dart');
    });

    test('single-file no-source marker hits', () {
      final hits = scan.hScanContent(
        'out.dart',
        '// TODO(canvas): no source for kind "chip"\nchild: Text(\'chip\'),\n',
        const {},
      );
      expect(
        hits.where((h) => h.marker == 'single-no-source'),
        hasLength(1),
      );
      expect(hits.first.line, 1);
    });

    test('legacy Text(kind) hits only for listed kinds', () {
      const body = '    Text(\'chip\'),\n';
      final listed = scan.hScanContent('s.dart', body, {'chip'});
      expect(listed, hasLength(1));
      expect(listed.single.marker, 'legacy-text');
      expect(listed.single.line, 1);
      final unlisted = scan.hScanContent('s.dart', body, {'alert'});
      expect(unlisted, isEmpty);
      final empty = scan.hScanContent('s.dart', body, const {});
      expect(empty, isEmpty);
    });

    test('clean emitter output yields zero hits', () {
      const clean = '''
Container(
  padding: const EdgeInsets.all(16),
  child: Text('Hello'),
)
''';
      expect(
        scan.hScanContent('s.dart', clean, scan.hDefaultLegacyKinds),
        isEmpty,
        reason: 'honest Text labels must not trip the scanner',
      );
    });

    test('line numbers track multi-line output', () {
      const body = 'a\nb\nText(\'alert\'),\nc\n';
      final hits = scan.hScanContent('s.dart', body, {'alert'});
      expect(hits.single.line, 3);
    });
  });

  group('H FINAL scanner: file-map aggregation', () {
    test('hits sort by path then line', () {
      final hits = scan.hScanFiles(
        {
          'b.dart': 'Text(\'chip\'),\n',
          'a.dart': 'x\nText(\'chip\'),\nText(\'chip\'),\n',
        },
        {'chip'},
      );
      expect(hits, hasLength(3));
      expect(hits[0].path, 'a.dart');
      expect(hits[0].line, 2);
      expect(hits[1].line, 3);
      expect(hits[2].path, 'b.dart');
    });

    test('default legacy set is exactly the G1 10-kind gap', () {
      expect(
        scan.hDefaultLegacyKinds,
        {
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
        },
      );
    });
  });

  group('H FINAL scanner: CLI arg parsing', () {
    test('defaults; unknown/valueless flags are infra errors', () {
      final def = scan.hScanParseArgs([]);
      expect(def['dir'], isEmpty);
      expect(def['ext'], 'dart');
      expect(
        scan.hScanParseArgs(['--bogus', 'x']).containsKey('error'),
        isTrue,
      );
      expect(
        scan.hScanParseArgs(['--dir']).containsKey('error'),
        isTrue,
      );
    });

    test('kinds parse to a trimmed set', () {
      final opts = scan.hScanParseArgs(['--dir', '/tmp/x', '--kinds', 'a, b']);
      expect(opts['dir'], '/tmp/x');
      expect(opts['kinds'], 'a, b');
    });
  });

  group('H FINAL CI workflow contract (canvas/.github)', () {
    File workflowFile() => File('../.github/workflows/canvas-gates.yml');

    test('workflow file exists in canvas scope (not parent ../.github)', () {
      expect(
        workflowFile().existsSync(),
        isTrue,
        reason: 'canvas/.github/workflows/canvas-gates.yml is the H FINAL '
            'CI deliverable; parent ../.github must stay untouched',
      );
    });

    test('workflow wires §11 repo gates 1–2 + drift/golden guards', () {
      final yml = workflowFile().readAsStringSync();
      for (final needle in [
        'name: canvas-gates',
        'workflow_dispatch',
        'flutter analyze --no-pub',
        'working-directory: canvas_core',
        'working-directory: canvas_app',
        'flutter test',
        'test/gen_registry_drift_test.dart',
        'test/primitives_f3_goldens_test.dart',
        'render_codegen_diff.dart --stage pure',
      ]) {
        expect(yml, contains(needle), reason: 'workflow must contain $needle');
      }
    });

    test('workflow has the four jobs with format-check non-blocking', () {
      final yml = workflowFile().readAsStringSync();
      for (final job in ['analyze:', 'test:', 'drift:', 'format-check:']) {
        expect(yml, contains(job), reason: 'missing job $job');
      }
      final formatIdx = yml.indexOf('format-check:');
      final tail = yml.substring(formatIdx, formatIdx + 300);
      expect(tail, contains('continue-on-error: true'));
    });
  });
}
