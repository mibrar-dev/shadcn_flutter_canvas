import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Row-inspector + full-prop audit tests.
///
/// AUDIT (enforced): every [kCatalog] kind resolves a [kInspectorSchemas]
/// entry — loop test below.
///
/// ROW UI: row container nodes (created via `store.addRow`) carry no items,
/// so the inspector shows the container editor (Forge `Kind · id` header +
/// child count + gap stepper reporting through `store.patchNode`).
void main() {
  group('inspector schema audit', () {
    test('every catalog kind resolves a schema (loop)', () {
      expect(kCatalog, isNotEmpty);
      for (final entry in kCatalog) {
        expect(
          kInspectorSchemas.containsKey(entry.kind),
          isTrue,
          reason: 'missing kInspectorSchemas entry for kind ${entry.kind}',
        );
      }
    });

    test('all 97 catalog kinds are covered', () {
      const expected = {
        'button',
        'card',
        'input',
        'badge',
        'switch',
        'avatar',
        'checkbox',
        'divider',
        'progress',
        'tabs',
        'accordion',
        'select',
        'radio_group',
        'skeleton',
        'breadcrumb',
        'dialog',
        'tooltip',
        'toast',
        'drawer',
        // Track J additions (2026-09-05).
        'basic',
        'card_image',
        'scaffold',
        'collapsible',
        'steps',
        'timeline',
        'outlined_container',
        'hidden',
        'keyboard_shortcut',
        'tracker',
        'chat',
        'selectable',
        'star_rating',
        'clickable',
        'scrollbar',
        'pagination',
        'alert_dialog',
        // Track M additions (2026-09-05).
        'menu',
        'popover',
        'popup',
        'menubar',
        'dropdown_menu',
        'context_menu',
        'hover_card',
        'command',
        'swiper',
        'refresh_trigger',
        'tab_container',
        'tab_list',
        'tab_pane',
        'stepper',
        'slider',
        // Track P additions (2026-09-05).
        'input_otp',
        'calendar',
        'date_picker',
        'time_picker',
        'carousel',
        'tree',
        'table',
        'form',
        'form_field',
        'formatted_input',
        'validated',
        'color_picker',
        'color_input',
        'hsl',
        'hsv',
        'history',
        'feature_carousel',
        // Track FF2 additions (2026-09-06): covered via the derived
        // `kInspectorSchemas` (built from `kPropSchemas`, no inspector edit).
        'phone_input',
        'item_picker',
        'chip_input',
        'autocomplete',
        'multiple_choice',
        'object_input',
        'text_field',
        'text',
        'icon',
        'navigation_menu',
        'dropzone',
        'border_loading',
        'overflow_marquee',
        'focus_outline',
        'switcher',
        'scrollable',
        'stage_container',
        'media_query',
        'scrollview',
        'hover',
        'patch',
        'filter_bar',
        'fade_scroll',
        'resizable',
        'subfocus',
        'repeated_animation_builder',
        'markdown',
        'text_animate',
        // Track Y1 addition (2026-09-06): covered via the derived
        // `kInspectorSchemas` (built from `kPropSchemas`, no inspector edit).
        'navigation_bar',
      };
      expect(Set.of(kCatalog.map((e) => e.kind)), expected);
      expect(Set.of(kInspectorSchemas.keys), containsAll(expected));
    });
  });

  group('row container editor', () {
    testWidgets('row node shows gap editor', (tester) async {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InspectorPanel(store: store, nodeId: rowId),
          ),
        ),
      );
      await tester.pump();
      // Forge SELECTED header (Y5 restyle): the old badge + id row is now
      // one `Kind · id` line (keyed — the row's own parent-picker entry
      // renders the same label text, so a bare `find.text` matches twice).
      expect(
        find.byKey(const ValueKey('inspector-selected-header')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(
          find.byKey(const ValueKey('inspector-selected-header')),
        ).data,
        'Row · $rowId',
      );
      expect(find.text('0 children'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      // Step up to 12 through the real button.
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).gap,
        12.0,
      );
    });

    test('patchNode persists the gap and undo restores it', () {
      final store = CanvasStore();
      final rowId = store.addRow(screenId: 's1');
      store.patchNode(rowId, gap: 20.0);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).gap,
        20.0,
      );
      expect(store.undo(), isTrue);
      expect(
        store.doc.nodes.singleWhere((n) => n.id == rowId).gap,
        8.0,
      );
    });
  });
}
