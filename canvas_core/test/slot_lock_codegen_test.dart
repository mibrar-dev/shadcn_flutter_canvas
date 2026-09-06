/// Track DD: named-slot codegen goldens for both exporters — slot emission
/// (child built recursively into the host's slot arg, tiers/taps preserved),
/// missing-child omission, slotless byte-identity, lock transparency, and
/// cycle termination.
import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

import 'fixtures/two_screen_doc.dart';

/// Minimal registry-source stubs (same idiom as `codegen_single_test.dart`).
const kSlotTestSources = {
  'registry/components/button/button.dart': '''
import 'package:flutter/widgets.dart';

class Button extends StatelessWidget {
  const Button({super.key});
}
''',
};

/// Minimal bundle registry stubs keyed by destination template (same idiom
/// as `codegen_bundle_test.dart`).
const kSlotBundleSources = {
  '{installPath}/components/control/button/button.dart':
      'class Button extends StatelessWidget {}',
  '{installPath}/components/layout/card/card.dart':
      'class Card extends StatelessWidget {}',
};

Map<String, dynamic> _theme() => {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    };

/// Home screen: `card` host (`host`) with `slotNodes: {content: kid}`, a
/// `button` slot child (`kid`), and a plain `button` root (`plain`).
ScreenDoc _slotDoc() => ScreenDoc.fromJson(<String, dynamic>{
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'host',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'ih', 'kind': 'card', 'title': 'T'},
          ],
          'slotNodes': {'content': 'kid'},
        },
        {
          'id': 'kid',
          'screenId': 's1',
          'x': 0.0,
          'y': 100.0,
          'items': [
            {'id': 'ib', 'kind': 'button', 'label': 'Slotted'},
          ],
        },
        {
          'id': 'plain',
          'screenId': 's1',
          'x': 0.0,
          'y': 200.0,
          'items': [
            {'id': 'ip', 'kind': 'button', 'label': 'Plain'},
          ],
        },
      ],
      'theme': _theme(),
      'meta': {'title': 'T', 'brief': ''},
    });

int _count(String haystack, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(haystack).length;

void main() {
  group('codegen_single slots', () {
    test('slot child splices into the host slot exactly once', () {
      final out = buildSingleFile(_slotDoc(), kSlotTestSources);

      // Trace comment names the filled slot; the child label rides inside
      // the host Card (before the flow roots below it).
      expect(out, contains('// slot: content'));
      expect(out, contains("'Slotted'"));
      expect(out, contains("'Plain'"));
      // Single ownership: no duplicated widget at the flow root.
      expect(_count(out, "'Slotted'"), 1);
      // Slot-first order (canvas parity): the slotted button precedes the
      // plain root button in the file.
      expect(out.indexOf("'Slotted'"), lessThan(out.indexOf("'Plain'")));
    });

    test('missing slot child is omitted, host emits childless', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'host',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'ih', 'kind': 'card', 'title': 'T'},
            ],
            'slotNodes': {'content': 'ghost'},
          },
        ],
        'theme': _theme(),
        'meta': {'title': 'T', 'brief': ''},
      });
      final out = buildSingleFile(doc, kSlotTestSources);
      expect(out, isNot(contains('// slot:')));
      expect(out, contains('Card('));
    });

    test('explicitly empty slotNodes/locked:false emit slotless-identically',
        () {
      final withEmpty = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
          {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
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
                'action': {'to': 's2', 'transition': 'slide'},
              },
            ],
            'slotNodes': {},
            'locked': false,
          },
          {
            'id': 'n2',
            'screenId': 's2',
            'x': 16.0,
            'y': 96.0,
            'items': [
              {
                'id': 'i2',
                'kind': 'card',
                'title': 'Done',
                'description': 'Payment complete',
              },
            ],
            'slotNodes': {},
            'locked': false,
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Checkout', 'brief': '2-screen pay flow'},
      });
      expect(
        buildSingleFile(withEmpty, kSlotTestSources),
        buildSingleFile(buildTwoScreenDoc(), kSlotTestSources),
      );
    });

    test('responsive host keeps its slot in every tier branch', () {
      final doc = _slotDoc();
      final host = doc.nodes.singleWhere((n) => n.id == 'host');
      final responsive = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'host')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                hiddenOn: const {'desktop'},
                breakpointValues: const {
                  'tablet': {'title': 'T2'},
                },
                slotNodes: Map<String, String>.from(n.slotNodes),
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      expect(host.slotNodes, {'content': 'kid'});
      final out = buildSingleFile(responsive, kSlotTestSources);
      expect(out, contains('LayoutBuilder'));
      // Tablet branch + default branch each carry the slot.
      expect(_count(out, '// slot: content'), 2);
    });

    test('slot cycle terminates with a comment, never a hang', () {
      // host slots its own parentId-ancestor (allowed by the store, guarded
      // by the emitters): row R holds host H; H slots R.
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'r',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [],
            'isRow': true,
          },
          {
            'id': 'h',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'parentId': 'r',
            'items': [
              {'id': 'ih', 'kind': 'card'},
            ],
            'slotNodes': {'content': 'r'},
          },
        ],
        'theme': _theme(),
        'meta': {'title': 'T', 'brief': ''},
      });
      final out = buildSingleFile(doc, kSlotTestSources);
      expect(out, contains('cycle: node r is its own ancestor (skipped)'));
    });

    test('locked nodes emit normally (export ignores the flag)', () {
      final doc = _slotDoc();
      final locked = ScreenDoc(
        screens: doc.screens,
        nodes: [
          for (final n in doc.nodes)
            if (n.id == 'kid')
              CanvasNode(
                id: n.id,
                screenId: n.screenId,
                x: n.x,
                y: n.y,
                items: n.items,
                locked: true,
              )
            else
              n,
        ],
        theme: doc.theme,
        meta: doc.meta,
      );
      final out = buildSingleFile(locked, kSlotTestSources);
      expect(out, contains('// slot: content'));
      expect(out, contains("'Slotted'"));
    });
  });

  group('codegen_bundle slots', () {
    test('slot child splices into the host screen exactly once', () {
      final bundle = buildCleanBundle(_slotDoc(), kSlotBundleSources);
      final screen =
          bundle.files['lib/ui/screens/home_screen.dart']!;
      expect(screen, contains('// slot: content'));
      expect(screen, contains('Slotted'));
      // Single ownership counts the WIDGET (the bundle's `// button
      // 'Slotted'.` doc comment is this file's per-item convention).
      expect(_count(screen, "Text('Slotted')"), 1);
      expect(screen.indexOf('Slotted'), lessThan(screen.indexOf('Plain')));
    });

    test('missing slot child is omitted, host emits childless', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'host',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'ih', 'kind': 'card', 'title': 'T'},
            ],
            'slotNodes': {'content': 'ghost'},
          },
        ],
        'theme': _theme(),
        'meta': {'title': 'T', 'brief': ''},
      });
      final bundle = buildCleanBundle(doc, kSlotBundleSources);
      final screen =
          bundle.files['lib/ui/screens/home_screen.dart']!;
      expect(screen, isNot(contains('// slot:')));
    });

    test('slotless bundle screens stay byte-identical', () {
      final withEmpty = ScreenDoc.fromJson(
        (buildTwoScreenDoc().toJson()..['nodes'] = [
          for (final n in buildTwoScreenDoc().nodes)
            {
              ...n.toJson(),
              'slotNodes': {},
              'locked': false,
            },
        ]),
      );
      final a = buildCleanBundle(withEmpty, kSlotBundleSources);
      final b = buildCleanBundle(buildTwoScreenDoc(), kSlotBundleSources);
      expect(
        a.files['lib/ui/screens/pay_screen.dart'],
        b.files['lib/ui/screens/pay_screen.dart'],
      );
      expect(
        a.files['lib/ui/screens/done_screen.dart'],
        b.files['lib/ui/screens/done_screen.dart'],
      );
    });
  });
}
