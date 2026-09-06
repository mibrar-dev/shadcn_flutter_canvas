/// Track F1: sizing-mode derivation (P16 reconciliation) + the §7.5
/// golden-first fixtures exist and load.
///
/// [SizeMode] is derived from the stored P16/U2 fields (`w`/`h`/`expand`),
/// never stored: these tests pin the derivation table and the
/// byte-identical round-trip (no new JSON keys) that makes the derivation
/// store-safe without touching `canvas_store.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

CanvasNode _node({double? w, double? h, String? expand, int? flex}) =>
    CanvasNode(
      id: 'n',
      screenId: 's',
      x: 0,
      y: 0,
      items: const [],
      expand: expand,
      flex: flex,
      w: w,
      h: h,
    );

void main() {
  group('f1 SizeMode derivation (P16 reconciliation)', () {
    test('bare node hugs both axes', () {
      final n = _node();
      expect(n.widthMode, SizeMode.hug);
      expect(n.heightMode, SizeMode.hug);
    });

    test('w sets fixed width, h sets fixed height', () {
      final n = _node(w: 120, h: 80);
      expect(n.widthMode, SizeMode.fixed);
      expect(n.heightMode, SizeMode.fixed);
    });

    test('h-only leaves width hugging', () {
      final n = _node(h: 80);
      expect(n.widthMode, SizeMode.hug);
      expect(n.heightMode, SizeMode.fixed);
    });

    test('expand role reads as expand on width only', () {
      for (final role in ['flex', 'expanded']) {
        final n = _node(expand: role, flex: 2);
        expect(n.widthMode, SizeMode.expand, reason: role);
        expect(n.heightMode, SizeMode.hug, reason: role);
      }
    });

    test('unknown expand role hugs', () {
      final n = _node(expand: 'none');
      expect(n.widthMode, SizeMode.hug);
    });

    test('fixed beats expand (documented precedence)', () {
      final n = _node(w: 120, expand: 'expanded', flex: 2);
      expect(n.widthMode, SizeMode.fixed);
    });

    test('no new JSON keys: old docs round-trip byte-identically', () {
      final n = _node(w: 120, expand: 'flex', flex: 1);
      final json = n.toJson();
      expect(json.containsKey('widthMode'), isFalse);
      expect(json.containsKey('heightMode'), isFalse);
      expect(json.containsKey('sizeMode'), isFalse);
      final back = CanvasNode.fromJson(Map<String, dynamic>.from(json));
      expect(back.widthMode, SizeMode.fixed);
      expect(back.toJson(), json);
    });
  });

  group('f1 §7.5 fixtures (golden-first inputs)', () {
    test('primitives_screen.json loads with clean nesting', () {
      final file = File('test/fixtures/primitives_screen.json');
      expect(file.existsSync(), isTrue);
      final doc = ScreenDoc.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(validateNesting(doc), isEmpty);
      expect(doc.screens.single.name, 'Primitives');
    });

    test('fixture carries the §7.5 tree shape', () {
      final file = File('test/fixtures/primitives_screen.json');
      final doc = ScreenDoc.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      final kinds = {
        for (final n in doc.nodes)
          for (final i in n.items) '${n.id}:${i.kind}',
      };
      expect(
        kinds,
        containsAll([
          'n_scaffold:scaffold',
          'n_col:column',
          'n_hero:container',
          'n_avatar:avatar',
          'n_namecol:column',
          'n_t1:text',
          'n_spacer:spacer',
          'n_badge:badge',
          'n_gap:sized_box',
          'n_exp:expanded',
          'n_list:column',
          'n_c1:card',
        ]),
      );
      final heroRow = doc.nodes.singleWhere((n) => n.id == 'n_heroRow');
      expect(heroRow.isRow, isTrue);
      // §6.1 tagged envelopes ride the container props (parsed by the F3
      // emitters; asserted structurally here so the fixture cannot rot).
      final heroProps =
          doc.nodes.singleWhere((n) => n.id == 'n_hero').items.single.props;
      for (final key in ['padding', 'color', 'radius']) {
        expect(
          (heroProps[key] as Map)['\$'],
          isNotNull,
          reason: '$key must be a tagged envelope',
        );
      }
      expect(heroProps['gradient'], isA<Map>());
    });

    test('primitives_screen.expected.dart exists (hand-written golden)', () {
      expect(
        File('test/fixtures/primitives_screen.expected.dart').existsSync(),
        isTrue,
      );
    });
  });
}
