import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/keyboard_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends a key press with the given modifiers held (Control/Command/Shift).
///
/// NOTE: the physical Left variants are used deliberately — the generic
/// [LogicalKeyboardKey.control]/[meta]/[shift] do not set
/// `isControlPressed`/`isMetaPressed`/`isShiftPressed` on the simulated event,
/// so [SingleActivator]s with `control:`/`meta:`/`shift:` never match them.
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool meta = false,
  bool shift = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _pumpShortcuts(
  WidgetTester tester, {
  required CanvasStore store,
  String? selectedNodeId,
  ValueChanged<String>? onDeleteNode,
  ValueChanged<String>? onDuplicateNode,
  VoidCallback? onPreview,
  Widget? child,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EditorShortcuts(
          store: store,
          selectedNodeId: selectedNodeId,
          onDeleteNode: onDeleteNode ?? (_) {},
          onDuplicateNode: onDuplicateNode ?? (_) {},
          onPreview: onPreview ?? () {},
          child: child ?? const SizedBox.expand(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Ctrl+Z undoes, guarded when history is empty', (tester) async {
    final store = CanvasStore();
    store.addNode(screenId: 's1', x: 0, y: 0);
    expect(store.canUndo, isTrue);

    await _pumpShortcuts(tester, store: store);
    await _press(tester, LogicalKeyboardKey.keyZ, control: true);

    expect(store.doc.nodes, isEmpty);
    expect(store.canUndo, isFalse);

    // Guarded: pressing undo with empty history is a no-op, not a crash.
    await _press(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(store.doc.nodes, isEmpty);
  });

  testWidgets('Cmd+Z undoes via the meta variant', (tester) async {
    final store = CanvasStore();
    store.addNode(screenId: 's1', x: 0, y: 0);

    await _pumpShortcuts(tester, store: store);
    await _press(tester, LogicalKeyboardKey.keyZ, meta: true);

    expect(store.doc.nodes, isEmpty);
  });

  testWidgets('redo works via Ctrl+Shift+Z and Ctrl+Y', (tester) async {
    final store = CanvasStore();
    store.addNode(screenId: 's1', x: 0, y: 0);
    expect(store.undo(), isTrue);
    expect(store.doc.nodes, isEmpty);

    await _pumpShortcuts(tester, store: store);
    await _press(
      tester,
      LogicalKeyboardKey.keyZ,
      control: true,
      shift: true,
    );
    expect(store.doc.nodes, hasLength(1));

    // Ctrl+Shift+Z must not have been swallowed as undo: history still redos.
    expect(store.undo(), isTrue);
    await _press(tester, LogicalKeyboardKey.keyY, control: true);
    expect(store.doc.nodes, hasLength(1));

    // Meta variants.
    expect(store.undo(), isTrue);
    await _press(tester, LogicalKeyboardKey.keyY, meta: true);
    expect(store.doc.nodes, hasLength(1));
  });

  testWidgets('redo is guarded when redo history is empty', (tester) async {
    final store = CanvasStore();
    await _pumpShortcuts(tester, store: store);
    await _press(
      tester,
      LogicalKeyboardKey.keyZ,
      control: true,
      shift: true,
    );
    expect(store.doc.nodes, isEmpty);
  });

  testWidgets('Delete/Backspace forward the selection id', (tester) async {
    for (final key in [
      LogicalKeyboardKey.delete,
      LogicalKeyboardKey.backspace,
    ]) {
      final deleted = <String>[];
      await _pumpShortcuts(
        tester,
        store: CanvasStore(),
        selectedNodeId: 'n1',
        onDeleteNode: deleted.add,
      );
      await _press(tester, key);
      expect(deleted, ['n1']);
    }
  });

  testWidgets('Delete with no selection is a no-op', (tester) async {    var calls = 0;
    await _pumpShortcuts(
      tester,
      store: CanvasStore(),
      onDeleteNode: (_) => calls++,
    );
    await _press(tester, LogicalKeyboardKey.delete);
    await _press(tester, LogicalKeyboardKey.backspace);
    expect(calls, 0);
  });

  testWidgets('Delete fires when focus is on a descendant widget',
      (tester) async {
    // onKeyEvent must bubble from the focused descendant up to the scope.
    final deleted = <String>[];
    await _pumpShortcuts(
      tester,
      store: CanvasStore(),
      selectedNodeId: 'n1',
      onDeleteNode: deleted.add,
      child: const Center(child: TextButton(onPressed: null, child: Text('x'))),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.backspace);
    expect(deleted, ['n1']);
  });

  testWidgets('Delete inside a text field does not delete the node',
      (tester) async {
    final deleted = <String>[];
    await _pumpShortcuts(
      tester,
      store: CanvasStore(),
      selectedNodeId: 'n1',
      onDeleteNode: deleted.add,
      child: const TextField(),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'hi');
    await _press(tester, LogicalKeyboardKey.backspace);

    // The keystroke went to the field (editing 'hi' -> 'h'), not to onDeleteNode.
    expect(deleted, isEmpty);
    expect(find.text('h'), findsOneWidget);
  });

  testWidgets('Ctrl+D duplicates the selection, no-op without one',
      (tester) async {
    final duplicated = <String>[];
    await _pumpShortcuts(
      tester,
      store: CanvasStore(),
      selectedNodeId: 'n1',
      onDuplicateNode: duplicated.add,
    );
    await _press(tester, LogicalKeyboardKey.keyD, control: true);
    expect(duplicated, ['n1']);

    final noneSelected = <String>[];
    await _pumpShortcuts(
      tester,
      store: CanvasStore(),
      onDuplicateNode: noneSelected.add,
    );
    await _press(tester, LogicalKeyboardKey.keyD, meta: true);
    expect(noneSelected, isEmpty);
  });

  testWidgets('Ctrl+P and Cmd+P call onPreview', (tester) async {
    var calls = 0;
    await _pumpShortcuts(
      tester,
      store: CanvasStore(),
      onPreview: () => calls++,
    );
    await _press(tester, LogicalKeyboardKey.keyP, control: true);
    await _press(tester, LogicalKeyboardKey.keyP, meta: true);
    expect(calls, 2);
  });

}
