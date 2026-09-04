import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

import 'fixtures/two_screen_doc.dart';

/// Minimal registry-source stub keyed by the exact bundle destination
/// templates. The real `kTestSources` map stays in canvas_app
/// (generated Flutter-app data, not shared logic).
const kTestSources = {
  '{installPath}/components/control/button/button.dart':
      'class Button extends StatelessWidget {}',
  '{installPath}/components/layout/card/card.dart':
      'class Card extends StatelessWidget {}',
};

void main() {
  test('buildCleanBundle manifest has the Task 12 shape', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    final manifest = jsonDecode(bundle.manifestJson) as Map<String, dynamic>;

    expect(manifest['screens'], ['pay', 'done']);
    expect(manifest['namespace'], 'shadcn');
    expect(manifest['root'], 'lib/ui/shadcn');
    expect(manifest['entry'], 'lib/ui/screens/pay_screen.dart');

    final files = manifest['files'] as List;
    expect(files, isNotEmpty);
    for (final f in files) {
      final entry = f as Map<String, dynamic>;
      expect(entry.keys, containsAll(['source', 'destination']));
      expect(entry['source'] as String, startsWith('registry/'));
      expect(
        entry['destination'] as String,
        startsWith('lib/ui/shadcn/'),
      );
    }

    final shared = manifest['shared'] as List;
    expect(shared, contains('theme'));

    final pubspec = manifest['pubspec'] as Map<String, dynamic>;
    final deps = pubspec['dependencies'] as Map<String, dynamic>;
    expect(deps.keys, contains('gap'));
  });

  test('buildCleanBundle files hold screens plus shadcn bodies', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);

    expect(
      bundle.files.keys,
      containsAll([
        'lib/ui/screens/pay_screen.dart',
        'lib/ui/screens/done_screen.dart',
      ]),
    );
    final shadcnPaths = bundle.files.keys
        .where((p) => p.startsWith('lib/ui/shadcn/'))
        .toList();
    expect(shadcnPaths, isNotEmpty);

    // Screens are minimal scaffolds referencing package imports, never
    // inlined component bodies (those ship as separate files).
    final payScreen = bundle.files['lib/ui/screens/pay_screen.dart']!;
    expect(payScreen, contains('package:flutter'));
    expect(payScreen, contains('PayScreen'));
    expect(payScreen, isNot(contains('class Button')));

    // At least one shipped body carries the real Button implementation.
    expect(
      bundle.files.values.any((c) => c.contains('class Button')),
      isTrue,
    );
  });

  test('buildCleanBundle zip decodes listing the same entries', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    final archive = ZipDecoder().decodeBytes(bundle.zipBytes);
    final names = {for (final f in archive.files) f.name};

    expect(names, containsAll(bundle.files.keys));
    expect(names, containsAll(['manifest.json', 'pubspec_patch.yaml']));

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final expected = file.name == 'manifest.json'
          ? bundle.manifestJson
          : file.name == 'pubspec_patch.yaml'
              ? bundle.pubspecPatch
              : bundle.files[file.name];
      expect(utf8.decode(file.content as List<int>), expected);
    }
  });

  test('buildCleanBundle pubspec patch merges component dependencies', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    expect(bundle.pubspecPatch, contains('gap'));
    expect(bundle.pubspecPatch, contains('dependencies:'));
  });

  test('buildCleanBundle warns on unknown kinds instead of crashing', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': 'not_a_component', 'label': '???'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Weird', 'brief': 'unknown kind doc'},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final manifest = jsonDecode(bundle.manifestJson) as Map<String, dynamic>;
    expect((manifest['warnings'] as List), isNotEmpty);
    expect(bundle.files.keys, contains('lib/ui/screens/pay_screen.dart'));
  });
}
