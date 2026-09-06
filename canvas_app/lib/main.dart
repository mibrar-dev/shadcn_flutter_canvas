/// Editor shell, laid out to match the m3e-canvas reference.
///
/// Three columns at a 1440x900 viewport: a 320px left aside (52px icon rail +
/// parts panel), the flexible canvas, and a 320px right aside. The columns
/// share one background with no dividers — see [EditorMetrics] for the
/// measured values.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:canvas_app/canvas/canvas_store.dart' hide ChangeNotifier;
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/export_panel.dart';
import 'package:canvas_app/ui/icon_rail.dart';
import 'package:canvas_app/ui/keyboard_shortcuts.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/open_dialog.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:canvas_app/ui/selection_model.dart';
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_app/ui/theme_panels.dart';
import 'package:canvas_app/ui/zoom_controls.dart';
export 'ui/selection_model.dart'
    show
        toggleNodeSelection,
        rangeNodeSelection,
        resolveNodeTap,
        NodeTapSelection,
        canGroupNodes,
        ungroupTargetRow,
        ungroupRowDoc;

/// Package asset prefix for fonts bundled by `flutter_shadcn_kit`.
const _kitFonts = 'packages/flutter_shadcn_kit/assets/fonts';

/// The kit's `IconData`/typography reference short family names
/// (`LucideIcons`, `GeistSans`, …) while the Flutter tool registers package
/// fonts under `packages/<pkg>/<family>` (see `FontManifest.json`), so the
/// families never resolve and icons render as tofu boxes. Register short-name
/// aliases at startup so every kit widget resolves its intended font.
Future<void> _loadKitFontAliases() async {
  const families = <String, List<String>>{
    'LucideIcons': ['lucide.ttf'],
    'RadixIcons': ['radix.otf'],
    'BootstrapIcons': ['bootstrap.otf'],
    'NotoSansSymbols2': ['NotoSansSymbols2-Regular.ttf'],
    'GeistSans': [
      'Geist-Regular.otf',
      'Geist-Medium.otf',
      'Geist-SemiBold.otf',
      'Geist-Bold.otf',
    ],
    'GeistMono': [
      'GeistMono-Regular.otf',
      'GeistMono-Medium.otf',
      'GeistMono-SemiBold.otf',
      'GeistMono-Bold.otf',
    ],
  };
  for (final entry in families.entries) {
    try {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('$_kitFonts/$file'));
      }
      await loader.load();
    } catch (_) {
      // One missing alias must not prevent startup; affected glyphs fall
      // back to the system font as before.
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadKitFontAliases();
  runApp(const CanvasRoot());
}

class CanvasRoot extends StatelessWidget {
  const CanvasRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadcn Canvas',
      debugShowCheckedModeBanner: false,
      // Production prefs: autosave persists to localStorage on web and
      // initState's load() restores it (migrated to flow on read).
      home: EditorShell(store: CanvasStore(prefs: SharedPreferencesPrefs())),
    );
  }
}

/// Forwards pure-Dart store notifications to Flutter (same relay pattern as
/// the editor panels, which each own a private equivalent).
class _ShellRelay extends ChangeNotifier {
  _ShellRelay(this._store) {
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

/// Track D2 multi-selection primitives (pure, widget-testable) live in
/// `ui/selection_model.dart` and are re-exported above so existing
/// `package:canvas_app/main.dart` imports (e.g. `multiselect_test.dart`) keep
/// resolving. The shell owns a SET of selected node ids plus a range anchor;
/// screen selection stays a single id mutually exclusive with any node
/// selection. Canvas taps resolve through [resolveNodeTap] (the shell reads
/// the live modifier keys via `HardwareKeyboard` because the `DesignCanvas`/
/// `ScreenSurface` tap signatures are single-id and owned by another track).
/// The layers panel is multi-aware since Track S2: it receives the set plus
/// toggle/range callbacks and collapses only on plain taps (see the wiring in
/// [_EditorShellState._leftPanel] and [_EditorShellState._collapseToNode]).

/// Assembles rail + parts panel + canvas + toolbar + zoom + right aside.
class EditorShell extends StatefulWidget {
  final CanvasStore store;

  const EditorShell({super.key, required this.store});

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  late final _ShellRelay _relay = _ShellRelay(widget.store);
  bool _preview = false;
  bool _panMode = false;
  double _zoom = 0.79;
  String _railId = kRailParts;

  /// Shell-owned multi-selection, mutually exclusive with [_selectedScreenId]:
  /// selecting any node clears the screen selection and vice versa. Canvas
  /// AND layers taps resolve through [resolveNodeTap] (plain = collapse,
  /// Ctrl/Cmd = toggle, Shift = same-group range); the layers panel receives
  /// the set plus toggle/range callbacks (see [_leftPanel]).
  final Set<String> _selectedNodeIds = {};

  /// Range anchor for Shift+click: the last plain-selected or Ctrl-added
  /// node. Primary surfaces (inspector, canvas ring, shortcuts) bind the
  /// anchor when selected, else the first selected id in doc order. The layers
  /// panel binds the full set (primary ring + secondary tint).
  String? _selectionAnchorId;

  /// Shell-owned screen selection, mutually exclusive with [_selectedNodeIds]:
  /// selecting a node clears the screen selection and vice versa.
  String? _selectedScreenId;

  @override
  void initState() {
    super.initState();
    // Restore the last autosaved doc (migrated to flow on load). The relay
    // rebuilds the shell when the async read lands; until then the empty doc
    // shows — no loading spinner for a local read.
    widget.store.load();
  }

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  void _setZoom(double next) =>
      setState(() => _zoom = next.clamp(0.25, 4.0));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _relay,
      builder: (context, _) {
        final doc = widget.store.doc;
        // Track G split: the editor chrome (rail/panels/toolbar/zoom) renders
        // under the chrome override while the canvas area keeps the main
        // (components) theme. `effectiveChrome` is chrome-or-main, so a null
        // chrome preserves the old single-theme behavior.
        final chrome = doc.theme.effectiveChrome;
        final colors =
            chrome.dark ? EditorColors.dark : EditorColors.light;
        // EditorTheme sits above both branches so the preview chrome can
        // use the same tokens as the editor (it previously had no styled
        // ancestor at all, which is why its title rendered unstyled).
        return EditorTheme(
          colors: colors,
          child: _preview
              ? PreviewPlayer(
                  doc: doc,
                  themeOverride: doc.theme,
                  onExit: () => setState(() => _preview = false),
                )
              : ThemedCanvas(
                  theme: chrome,
                  child: Scaffold(
                    backgroundColor: colors.surface,
                    body: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: EditorMetrics.sidePanelWidth,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              EditorIconRail(
                                activeId: _railId,
                                onSelect: (id) =>
                                    setState(() => _railId = id),
                              ),
                              Expanded(child: _leftPanel()),
                            ],
                          ),
                        ),
                        Expanded(child: _canvasArea()),
                        SizedBox(
                          width: EditorMetrics.promptPanelWidth,
                          child: RightAside(
                            store: widget.store,
                            nodeId: _primaryNodeId(),
                            itemId: _selectedItemId(),
                            onSelectNode: (id) => setState(() {
                              _selectedScreenId = null;
                              _selectedNodeIds.clear();
                              if (id != null) _selectedNodeIds.add(id);
                              _selectionAnchorId = id;
                            }),
                            onSelectScreen: (id) => setState(() {
                              _selectedScreenId = id;
                              _selectedNodeIds.clear();
                              _selectionAnchorId = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  /// Primary id for the single-ring surfaces (inspector, canvas ring,
  /// shortcuts): the anchor while selected, else the first selected id in doc
  /// order, else null. Stale ids (e.g. after an undo) resolve to null rather
  /// than a dangling selection. The layers panel takes the full set
  /// separately and highlights the primary with a ring plus the rest with a
  /// secondary tint.
  String? _primaryNodeId() {
    if (_selectionAnchorId != null &&
        _selectedNodeIds.contains(_selectionAnchorId)) {
      return _selectionAnchorId;
    }
    for (final node in widget.store.doc.nodes) {
      if (_selectedNodeIds.contains(node.id)) return node.id;
    }
    return null;
  }

  /// First item of the primary node, so the inspector has something to
  /// edit: selection is tracked per node, while the inspector binds per item.
  /// Multi-select edits the primary node's first item; the rest of the set
  /// is untouched by the inspector.
  String? _selectedItemId() {
    final nodeId = _primaryNodeId();
    if (nodeId == null) return null;
    for (final node in widget.store.doc.nodes) {
      if (node.id == nodeId && node.items.isNotEmpty) {
        return node.items.first.id;
      }
    }
    return null;
  }

  /// The left aside's body, switched by the icon rail's selection.
  Widget _leftPanel() {
    switch (_railId) {
      case kRailParts:
        return const PartsPalette();
      case kRailLayers:
        // Track S2: multi-aware layers — the panel receives the full set
        // (primary ring + secondary tint + count header with delete/group
        // actions) and three tap intents: plain collapses, Ctrl/Cmd toggles,
        // Shift ranges. The panel reads the live modifiers itself, like the
        // canvas tap path. The canvas ring stays primary-only (documented
        // limitation, owned by another track).
        return LayersPanel(
          store: widget.store,
          selectedNodeIds: _selectedNodeIds,
          selectedNodeId: _primaryNodeId(),
          onSelectNode: _collapseToNode,
          onToggleNode: _toggleLayerNode,
          onRangeSelectNode: _rangeLayerNode,
          onGroupSelection: _groupSelection,
          onUngroupSelection: _ungroupSelection,
          onDeleteSelection: _deleteSelection,
        );
      // Theme panels hug their content: the loose scroll constraints stop
      // the panel Card from stretching to the full column height.
      case kRailColor:
        return SingleChildScrollView(
          child: ColorPanel(
            theme: widget.store.doc.theme,
            onChanged: widget.store.setTheme,
          ),
        );
      case kRailShape:
        return SingleChildScrollView(
          child: ShapePanel(
            theme: widget.store.doc.theme,
            onChanged: widget.store.setTheme,
          ),
        );
      case kRailType:
        return SingleChildScrollView(
          child: TypePanel(
            theme: widget.store.doc.theme,
            onChanged: widget.store.setTheme,
          ),
        );
      case kRailMotion:
        return SingleChildScrollView(
          child: MotionPanel(
            theme: widget.store.doc.theme,
            onChanged: widget.store.setTheme,
          ),
        );
      default:
        return _placeholder(_railId);
    }
  }

  Widget _placeholder(String id) {
    final colors = EditorTheme.of(context);
    return Center(
      child: Text(
        '$id panel',
        style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }

  Widget _canvasArea() {
    // Inner components theme: screens/components render under `doc.theme`
    // while rail/panels/toolbar/zoom stay under the outer chrome theme.
    final doc = widget.store.doc;
    return EditorShortcuts(
      store: widget.store,
      selectedNodeId: _primaryNodeId(),
      // Keyboard Delete operates on the WHOLE set (handled here in the shell
      // rather than in keyboard_shortcuts.dart): the forwarded id is only the
      // primary's liveness gate, the shell deletes every selected node.
      onDeleteNode: (_) => _deleteSelection(),
      onDuplicateNode: (id) {
        final nodes = widget.store.doc.nodes;
        if (nodes.any((n) => n.id == id)) {
          final copy = widget.store.duplicateNode(id);
          setState(() {
            _selectedNodeIds
              ..clear()
              ..add(copy);
            _selectionAnchorId = copy;
          });
        } else {
          setState(() {
            _selectedNodeIds.clear();
            _selectionAnchorId = null;
          });
        }
      },
      onPreview: () => setState(() => _preview = true),
      child: Stack(
        children: [
        Positioned.fill(
          child: ThemedCanvas(
            theme: doc.theme,
            child: DesignCanvas(
            store: widget.store,
            zoom: _zoom,
            panMode: _panMode,
            // The canvas ring highlights the primary only: DesignCanvas /
            // ScreenSurface carry a single `selectedNodeId` owned by another
            // track. Multi-select is still fully modeled in the shell (group,
            // ungroup, delete-set, toolbar state) — only the ring stays
            // single until the canvas owner lands a multi-aware signature.
            selectedNodeId: _primaryNodeId(),
            onSelectNode: _onCanvasNodeTap,
            selectedScreenId: _selectedScreenId,
            onSelectScreen: (id) {
              setState(() {
                _selectedScreenId = id;
                _selectedNodeIds.clear();
                _selectionAnchorId = null;
              });
            },
            onZoomChanged: _setZoom,
          ),
          ),
        ),
        Positioned(
          top: EditorMetrics.toolbarTop,
          left: 0,
          right: 0,
          child: Center(
            child: CanvasToolbar(
              panMode: _panMode,
              onPanModeChanged: (v) => setState(() => _panMode = v),
              onAddScreen: _addScreen,
              onPreview: () => setState(() => _preview = true),
              onUndo: widget.store.canUndo ? () => widget.store.undo() : null,
              onRedo: widget.store.canRedo ? () => widget.store.redo() : null,
              hasSelection: _selectedNodeIds.isNotEmpty ||
                  _selectedScreenId != null,
              onDelete: _deleteSelection,
              onOpen: () => showOpenDialog(context, widget.store),
              onExport: () => showExportDialog(context, widget.store),
              canGroup: canGroupNodes(doc, _selectedNodeIds),
              onGroup:
                  canGroupNodes(doc, _selectedNodeIds) ? _groupSelection : null,
              canUngroup:
                  ungroupTargetRow(doc, _selectedNodeIds) != null,
              onUngroup: ungroupTargetRow(doc, _selectedNodeIds) != null
                  ? _ungroupSelection
                  : null,
            ),
          ),
        ),
        Positioned(
          right: EditorMetrics.zoomBottomInset,
          bottom: EditorMetrics.zoomBottomInset,
          child: ZoomControls(
            zoom: _zoom,
            onZoomIn: () => _setZoom(_zoom + 0.1),
            onZoomOut: () => _setZoom(_zoom - 0.1),
            onFit: () => _setZoom(0.79),
          ),
        ),
        ],
      ),
    );
  }

  void _addScreen() => widget.store.addScreen();

  /// Layers-panel plain tap: collapses the set to the single tapped node
  /// (null clears). Ctrl/Cmd and Shift taps arrive on [_toggleLayerNode] and
  /// [_rangeLayerNode] instead (the panel reads the live modifiers itself).
  void _collapseToNode(String? id) => setState(() {
        _selectedNodeIds.clear();
        if (id == null) {
          _selectionAnchorId = null;
        } else {
          _selectedNodeIds.add(id);
          _selectionAnchorId = id;
        }
        _selectedScreenId = null;
      });

  /// Layers-panel Ctrl/Cmd-tap: toggles the node in the set via
  /// [resolveNodeTap] (`additive`), clearing any screen selection.
  void _toggleLayerNode(String id) {
    final resolved = resolveNodeTap(
      current: _selectedNodeIds,
      anchor: _selectionAnchorId,
      doc: widget.store.doc,
      tappedId: id,
      additive: true,
    );
    setState(() {
      _selectedNodeIds
        ..clear()
        ..addAll(resolved.ids);
      _selectionAnchorId = resolved.anchor;
      _selectedScreenId = null;
    });
  }

  /// Layers-panel Shift-tap: unions the anchor→tap range into the set via
  /// [resolveNodeTap] (`ranged`), clearing any screen selection.
  void _rangeLayerNode(String id) {
    final resolved = resolveNodeTap(
      current: _selectedNodeIds,
      anchor: _selectionAnchorId,
      doc: widget.store.doc,
      tappedId: id,
      ranged: true,
    );
    setState(() {
      _selectedNodeIds
        ..clear()
        ..addAll(resolved.ids);
      _selectionAnchorId = resolved.anchor;
      _selectedScreenId = null;
    });
  }

  /// Canvas node tap: resolves Ctrl/Cmd-toggle and Shift-range through
  /// [resolveNodeTap]. Modifier keys are read live from `HardwareKeyboard`
  /// because the canvas tap signature carries only the node id.
  void _onCanvasNodeTap(String? id) {
    final keys = HardwareKeyboard.instance;
    final resolved = resolveNodeTap(
      current: _selectedNodeIds,
      anchor: _selectionAnchorId,
      doc: widget.store.doc,
      tappedId: id,
      additive: keys.isControlPressed || keys.isMetaPressed,
      ranged: keys.isShiftPressed,
    );
    setState(() {
      _selectedNodeIds
        ..clear()
        ..addAll(resolved.ids);
      _selectionAnchorId = resolved.anchor;
      _selectedScreenId = null;
    });
  }

  /// Toolbar Group: wraps the selection in a new row via
  /// [CanvasStore.groupIntoRow] (one atomic undo unit) and selects the row.
  /// A [StateError] from the store surfaces as a SnackBar without touching
  /// the selection.
  void _groupSelection() {
    try {
      final rowId = widget.store.groupIntoRow(_selectedNodeIds.toList());
      setState(() {
        _selectedNodeIds
          ..clear()
          ..add(rowId);
        _selectionAnchorId = rowId;
        _selectedScreenId = null;
      });
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot group: ${e.message}')),
      );
    }
  }

  /// Toolbar Ungroup: lifts the selected row's children to the root via a
  /// single [CanvasStore.replaceDoc] of [ungroupRowDoc] (one atomic undo
  /// unit) and selects the released children.
  void _ungroupSelection() {
    final doc = widget.store.doc;
    final rowId = ungroupTargetRow(doc, _selectedNodeIds);
    if (rowId == null) return;
    final kids = [
      for (final n in doc.nodes)
        if (n.parentId == rowId) n.id,
    ];
    widget.store.replaceDoc(ungroupRowDoc(doc, rowId));
    setState(() {
      _selectedNodeIds
        ..clear()
        ..addAll(kids);
      _selectionAnchorId = kids.isEmpty ? null : kids.last;
    });
  }

  /// Toolbar trash / keyboard Delete: deletes the whole node set (one
  /// [CanvasStore.deleteNode] commit per id — undo restores them one step at
  /// a time; cascade covers parent+child pairs and unknown ids no-op, so any
  /// order is safe), then clears. A selected screen deletes via
  /// [CanvasStore.deleteScreen], which refuses when an action would dangle —
  /// the screen stays and a SnackBar names the blockers. With nothing
  /// selected this is a no-op (the toolbar tooltip says so).
  void _deleteSelection() {
    if (_selectedNodeIds.isNotEmpty) {
      for (final id in _selectedNodeIds.toList()) {
        widget.store.deleteNode(id);
      }
      setState(() {
        _selectedNodeIds.clear();
        _selectionAnchorId = null;
      });
      return;
    }
    final screenId = _selectedScreenId;
    if (screenId != null) {
      final dangling = widget.store.deleteScreen(screenId);
      if (dangling.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot delete screen: ${dangling.join('; ')}',
            ),
          ),
        );
        return;
      }
      setState(() => _selectedScreenId = null);
    }
  }
}
