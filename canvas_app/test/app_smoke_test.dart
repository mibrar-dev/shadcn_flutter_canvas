import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/main.dart';import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/palette_panel.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editor shell assembles palette, canvas, and inspector',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EditorShell(store: CanvasStore())),
    );
    await tester.pump();
    expect(find.byType(PalettePanel), findsOneWidget);
    expect(find.byType(DesignCanvas), findsOneWidget);
    expect(find.byType(InspectorPanel), findsOneWidget);
    expect(find.byType(PreviewPlayer), findsNothing);
  });

  testWidgets('preview button swaps editor for preview player',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EditorShell(store: CanvasStore())),
    );
    await tester.pump();
    await tester.tap(find.text('Preview'));
    await tester.pump();
    expect(find.byType(PreviewPlayer), findsOneWidget);
    expect(find.byType(DesignCanvas), findsNothing);
  });
}
