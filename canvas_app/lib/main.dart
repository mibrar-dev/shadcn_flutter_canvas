/// Forge editor shell (Y6 cutover, FORGE.md §5) with the restored classic
/// left aside (Track CC sidebar revert).
///
/// Three columns at a 1440x900 viewport: a 320px left aside (52px icon rail +
/// parts panel, switched by the rail selection incl. Layers and the
/// Color/Shape/Type/Motion theme panels), the flexible canvas
/// (ForgeCanvasHeader + DesignCanvas + ForgeSelectionToolbar), and a 320px
/// right aside. The columns share one background with no dividers — see
/// [EditorMetrics] for the measured values. Chrome follows the doc theme as
/// before (no forced light — FORGE.md §5 DECISIONS); dark values are kept.
library;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:canvas_app/canvas/canvas_store.dart' hide ChangeNotifier;
import 'package:canvas_app/canvas/persistence.dart';
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/export_panel.dart';
import 'package:canvas_app/ui/forge_canvas_header.dart';
import 'package:canvas_app/ui/forge_topbar.dart';
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

/// Forge selection-toolbar hover height above the canvas bottom (FORGE.md §3:
/// shell-centered near the canvas bottom; anchoring to the selection is
/// follow-up per §6).
const double _kForgeToolbarBottomInset = 24;

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

/// Track EE device-lab gate (pure, unit-testable).
///
/// Simulation is active only when explicitly requested AND the build can
/// simulate (anything but release). Truth table:
/// - release + requested → false (release never simulates)
/// - release + not requested → false
/// - debug/profile + requested → true
/// - debug/profile + not requested → false (the default)
bool shouldEnableDevicePreview({
  required bool releaseMode,
  required bool requested,
}) =>
    !releaseMode && requested;

/// Opt-in switch for the Track EE device lab. Absent by default (false);
/// enable a run with `--dart-define=DEVICE_PREVIEW=true`.
const bool _devicePreviewRequested =
    bool.fromEnvironment('DEVICE_PREVIEW', defaultValue: false);

Future<void> main() async {
  // Track EE — device lab (device_preview 3.0, CURRENT 3.x API).
  //
  // One-line integration: installs a custom WidgetsBinding that simulates
  // device characteristics (metrics, safe areas, locale, brightness, text
  // scale, accessibility flags, target platform) BELOW the widget layer, so
  // no MaterialApp wrapper / builder / locale glue is needed (the 2.x
  // `DevicePreview(builder:)`, `useInheritedMediaQuery`, `locale` and
  // `appBuilder` API is gone in 3.x — do not re-add it).
  //
  // ENABLED FLAG (deliberately opt-in, default OFF):
  // `shouldEnableDevicePreview` ANDs `!kReleaseMode` with the
  // `--dart-define=DEVICE_PREVIEW=true` switch, so release builds NEVER
  // simulate (zero footprint — the binding is behaviorally identical to
  // WidgetsFlutterBinding when disabled) and debug/profile runs simulate
  // only on request. Rationale: test-suite hermeticity (983 widget tests
  // pump bare MaterialApps/EditorShell under the stock test binding and
  // must never see a simulated viewport) plus product fit (the Forge
  // editor already has per-screen device modes + preview presets in-canvas;
  // wrapping the whole editor chrome in a simulated device by default would
  // be confusing). Opt-in run:
  //   flutter run -d chrome --dart-define=DEVICE_PREVIEW=true
  //
  // DRIVING IT (no custom device UI is built — intentionally): the control
  // surface is the "Device Preview" tab in Flutter DevTools (device picker
  // with framed previews, locale/a11y/orientation/text-scale/dark-mode
  // controls, screenshot button, "New device from JSON…"). From Dart, drive
  // the same simulation via `DevicePreview.maybeController` (null when
  // simulation is off — never `DevicePreview.controller` from shipped code,
  // it throws when disabled):
  //   DevicePreview.maybeController?.applyPreset(DevicePresets.iPhone16);
  // Presets live in the separate, tree-shakable
  // `package:device_preview/presets.dart` (name only the presets used —
  // `DevicePresets.all`/`byId` pull in the whole ~300KB catalog).
  //
  // Widget-test note: tests pump widgets directly (main() never runs under
  // flutter_test), so this line has no test side effects. A test that wants
  // a simulated device must use its own binding
  // (`TestDevicePreviewBinding` + `DevicePreviewBindingMixin`, see the
  // package README "Testing under a simulated device") — see
  // test/device_preview_gate_test.dart for the gate coverage.
  DevicePreview.enable(
    enabled: shouldEnableDevicePreview(
      releaseMode: kReleaseMode,
      requested: _devicePreviewRequested,
    ),
  );
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

/// Assembles the Forge shell: topbar + classic left aside (icon rail + parts
/// panel) + canvas header/canvas/selection toolbar + right aside.
class EditorShell extends StatefulWidget {
  final CanvasStore store;

  const EditorShell({super.key, required this.store});

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  late final _ShellRelay _relay = _ShellRelay(widget.store);
  bool _preview = false;
  double _zoom = 0.79;
  bool _showGuides = true;

  /// Classic left-aside selection (Track CC sidebar revert): the icon rail
  /// switches the parts palette, the layers panel, and the Color/Shape/
  /// Type/Motion theme panels. The Forge Library|Layers pills + Theme
  /// disclosure are removed.
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
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Track Y2 (FORGE.md §1-1a–1g): Forge topbar mounted
                        // above the shell columns. Pure mount wiring: tabs
                        // read `store.doc.screens`, "current" is the existing
                        // shell screen selection, Preview/Export/Open
                        // delegate to the existing callbacks. No shell-model
                        // changes (full cutover stays Y6-owned).
                        ForgeTopbar(
                          projectTitle: doc.meta.title,
                          screens: [
                            for (final s in doc.screens)
                              ForgeScreenTab(id: s.id, name: s.name),
                          ],
                          selectedScreenId: _selectedScreenId,
                          onSelectScreen: (id) => setState(() {
                            _selectedScreenId = id;
                            _selectedNodeIds.clear();
                            _selectionAnchorId = null;
                          }),
                          onAddScreen: _addScreen,
                          onRenameScreen: (id, name) =>
                              widget.store.renameScreen(id, name),
                          onDeleteScreen: _deleteTopbarScreen,
                          onUndo: widget.store.canUndo
                              ? () => widget.store.undo()
                              : null,
                          onRedo: widget.store.canRedo
                              ? () => widget.store.redo()
                              : null,
                          onPreview: () => setState(() => _preview = true),
                          onExport: () =>
                              showExportDialog(context, widget.store),
                          onOpen: () => showOpenDialog(context, widget.store),
                        ),
                        Expanded(
                          child: Row(
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
                            // FORGE.md §1-4e (Y5 pass-through, Y6 wiring):
                            // duplicate reselects the clone (same path as
                            // keyboard duplicate); delete removes the node
                            // and clears it from the selection.
                            onDuplicate: _duplicateAndReselect,
                            onDelete: _deleteNodeAndClear,
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

  /// Current screen for the header breadcrumb, the Library tap-to-add target,
  /// and the device strip: the shell screen selection when it names a live
  /// screen, else the first screen, else 's1' (empty-doc fallback for the
  /// palette; the header renders an empty trail when there are no screens).
  String _currentScreenId() {
    final doc = widget.store.doc;
    final id = _selectedScreenId;
    if (id != null && doc.screens.any((s) => s.id == id)) return id;
    if (doc.screens.isNotEmpty) return doc.screens.first.id;
    return 's1';
  }

  /// Prebuilt `<Kind> · <id>` label for the header node crumb (the same idiom
  /// as the inspector's `_nodeShortLabel`; the header takes the label as a
  /// string and never imports the inspector). Null when nothing is selected.
  String? _selectedNodeLabel() {
    final nodeId = _primaryNodeId();
    if (nodeId == null) return null;
    for (final node in widget.store.doc.nodes) {
      if (node.id != nodeId) continue;
      if (node.isRow) return 'Row · ${node.id}';
      if (node.items.isEmpty) return 'Empty · ${node.id}';
      final kind = node.items.first.kind;
      if (kind.isEmpty) return 'Empty · ${node.id}';
      return '${kind[0].toUpperCase()}${kind.substring(1)} · ${node.id}';
    }
    return null;
  }

  /// Forge SELECTED-card + keyboard + toolbar duplicate: clones the node via
  /// `duplicateNode` (+16 offset, subtree clone — kept) and reselects the
  /// clone. Unknown ids clear the selection (same path as the keyboard
  /// handler) instead of throwing.
  void _duplicateAndReselect(String id) {
    final nodes = widget.store.doc.nodes;
    if (nodes.any((n) => n.id == id)) {
      final copy = widget.store.duplicateNode(id);
      setState(() {
        _selectedScreenId = null;
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
  }

  /// Forge SELECTED-card delete: removes the node via `deleteNode` (cascade —
  /// kept) and clears it from the selection. Cascaded descendants and other
  /// dangling ids are purged so the set never holds dead ids.
  void _deleteNodeAndClear(String id) {
    widget.store.deleteNode(id);
    final live = {for (final n in widget.store.doc.nodes) n.id};
    setState(() {
      _selectedNodeIds.retainAll(live);
      _selectedNodeIds.remove(id);
      if (_selectionAnchorId != null &&
          !_selectedNodeIds.contains(_selectionAnchorId)) {
        _selectionAnchorId = null;
      }
    });
  }

  /// Forge selection-toolbar up/down: moves the primary within its own group
  /// (same screen + same parent, doc order) via `reorderNode` ±1. Edges and
  /// unknown ids are safe no-ops (reorder clamps / throws only on unknown —
  /// guarded here).
  void _moveSelection(int delta) {
    final nodeId = _primaryNodeId();
    if (nodeId == null) return;
    final doc = widget.store.doc;
    final index = doc.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final node = doc.nodes[index];
    final group = [
      for (final n in doc.nodes)
        if (n.screenId == node.screenId && n.parentId == node.parentId) n,
    ];
    final from = group.indexWhere((n) => n.id == nodeId);
    if (from < 0) return;
    widget.store.reorderNode(nodeId, from + delta);
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
    final doc = widget.store.doc;
    // Inner components theme: screens/components render under `doc.theme`
    // while the chrome stays under the outer chrome theme.
    final currentId = _currentScreenId();
    final currentScreen = doc.screens.isEmpty
        ? null
        : doc.screens.firstWhere(
            (s) => s.id == currentId,
            orElse: () => doc.screens.first,
          );
    final primaryId = _primaryNodeId();
    return EditorShortcuts(
      store: widget.store,
      selectedNodeId: primaryId,
      // Keyboard Delete operates on the WHOLE set (handled here in the shell
      // rather than in keyboard_shortcuts.dart): the forwarded id is only the
      // primary's liveness gate, the shell deletes every selected node.
      onDeleteNode: (_) => _deleteSelection(),
      onDuplicateNode: _duplicateAndReselect,
      onPreview: () => setState(() => _preview = true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Forge canvas header (FORGE.md §1-3a–3b, 3g): breadcrumb trail +
          // compact device strip + zoom pill with the snap-guides toggle.
          // Screen clicks reuse onSelectScreen; node clicks reuse
          // onSelectNode; device taps forward to setScreenDevice.
          ForgeCanvasHeader(
            projectTitle: doc.meta.title,
            screenId: currentScreen?.id ?? '',
            screenName: currentScreen?.name ?? '',
            onSelectScreen: (id) => setState(() {
              _selectedScreenId = id;
              _selectedNodeIds.clear();
              _selectionAnchorId = null;
            }),
            selectedNodeId: primaryId,
            selectedNodeLabel: _selectedNodeLabel(),
            onSelectNode: (id) => setState(() {
              _selectedScreenId = null;
              _selectedNodeIds.clear();
              if (id != null) _selectedNodeIds.add(id);
              _selectionAnchorId = id;
            }),
            zoom: _zoom,
            onZoomIn: () => _setZoom(_zoom + 0.1),
            onZoomOut: () => _setZoom(_zoom - 0.1),
            onFit: () => _setZoom(0.79),
            showGuides: _showGuides,
            onShowGuidesChanged: (v) => setState(() => _showGuides = v),
            screenDevice: currentScreen?.device,
            onDeviceChanged: currentScreen == null
                ? null
                : (device) =>
                    widget.store.setScreenDevice(currentScreen.id, device),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ThemedCanvas(
                    theme: doc.theme,
                    child: DesignCanvas(
                      store: widget.store,
                      zoom: _zoom,
                      // The canvas ring highlights the primary only:
                      // DesignCanvas / ScreenSurface carry a single
                      // `selectedNodeId` owned by another track. Multi-select
                      // is still fully modeled in the shell (group, ungroup,
                      // delete-set) — only the ring stays single until the
                      // canvas owner lands a multi-aware signature.
                      selectedNodeId: primaryId,
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
                      showGuides: _showGuides,
                    ),
                  ),
                ),
                // Forge black selection toolbar (FORGE.md §1-3f, §3):
                // shell-centered near the canvas bottom, above the bottom
                // inset. Up/down reorder within the node's group; duplicate
                // clones and reselects. Hidden without a selection (the
                // widget returns shrink when selectedNodeId is null).
                Positioned(
                  bottom: _kForgeToolbarBottomInset,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForgeSelectionToolbar(
                      selectedNodeId: primaryId,
                      onMoveUp:
                          primaryId == null ? null : () => _moveSelection(-1),
                      onMoveDown:
                          primaryId == null ? null : () => _moveSelection(1),
                      onDuplicate: primaryId == null
                          ? null
                          : () => _duplicateAndReselect(primaryId),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addScreen() => widget.store.addScreen();

  /// Topbar screen-tab "×": deletes the tab's screen via
  /// [CanvasStore.deleteScreen], keeping the dangling-action refusal +
  /// SnackBar path from [_deleteSelection]'s screen branch. Clears the shell
  /// screen selection when it pointed at the removed screen; node selection
  /// is already empty on this path (a tab tap selects the screen first).
  void _deleteTopbarScreen(String id) {
    final dangling = widget.store.deleteScreen(id);
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
    if (_selectedScreenId == id) setState(() => _selectedScreenId = null);
  }

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

  /// Layers-header / keyboard Delete: deletes the whole node set (one
  /// [CanvasStore.deleteNode] commit per id — undo restores them one step at
  /// a time; cascade covers parent+child pairs and unknown ids no-op, so any
  /// order is safe), then clears. A selected screen deletes via
  /// [CanvasStore.deleteScreen], which refuses when an action would dangle —
  /// the screen stays and a SnackBar names the blockers. With nothing
  /// selected this is a no-op.
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
