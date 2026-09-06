import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Reference viewport (HANDOFF §2): the 3-column shell is measured at
  /// 1440x900 and overflows the default 800x600 test surface.
  void useReferenceViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('editor shell assembles palette, canvas, and right aside',
      (tester) async {
    useReferenceViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: EditorShell(store: CanvasStore())),
    );
    await tester.pump();
    expect(find.byType(PartsPalette), findsOneWidget);
    expect(find.byType(DesignCanvas), findsOneWidget);
    // No selection → the aside auto-shows the Prompt tab, not the Inspector.
    expect(find.byType(RightAside), findsOneWidget);
    expect(find.byType(InspectorPanel), findsNothing);
    expect(find.byType(PreviewPlayer), findsNothing);
    // Toolbar entries are icon buttons with kit tooltips, not text buttons.
    // (Kit tips don't register with `find.byTooltip`; scope the glyphs to
    // the toolbar because palette tiles reuse some icon glyphs.)
    Finder toolbarIcon(IconData icon) => find.descendant(
          of: find.byType(CanvasToolbar),
          matching: find.byIcon(icon),
        );
    expect(toolbarIcon(Icons.play_arrow), findsOneWidget);
    expect(toolbarIcon(Icons.folder_open), findsOneWidget);
    // Toolbar entries stay icon-only: the text Preview action lives in the
    // Forge topbar (Y2 mount), not in the floating toolbar.
    expect(
      find.descendant(
        of: find.byType(CanvasToolbar),
        matching: find.text('Preview'),
      ),
      findsNothing,
    );
    expect(find.byType(ForgeTopbar), findsOneWidget);
    expect(find.text('Export Flutter'), findsOneWidget);
  });

  testWidgets('inspector tab shows the empty hint with no selection',
      (tester) async {
    useReferenceViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: EditorShell(store: CanvasStore())),
    );
    await tester.pump();
    // Aside opens on Prompt; switch to the Inspector tab first (scoped to
    // the aside: a palette tile reuses the tune glyph, and the Prompt
    // panel's own Settings button reuses it too — the tab header renders
    // above the body, so the first match is the Inspector tab).
    await tester.tap(
      find
          .descendant(
            of: find.byType(RightAside),
            matching: find.byIcon(Icons.tune),
          )
          .first,
    );
    await tester.pump();
    expect(find.byType(InspectorPanel), findsOneWidget);
    expect(find.text('Select an item to edit its props'), findsOneWidget);
  });

  testWidgets('preview button swaps editor for preview player',
      (tester) async {
    useReferenceViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: EditorShell(store: CanvasStore())),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(CanvasToolbar),
        matching: find.byIcon(Icons.play_arrow),
      ),
    );
    await tester.pump();
    expect(find.byType(PreviewPlayer), findsOneWidget);
    expect(find.byType(DesignCanvas), findsNothing);
  });
}
