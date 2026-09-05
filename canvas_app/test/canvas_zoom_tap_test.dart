import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/canvas_store.dart' show CanvasStore;
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The live release build showed clicks on the *visible* button missing at
/// fractional zooms. This pins layout/hit parity of the zoomed canvas: the
/// tap target resolved from the render tree must select the leaf.
void main() {
  for (final zoom in <double>[1.0, 0.99, 0.89, 0.79, 0.59]) {
    testWidgets('tap at rendered center selects leaf at zoom $zoom', (
      tester,
    ) async {
      final store = CanvasStore();
      store.replaceDoc(ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'r1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [],
            'parentId': null,
            'isRow': true,
            'gap': 8.0,
          },
          {
            'id': 'b1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'ib1', 'kind': 'button', 'label': 'TapMe'},
            ],
            'parentId': 'r1',
          },
        ],
        'theme': {
          'paletteKey': 'clean-slate',
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'ZoomTap', 'brief': ''},
      }));
      String? selected;
      tester.view.physicalSize = const Size(1440, 813);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ThemedCanvas(
          theme: store.doc.theme,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: DesignCanvas(
                  store: store,
                  zoom: zoom,
                  onSelectNode: (id) => selected = id,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.text('TapMe'));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      expect(selected, 'b1', reason: 'zoom $zoom, tapped at $center');
    });
  }
}
