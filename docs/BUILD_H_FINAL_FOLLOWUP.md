# H-FINAL-2 follow-up: legacy bundle screen indent (DEFERRED, not fixed)

Status: **deferred by the H-final closeout batch** — output left untouched,
no goldens changed. Owner: G-track (the G2 `code_builder` migration is the
structural fix, as filed in `docs/BUILD_H_FINAL.md` §7 H-FINAL-2).

## Verdict

The gate-3 probe still fails on the legacy bundle path after the FF/G waves
landed, and a small emitter tweak does NOT close it. Per the closeout
brief's blast-radius rule (>~3 goldens → defer, don't chase), the fix is
deferred to the G2 migration; this doc records the evidence so the owning
track can reproduce in minutes.

## Reproduction (exact, repo-clean — all writes go to /tmp)

```sh
cd canvas/canvas_core
cat > /tmp/genprobe.dart <<'EOF'
import 'dart:convert';
import 'dart:io';
import 'package:canvas_core/canvas_core.dart';
Future<void> main() async {
  final doc = ScreenDoc.fromJson(jsonDecode(
      File('test/fixtures/primitives_screen.json').readAsStringSync())
      as Map<String, dynamic>);
  final bundle = buildCleanBundle(doc, const {});
  final out = Directory('/tmp/genout_probe/lib/ui/screens');
  await out.create(recursive: true);
  for (final e in bundle.files.entries) {
    if (!e.key.startsWith('lib/ui/screens/')) continue;
    await File('${out.path}/${e.key.split('/').last}').writeAsString(e.value);
  }
}
EOF
dart --packages=.dart_tool/package_config.json /tmp/genprobe.dart
dart format --output=none --set-exit-if-changed /tmp/genout_probe
# => exit 1, `Changed .../primitives_screen.dart` (measured 2026-09-06,
# Dart 3.13.2). The G1 scaffold path (`main.dart`, `app_theme.dart`) stays
# clean — legacy `_screenFile` screens only.
```

## Hand-verification (golden-first discipline)

The formatter's proposed shape was hand-checked (before/after diff of the
probe output) and **is correct Dart, not just formatter-happy**:

1. Import grouping: a blank line between the `package:flutter/…` import
   (plus `package:http`, when present) and the relative `../shadcn/…`
   barrel imports — canonical Dart import-group separation.
2. Body base indent: rows move from 6sp to 8sp under `children: [` —
   the canonical block indent for `return Column(` at 4sp.
3. Nested continuation indents: legacy hand-shaped blocks (e.g. a
   `child: Row(` whose args the emitter lays out at a +6sp continuation)
   reflow to the canonical block indent.

No semantic change anywhere in the reformatted output (pure whitespace
plus the one import-group blank line).

## Why a small fix is insufficient (measured, not assumed)

Applying ONLY (2) + (1) — uniform +2sp on the body block plus the import
blank line — to the probe output and re-running the gate-3 check **still
exits 1**: the formatter additionally reflows nested arg indentation (3)
inside `Row`/`Column` bodies built by the legacy `_bundle*Body` emitters.
Closing gate 3 emitter-side therefore means reworking indentation logic
across the whole legacy string-emitter family, not touching two lines in
`_screenFile`.

## Blast radius (why this batch stopped)

Any screen-output change invalidates expectations across the core suite:
`test/codegen_bundle_test.dart` alone has ~2500 lines carrying 6sp
indent-sensitive screen expectations, plus byte-exact fixtures and the
g2/g3/g4 suites that pin screen bodies. That is far beyond the ~3-golden
budget — so per the brief, output is untouched and no golden was updated.

## Pointers for the owning track

- Root base indent: `codegen_bundle.dart` `_screenFile` — `_writeBundleNode`
  call with `'      '` (6sp) base plus the `'      // (empty screen).'`
  literal.
- Import-group blank line: the `_screenFile` return template
  (`$flutterLine` / `${extraImports}${kitImports}` run the `package:` and
  relative groups together with no blank line).
- Nested continuation indents: the legacy `_bundleContainerBody` /
  `_bundleFallbackLines` / per-kind `_bundleX` string emitters (compare the
  G2 AST path, which is already canonical post-format).
- Suggested acceptance: re-run the reproduction above (exit 0) plus the
  full `canvas_core` suite green with goldens re-based to the verified
  shape — ideally as part of the G2 `code_builder` cutover, which replaces
  the hand-shaped blocks structurally.
