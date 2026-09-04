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
  /// [offset] (frame-local logical px) to the target screen, seeded with the
  /// catalog defaults. Unknown kinds are accepted — [ScreenSurface] renders
  /// them via the catalog fallback instead of crashing. Returns the node id.
  ///
  /// Pass [screenId] to target a specific screen (per-surface drops do this);
  /// when omitted the drop lands on [this.screenId], preserving the original
  /// single-screen call shape.
  String onAccept(String kind, Offset offset, {String? screenId}) {
    final entry = findEntry(kind);
    final item = CanvasItem(
      id: store.uid(),
      kind: kind,
      props: entry == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.of(entry.defaults),
    );
    return store.addNode(
      screenId: screenId ?? this.screenId,
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
        if (doc.screens.isEmpty) {
          return Center(
            child: Text(
              'No screens',
              style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
            ),
          );
        }
        // All screens side by side. No dividers between screens (the
        // reference shares one background across columns). Gap: no screen-gap
        // token exists in EditorMetrics, so a local 48.0 const.
        const screenGap = 48.0;
        final surfaces = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < doc.screens.length; i++) ...[
              if (i > 0) const SizedBox(width: screenGap),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenLabel(name: doc.screens[i].name),
                  const SizedBox(height: 10),
                  ScreenSurface(
                    screen: doc.screens[i],
                    nodes: [
                      for (final n in doc.nodes)
                        if (n.screenId == doc.screens[i].id) n,
                    ],
                    selectedNodeId: _selectedNodeId,
                    zoom: widget.zoom,
                    onSelectNode: (id) {
                      setState(() => _selectedNodeId = id);
                      widget.onSelectNode?.call(id);
                    },
                    onDropKind: (kind, position) => widget.onAccept(
                      kind,
                      position,
                      screenId: doc.screens[i].id,
                    ),
                  ),
                ],
              ),
            ],
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
                  child: surfaces,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
