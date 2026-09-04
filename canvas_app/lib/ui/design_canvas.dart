/// Pan/zoom canvas viewport hosting the screen frames.
///
/// Rebuilds on store changes through [_StoreRelay], which forwards the
/// pure-Dart [CanvasStore] notifications to Flutter's listenable world
/// (the plan's sanctioned `Listenable` adapter under `lib/ui/`).
///
/// The palette lives in the editor shell, not here — this widget owns only the
/// scrollable/zoomable surface, matching the reference's centre column.
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/phone_frame.dart';
import 'package:canvas_core/canvas_core.dart';

/// Forwards pure-Dart store notifications to Flutter listeners.
class _StoreRelay extends foundation.ChangeNotifier {
  _StoreRelay(this._store) {
    _store.addListener(_forward);
  }

  final CanvasStore _store;

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_forward);
    super.dispose();
  }
}

/// Editor surface: drag a palette tile onto a phone frame to add a node.
class DesignCanvas extends StatefulWidget {
  final CanvasStore store;
  final String screenId;

  /// Current viewport scale, driven by the shell's zoom controls.
  final double zoom;

  /// `true` while the pan tool is active, so drags move the viewport instead
  /// of selecting.
  final bool panMode;

  /// Forwarded whenever the selection changes (shell wires it to the inspector).
  final ValueChanged<String?>? onSelectNode;

  const DesignCanvas({
    super.key,
    required this.store,
    this.screenId = 's1',
    this.zoom = 1.0,
    this.panMode = false,
    this.onSelectNode,
  });

  /// Store-level drop handler: adds exactly one node carrying [kind] at
  /// [offset] (frame-local logical px) to [screenId], seeded with the
  /// catalog defaults. Unknown kinds are accepted — [ScreenSurface] renders
  /// them via the catalog fallback instead of crashing. Returns the node id.
  String onAccept(String kind, Offset offset) {
    final entry = findEntry(kind);
    final item = CanvasItem(
      id: store.uid(),
      kind: kind,
      props: entry == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.of(entry.defaults),
    );
    return store.addNode(
      screenId: screenId,
      x: offset.dx,
      y: offset.dy,
      items: [item],
    );
  }

  @override
  State<DesignCanvas> createState() => _DesignCanvasState();
}

class _DesignCanvasState extends State<DesignCanvas> {
  late final _StoreRelay _relay = _StoreRelay(widget.store);
  String? _selectedNodeId;
  Offset _pan = Offset.zero;

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return ListenableBuilder(
      listenable: _relay,
      builder: (context, _) {
        final doc = widget.store.doc;
        CanvasScreen? screen;
        for (final s in doc.screens) {
          if (s.id == widget.screenId) screen = s;
        }
        screen ??= doc.screens.isEmpty ? null : doc.screens.first;
        if (screen == null) {
          return Center(
            child: Text(
              'No screens',
              style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
            ),
          );
        }
        final current = screen;
        final nodes = [
          for (final n in doc.nodes)
            if (n.screenId == current.id) n,
        ];
        final surface = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenLabel(name: current.name),
            const SizedBox(height: 10),
            ScreenSurface(
              screen: current,
              nodes: nodes,
              selectedNodeId: _selectedNodeId,
              onSelectNode: (id) {
                setState(() => _selectedNodeId = id);
                widget.onSelectNode?.call(id);
              },
              onDropKind: (kind, position) =>
                  widget.onAccept(kind, position),
            ),
          ],
        );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: widget.panMode
              ? (d) => setState(() => _pan += d.delta)
              : null,
          child: MouseRegion(
            cursor: widget.panMode
                ? SystemMouseCursors.grab
                : SystemMouseCursors.basic,
            child: Center(
              child: Transform.translate(
                offset: _pan,
                child: Transform.scale(
                  scale: widget.zoom,
                  child: surface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
