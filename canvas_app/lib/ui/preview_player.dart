/// Full-screen preview: hides editor chrome, runs real widgets.
///
/// Taps reach the real catalog widgets: items WITHOUT actions are not wrapped
/// at all, and items WITH an action get a [_TapCatcher] that pushes the target
/// screen. [_TapCatcher] uses a raw [Listener] on purpose: the kit buttons
/// resolve taps through `Clickable`'s own `GestureDetector`, which wins the
/// gesture arena against an ancestor `GestureDetector.onTap` (same-type tap
/// recognizers compete — only the inner one fires, verified by probe), so a
/// wrapping `GestureDetector` would silently never navigate. Pointer events
/// bypass the arena, so both the widget's own tap and navigation fire.
/// Back pops the preview stack, or calls [onExit] at the stack root (return
/// to the editor). Unknown action targets are ignored; unknown kinds render
/// the catalog fallback.
///
/// The player takes an immutable [ScreenDoc] snapshot (preview never edits),
/// themed by [themeOverride] or `doc.theme` via [ThemedCanvas].
///
/// Content area is exempt from the chrome dogfooding rule (user content), but
/// the chrome here (back bar) still uses registry widgets via
/// `lib/shadcn_ui.dart` — no raw Material or Cupertino widgets in this file.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/theme_bar.dart';

/// Preview host over [doc] starting at [startScreenId] (or the first screen).
class PreviewPlayer extends StatefulWidget {
  final ScreenDoc doc;
  final CanvasTheme? themeOverride;
  final String? startScreenId;

  /// Called when back is pressed at the stack root.
  final VoidCallback? onExit;

  const PreviewPlayer({
    super.key,
    required this.doc,
    this.themeOverride,
    this.startScreenId,
    this.onExit,
  });

  @override
  State<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends State<PreviewPlayer> {
  late List<String> _stack = [
    if (widget.startScreenId != null)
      widget.startScreenId!
    else if (widget.doc.screens.isNotEmpty)
      widget.doc.screens.first.id,
  ];

  String? get _currentId => _stack.isEmpty ? null : _stack.last;

  CanvasScreen? _screen(String id) {
    for (final screen in widget.doc.screens) {
      if (screen.id == id) return screen;
    }
    return null;
  }

  void _onItemTap(CanvasItem item) {
    final to = item.action?.to;
    if (to == null || _screen(to) == null) return;
    setState(() => _stack.add(to));
  }

  void _onBack() {
    if (_stack.length > 1) {
      setState(() => _stack.removeLast());
    } else {
      widget.onExit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentId == null ? null : _screen(_currentId!);
    final colors = EditorTheme.of(context);
    return ThemedCanvas(
      theme: widget.themeOverride ?? widget.doc.theme,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    shadcn.GhostButton(
                      onPressed: _onBack,
                      child: const Text('‹ Back'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        current?.name ?? 'No screens',
                        style: EditorType.screenLabel
                            .copyWith(color: colors.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: current == null
                    ? Center(
                        child: Text(
                          'No screens to preview',
                          style: EditorType.field.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final node in widget.doc.nodes)
                            if (node.screenId == current.id)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final item in node.items)
                                      _previewItem(item),
                                  ],
                                ),
                              ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Action-less items render bare so every gesture reaches the real widget.
  Widget _previewItem(CanvasItem item) {
    final built = buildCatalogItem(item.kind, item.props);
    if (item.action == null) return built;
    return _TapCatcher(
      onTap: () => _onItemTap(item),
      child: built,
    );
  }
}

/// Arena-independent tap catcher: raw pointer down/up within [kTouchSlop]
/// counts as a tap. Ignores drags (e.g. scrolling the preview list) and
/// never joins the gesture arena, so wrapped widgets keep their own taps.
class _TapCatcher extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TapCatcher({required this.onTap, required this.child});

  @override
  State<_TapCatcher> createState() => _TapCatcherState();
}

class _TapCatcherState extends State<_TapCatcher> {
  final Map<int, Offset> _downs = {};

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _downs[event.pointer] = event.position,
      onPointerUp: (event) {
        final down = _downs.remove(event.pointer);
        if (down != null &&
            (event.position - down).distance <= kTouchSlop) {
          widget.onTap();
        }
      },
      onPointerCancel: (event) => _downs.remove(event.pointer),
      child: widget.child,
    );
  }
}
