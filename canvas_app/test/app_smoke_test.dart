import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/forge_canvas_header.dart';
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

  testWidgets('editor shell assembles forge chrome (Y6 cutover)',
      (tester) async {
    useReferenceViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: EditorShell(store: CanvasStore())),
    );
    await tester.pump();
    // Forge pieces coexist: topbar + header + library + canvas + aside.
    expect(find.byType(ForgeTopbar), findsOneWidget);
    expect(find.byType(ForgeCanvasHeader), findsOneWidget);
    expect(find.byType(PartsPalette), findsOneWidget);
    expect(find.byType(DesignCanvas), findsOneWidget);
    expect(find.byType(RightAside), findsOneWidget);
    // No selection → the aside auto-shows the Prompt tab, not the Inspector,
    // and the black selection toolbar stays hidden.
    expect(find.byType(InspectorPanel), findsNothing);
    expect(find.byKey(kForgeSelectionToolbarKey), findsNothing);
    expect(find.byType(PreviewPlayer), findsNothing);
    // Y6 removals: the old rail and the old always-visible toolbar are gone
    // (the rail widget no longer exists; here we pin the old toolbar type
    // absent from the shell).
    expect(find.byType(CanvasToolbar), findsNothing);
    // Library|Layers pills + bottom Theme disclosure own the left column.
    expect(find.byKey(const ValueKey('forge-left-pill-library')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('forge-left-pill-layers')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('forge-left-theme-disclosure')),
        findsOneWidget);
    // The Export action lives in the Forge topbar (not in a floating bar).
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

  testWidgets('preview pill swaps editor for preview player', (tester) async {
    useReferenceViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: EditorShell(store: CanvasStore())),
    );
    await tester.pump();
    // Y6: Preview lives in the Forge topbar pill (black pill, white text +
    // play icon) — the old floating-toolbar play glyph is gone.
    await tester.tap(
      find.descendant(
        of: find.byType(ForgeTopbar),
        matching: find.text('Preview'),
      ),
    );
    await tester.pump();
    expect(find.byType(PreviewPlayer), findsOneWidget);
    expect(find.byType(DesignCanvas), findsNothing);
  });
}
