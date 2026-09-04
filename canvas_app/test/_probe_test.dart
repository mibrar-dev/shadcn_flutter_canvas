import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canvas_app/ui/editor_buttons.dart';

void main() {
  testWidgets('EditorIconButton fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: EditorIconButton(
            icon: Icons.play_arrow,
            tooltip: 'Preview',
            onPressed: () => taps++,
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(EditorIconButton));
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'EditorIconButton did not fire');
  });
}
