// Gates 4-5 sample-project generator (BUILD_SPEC §11, H-FINAL-4).
//
// Throwaway driver: drives the repo's own §8.4 writers (`scaffoldProject` +
// `emitPrimitivePageFiles` with `g3Emitters` from `package:canvas_core`) to
// emit a runnable `out/` project for the §7.5 primitives fixture plus one
// stateless G3-kind page (`g3_chip`) and one stateful G3-kind page
// (`g3_text_area`, exercises the `{Page}Model` split) into `--out`.
//
// Fidelity rules (evidence must be honest):
// * Writer output is written VERBATIM, except the single documented pubspec
//   tweak below. No hand-fixes to page bodies, imports, or `main.dart`.
// * The ONE tweak: `buildPubspec` emits `flutter_shadcn_kit: ^1.0.0`
//   (hosted). This driver rewrites that line to a `path:` dependency on the
//   LOCAL kit checkout (`--kit`), so the attempt is offline-safe and does
//   not depend on a pub.dev publish. The exact rewritten pubspec is printed
//   and belongs in the evidence doc.
// * Fixture surgery is driver-side and reported: the two G3 fixtures both
//   declare screen `s1`/`Home`; they are remapped to unique ids/names here
//   (slug uniqueness for `pages/<slug>/`) before `ScreenDoc.fromJson`.
//
// Usage (from `canvas_app/`):
//   dart run tool/gen_sample_project.dart --out /tmp/genproj_2026-09-06
//
// Exit codes: 0 = project written, 1 = usage/IO error, 2 = fidelity assert
// failed (writer contract changed under the driver).
import 'dart:convert';
import 'dart:io';

import 'package:canvas_core/canvas_core.dart';

void _usage() {
  stderr.writeln('usage: dart run tool/gen_sample_project.dart '
      '--out <dir> [--fixtures <dir>] [--kit <dir>] [--title <name>]');
  stderr.writeln('  defaults: --fixtures ../canvas_core/test/fixtures');
  stderr.writeln('            --kit ../../shadcn_flutter_kit/flutter_shadcn_kit');
  stderr.writeln('            --title Genproj');
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

Map<String, dynamic> _readDoc(String path) {
  final text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}

/// Remaps a single-screen G3 fixture doc's screen/node/item ids under
/// [prefix] and renames its screen to [screenName] (slug uniqueness).
Map<String, dynamic> _remapG3(
  Map<String, dynamic> doc,
  String prefix,
  String screenName,
) {
  final screens = (doc['screens'] as List).cast<Map<String, dynamic>>();
  final nodes = (doc['nodes'] as List).cast<Map<String, dynamic>>();
  final oldScreen = screens.single['id'] as String;
  final outNodes = <Map<String, dynamic>>[];
  for (final n in nodes) {
    final items = (n['items'] as List).cast<Map<String, dynamic>>();
    outNodes.add({
      ...n,
      'id': '${prefix}_${n['id']}',
      'screenId': '${prefix}_s',
      if (n.containsKey('parentId')) 'parentId': '${prefix}_${n['parentId']}',
      'items': [
        for (final it in items)
          {
            ...it,
            // Prefix item ids for page-level uniqueness, but never
            // double-prefix (fixture id `bio` under prefix `bio` stays
            // `bio`, so `planModelFields` allocates `bioController`, not
            // `bio_bioController` — the generator reads ids verbatim).
            'id': it['id'] == prefix ||
                    (it['id'] as String).startsWith('${prefix}_')
                ? it['id']
                : '${prefix}_${it['id']}',
          },
      ],
    });
  }
  return {
    ...doc,
    'screens': [
      {...screens.single, 'id': '${prefix}_s', 'name': screenName},
    ],
    'nodes': outNodes,
    '_remappedFrom': oldScreen,
  };
}

void main(List<String> args) {
  final out = _flag(args, '--out');
  if (out == null || args.contains('--help') || args.contains('-h')) {
    _usage();
    exit(1);
  }
  final fixtures = _flag(args, '--fixtures') ?? '../canvas_core/test/fixtures';
  final kit =
      _flag(args, '--kit') ?? '../../shadcn_flutter_kit/flutter_shadcn_kit';
  final title = _flag(args, '--title') ?? 'Genproj';

  final kitDir = Directory(kit);
  if (!kitDir.existsSync()) {
    stderr.writeln('gen_sample_project: kit checkout missing: $kit');
    exit(1);
  }

  // 1. Load fixtures.
  final prim = _readDoc('$fixtures/primitives_screen.json');
  final chip = _remapG3(
    _readDoc('$fixtures/g3_chip.json'),
    'chip',
    'Chip Demo',
  );
  final textArea = _remapG3(
    _readDoc('$fixtures/g3_text_area.json'),
    'bio',
    'Text Area Demo',
  );

  // 2. Combine into one multi-screen doc (multi-screen exercises the
  // go_router shell: `app_router.dart` + `MaterialApp.router`).
  final combined = <String, dynamic>{
    ...prim,
    'screens': [
      ...(prim['screens'] as List),
      ...(chip['screens'] as List),
      ...(textArea['screens'] as List),
    ],
    'nodes': [
      ...(prim['nodes'] as List),
      ...(chip['nodes'] as List),
      ...(textArea['nodes'] as List),
    ],
    'meta': {'title': title, 'brief': 'Gates 4-5 evidence project'},
  };
  combined.remove('_remappedFrom');
  final doc = ScreenDoc.fromJson(combined);

  // 3. Emit shells + pages via the repo writers.
  final shells = scaffoldProject(appName: title, doc: doc);
  final pages = <ProjectOutFile>[];
  for (final screen in doc.screens) {
    pages.addAll(emitPrimitivePageFiles(
      doc: doc,
      screen: screen,
      extraEmitters: g3Emitters,
    ));
  }

  // 4. Pubspec path-dep rewrite (the ONE allowed tweak).
  final kitAbs = kitDir.absolute.path;
  var pubspecSeen = false;
  final files = <ProjectOutFile>[...shells, ...pages];
  final rewritten = <ProjectOutFile>[];
  for (final f in files) {
    if (f.path == 'pubspec.yaml') {
      const hosted = '  flutter_shadcn_kit: ^1.0.0';
      if (!f.content.contains(hosted)) {
        stderr.writeln(
          'gen_sample_project: FIDELITY host-dep line missing from '
          'buildPubspec output (writer contract changed).',
        );
        exit(2);
      }
      rewritten.add(ProjectOutFile(
        f.path,
        f.content.replaceFirst(
          hosted,
          '  flutter_shadcn_kit:\n    path: $kitAbs',
        ),
      ));
      pubspecSeen = true;
    } else {
      rewritten.add(f);
    }
  }
  if (!pubspecSeen) {
    stderr.writeln('gen_sample_project: FIDELITY no pubspec emitted.');
    exit(2);
  }

  // 5. Write the tree (binary files — web icons — as bytes).
  final outDir = Directory(out);
  outDir.createSync(recursive: true);
  for (final f in rewritten) {
    final target = File('${outDir.path}/${f.path}');
    target.parent.createSync(recursive: true);
    if (f.isBinary) {
      target.writeAsBytesSync(f.bytes!);
    } else {
      target.writeAsStringSync(f.content);
    }
  }

  stdout.writeln('gen_sample_project: wrote ${rewritten.length} files '
      'to ${outDir.path}');
  for (final f in rewritten) {
    stdout.writeln('  ${f.path}');
  }
  stdout.writeln('kit path dep: $kitAbs');
}
