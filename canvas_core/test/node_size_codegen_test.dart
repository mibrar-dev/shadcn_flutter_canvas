/// Track U2 codegen: `w`/`h` emission in the single-file and bundle
/// exporters, plus the unsized-identical guard (unsized docs emit exactly the
/// legacy shapes — the byte-identical goldens in `codegen_single_test.dart`
/// and `codegen_bundle_test.dart` enforce this suite-wide; here we pin the
/// row-child shapes explicitly).
///
/// Shared semantics (mirrors the sizing table on [CanvasNode]):
/// * root sized → `SizedBox(w/h)` around the whole subtree expression;
/// * row child with `w` → `SizedBox`, NO flex wrapper (fixed beats flex);
/// * row child with `h`-only + explicit flex → flex wrapper OUTSIDE
///   `SizedBox(h)`;
/// * responsive conditional nests INSIDE the `SizedBox` when sized.
library;

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

ScreenDoc _doc(List<Map<String, dynamic>> nodes) => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': nodes,
      'theme': {
        'paletteKey': 'clean-slate',
        'dark': true,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Sizes', 'brief': ''},
    });

Map<String, dynamic> _leaf({
  required String id,
  String? parentId,
  String kind = 'button',
  String label = 'Go',
  double? w,
  double? h,
  String? expand,
  int? flex,
}) => {
      'id': id,
      'screenId': 's1',
      'x': 0.0,
      'y': 0.0,
      'items': [
        {'id': 'i$id', 'kind': kind, 'label': label},
      ],
      'parentId': parentId,
      if (w != null) 'w': w,
      if (h != null) 'h': h,
      if (expand != null) 'expand': expand,
      if (flex != null) 'flex': flex,
    };

Map<String, dynamic> _row({required String id}) => {
      'id': id,
      'screenId': 's1',
      'x': 0.0,
      'y': 0.0,
      'items': [],
      'parentId': null,
      'isRow': true,
      'gap': 8.0,
    };

/// The emitted screen body of a single-screen bundle (the only file for
/// these one-screen docs).
String _bundleScreen(ScreenDoc doc) {
  final bundle = buildCleanBundle(doc, const {});
  final path = bundle.files.keys.singleWhere(
    (k) => k.startsWith('lib/ui/screens/'),
  );
  return bundle.files[path]!;
}

void main() {
  group('single-file size emission', () {
    test('sized root leaf wraps in SizedBox with both dims', () {
      final out = buildSingleFile(
        _doc([
          _leaf(id: 'n1', w: 120, h: 80),
        ]),
        const {},
      );
      expect(out, contains('SizedBox('));
      expect(out, contains('width: 120,'));
      expect(out, contains('height: 80,'));
      expect(out, contains('child: '));
      expect(out, contains("'Go'"));
      // Size outside content: the box opens before the button expression.
      expect(out.indexOf('width: 120,'), lessThan(out.indexOf("'Go'")));
    });

    test('w-only root emits width without height', () {
      final out = buildSingleFile(
        _doc([
          _leaf(id: 'n1', w: 200),
        ]),
        const {},
      );
      expect(out, contains('width: 200,'));
      expect(out, isNot(contains('height:')));
    });

    test('row child with w emits SizedBox with no flex wrapper', () {
      final out = buildSingleFile(
        _doc([
          _row(id: 'r1'),
          _leaf(id: 'c1', parentId: 'r1', w: 100, label: 'Fixed'),
          _leaf(id: 'c2', parentId: 'r1', label: 'Auto'),
        ]),
        const {},
      );
      expect(out, contains('width: 100,'));
      expect(out, contains("'Fixed'"));
      expect(out, contains("'Auto'"));
      expect(out, isNot(contains('Expanded(')));
      expect(out, isNot(contains('Flexible(')));
    });

    test('h-only row child with explicit flex keeps flex outside SizedBox',
        () {
      final out = buildSingleFile(
        _doc([
          _row(id: 'r1'),
          _leaf(
            id: 'c1',
            parentId: 'r1',
            h: 90,
            expand: 'flex',
            flex: 2,
            label: 'Tall',
          ),
        ]),
        const {},
      );
      expect(out, contains('Flexible('));
      expect(out, contains('flex: 2,'));
      expect(out, contains('height: 90,'));
      expect(out, contains("'Tall'"));
      // Flex role outside the fixed height.
      expect(
        out.indexOf('Flexible('),
        lessThan(out.indexOf('height: 90,')),
      );
    });

    test('h-only row child without flex fills via inner Expanded', () {
      // Track X2 fill parity: h-pinned content fills vertically with an
      // inner Expanded (matching canvas applyNodeSizeValues) — no flex
      // *role* (no Flexible/Expanded wrapper outside the SizedBox).
      final out = buildSingleFile(
        _doc([
          _row(id: 'r1'),
          _leaf(id: 'c1', parentId: 'r1', h: 90, label: 'Tall'),
        ]),
        const {},
      );
      expect(out, contains('height: 90,'));
      expect(out, contains('Expanded('));
      expect(out, isNot(contains('Flexible(')));
    });

    test('sized row container wraps the Row in SizedBox', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            ..._row(id: 'r1'),
            'w': 240,
            'h': 120,
          },
          _leaf(id: 'c1', parentId: 'r1', label: 'InRow'),
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Sizes', 'brief': ''},
      });
      final out = buildSingleFile(doc, const {});
      expect(out, contains('width: 240,'));
      expect(out, contains('height: 120,'));
      expect(out, contains('Row('));
      expect(
        out.indexOf('width: 240,'),
        lessThan(out.indexOf('Row(')),
      );
    });

    test('sized + responsive nests LayoutBuilder inside SizedBox', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            ..._leaf(id: 'n1', w: 120, label: 'Sized'),
            'hiddenOn': ['mobile'],
          },
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Sizes', 'brief': ''},
      });
      final out = buildSingleFile(doc, const {});
      expect(out, contains('width: 120,'));
      expect(out, contains('LayoutBuilder('));
      expect(
        out.indexOf('width: 120,'),
        lessThan(out.indexOf('LayoutBuilder(')),
      );
    });

    test('unsized row children keep the legacy unwrapped emission', () {
      final out = buildSingleFile(
        _doc([
          _row(id: 'r1'),
          _leaf(id: 'c1', parentId: 'r1', label: 'One'),
          _leaf(id: 'c2', parentId: 'r1', label: 'Two'),
        ]),
        const {},
      );
      expect(out, contains('Row('));
      expect(out, isNot(contains('Expanded(')));
      expect(out, isNot(contains('Flexible(')));
      expect(out, isNot(contains('width: 100')));
      expect(out, isNot(contains('SizedBox(\n')));
    });
  });

  group('bundle size emission', () {
    test('sized root leaf wraps in SizedBox with both dims', () {
      final screen = _bundleScreen(
        _doc([
          _leaf(id: 'n1', w: 120, h: 80),
        ]),
      );
      expect(screen, contains('SizedBox('));
      expect(screen, contains('width: 120,'));
      expect(screen, contains('height: 80,'));
      expect(screen, contains('Go'));
    });

    test('row child with w emits SizedBox with no flex wrapper', () {
      final screen = _bundleScreen(
        _doc([
          _row(id: 'r1'),
          _leaf(id: 'c1', parentId: 'r1', w: 100, label: 'Fixed'),
          _leaf(id: 'c2', parentId: 'r1', label: 'Auto'),
        ]),
      );
      expect(screen, contains('width: 100,'));
      expect(screen, isNot(contains('Expanded(')));
      expect(screen, isNot(contains('Flexible(')));
    });

    test('h-only row child with explicit flex keeps flex outside SizedBox',
        () {
      final screen = _bundleScreen(
        _doc([
          _row(id: 'r1'),
          _leaf(
            id: 'c1',
            parentId: 'r1',
            h: 90,
            expand: 'expanded',
            label: 'Tall',
          ),
        ]),
      );
      expect(screen, contains('Expanded('));
      expect(screen, contains('height: 90,'));
      expect(
        screen.indexOf('Expanded('),
        lessThan(screen.indexOf('height: 90,')),
      );
    });

    test('sized + responsive nests LayoutBuilder inside SizedBox', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            ..._leaf(id: 'n1', w: 120, label: 'Sized'),
            'hiddenOn': ['mobile'],
          },
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Sizes', 'brief': ''},
      });
      final screen = _bundleScreen(doc);
      expect(screen, contains('width: 120,'));
      expect(screen, contains('LayoutBuilder('));
      expect(
        screen.indexOf('width: 120,'),
        lessThan(screen.indexOf('LayoutBuilder(')),
      );
    });

    test('unsized docs emit no size boxes', () {
      final screen = _bundleScreen(
        _doc([
          _row(id: 'r1'),
          _leaf(id: 'c1', parentId: 'r1', label: 'One'),
        ]),
      );
      expect(screen, contains('Row('));
      expect(screen, isNot(contains('width: 100')));
      expect(screen, isNot(contains('Expanded(')));
    });
  });
}
