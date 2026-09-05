/// Canvas-area keyboard shortcuts wrapper (HANDOFF §5 item 8).
///
/// The shell places [EditorShortcuts] around the canvas area so the editor
/// responds to the reference app's keyboard shortcuts without stealing keys
/// from surrounding panels.
///
/// ## Bindings
///
/// | Action    | Keys (either Control or Meta/Cmd variant) |
/// |-----------|-------------------------------------------|
/// | Undo      | Ctrl+Z, Cmd+Z                             |
/// | Redo      | Ctrl+Shift+Z, Cmd+Shift+Z, Ctrl+Y, Cmd+Y  |
/// | Delete    | Delete, Backspace (selection only)        |
/// | Duplicate | Ctrl+D, Cmd+D (selection only)            |
/// | Preview   | Ctrl+P, Cmd+P                             |
///
/// Both `control` and `meta` variants of every modified binding are
/// registered via separate [SingleActivator]s so Windows/Linux (Control) and
/// macOS (Command/Meta) both work.
///
/// ## Semantics
///
/// * Undo fires only when [CanvasStore.canUndo] is true and calls
///   `store.undo()` (wrapped in a closure because `undo()` returns `bool`,
///   not `void` — see HANDOFF §6).
/// * Redo fires only when [CanvasStore.canRedo] is true and calls
///   `store.redo()`.
/// * Delete/Backspace fire only when [selectedNodeId] is non-null **and**
///   keyboard focus is not inside an editable text field, then forward the id
///   to [onDeleteNode] (the shell deletes the node and clears selection).
/// * Duplicate fires only when [selectedNodeId] is non-null and focus is not
///   inside an editable text field, then forwards the id to [onDuplicateNode]
///   (the shell duplicates the node and selects the copy).
/// * Preview always fires and calls [onPreview].
///
/// ## Implementation choice
///
/// [Focus] with `autofocus: true` owns the scope's focus so the bindings are
/// live as soon as the canvas area appears, with [CallbackShortcuts] mapping
/// each modified-key [SingleActivator] to a plain closure. [CallbackShortcuts]
/// was chosen over raw [Shortcuts]/[Actions] because the shell only needs
/// fire-and-forget `VoidCallback`s — no custom [Intent] classes are required.
/// Nesting order is load-bearing: [CallbackShortcuts] encloses the [Focus]
/// because shortcut lookup walks up from the focused node (see the note in
/// [EditorShortcuts.build]). The two unmodified keys (Delete, Backspace) are
/// the exception: they are handled in [Focus.onKeyEvent] rather than in
/// [CallbackShortcuts] so that returning [KeyEventResult.ignored] while
/// editing lets the key keep bubbling to the app-level text-editing shortcuts
/// (see [_handleDeleteKey]).
///
/// ## Focus / editing-text guard
///
/// Delete, Backspace (and Duplicate, which shares the guard) must not steal
/// keys from text fields such as the inspector inputs or a text part being
/// edited on the canvas. The guard is [_isEditingText], which inspects the
/// currently focused widget:
///
/// ```dart
/// FocusManager.instance.primaryFocus?.context?.widget is EditableText
/// ```
///
/// When a [TextField] (or any [EditableText]) holds primary focus, the
/// focused node is usually an inner `Focus` widget inside the editable rather
/// than the [EditableText] itself — hence the ancestor walk on top of the
/// direct `is EditableText` check. Two further subtleties, both verified by
/// widget test:
/// * Delete/Backspace cannot live in [CallbackShortcuts]: our bindings sit
///   nearer the focus than the app-level `DefaultTextEditingShortcuts` that
///   [EditableText] relies on, so a matched binding consumes the key even
///   when its callback no-ops. They are handled in [Focus.onKeyEvent] instead,
///   where returning [KeyEventResult.ignored] lets the key keep bubbling and
///   the field edits normally.
/// * Undo/redo/preview stay unguarded: a focused text field's own nearer
///   undo/redo shortcuts win for keys it consumes, and preview has no editing
///   conflict.
///
/// Note for web integrators: browsers may intercept Ctrl+P (print) before it
/// reaches Flutter; the binding is still registered per contract.
library;

import 'package:canvas_app/canvas/canvas_store.dart' hide ChangeNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps the canvas area and maps keyboard shortcuts to editor actions.
///
/// See the library doc comment for the full binding table and the
/// focus/editing-text guard approach.
class EditorShortcuts extends StatelessWidget {
  const EditorShortcuts({
    super.key,
    required this.store,
    required this.selectedNodeId,
    required this.onDeleteNode,
    required this.onDuplicateNode,
    required this.onPreview,
    required this.child,
  });

  /// Undoable editor state. Read for [CanvasStore.canUndo]/[CanvasStore.canRedo]
  /// guards; mutated via `store.undo()` / `store.redo()`.
  final CanvasStore store;

  /// Currently selected canvas node, if any. Selection-gated bindings
  /// (delete, duplicate) no-op while this is null.
  final String? selectedNodeId;

  /// Called with the selected id on Delete/Backspace. The shell deletes the
  /// node and clears selection.
  final ValueChanged<String> onDeleteNode;

  /// Called with the selected id on Ctrl/Cmd+D. The shell duplicates the node
  /// and selects the copy.
  final ValueChanged<String> onDuplicateNode;

  /// Called on Ctrl/Cmd+P to enter preview mode.
  final VoidCallback onPreview;

  /// The canvas area this widget provides shortcuts for.
  final Widget child;

  /// True while keyboard focus sits inside an editable text widget.
  ///
  /// Implemented by checking whether the primary focus's widget — or any of
  /// its ancestors — is an [EditableText] (the inner widget that backs
  /// [TextField], [TextFormField], and friends). The ancestor walk matters
  /// because the focused node is often an inner `Focus` widget inside the
  /// editable (whose own `widget` is a `Focus`, not the [EditableText]),
  /// depending on where the node was attached. Null-safe: unfocused (`null`)
  /// or context-less focus nodes report `false`.
  static bool _isEditingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    var found = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  void _undo() {
    if (store.canUndo) store.undo();
  }

  void _redo() {
    if (store.canRedo) store.redo();
  }

  void _duplicateSelected() {
    final id = selectedNodeId;
    if (id == null || _isEditingText()) return;
    onDuplicateNode(id);
  }

  /// Handles Delete/Backspace on the way up the focus tree.
  ///
  /// These two keys are deliberately NOT in the [CallbackShortcuts] bindings:
  /// a matched [CallbackShortcuts] action consumes the key even when its
  /// callback no-ops, which would swallow Backspace for a focused text field
  /// (our nearer bindings shadow the app-level `DefaultTextEditingShortcuts`
  /// that EditableText relies on). Handling them here instead lets us return
  /// [KeyEventResult.ignored] while editing so the key keeps bubbling and the
  /// field edits normally. Only [KeyDownEvent]s fire (repeats ignored, so a
  /// held key cannot double-fire across the shell's selection-clear rebuild).
  KeyEventResult _handleDeleteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.delete &&
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    final id = selectedNodeId;
    if (id == null || _isEditingText()) return KeyEventResult.ignored;
    onDeleteNode(id);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // NOTE on nesting order: [CallbackShortcuts] must enclose the [Focus].
    // Key events resolve shortcuts by walking UP the focus tree from the
    // focused node, so when the scope's own focus node holds primary focus
    // (the common case right after the canvas appears), a bindings widget
    // *below* it would never see the key. With the bindings outside, they
    // are found both when the scope node itself is focused and when focus
    // sits on any descendant (e.g. a button or text part on the canvas).
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
          // Undo: Ctrl+Z and Cmd+Z.
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
          // Redo: Ctrl/Cmd+Shift+Z and Ctrl/Cmd+Y.
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): _redo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): _redo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redo,
          // Delete/Backspace are handled in [_handleDeleteKey], not here —
          // see its doc comment for why a CallbackShortcuts binding would
          // steal Backspace from focused text fields.
          // Duplicate selection.
          const SingleActivator(LogicalKeyboardKey.keyD, control: true):
              _duplicateSelected,
          const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
              _duplicateSelected,
          // Preview.
          const SingleActivator(LogicalKeyboardKey.keyP, control: true):
              onPreview,
          const SingleActivator(LogicalKeyboardKey.keyP, meta: true): onPreview,
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: _handleDeleteKey,
          child: child,
        ),
    );
  }
}
