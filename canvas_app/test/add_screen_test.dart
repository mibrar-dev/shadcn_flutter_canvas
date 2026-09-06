import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canvas screen label (Y2: the Forge topbar tabs render the same screen
/// names, so bare `find.text` is ambiguous — scope to the canvas).
Finder canvasScreenLabel(String name) => find.descendant(
      of: find.byType(DesignCanvas),
      matching: find.text(name),
    );

void main() {
  testWidgets('toolbar add-screen adds a second phone', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: EditorShell(store: CanvasStore())));
    await tester.pump();
    expect(canvasScreenLabel('Screen 1'), findsOneWidget);
    // The toolbar tip is a kit tooltip now (invisible to `find.byTooltip`),
    // so tap the toolbar's add-screen glyph directly.
    await tester.tap(
      find.descendant(
        of: find.byType(CanvasToolbar),
        matching: find.byIcon(Icons.add_to_photos),
      ),
    );
    await tester.pump();
    expect(canvasScreenLabel('Screen 2'), findsOneWidget);
  });
}
