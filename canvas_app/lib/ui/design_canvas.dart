/// Vertical-slice host: palette + phone frame + drop handling.
///
/// Rebuilds on store changes through [_StoreRelay], which forwards the
/// pure-Dart [CanvasStore] notifications to Flutter's listenable world
/// (the plan's sanctioned `Listenable` adapter under `lib/ui/`).
library;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/ui/palette_panel.dart';
import 'package:canvas_app/ui/phone_frame.dart';

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

/// Editor surface: drag a palette tile onto the phone frame to add a node.
class DesignCanvas extends StatefulWidget {
  final CanvasStore store;
  final String screenId;

  const DesignCanvas({super.key, required this.store, this.screenId = 's1'});

  /// Store-level drop handler: adds exactly one node carrying [kind] at
  /// [offset] (frame-local logical px) to [screenId], seeded with the
  /// catalog defaults. Unknown kinds are accepted — [PhoneFrame] renders
  /// them via [fallbackBuilder] instead of crashing. Returns the node id.
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
  final GlobalKey _frameKey = GlobalKey();
  String? _selectedNodeId;

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          return const Center(child: Text('No screens'));
        }
        final current = screen;
        final nodes = [
          for (final n in doc.nodes)
            if (n.screenId == current.id) n,
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 280, child: PalettePanel()),
            Expanded(
              child: DragTarget<String>(
                onAcceptWithDetails: (details) {
                  final box = _frameKey.currentContext?.findRenderObject()
                      as RenderBox?;
                  final local = box == null
                      ? details.offset
                      : box.globalToLocal(details.offset);
                  widget.onAccept(details.data, local);
                },
                builder: (context, candidate, rejected) => PhoneFrame(
                  key: _frameKey,
                  screen: current,
                  nodes: nodes,
                  selectedNodeId: _selectedNodeId,
                  onSelectNode: (id) => setState(() => _selectedNodeId = id),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
