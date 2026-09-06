/// Track Y2 origin, Track FF3 reskin (BUILD_SPEC §9.3): dense 56px Forge
/// topbar + page dropdown tests.
///
/// Covers the topbar zones (logo, project pill, page dropdown, undo/redo,
/// Preview, Export — plus the §1-1g Open icon): the dropdown lists pages
/// from props, select/add/rename/delete callbacks, undo/redo disabled
/// states, Preview/Export/Open call-through, and the device/zoom embed
/// wiring (hidden when unwired, live when wired). Also pins the three
/// additive Y2 tokens (`accent`/`onAccent`/`danger`) in both chrome modes;
/// the pre-existing values stay guarded by `light_theme_test.dart` and the
/// FF1 values by `ff_tokens_test.dart`.
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:canvas_app/ui/zoom_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Reference viewport: the full topbar row (dropdown + embeds + actions)
  /// is measured for wide screens and would clip on the default 800x600
  /// test surface.
  void useReferenceViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  const demoTabs = [
    ForgeScreenTab(id: 's1', name: 'Home'),
    ForgeScreenTab(id: 's2', name: 'Search'),
    ForgeScreenTab(id: 's3', name: 'Saved'),
  ];

  Widget harness({
    List<ForgeScreenTab> screens = demoTabs,
    String projectTitle = 'My Project',
    String? selectedScreenId = 's1',
    ValueChanged<String>? onSelectScreen,
    VoidCallback? onAddScreen,
    void Function(String id, String name)? onRenameScreen,
    ValueChanged<String>? onDeleteScreen,
    VoidCallback? onUndo,
    VoidCallback? onRedo,
    VoidCallback? onPreview,
    VoidCallback? onExport,
    VoidCallback? onOpen,
    int? deviceSelectedIndex,
    ValueChanged<int>? onDeviceSelect,
    bool landscape = false,
    ValueChanged<bool>? onLandscapeChanged,
    double? zoom,
    VoidCallback? onZoomIn,
    VoidCallback? onZoomOut,
    VoidCallback? onZoomFit,
    EditorColors colors = EditorColors.light,
  }) {
    return MaterialApp(
      home: Scaffold(
        // Kit popovers (the page dropdown) need the overlay manager; the
        // production shell provides it above the chrome — same here.
        body: shadcn.ShadcnLayer(
          child: EditorTheme(
            colors: colors,
            child: ForgeTopbar(
              projectTitle: projectTitle,
              screens: screens,
              selectedScreenId: selectedScreenId,
              onSelectScreen: onSelectScreen ?? (_) {},
              onAddScreen: onAddScreen ?? () {},
              onRenameScreen: onRenameScreen ?? (_, __) {},
              onDeleteScreen: onDeleteScreen ?? (_) {},
              onUndo: onUndo,
              onRedo: onRedo,
              onPreview: onPreview ?? () {},
              onExport: onExport ?? () {},
              onOpen: onOpen ?? () {},
              deviceSelectedIndex: deviceSelectedIndex,
              onDeviceSelect: onDeviceSelect,
              landscape: landscape,
              onLandscapeChanged: onLandscapeChanged,
              zoom: zoom,
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
              onZoomFit: onZoomFit,
            ),
          ),
        ),
      ),
    );
  }

  EditorIconButton undoButton(WidgetTester tester) =>
      tester.widget<EditorIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.undo),
          matching: find.byType(EditorIconButton),
        ),
      );

  EditorIconButton redoButton(WidgetTester tester) =>
      tester.widget<EditorIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.redo),
          matching: find.byType(EditorIconButton),
        ),
      );

  group('Forge tokens (additive, FORGE.md §2)', () {
    test('light values match the spec APPROXIMATE hexes', () {
      expect(EditorColors.light.accent, const Color(0xFF2563EB));
      expect(EditorColors.light.onAccent, const Color(0xFFFFFFFF));
      expect(EditorColors.light.danger, const Color(0xFFDC2626));
    });

    test('dark values match the spec APPROXIMATE hexes', () {
      expect(EditorColors.dark.accent, const Color(0xFF60A5FA));
      expect(EditorColors.dark.onAccent, const Color(0xFFFFFFFF));
      expect(EditorColors.dark.danger, const Color(0xFFF87171));
    });
  });

  group('Forge topbar zones (FF3 dense 56px bar)', () {
    testWidgets('renders logo, project pill, dropdown, and actions',
        (tester) async {
      useReferenceViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(
        tester.getSize(find.byType(ForgeTopbar)).height,
        EditorMetrics.ffTopbarHeight,
      );
      expect(find.text('Forge'), findsOneWidget);
      expect(find.text('My Project'), findsOneWidget);
      // The dropdown trigger shows the current page; the tab strip is gone
      // (inactive pages live in the popup, not in the bar).
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsNothing);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Export Flutter'), findsOneWidget);
      // Open icon (FORGE.md §1-1g) survives as a small topbar icon.
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('picking a page from the dropdown selects that screen',
        (tester) async {
      useReferenceViewport(tester);
      String? selected;
      await tester.pumpWidget(
        harness(onSelectScreen: (id) => selected = id),
      );
      await tester.pump();

      // The kit popover follows its anchor every frame, so the scheduler
      // never settles while it is open — drive it with bounded pumps.
      await tester.tap(find.text('Home'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Search'), findsOneWidget);
      await tester.tap(find.text('Search'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected, 's2');
    });

    testWidgets('only the selected page shows the delete affordance',
        (tester) async {
      useReferenceViewport(tester);
      String? deleted;
      await tester.pumpWidget(
        harness(onDeleteScreen: (id) => deleted = id),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(deleted, 's1');
    });

    testWidgets('no selection hides the delete affordance', (tester) async {
      useReferenceViewport(tester);
      await tester.pumpWidget(harness(selectedScreenId: null));
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('add button fires the add-screen callback', (tester) async {
      useReferenceViewport(tester);
      var adds = 0;
      await tester.pumpWidget(harness(onAddScreen: () => adds++));
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('ff-page-selector')),
          matching: find.byIcon(Icons.add),
        ),
      );
      await tester.pump();
      expect(adds, 1);
    });

    testWidgets('rename icon edits the selected page inline', (tester) async {
      useReferenceViewport(tester);
      final renamed = <String>[];
      await tester.pumpWidget(
        harness(
          onRenameScreen: (id, name) => renamed.add('$id=$name'),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'Gallery');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      expect(renamed, ['s1=Gallery']);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('empty rename cancels without calling back', (tester) async {
      useReferenceViewport(tester);
      var calls = 0;
      await tester.pumpWidget(
        harness(onRenameScreen: (_, __) => calls++),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '   ');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      expect(calls, 0);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  group('undo/redo disabled states', () {
    testWidgets('null callbacks render the disabled state', (tester) async {
      useReferenceViewport(tester);
      await tester.pumpWidget(harness(onUndo: null, onRedo: null));
      await tester.pump();

      expect(undoButton(tester).onPressed, isNull);
      expect(redoButton(tester).onPressed, isNull);
    });

    testWidgets('wired callbacks fire on tap', (tester) async {
      useReferenceViewport(tester);
      var undos = 0;
      var redos = 0;
      await tester.pumpWidget(
        harness(onUndo: () => undos++, onRedo: () => redos++),
      );
      await tester.pump();

      expect(undoButton(tester).onPressed, isNotNull);
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.redo));
      await tester.pump();
      expect(undos, 1);
      expect(redos, 1);
    });
  });

  group('action call-through', () {
    testWidgets('Preview, Export, and Open delegate to shell callbacks',
        (tester) async {
      useReferenceViewport(tester);
      var previews = 0;
      var exports = 0;
      var opens = 0;
      await tester.pumpWidget(
        harness(
          onPreview: () => previews++,
          onExport: () => exports++,
          onOpen: () => opens++,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Preview'));
      await tester.pump();
      await tester.tap(find.text('Export Flutter'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pump();
      expect(previews, 1);
      expect(exports, 1);
      expect(opens, 1);
    });
  });

  group('device/zoom embeds', () {
    testWidgets('embeds stay hidden until the shell wires them',
        (tester) async {
      useReferenceViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.byType(DevicePickerEmbed), findsNothing);
      expect(find.byType(ZoomControlsEmbed), findsNothing);
    });

    testWidgets('wired device strip selects presets and rotates',
        (tester) async {
      useReferenceViewport(tester);
      var selected = -1;
      var landscape = false;
      await tester.pumpWidget(
        harness(
          deviceSelectedIndex: 0,
          onDeviceSelect: (i) => selected = i,
          landscape: false,
          onLandscapeChanged: (v) => landscape = v,
        ),
      );
      await tester.pump();

      expect(find.byType(DevicePickerEmbed), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tablet_mac));
      await tester.pump();
      expect(selected, 1);
      await tester.tap(find.byIcon(Icons.screen_rotation));
      await tester.pump();
      expect(landscape, isTrue);
    });

    testWidgets('wired zoom strip shows the readout and zooms',
        (tester) async {
      useReferenceViewport(tester);
      var ins = 0;
      var outs = 0;
      var fits = 0;
      await tester.pumpWidget(
        harness(
          zoom: 1.0,
          onZoomIn: () => ins++,
          onZoomOut: () => outs++,
          onZoomFit: () => fits++,
        ),
      );
      await tester.pump();

      expect(find.byType(ZoomControlsEmbed), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      // The page selector also carries an add glyph — scope zoom taps to
      // the embedded strip.
      final zoomAdd = find.descendant(
        of: find.byType(ZoomControlsEmbed),
        matching: find.byIcon(Icons.add),
      );
      expect(zoomAdd, findsOneWidget);
      await tester.tap(zoomAdd);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pump();
      expect(ins, 1);
      expect(outs, 1);
      expect(fits, 1);
    });
  });
}
