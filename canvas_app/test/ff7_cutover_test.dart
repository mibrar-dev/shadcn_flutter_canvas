/// Track FF7 (BUILD_SPEC §9.3 FF7): cutover mount tests.
///
/// The planned cutover mounts rail + panel host + topbar + canvas +
/// properties at 48/280/flex/300: [FfNavRail] (48) | [FfPanelHost] (280) |
/// canvas flex | inspector (300). Asserts structure and callbacks, NOT
/// pixels (§12 rule 4): regions mount at the token widths, the rail
/// switches panels, and the topbar device/zoom embeds wire to the same
/// store paths the canvas header uses.
library;

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/ff_nav_rail.dart';
import 'package:canvas_app/ui/ff_panel_host.dart';
import 'package:canvas_app/ui/forge_canvas_header.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:canvas_app/ui/zoom_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport (HANDOFF §2): the shell is measured at 1440x900.
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpShell(WidgetTester tester, CanvasStore store) async {
  _useReferenceViewport(tester);
  await tester.pumpWidget(MaterialApp(home: EditorShell(store: store)));
  await tester.pump();
}

void main() {
  group('ff7 cutover regions', () {
    testWidgets('rail | panel | canvas | inspector mount at 48/280/flex/300',
        (tester) async {
      await _pumpShell(tester, CanvasStore());

      expect(find.byType(ForgeTopbar), findsOneWidget);
      expect(find.byType(FfNavRail), findsOneWidget);
      expect(find.byType(FfPanelHost), findsOneWidget);
      expect(find.byType(DesignCanvas), findsOneWidget);
      expect(find.byType(ForgeCanvasHeader), findsOneWidget);
      expect(find.byType(RightAside), findsOneWidget);

      // Widths come from the FF metrics (no literals in the shell).
      expect(
        tester.getSize(find.byType(FfNavRail)).width,
        EditorMetrics.ffRailWidth,
      );
      expect(
        tester.getSize(find.byType(FfPanelHost)).width,
        EditorMetrics.ffPanelWidth,
      );
      expect(
        tester.getSize(find.byType(RightAside)).width,
        EditorMetrics.ffInspectorWidth,
      );

      // Tree is the default destination: the first-class panel mounts,
      // the palette stays hidden, and the Y6-deleted classic rail is gone
      // (this cutover restores the rail as FfNavRail — planned, not a
      // regression).
      expect(find.byType(LayersPanel), findsOneWidget);
      expect(find.byType(PartsPalette), findsNothing);
    });

    testWidgets('rail switches the panel host', (tester) async {
      await _pumpShell(tester, CanvasStore());

      await tester.tap(find.byIcon(Icons.widgets_outlined));
      await tester.pump();
      expect(find.byType(PartsPalette), findsOneWidget);
      expect(find.byType(LayersPanel), findsNothing);

      await tester.tap(find.byIcon(Icons.account_tree_outlined));
      await tester.pump();
      expect(find.byType(LayersPanel), findsOneWidget);
      expect(find.byType(PartsPalette), findsNothing);
    });
  });

  group('ff7 topbar embeds', () {
    testWidgets('device + zoom strips mount wired, not hidden', (
      tester,
    ) async {
      await _pumpShell(tester, CanvasStore());

      expect(find.byType(DevicePickerEmbed), findsOneWidget);
      expect(find.byType(ZoomControlsEmbed), findsOneWidget);
    });

    testWidgets('topbar zoom drives the shell zoom', (tester) async {
      await _pumpShell(tester, CanvasStore());

      final zoomStrip = find.byType(ZoomControlsEmbed);
      expect(
        find.descendant(of: zoomStrip, matching: find.text('79%')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: zoomStrip, matching: find.byIcon(Icons.add)),
      );
      await tester.pump();
      expect(
        find.descendant(of: zoomStrip, matching: find.text('89%')),
        findsOneWidget,
      );
    });

    testWidgets('topbar device applies the preset to the current screen', (
      tester,
    ) async {
      final store = CanvasStore();
      store.addScreen();
      await _pumpShell(tester, store);

      final deviceStrip = find.byType(DevicePickerEmbed);
      await tester.tap(
        find.descendant(
          of: deviceStrip,
          matching: find.byIcon(Icons.tablet_mac),
        ),
      );
      await tester.pump();
      expect(store.doc.screens.first.device, 'tablet');

      // Landscape toggle flips the shell-owned flag (the button's tooltip
      // follows; tooltips only materialize as overlay text on hover, so
      // read the widget property, not a finder).
      await tester.tap(
        find.descendant(
          of: deviceStrip,
          matching: find.byIcon(Icons.screen_rotation),
        ),
      );
      await tester.pump();
      final rotate = tester.widget<EditorIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.screen_rotation),
          matching: find.byType(EditorIconButton),
        ),
      );
      expect(rotate.tooltip, 'Landscape on — tap for portrait');
    });
  });
}
