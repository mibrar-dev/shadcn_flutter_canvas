/// Y6 cutover shell assembly (FORGE.md §5) with the Track CC sidebar revert:
/// topbar + header + selection toolbar + inspector coexist with the restored
/// classic icon rail + parts palette; inspector Duplicate/Delete hit the
/// store, and Layers + the Color/Shape/Type/Motion theme panels live behind
/// the rail.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/forge_canvas_header.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:canvas_app/ui/icon_rail.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:canvas_app/ui/theme_panels.dart';
import 'package:canvas_app/ui/zoom_controls.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpShell(WidgetTester tester, CanvasStore store) async {
  _useReferenceViewport(tester);
  await tester.pumpWidget(MaterialApp(home: EditorShell(store: store)));
  await tester.pumpAndSettle();
}

/// Taps a classic rail item by glyph, scoped to the rail (the rail tips are
/// kit tooltips, invisible to `find.byTooltip`; palette tiles may reuse the
/// glyph — the pre-Forge shell test idiom).
Future<void> _tapRail(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(EditorIconRail),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}
void main() {
  group('Y6 shell assembly', () {
    testWidgets('all forge pieces + classic rail coexist; pills gone',
        (tester) async {
      await _pumpShell(tester, CanvasStore());

      expect(find.byType(ForgeTopbar), findsOneWidget);
      expect(find.byType(ForgeCanvasHeader), findsOneWidget);
      expect(find.byType(EditorIconRail), findsOneWidget);
      expect(find.byType(PartsPalette), findsOneWidget);
      expect(find.byType(DesignCanvas), findsOneWidget);
      expect(find.byType(RightAside), findsOneWidget);
      // Zoom lives inside the header now (no bottom-right mount).
      expect(
        find.descendant(
          of: find.byType(ForgeCanvasHeader),
          matching: find.byType(ZoomControls),
        ),
        findsOneWidget,
      );
      // Old always-visible toolbar is removed; the Forge selection toolbar
      // hides without a selection.
      expect(find.byType(CanvasToolbar), findsNothing);
      expect(find.byKey(kForgeSelectionToolbarKey), findsNothing);
      // Track CC revert: the classic rail owns the left column — the Forge
      // Library|Layers pills + the Theme disclosure are gone.
      expect(find.byKey(const ValueKey('forge-left-pill-library')),
          findsNothing);
      expect(find.byKey(const ValueKey('forge-left-pill-layers')),
          findsNothing);
      expect(find.byKey(const ValueKey('forge-left-theme-disclosure')),
          findsNothing);
    });

    testWidgets('header shows breadcrumb + zoom + device', (tester) async {
      await _pumpShell(tester, CanvasStore());

      // Default doc: title Untitled, first screen Screen 1, zoom 79%.
      expect(find.text('Untitled'), findsWidgets);
      expect(find.text('Screen 1'), findsWidgets);
      expect(find.text('79%'), findsOneWidget);
      // Compact device strip glyphs render in the header.
      expect(
        find.descendant(
          of: find.byType(ForgeCanvasHeader),
          matching: find.byIcon(Icons.smartphone),
        ),
        findsOneWidget,
      );
    });

    testWidgets('inspector Duplicate clones and reselects', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(id: store.uid(), kind: 'button', props: const {}),
        ],
      );
      await _pumpShell(tester, store);

      // Select via the rail's Layers item (pills are gone with the revert).
      await _tapRail(tester, Icons.layers);
      await tester.tap(find.text('Button · $nodeId'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('inspector-duplicate')));
      await tester.pumpAndSettle();

      expect(store.doc.nodes, hasLength(2));
      final ids = [for (final n in store.doc.nodes) n.id];
      expect(ids, contains(nodeId));
      // Reselected the clone: toolbar stays up and the header crumb shows a
      // node label (kind · id) rather than disappearing.
      expect(find.byKey(kForgeSelectionToolbarKey), findsOneWidget);
      expect(find.textContaining('Button · '), findsWidgets);
    });

    testWidgets('inspector Delete removes the node and clears', (tester) async {
      final store = CanvasStore();
      final nodeId = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(id: store.uid(), kind: 'button', props: const {}),
        ],
      );
      await _pumpShell(tester, store);

      await _tapRail(tester, Icons.layers);
      await tester.tap(find.text('Button · $nodeId'));
      await tester.pumpAndSettle();
      expect(find.byKey(kForgeSelectionToolbarKey), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inspector-delete')));
      await tester.pumpAndSettle();

      expect(store.doc.nodes, isEmpty);
      expect(find.byKey(kForgeSelectionToolbarKey), findsNothing);
    });

    testWidgets('selection toolbar reorders within the group', (tester) async {
      final store = CanvasStore();
      final first = store.addNode(
        screenId: 's1',
        x: 0,
        y: 0,
        items: [
          CanvasItem(id: store.uid(), kind: 'button', props: const {}),
        ],
      );
      final second = store.addNode(
        screenId: 's1',
        x: 0,
        y: 64,
        items: [
          CanvasItem(id: store.uid(), kind: 'button', props: const {}),
        ],
      );
      expect(
        [for (final n in store.doc.nodes) n.id],
        [first, second],
      );
      await _pumpShell(tester, store);

      await _tapRail(tester, Icons.layers);
      // Select the second (frontmost) node, then move it up one slot.
      await tester.tap(find.text('Button · $second'));
      await tester.pumpAndSettle();

      final toolbar = find.byKey(kForgeSelectionToolbarKey);
      await tester.tap(
        find.descendant(
          of: toolbar,
          matching: find.byIcon(Icons.arrow_upward),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        [for (final n in store.doc.nodes) n.id],
        [second, first],
      );

      await tester.tap(
        find.descendant(
          of: toolbar,
          matching: find.byIcon(Icons.arrow_downward),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        [for (final n in store.doc.nodes) n.id],
        [first, second],
      );
    });

    testWidgets('Rail swaps content', (tester) async {
      await _pumpShell(tester, CanvasStore());

      expect(find.byType(PartsPalette), findsOneWidget);
      expect(find.byType(LayersPanel), findsNothing);

      await _tapRail(tester, Icons.layers);
      expect(find.byType(LayersPanel), findsOneWidget);
      expect(find.byType(PartsPalette), findsNothing);

      await _tapRail(tester, Icons.add_box);
      expect(find.byType(PartsPalette), findsOneWidget);
      expect(find.byType(LayersPanel), findsNothing);
    });

    testWidgets('Rail mounts the four theme panels', (tester) async {
      await _pumpShell(tester, CanvasStore());

      expect(find.byType(ColorPanel), findsNothing);
      await _tapRail(tester, Icons.palette);
      expect(find.byType(ColorPanel), findsOneWidget);
      await _tapRail(tester, Icons.rounded_corner);
      expect(find.byType(ShapePanel), findsOneWidget);
      await _tapRail(tester, Icons.text_fields);
      expect(find.byType(TypePanel), findsOneWidget);
      await _tapRail(tester, Icons.animation);
      expect(find.byType(MotionPanel), findsOneWidget);
    });
  });
}
