/// Undoable canvas store with debounced autosave.
///
/// NOTE on `ChangeNotifier`: this file must not import any Flutter SDK
/// packages (global plan constraint — `lib/canvas/` compiles for CLI
/// defines a minimal local [ChangeNotifier] with the same listener API
/// (`addListener`/`removeListener`/`notifyListeners`) instead of Flutter's.
/// UI-layer code can subscribe directly; a `Listenable` adapter can be added
/// in `lib/ui/` later if widget bindings need one.
import 'dart:async';
import 'dart:convert';

import 'persistence.dart';
import 'package:canvas_core/canvas_core.dart';

/// Minimal listener registry mirroring Flutter's `ChangeNotifier` API.
class ChangeNotifier {
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void dispose() => _listeners.clear();
}

/// Undoable editor state over an immutable [ScreenDoc] snapshot stack.
class CanvasStore extends ChangeNotifier {
  static const String docKey = 'canvas:doc';
  static const int historyCap = 100;

  final PrefsPort? _prefs;
  final Duration _debounce;

  ScreenDoc _doc;
  final List<ScreenDoc> _undo = [];
  final List<ScreenDoc> _redo = [];
  int _uidCounter = 0;
  Timer? _saveTimer;
  bool _saveScheduled = false;

  CanvasStore({PrefsPort? prefs, ScreenDoc? initial, Duration? debounce})
      : _prefs = prefs,
        _doc = initial ?? CanvasStore.emptyDoc(),
        _debounce = debounce ?? const Duration(milliseconds: 300);

  static ScreenDoc emptyDoc() => ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Screen 1', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [],
        'theme': {
          // Must be a member of `kPaletteOptions` (theme_bar.dart) so the
          // palette [Select] shows the active value instead of its
          // placeholder. ('slate' matched no preset and silently fell back
          // to `registryThemePresets.first`, i.e. amber-minimal.)
          'paletteKey': 'clean-slate',
          // Dark by default, matching the m3e-canvas reference's default.
          'dark': true,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Untitled', 'brief': ''},
      });

  ScreenDoc get doc => _doc;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Restores the last autosaved doc, if any. Keeps current on bad data.
  /// Persisted docs predate flow layout, so every load runs the one-shot
  /// [migrateToFlow] (idempotent: already-flow docs keep their order).
  Future<void> load() async {
    final raw = await _prefs?.read(docKey);
    if (raw == null || raw.isEmpty) return;
    try {
      _doc = migrateToFlow(
        ScreenDoc.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
      notifyListeners();
    } on FormatException {
      // Keep current doc on corrupt payloads.
    }
  }

  /// Unique id not present anywhere in the current doc.
  String uid() {
    final taken = {
      for (final s in _doc.screens) s.id,
      for (final n in _doc.nodes) n.id,
      for (final n in _doc.nodes)
        for (final i in n.items) i.id,
    };
    late String id;
    do {
      id = 'u${++_uidCounter}';
    } while (taken.contains(id));
    return id;
  }

  String addNode({
    required String screenId,
    required double x,
    required double y,
    List<CanvasItem> items = const [],
    String? mainAxis,
    String? crossAxis,
    String? expand,
    int? flex,
  }) {
    final node = CanvasNode(
      id: uid(),
      screenId: screenId,
      x: x,
      y: y,
      items: List.of(items),
      mainAxis: mainAxis,
      crossAxis: crossAxis,
      expand: expand,
      flex: flex,
    );
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [..._doc.nodes, node],
      theme: _doc.theme,
      meta: _doc.meta,
    ));
    return node.id;
  }

  void moveNode(String nodeId, double x, double y) {
    _commit(_mapNodes(
      (n) => n.id == nodeId
          ? CanvasNode(
              id: n.id,
              screenId: n.screenId,
              x: x,
              y: y,
              items: n.items,
              parentId: n.parentId,
              isRow: n.isRow,
              gap: n.gap,
              mainAxis: n.mainAxis,
              crossAxis: n.crossAxis,
              expand: n.expand,
              flex: n.flex,
            )
          : n,
    ));
  }

  /// Merges [props] into the item and optionally replaces its action.
  /// Pass `action: () => null` to clear, omit to leave unchanged.
  void patchItem(
    String nodeId,
    String itemId, {
    Map<String, dynamic>? props,
    NodeAction? Function()? action,
  }) {
    _commit(_mapNodes((n) {
      if (n.id != nodeId) return n;
      return CanvasNode(
        id: n.id,
        screenId: n.screenId,
        x: n.x,
        y: n.y,
        parentId: n.parentId,
        isRow: n.isRow,
        gap: n.gap,
        mainAxis: n.mainAxis,
        crossAxis: n.crossAxis,
        expand: n.expand,
        flex: n.flex,
        items: [
          for (final i in n.items)
            if (i.id == itemId)
              i.copyWith(
                props: props == null ? null : {...i.props, ...props},
                action: action,
              )
            else
              i,
        ],
      );
    }));
  }

  void setItemAction(String nodeId, String itemId, NodeAction? action) =>
      patchItem(nodeId, itemId, action: () => action);

  /// Deletes a node. Deleting a row cascades to its descendants (they live
  /// inside it — leaving them orphaned would make them invisible). Unknown
  /// ids are a no-op (no history pollution), matching reorderNode/patchNode
  /// which throw before committing.
  void deleteNode(String nodeId) {
    if (_doc.nodes.every((n) => n.id != nodeId)) return;
    final doomed = <String>{nodeId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in _doc.nodes) {
        if (n.parentId != null &&
            doomed.contains(n.parentId) &&
            doomed.add(n.id)) {
          grew = true;
        }
      }
    }
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [for (final n in _doc.nodes) if (!doomed.contains(n.id)) n],
      theme: _doc.theme,
      meta: _doc.meta,
    ));
  }

  /// Replaces the doc theme (undoable, autosaved).
  void setTheme(CanvasTheme theme) {
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: List.of(_doc.nodes),
      theme: theme,
      meta: _doc.meta,
    ));
  }

  /// Deep-copies the node with fresh ids for the node and every item.
  /// Returns the new node id.
  String duplicateNode(String nodeId) {
    final source = _doc.nodes.singleWhere((n) => n.id == nodeId);
    final taken = {
      for (final n in _doc.nodes) n.id,
      for (final n in _doc.nodes)
        for (final i in n.items) i.id,
    };
    String fresh(String _old) {
      late String id;
      do {
        id = 'u${++_uidCounter}';
      } while (taken.contains(id));
      taken.add(id);
      return id;
    }

    // Duplicating a row duplicates its whole subtree, any depth
    // (Figma-frame semantics); clones are re-parented to the fresh ids.
    final subtree = <CanvasNode>[source];
    final known = <String>{source.id};
    var cursor = 0;
    while (cursor < subtree.length) {
      final parent = subtree[cursor++];
      for (final n in _doc.nodes) {
        if (n.parentId == parent.id && known.add(n.id)) subtree.add(n);
      }
    }
    final idMap = {for (final n in subtree) n.id: fresh(n.id)};
    final clones = [
      for (final n in subtree)
        CanvasNode(
          id: idMap[n.id]!,
          screenId: n.screenId,
          x: n.x + 16,
          y: n.y + 16,
          parentId: n.id == source.id ? n.parentId : idMap[n.parentId],
          isRow: n.isRow,
          gap: n.gap,
          mainAxis: n.mainAxis,
          crossAxis: n.crossAxis,
          expand: n.expand,
          flex: n.flex,
          items: [
            for (final i in n.items)
              CanvasItem(
                id: fresh(i.id),
                kind: i.kind,
                props: Map<String, dynamic>.from(i.props),
                action: i.action == null
                    ? null
                    : NodeAction(
                        to: i.action!.to, transition: i.action!.transition),
              ),
          ],
        ),
    ];
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [..._doc.nodes, ...clones],
      theme: _doc.theme,
      meta: _doc.meta,
    ));
    return clones.first.id;
  }

  /// Deletes a screen (plus its nodes). Refuses — returning the dangling
  /// list — when an action would be left pointing at the removed screen.
  /// Returns `[]` on success.
  List<String> deleteScreen(String screenId) {
    final candidate = ScreenDoc(
      screens: [
        for (final s in _doc.screens)
          if (s.id != screenId) s
      ],
      nodes: [
        for (final n in _doc.nodes)
          if (n.screenId != screenId) n
      ],
      theme: _doc.theme,
      meta: _doc.meta,
    );
    final dangling = candidate.validateRefs();
    if (dangling.isNotEmpty) return dangling;
    _commit(candidate);
    return [];
  }

  /// Appends a screen named [name] (default 'Screen N') with bg 'surface'.
  /// Returns the id. Undoable and autosaved like every other mutation.
  String addScreen({String? name}) {
    final screen = CanvasScreen(
      id: uid(),
      name: name ?? 'Screen ${_doc.screens.length + 1}',
      x: 0.0,
      y: 0.0,
      bg: 'surface',
    );
    _commit(ScreenDoc(
      screens: [..._doc.screens, screen],
      nodes: List.of(_doc.nodes),
      theme: _doc.theme,
      meta: _doc.meta,
    ));
    return screen.id;
  }

  /// Renames a screen. Throws [StateError] when [id] is unknown.
  /// Undoable and autosaved like every other mutation.
  void renameScreen(String id, String name) {
    final index = _doc.screens.indexWhere((s) => s.id == id);
    if (index < 0) throw StateError('Unknown screen: $id');
    final screens = List.of(_doc.screens);
    final current = screens[index];
    screens[index] = CanvasScreen(
      id: current.id,
      name: name,
      x: current.x,
      y: current.y,
      bg: current.bg,
    );
    _commit(ScreenDoc(
      screens: screens,
      nodes: List.of(_doc.nodes),
      theme: _doc.theme,
      meta: _doc.meta,
    ));
  }

  /// Moves the node with [nodeId] within its own parent group to
  /// [newIndex] (position among the group's nodes in doc order; later =
  /// more frontmost in the layers panel and later in the flow).
  ///
  /// The group is the node's flow siblings: the screen-root nodes
  /// (`parentId == null`) when the node is root-level, or the row's children
  /// (equal `parentId`) when it lives inside a row. Only same-screen nodes
  /// are ever siblings, so [newIndex] is clamped into the group and
  /// cross-parent / cross-screen moves are refused structurally (neither
  /// `screenId` nor `parentId` ever changes). Throws [StateError] when
  /// [nodeId] is unknown (before committing, so history stays clean).
  /// Undoable and autosaved like every other mutation.
  void reorderNode(String nodeId, int newIndex) {
    final current = _doc.nodes.indexWhere((n) => n.id == nodeId);
    if (current < 0) throw StateError('Unknown node: $nodeId');
    final node = _doc.nodes[current];
    final group = [
      for (final n in _doc.nodes)
        if (n.screenId == node.screenId && n.parentId == node.parentId) n,
    ];
    final from = group.indexWhere((n) => n.id == nodeId);
    final to = newIndex.clamp(0, group.length - 1);
    if (from == to) return;
    group.removeAt(from);
    group.insert(to, node);
    final spots = <int>[
      for (var i = 0; i < _doc.nodes.length; i++)
        if (_doc.nodes[i].screenId == node.screenId &&
            _doc.nodes[i].parentId == node.parentId)
          i,
    ];
    final next = List.of(_doc.nodes);
    for (var k = 0; k < spots.length; k++) {
      next[spots[k]] = group[k];
    }
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: next,
      theme: _doc.theme,
      meta: _doc.meta,
    ));
  }

  /// Appends a root-level row container to [screenId].
  ///
  /// The container node carries no items (`items` is empty), `isRow` is true,
  /// `gap` is [kFlowRowGapDefault], and `parentId` is null (root-level row).
  /// `x`/`y` are stored as 0 metadata; the flow renderer ignores them and
  /// uses doc order instead. Alignment (`mainAxis`/`crossAxis`) and flex
  /// (`expand`/`flex`) default to null (Flutter defaults). Returns the id.
  /// Undoable and autosaved like every other mutation.
  String addRow({
    required String screenId,
    String? mainAxis,
    String? crossAxis,
    String? expand,
    int? flex,
    double? gap,
  }) {
    final node = CanvasNode(
      id: uid(),
      screenId: screenId,
      x: 0.0,
      y: 0.0,
      items: const [],
      parentId: null,
      isRow: true,
      gap: gap ?? kFlowRowGapDefault,
      mainAxis: mainAxis,
      crossAxis: crossAxis,
      expand: expand,
      flex: flex,
    );
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [..._doc.nodes, node],
      theme: _doc.theme,
      meta: _doc.meta,
    ));
    return node.id;
  }

  /// Updates a node's container/flex fields. [gap] is the row spacing;
  /// [mainAxis] (`start|center|end|spaceBetween|spaceAround|spaceEvenly`,
  /// null = Flutter default start) and [crossAxis]
  /// (`start|center|end|stretch`, null = default center for rows) live on the
  /// row container; [expand] (`none|flex|expanded`, null/none = default) and
  /// [flex] (default 1 when expand is flex/expanded and flex is null) live on
  /// the child node. Throws [StateError] when [nodeId] is unknown (before
  /// committing, so history stays clean). All-null is a no-op.
  /// Undoable and autosaved like every other mutation.
  void patchNode(
    String nodeId, {
    double? gap,
    String? mainAxis,
    String? crossAxis,
    String? expand,
    int? flex,
  }) {
    final index = _doc.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) throw StateError('Unknown node: $nodeId');
    if (gap == null &&
        mainAxis == null &&
        crossAxis == null &&
        expand == null &&
        flex == null) {
      return;
    }
    _commit(_mapNodes((n) => n.id == nodeId
        ? CanvasNode(
            id: n.id,
            screenId: n.screenId,
            x: n.x,
            y: n.y,
            items: n.items,
            parentId: n.parentId,
            isRow: n.isRow,
            gap: gap ?? n.gap,
            mainAxis: mainAxis ?? n.mainAxis,
            crossAxis: crossAxis ?? n.crossAxis,
            expand: expand ?? n.expand,
            flex: flex ?? n.flex,
          )
        : n));
  }

  /// Replaces the whole doc (undoable import path for the Open dialog).
  /// Commits verbatim.
  void replaceDoc(ScreenDoc doc) {
    _commit(doc);
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _redo.add(_snapshot(_doc));
    _doc = _undo.removeLast();
    _scheduleSave();
    notifyListeners();
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    _undo.add(_snapshot(_doc));
    _doc = _redo.removeLast();
    _scheduleSave();
    notifyListeners();
    return true;
  }

  /// Writes the current doc to prefs immediately (cancels any debounce).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _saveScheduled = false;
    await _saveNow();
  }

  void _commit(ScreenDoc next) {
    _undo.add(_snapshot(_doc));
    if (_undo.length > historyCap) {
      _undo.removeRange(0, _undo.length - historyCap);
    }
    _redo.clear();
    _doc = next;
    _scheduleSave();
    notifyListeners();
  }

  ScreenDoc _mapNodes(CanvasNode Function(CanvasNode) map) => ScreenDoc(
        screens: List.of(_doc.screens),
        nodes: [for (final n in _doc.nodes) map(n)],
        theme: _doc.theme,
        meta: _doc.meta,
      );

  /// Deep copy via JSON so history snapshots stay immutable.
  ScreenDoc _snapshot(ScreenDoc doc) =>
      ScreenDoc.fromJson(jsonDecode(jsonEncode(doc.toJson())));

  void _scheduleSave() {
    if (_prefs == null) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_debounce == Duration.zero) {
      if (_saveScheduled) return;
      _saveScheduled = true;
      scheduleMicrotask(() async {
        _saveScheduled = false;
        await _saveNow();
      });
      return;
    }
    _saveTimer = Timer(_debounce, _saveNow);
  }

  Future<void> _saveNow() =>
      _prefs?.write(docKey, jsonEncode(_doc.toJson())) ?? Future.value();

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
