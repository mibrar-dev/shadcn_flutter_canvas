/// Track Y2 (FORGE.md §5): Forge topbar + Forge token tests.
///
/// Covers the six topbar zones (logo, project pill, screen tabs, undo/redo,
/// Preview, Export — plus the §1-1g Open icon): tabs render from props,
/// select/add/rename/delete callbacks, undo/redo disabled states, and
/// Preview/Export/Open call-through. Also pins the three additive Y2 tokens
/// (`accent`/`onAccent`/`danger`) in both chrome modes; the pre-existing
/// values stay guarded by `light_theme_test.dart`.
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_buttons.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Reference viewport: the full topbar row (tabs + actions) is measured
  /// for wide screens and would clip on the default 800x600 test surface.
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
    EditorColors colors = EditorColors.light,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EditorTheme(
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

  group('Forge topbar zones', () {
    testWidgets('renders logo, project pill, tabs, and actions at 64px',
        (tester) async {
      useReferenceViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(tester.getSize(find.byType(ForgeTopbar)).height, 64);
      expect(find.text('Forge'), findsOneWidget);
      expect(find.text('My Project'), findsOneWidget);
      for (final tab in demoTabs) {
        expect(find.text(tab.name), findsOneWidget);
      }
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Export Flutter'), findsOneWidget);
      // Open icon (FORGE.md §1-1g) survives as a small topbar icon.
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('tapping an inactive tab selects that screen', (tester) async {
      useReferenceViewport(tester);
      String? selected;
      await tester.pumpWidget(
        harness(onSelectScreen: (id) => selected = id),
      );
      await tester.pump();

      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(selected, 's2');
    });

    testWidgets('only the active tab shows the delete affordance',
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

    testWidgets('add button fires the add-screen callback', (tester) async {
      useReferenceViewport(tester);
      var adds = 0;
      await tester.pumpWidget(harness(onAddScreen: () => adds++));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(adds, 1);
    });

    testWidgets('double-clicking the active tab renames inline',
        (tester) async {
      useReferenceViewport(tester);
      final renamed = <String>[];
      await tester.pumpWidget(
        harness(
          onRenameScreen: (id, name) => renamed.add('$id=$name'),
        ),
      );
      await tester.pump();

      // Two taps inside the double-tap window (above kDoubleTapMinTime,
      // below kDoubleTapTimeout); the trailing pump flushes the
      // recognizer's min-time gate and rebuilds with the editor.
      await tester.tap(find.text('Home'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Home'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(shadcn.TextField), findsOneWidget);

      await tester.enterText(
        find.byType(shadcn.TextField),
        'Gallery',
      );
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      expect(renamed, ['s1=Gallery']);
      expect(find.byType(shadcn.TextField), findsNothing);
    });

    testWidgets('empty rename cancels without calling back', (tester) async {
      useReferenceViewport(tester);
      var calls = 0;
      await tester.pumpWidget(
        harness(onRenameScreen: (_, __) => calls++),
      );
      await tester.pump();

      await tester.tap(find.text('Home'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Home'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(shadcn.TextField), '   ');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      expect(calls, 0);
      expect(find.byType(shadcn.TextField), findsNothing);
    });

    testWidgets('double-tap on an inactive tab selects, never edits',
        (tester) async {
      useReferenceViewport(tester);
      String? selected;
      await tester.pumpWidget(
        harness(onSelectScreen: (id) => selected = id),
      );
      await tester.pump();

      await tester.tap(find.text('Search'));
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(selected, 's2');
      expect(find.byType(shadcn.TextField), findsNothing);
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
}
