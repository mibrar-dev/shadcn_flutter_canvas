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

  test('buildCleanBundle warns on unknown kinds instead of crashing', () {    final doc = ScreenDoc.fromJson({
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

  test('tap action emits a pushNamed navigation to the screen route', () {
    final bundle = buildCleanBundle(buildTwoScreenDoc(), kTestSources);
    final payScreen = bundle.files['lib/ui/screens/pay_screen.dart']!;

    // Vanilla StatefulWidget with no store dependency (easy adoption).
    expect(payScreen, contains('extends StatefulWidget'));
    expect(payScreen, contains('no store dependency'));
    expect(payScreen, isNot(contains('CanvasStore')));

    // The Pay button navigates to the Done route by name.
    expect(payScreen, contains('GestureDetector('));
    expect(payScreen, contains("pushNamed('/done')"));
    expect(payScreen, contains('// transition: slide'));

    // The Done screen has no actions: no navigation emitted there.
    final doneScreen = bundle.files['lib/ui/screens/done_screen.dart']!;
    expect(doneScreen, isNot(contains('pushNamed')));
    expect(doneScreen, isNot(contains('Navigator')));
  });

  test('unknown action target emits a comment and no navigation', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Lost',
              'action': {'to': 'missing', 'transition': 'fade'},
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Dangling', 'brief': ''},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains("unknown target 'missing'"));
    expect(screen, isNot(contains('pushNamed')));
    expect(screen, isNot(contains('Navigator')));
  });

  test('hiddenOn emits a tier conditional in the bundle idiom', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'hiddenOn': ['mobile'],
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Pay'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Hidden', 'brief': ''},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains('LayoutBuilder'));
    expect(screen, contains("tier == 'mobile'"));
    expect(screen, contains('SizedBox.shrink'));
    expect(screen, contains("'Pay'"));
  });

  test('breakpointValues merge per tier with a static default', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'breakpointValues': {
            'desktop': {'label': 'Wide Pay'},
          },
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Pay'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Overrides', 'brief': ''},
    });

    final bundle = buildCleanBundle(doc, kTestSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;
    expect(screen, contains('LayoutBuilder'));
    expect(screen, contains("tier == 'desktop'"));
    expect(screen, contains("'Wide Pay'"));
    expect(screen, contains("'Pay'"));
  });

  test('docs without responsive/actions produce byte-identical output', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Pay',
              'variant': 'primary',
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Plain', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, kTestSources);
    expect(
      bundle.files['lib/ui/screens/home_screen.dart'],
      kBundleScreenGolden,
    );
  });
}

/// Byte-identical golden for the bundle screen scaffold on a plain doc (no
/// actions, no responsive fields): responsive/action emission must not alter
/// output for such docs. Regenerate only by reviewing the exporter diff.
const kBundleScreenGolden = '''// GENERATED by canvas bundle exporter — DO NOT EDIT BY HAND.
// Screen: Home (id: s1). Component bodies ship
// separately under lib/ui/shadcn/ — wire them here:
// - button -> lib/ui/shadcn/components/control/button/button.dart
import 'package:flutter/widgets.dart';

/// Home screen.
///
/// Vanilla [StatefulWidget] with no store dependency: bring your own state
/// management (Provider, Riverpod, Bloc, …) by lifting this `build` body
/// into your own widget. Depends only on `package:flutter/widgets.dart`
/// plus the shipped kit bodies.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
      // button 'Pay' (variant primary).
      Text('Pay'),
      ],
    );
  }
}
''';
