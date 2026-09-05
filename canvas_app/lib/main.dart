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
import 'package:canvas_app/ui/canvas_toolbar.dart';
import 'package:canvas_app/ui/design_canvas.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/icon_rail.dart';
import 'package:canvas_app/ui/keyboard_shortcuts.dart';
import 'package:canvas_app/ui/layers_panel.dart';
import 'package:canvas_app/ui/open_dialog.dart';
import 'package:canvas_app/ui/parts_palette.dart';
import 'package:canvas_app/ui/preview_player.dart';
import 'package:canvas_app/ui/right_aside.dart';
import 'package:canvas_app/ui/theme_bar.dart';
import 'package:canvas_app/ui/theme_panels.dart';
import 'package:canvas_app/ui/zoom_controls.dart';

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
      home: EditorShell(store: CanvasStore()),
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
  String? _selectedNodeId;

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
        final colors =
            doc.theme.dark ? EditorColors.dark : EditorColors.light;
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
                  theme: doc.theme,
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
                            nodeId: _selectedNodeId,
                            itemId: _selectedItemId(),
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

  /// First item of the selected node, so the inspector has something to
  /// edit: selection is tracked per node, while the inspector binds per item.
  String? _selectedItemId() {
    final nodeId = _selectedNodeId;
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
        return LayersPanel(
          store: widget.store,
          selectedNodeId: _selectedNodeId,
          onSelectNode: (id) => setState(() => _selectedNodeId = id),
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
    return EditorShortcuts(
      store: widget.store,
      selectedNodeId: _selectedNodeId,
      onDeleteNode: (id) {
        widget.store.deleteNode(id);
        setState(() => _selectedNodeId = null);
      },
      onDuplicateNode: (id) {
        final nodes = widget.store.doc.nodes;
        if (nodes.any((n) => n.id == id)) {
          setState(() => _selectedNodeId = widget.store.duplicateNode(id));
        } else {
          setState(() => _selectedNodeId = null);
        }
      },
      onPreview: () => setState(() => _preview = true),
      child: Stack(
        children: [
        Positioned.fill(
          child: DesignCanvas(
            store: widget.store,
            zoom: _zoom,
            panMode: _panMode,
            selectedNodeId: _selectedNodeId,
            onSelectNode: (id) => setState(() => _selectedNodeId = id),
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
              onClear: _clearScreen,
              onOpen: () => showOpenDialog(context, widget.store),
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

  void _clearScreen() {
    final doc = widget.store.doc;
    for (final node in List.of(doc.nodes)) {
      widget.store.deleteNode(node.id);
    }
    setState(() => _selectedNodeId = null);
  }
}
