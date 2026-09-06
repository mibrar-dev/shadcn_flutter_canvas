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

/// Known per-screen device ids (mirror the `PreviewDeviceSpec` ids in
/// `lib/ui/device_picker.dart`; duplicated as plain strings because
/// `lib/canvas/` must stay Flutter-free).
const Set<String> kScreenDeviceIds = {
  'phone',
  'tablet',
  'desktop-fluid',
  'desktop-wide',
};

/// Named widget-composition slots per node kind (Track DD validation copy).
///
/// PRIVATE SNAPSHOT of the authoritative `kNodeSlots` in
/// `lib/canvas/component_catalog.dart` (same entries, same order): this file
/// must stay Flutter-free, so it cannot import the catalog — and the catalog
/// is owned by a parallel batch, so this table cannot move there either.
/// SYNC RULE: when the catalog's table gains/loses a kind or slot, mirror
/// the edit here (a drift only affects [CanvasStore.setSlotChild]'s
/// unknown-slot refusal; the inspector reads the catalog's table directly,
/// and codegen splices whatever `slotNodes` entries resolve, so neither
/// needs this copy).
const _kNodeSlots = <String, List<String>>{
  'scaffold': ['appBar', 'body', 'footer'],
  'card': ['content'],
  'dialog': ['content'],
  'alert_dialog': ['content'],
  'drawer': ['content'],
  'form': ['content'],
  'outlined_container': ['content'],
  'hidden': ['content'],
  'clickable': ['content'],
  'scrollbar': ['content'],
  'chat': ['content'],
  'toast': ['content'],
  'validated': ['content'],
  'refresh_trigger': ['content'],
  'card_image': ['image'],
  'basic': ['leading', 'trailing'],
};

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
///
/// Track R1 (app state): the doc's [ScreenDoc.states] flow through every
/// mutation below (each new [ScreenDoc] copies them — dropping them would
/// wipe all vars on the next edit). Var CRUD ([addVar]/[renameVar]/
  /// [deleteVar]) is undoable like every doc mutation; session values
/// ([setStateValue]) are preview-runtime only: they [notifyListeners] but
/// never commit, never touch history, and never persist (see [_saveNow] —
/// only [_doc] serializes).
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

  /// Session-only state values (preview-runtime overrides over the var
  /// defaults). A copy — mutating it does nothing; write via
  /// [setStateValue].
  Map<String, dynamic> get sessionValues => Map<String, dynamic>.of(_session);
  final Map<String, dynamic> _session = {};

  /// Effective value of state var [name]: the session override when set,
  /// else the var default. Null when the var is unknown.
  Object? stateValue(String name) {
    if (_session.containsKey(name)) return _session[name];
    for (final v in _doc.states) {
      if (v.name == name) return v.defaultValue;
    }
    return null;
  }

  /// Sets a session-only state value (preview runtime). Unknown vars are a
  /// no-op without notifying; setting the current effective value is a
  /// no-op too. Never commits (no history), never persists — the doc (and
  /// its autosave) only carries var *declarations*.
  void setStateValue(String name, Object? value) {
    if (!_doc.states.any((v) => v.name == name)) return;
    if (_session.containsKey(name)) {
      if (_session[name] == value) return;
    } else {
      Object? def;
      for (final v in _doc.states) {
        if (v.name == name) def = v.defaultValue;
      }
      // No override yet and the default already equals [value]: storing a
      // redundant override would only pollute the session map.
      if (def == value) return;
    }
    _session[name] = value;
    notifyListeners();
  }

  /// Clears all session overrides (back to var defaults). Notifies.
  void resetSessionValues() {
    if (_session.isEmpty) return;
    _session.clear();
    notifyListeners();
  }

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
      states: List.of(_doc.states),
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
              w: n.w,
              h: n.h,
              hiddenOn: Set<String>.from(n.hiddenOn),
              breakpointValues: {
                for (final entry in n.breakpointValues.entries)
                  entry.key: Map<String, dynamic>.from(entry.value),
              },
              slots: Map<String, String>.from(n.slots),
              // Track DD carry: slot composition + lock ride every rebuild.
              slotNodes: Map<String, String>.from(n.slotNodes),
              locked: n.locked,
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
        w: n.w,
        h: n.h,
        hiddenOn: Set<String>.from(n.hiddenOn),
        breakpointValues: {
          for (final entry in n.breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        slots: Map<String, String>.from(n.slots),
        // Track DD carry: slot composition + lock ride every rebuild.
        slotNodes: Map<String, String>.from(n.slotNodes),
        locked: n.locked,
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

  /// Adds a state var. Throws [ArgumentError] when the var is invalid (bad
  /// identifier, unknown type, mistyped default) or a duplicate — before
  /// committing, so history stays clean. Undoable and autosaved like every
  /// doc mutation.
  void addVar(AppStateVar v) {
    final problems = validateAppStateVars([..._doc.states, v]);
    if (problems.isNotEmpty) {
      throw ArgumentError('Invalid state var: ${problems.join('; ')}');
    }
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: List.of(_doc.nodes),
      theme: _doc.theme,
      meta: _doc.meta,
      states: [..._doc.states, v],
    ));
  }

  /// Renames a state var, rewriting every `=old` binding in ONE undoable
  /// commit: exact `=old` item props become `=next`, and step `variable`
  /// refs plus `=old` value/message refs follow (see
  /// [ActionStep.withVariableRenamed]).
  ///
  /// Throws [StateError] on unknown [old] (mirroring [renameScreen]) and
  /// [ArgumentError] on an invalid or taken [next] — both before committing.
  /// A same-name rename is a no-op without committing. Type and default ride
  /// along unchanged (rename never migrates values: change those via delete
  /// + re-add).
  void renameVar(String old, String next) {
    final index = _doc.states.indexWhere((v) => v.name == old);
    if (index < 0) throw StateError('Unknown state var: $old');
    if (old == next) return;
    final candidate = List.of(_doc.states)
      ..[index] = _doc.states[index].renamed(next);
    final problems = validateAppStateVars(candidate);
    if (problems.isNotEmpty) {
      throw ArgumentError('Invalid state var: ${problems.join('; ')}');
    }
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [for (final n in _doc.nodes) _renameNodeRefs(n, old, next)],
      theme: _doc.theme,
      meta: _doc.meta,
      states: candidate,
    ));
  }

  /// Deletes a state var (undoable). Exact `=name` item props are cleared to
  /// the raw literal (`=count` → `count`); `=name` refs in step
  /// values/messages clear the same way (see [ActionStep.withBindingCleared]).
  /// Step `variable` refs are left intact — the executor skips unknown vars
  /// (documented in `app_state.dart`), so deleting a var never silently
  /// drops steps. Unknown [name] is a no-op without committing.
  void deleteVar(String name) {
    if (_doc.states.every((v) => v.name != name)) return;
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [for (final n in _doc.nodes) _clearNodeRefs(n, name)],
      theme: _doc.theme,
      meta: _doc.meta,
      states: [for (final v in _doc.states) if (v.name != name) v],
    ));
  }

  /// Replaces an item's action steps (undoable; the inspector's step editor
  /// writes through here).
  ///
  /// The legacy `to`/`transition` stay synced to the last navigate step when
  /// one exists (old readers keep working); with no navigate step they keep
  /// their previous values and are ignored at runtime (steps are
  /// authoritative — see `effectiveActionSteps`). Clearing to `[]` restores
  /// pure legacy behavior. Unknown node/item ids, and writes equal to the
  /// current action, are no-ops without committing.
  void setItemSteps(String nodeId, String itemId, List<ActionStep> steps) {
    CanvasItem? target;
    for (final n in _doc.nodes) {
      if (n.id != nodeId) continue;
      for (final i in n.items) {
        if (i.id == itemId) target = i;
      }
    }
    if (target == null) return;
    if (target.action == null && steps.isEmpty) return;
    final next = _actionWithSteps(target.action, steps);
    if (target.action != null && _actionsEqual(target.action!, next)) return;
    _commit(_mapNodes((n) {
      if (n.id != nodeId) return n;
      return _nodeWithItems(n, [
        for (final i in n.items)
          if (i.id == itemId) i.copyWith(action: () => next) else i,
      ]);
    }));
  }

  /// Rebuilds [node] with [items] (deep-copy precedent: responsive fields
  /// are copied, never aliased — mirrors [patchItem]).
  CanvasNode _nodeWithItems(CanvasNode n, List<CanvasItem> items) =>
      CanvasNode(
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
        w: n.w,
        h: n.h,
        hiddenOn: Set<String>.from(n.hiddenOn),
        breakpointValues: {
          for (final entry in n.breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        slots: Map<String, String>.from(n.slots),
        // Track DD carry: slot composition + lock ride every rebuild.
        slotNodes: Map<String, String>.from(n.slotNodes),
        locked: n.locked,
        items: items,
      );

  /// Rebuilds [node] with `=old` bindings renamed to `=next` (or returns it
  /// untouched when nothing references [old]).
  CanvasNode _renameNodeRefs(CanvasNode node, String old, String next) {
    var changed = false;
    final items = <CanvasItem>[];
    for (final i in node.items) {
      var props = i.props;
      final rewritten = <String, dynamic>{};
      for (final entry in i.props.entries) {
        if (entry.value == '=$old') {
          rewritten[entry.key] = '=$next';
          changed = true;
        } else {
          rewritten[entry.key] = entry.value;
        }
      }
      if (changed) props = rewritten;
      var action = i.action;
      if (action != null && action.steps.isNotEmpty) {
        final steps = [
          for (final s in action.steps) s.withVariableRenamed(old, next),
        ];
        if (!_stepsEqual(action.steps, steps)) {
          action = NodeAction(
            to: action.to,
            transition: action.transition,
            steps: steps,
          );
          changed = true;
        }
      }
      // Per-item change tracking would need a second flag; rebuilding an
      // untouched item is value-identical (props map is fresh but equal),
      // so only the node-level flag gates the rebuild.
      items.add(
        changed && identical(props, i.props) && identical(action, i.action)
            ? i
            : CanvasItem(id: i.id, kind: i.kind, props: props, action: action),
      );
    }
    // [changed] is node-wide: when false every item above is identical and
    // the rebuild below is still value-identical (harmless — rename commits
    // once per call by design, since the states list itself changed).
    return _nodeWithItems(node, items);
  }

  /// Rebuilds [node] with `=name` bindings cleared to raw (see [deleteVar]).
  CanvasNode _clearNodeRefs(CanvasNode node, String name) {
    final items = <CanvasItem>[];
    for (final i in node.items) {
      var props = i.props;
      if (i.props.values.any((v) => v == '=$name')) {
        props = {
          for (final entry in i.props.entries)
            entry.key: entry.value == '=$name' ? name : entry.value,
        };
      }
      var action = i.action;
      if (action != null && action.steps.isNotEmpty) {
        final steps = [
          for (final s in action.steps) s.withBindingCleared(name),
        ];
        action = NodeAction(
          to: action.to,
          transition: action.transition,
          steps: steps,
        );
      }
      items.add(CanvasItem(id: i.id, kind: i.kind, props: props, action: action));
    }
    return _nodeWithItems(node, items);
  }

  /// Builds the stored action for [steps]: empty steps restore the pure
  /// legacy action; non-empty steps sync `to`/`transition` to the last
  /// navigate step (falling back to [current], then the first screen, so
  /// `to` is never left meaninglessly empty for old readers).
  NodeAction _actionWithSteps(NodeAction? current, List<ActionStep> steps) {
    if (steps.isEmpty) {
      final c = current!;
      return NodeAction(to: c.to, transition: c.transition);
    }
    final navs = navigateTargetsOf(steps);
    var to = navs.isEmpty ? '' : navs.last;
    var transition = _lastNavigateTransition(steps);
    if (to.isEmpty) {
      to = current?.to ?? (_doc.screens.isEmpty ? '' : _doc.screens.first.id);
      transition = current?.transition ?? 'slide';
    }
    return NodeAction(to: to, transition: transition, steps: List.of(steps));
  }

  /// Transition of the last navigate step (recursing into conditions).
  String _lastNavigateTransition(List<ActionStep> steps) {
    var transition = 'slide';
    void walk(List<ActionStep> list) {
      for (final s in list) {
        if (s.kind == 'navigate') transition = s.transition;
        if (s.kind == 'condition') walk(s.thenSteps);
      }
    }

    walk(steps);
    return transition;
  }

  bool _actionsEqual(NodeAction a, NodeAction b) =>
      a.to == b.to &&
      a.transition == b.transition &&
      _stepsEqual(a.steps, b.steps);

  bool _stepsEqual(List<ActionStep> a, List<ActionStep> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Removes [keys] from the item's sparse props override map (true sparse
  /// delete: the keys resolve back to their schema/catalog defaults).
  /// Unknown node/item ids, an empty [keys] set, or none of the keys present
  /// in the item's props are a no-op (returns without committing, so history
  /// stays clean). Otherwise undoable and autosaved like every other
  /// mutation.
  void clearItemProps(String nodeId, String itemId, Set<String> keys) {
    if (keys.isEmpty) return;
    CanvasItem? target;
    for (final n in _doc.nodes) {
      if (n.id != nodeId) continue;
      for (final i in n.items) {
        if (i.id == itemId) target = i;
      }
    }
    if (target == null) return;
    if (!keys.any(target.props.containsKey)) return;
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
        w: n.w,
        h: n.h,
        hiddenOn: Set<String>.from(n.hiddenOn),
        breakpointValues: {
          for (final entry in n.breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        slots: Map<String, String>.from(n.slots),
        // Track DD carry: slot composition + lock ride every rebuild.
        slotNodes: Map<String, String>.from(n.slotNodes),
        locked: n.locked,
        items: [
          for (final i in n.items)
            if (i.id == itemId)
              i.copyWith(
                props: Map<String, dynamic>.from(i.props)
                  ..removeWhere((k, _) => keys.contains(k)),
              )
            else
              i,
        ],
      );
    }));
  }

  /// Deletes a node. Deleting a row cascades to its descendants (they live
  /// inside it — leaving them orphaned would make them invisible). Unknown
  /// ids are a no-op (no history pollution), matching reorderNode/patchNode
  /// which throw before committing.
  ///
  /// Track DD (lock): deleting a locked node — or a subtree containing a
  /// locked descendant — is a silent no-op without committing (the
  /// unknown-id precedent: keyboard/multi-delete paths must never crash on
  /// a locked target; the layers panel additionally skips locked ids before
  /// calling). Slot refs pointing at deleted nodes are scrubbed from
  /// survivors in the same commit (dangling slot entries would otherwise
  /// linger; codegen omits them, but the doc stays clean instead).
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
    for (final n in _doc.nodes) {
      if (doomed.contains(n.id) && n.locked) return;
    }
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [
        for (final n in _doc.nodes)
          if (!doomed.contains(n.id)) _withoutSlotRefs(n, doomed),
      ],
      theme: _doc.theme,
      meta: _doc.meta,
      states: List.of(_doc.states),
    ));
  }

  /// Rebuilds [node] minus any `slotNodes` entries pointing into [doomed]
  /// (see [deleteNode]); returns [node] untouched when nothing dangles, so
  /// clean deletes keep survivor instances identical.
  CanvasNode _withoutSlotRefs(CanvasNode node, Set<String> doomed) {
    if (!node.slotNodes.values.any(doomed.contains)) return node;
    final kept = Map<String, String>.from(node.slotNodes)
      ..removeWhere((_, childId) => doomed.contains(childId));
    return CanvasNode(
      id: node.id,
      screenId: node.screenId,
      x: node.x,
      y: node.y,
      items: node.items,
      parentId: node.parentId,
      isRow: node.isRow,
      gap: node.gap,
      mainAxis: node.mainAxis,
      crossAxis: node.crossAxis,
      expand: node.expand,
      flex: node.flex,
      w: node.w,
      h: node.h,
      hiddenOn: Set<String>.from(node.hiddenOn),
      breakpointValues: {
        for (final entry in node.breakpointValues.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      },
      slots: Map<String, String>.from(node.slots),
      slotNodes: kept,
      locked: node.locked,
    );
  }

  /// Replaces the doc theme (undoable, autosaved).
  void setTheme(CanvasTheme theme) {
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: List.of(_doc.nodes),
      theme: theme,
      meta: _doc.meta,
      states: List.of(_doc.states),
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
          w: n.w,
          h: n.h,
          hiddenOn: Set<String>.from(n.hiddenOn),
          breakpointValues: {
            for (final entry in n.breakpointValues.entries)
              entry.key: Map<String, dynamic>.from(entry.value),
          },
          slots: Map<String, String>.from(n.slots),
          // Track DD carry: the lock clones verbatim; slot refs inside the
          // duplicated subtree re-point at the fresh clone ids (like
          // `parentId` above), refs outside the subtree keep pointing out.
          slotNodes: {
            for (final entry in n.slotNodes.entries)
              entry.key: idMap[entry.value] ?? entry.value,
          },
          locked: n.locked,
          items: [
            for (final i in n.items)
              CanvasItem(
                id: fresh(i.id),
                kind: i.kind,
                props: Map<String, dynamic>.from(i.props),
                action: i.action == null
                    ? null
                    : NodeAction(
                        to: i.action!.to,
                        transition: i.action!.transition,
                        steps: List.of(i.action!.steps),
                      ),
              ),
          ],
        ),
    ];
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: [..._doc.nodes, ...clones],
      theme: _doc.theme,
      meta: _doc.meta,
      states: List.of(_doc.states),
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
      states: List.of(_doc.states),
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
      states: List.of(_doc.states),
    ));
    return screen.id;
  }

  /// Renames a screen. Throws [StateError] when [id] is unknown.
  /// Undoable and autosaved like every other mutation. Preserves the
  /// screen's [CanvasScreen.device].
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
      device: current.device,
    );
    _commit(ScreenDoc(
      screens: screens,
      nodes: List.of(_doc.nodes),
      theme: _doc.theme,
      meta: _doc.meta,
      states: List.of(_doc.states),
    ));
  }

  /// Sets a screen's preview device ([CanvasScreen.device], a member of
  /// [kScreenDeviceIds] or null for the phone default). Throws
  /// [ArgumentError] on an unknown non-null [device]. An unknown [screenId]
  /// or an unchanged value is a no-op without committing (matching
  /// [deleteNode], so history stays clean). Otherwise undoable and autosaved
  /// like every other mutation; all other screen fields are preserved.
  void setScreenDevice(String screenId, String? device) {
    if (device != null && !kScreenDeviceIds.contains(device)) {
      throw ArgumentError('Unknown device: $device');
    }
    final index = _doc.screens.indexWhere((s) => s.id == screenId);
    if (index < 0) return;
    if (_doc.screens[index].device == device) return;
    final screens = List.of(_doc.screens);
    final current = screens[index];
    screens[index] = CanvasScreen(
      id: current.id,
      name: current.name,
      x: current.x,
      y: current.y,
      bg: current.bg,
      device: device,
    );
    _commit(ScreenDoc(
      screens: screens,
      nodes: List.of(_doc.nodes),
      theme: _doc.theme,
      meta: _doc.meta,
      states: List.of(_doc.states),
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
      states: List.of(_doc.states),
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
      states: List.of(_doc.states),
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
            w: n.w,
            h: n.h,
            hiddenOn: Set<String>.from(n.hiddenOn),
            breakpointValues: {
              for (final entry in n.breakpointValues.entries)
                entry.key: Map<String, dynamic>.from(entry.value),
            },
            slots: Map<String, String>.from(n.slots),
            // Track DD carry: slot composition + lock ride every rebuild.
            slotNodes: Map<String, String>.from(n.slotNodes),
            locked: n.locked,
          )
        : n));
  }

  /// Updates a node's responsive fields (`hiddenOn`/`breakpointValues`/`slots`).
  ///
  /// Pass a non-null map/set to replace that field, or its `clear*` flag to
  /// reset it to empty (sparse-delete precedent, mirroring [clearItemProps];
  /// needed because `null` means "leave unchanged", matching [patchNode]).
  /// A `clear*` flag wins over its value param when both are given.
  /// Throws [ArgumentError] on unknown `hiddenOn` tiers (must be a subset of
  /// [kResponsiveTiers]). Unknown [nodeId] is a no-op without committing
  /// (matching [deleteNode], so history stays clean), as is calling with no
  /// values and no clear flags. Undoable and autosaved like every other
  /// mutation.
  void setNodeResponsive(
    String nodeId, {
    Set<String>? hiddenOn,
    Map<String, Map<String, dynamic>>? breakpointValues,
    Map<String, String>? slots,
    bool clearHiddenOn = false,
    bool clearBreakpointValues = false,
    bool clearSlots = false,
  }) {
    if (hiddenOn != null) {
      for (final tier in hiddenOn) {
        if (!kResponsiveTiers.contains(tier)) {
          throw ArgumentError('Unknown responsive tier: $tier');
        }
      }
    }
    if (_doc.nodes.every((n) => n.id != nodeId)) return;
    if (hiddenOn == null &&
        breakpointValues == null &&
        slots == null &&
        !clearHiddenOn &&
        !clearBreakpointValues &&
        !clearSlots) {
      return;
    }
    _commit(_mapNodes((n) {
      if (n.id != nodeId) return n;
      return CanvasNode(
        id: n.id,
        screenId: n.screenId,
        x: n.x,
        y: n.y,
        items: n.items,
        parentId: n.parentId,
        isRow: n.isRow,
        gap: n.gap,
        mainAxis: n.mainAxis,
        crossAxis: n.crossAxis,
        expand: n.expand,
        flex: n.flex,
        w: n.w,
        h: n.h,
        hiddenOn: clearHiddenOn
            ? const {}
            : (hiddenOn != null
                ? Set<String>.from(hiddenOn)
                : Set<String>.from(n.hiddenOn)),
        breakpointValues: clearBreakpointValues
            ? const {}
            : (breakpointValues != null
                ? {
                    for (final entry in breakpointValues.entries)
                      entry.key: Map<String, dynamic>.from(entry.value),
                  }
                : {
                    for (final entry in n.breakpointValues.entries)
                      entry.key: Map<String, dynamic>.from(entry.value),
                  }),
        slots: clearSlots
            ? const {}
            : (slots != null
                ? Map<String, String>.from(slots)
                : Map<String, String>.from(n.slots)),
        // Track DD carry: slot composition + lock ride every rebuild.
        slotNodes: Map<String, String>.from(n.slotNodes),
        locked: n.locked,
      );
    }));
  }

  /// Sets a node's explicit size (`w`/`h`, Track U2 — null = auto, see the
  /// sizing table on [CanvasNode]).
  ///
  /// Pass a non-null dimension to fix it, or its `clear*` flag to reset it to
  /// auto (sparse-delete precedent, mirroring [setNodeResponsive]; needed
  /// because `null` means "leave unchanged", matching [patchNode]). A `clear*`
  /// flag wins over its value param when both are given.
  ///
  /// Validation (all before committing, so history stays clean): non-null
  /// values must be positive and finite — zero, negative, NaN, and infinite
  /// throw [ArgumentError] (fail fast, mirroring [setScreenDevice]). There is
  /// deliberately NO upper bound here: docs may target wider future stages
  /// and codegen emits verbatim. Sane maxes live at the UI layer instead —
  /// drag handles clamp to the live stage (`clampResizeWidth/Height` in
  /// `phone_frame.dart`, `[kMinNodeSize, stage]`) and inspector steppers clamp
  /// to `[kMinNodeSize, kMaxNodeWidth/kMaxNodeHeight]`.
  ///
  /// Unknown [nodeId] is a no-op without committing (matching [deleteNode],
  /// so history stays clean), as is calling with no values and no clear flags
  /// or with values equal to the current size (so a handle release without
  /// movement writes no undo entry). Otherwise undoable and autosaved like
  /// every other mutation; every other field is preserved with the
  /// [setNodeResponsive] deep-copy precedent.
  void setNodeSize(
    String nodeId, {
    double? w,
    double? h,
    bool clearW = false,
    bool clearH = false,
  }) {
    if (!clearW && w != null && !(w.isFinite && w > 0)) {
      throw ArgumentError('Node width must be positive and finite: $w');
    }
    if (!clearH && h != null && !(h.isFinite && h > 0)) {
      throw ArgumentError('Node height must be positive and finite: $h');
    }
    final index = _doc.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final current = _doc.nodes[index];
    // Track DD (lock): resizing a locked node is a silent no-op without
    // committing (matches the unknown-id precedent above; resize handles
    // never show for locked nodes, so this only fires on stale calls).
    if (current.locked) return;
    final nextW = clearW ? null : (w ?? current.w);
    final nextH = clearH ? null : (h ?? current.h);
    if (nextW == current.w && nextH == current.h) return;
    _commit(_mapNodes((n) {
      if (n.id != nodeId) return n;
      return CanvasNode(
        id: n.id,
        screenId: n.screenId,
        x: n.x,
        y: n.y,
        items: n.items,
        parentId: n.parentId,
        isRow: n.isRow,
        gap: n.gap,
        mainAxis: n.mainAxis,
        crossAxis: n.crossAxis,
        expand: n.expand,
        flex: n.flex,
        w: nextW,
        h: nextH,
        hiddenOn: Set<String>.from(n.hiddenOn),
        breakpointValues: {
          for (final entry in n.breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        slots: Map<String, String>.from(n.slots),
        // Track DD carry: slot composition + lock ride every rebuild.
        slotNodes: Map<String, String>.from(n.slotNodes),
        locked: n.locked,
      );
    }));
  }

  /// Assigns (or clears) one named-slot child on [nodeId] (Track DD).
  ///
  /// [slot] names a slot from [_kNodeSlots] (the catalog `kNodeSlots`
  /// snapshot above) for the host's primary kind (its first item's kind;
  /// rows and item-less nodes declare no slots). A null or empty
  /// [childNodeId] CLEARS the entry.
  ///
  /// Validation (all before committing, so a refusal leaves history clean):
  /// unknown [nodeId] is a no-op without committing (matching [deleteNode]);
  /// clearing a slot with no entry is a no-op too. Assigning throws
  /// [ArgumentError] when [slot] is empty or unknown for the host kind (bad
  /// values throw, mirroring [setScreenDevice]); assigning or clearing on a
  /// locked host throws [StateError] (the frozen-subtree rule — the
  /// inspector disables slot pickers while locked, so this only fires on
  /// stale calls). An unknown [childNodeId] is a no-op without committing
  /// (matching [reparentNode]'s unknown-parent rule). A cross-screen child, a
  /// self assignment, or a `parentId`-descendant child throws [StateError]
  /// (via [isAncestorOf], mirroring [reparentNode]; message strings mirror
  /// [validateNesting] where they overlap). Assigning the current value is a
  /// no-op. Otherwise undoable and autosaved like every other mutation; every
  /// other field is preserved with the [setNodeResponsive] deep-copy
  /// precedent (plus the Track DD carry).
  ///
  /// NOTE: an ancestor (via `parentId`) of the host is NOT refused — only
  /// self/descendants are. An ancestor slot edge still cycles at render time,
  /// but the renderers and both codegen emitters are cycle-guarded (comment
  /// + skip), so the doc can never hang through the UI.
  void setSlotChild(String nodeId, String slot, String? childNodeId) {
    final index = _doc.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final node = _doc.nodes[index];
    if (childNodeId == null || childNodeId.isEmpty) {
      if (node.locked) {
        throw StateError('locked node $nodeId');
      }
      if (!node.slotNodes.containsKey(slot)) return;
      _commit(_mapNodes((n) {
        if (n.id != nodeId) return n;
        final next = Map<String, String>.from(n.slotNodes)..remove(slot);
        return _nodeWithSlotNodes(n, next);
      }));
      return;
    }
    final kind = node.isRow
        ? 'row'
        : (node.items.isEmpty ? '' : node.items.first.kind);
    final known = _kNodeSlots[kind] ?? const <String>[];
    if (slot.isEmpty || !known.contains(slot)) {
      throw ArgumentError('Unknown slot "$slot" for kind "$kind"');
    }
    if (node.locked) {
      throw StateError('locked node $nodeId');
    }
    final childIndex = _doc.nodes.indexWhere((n) => n.id == childNodeId);
    if (childIndex < 0) return;
    final child = _doc.nodes[childIndex];
    if (child.screenId != node.screenId) {
      throw StateError(
        'cross-screen slot $childNodeId for node $nodeId',
      );
    }
    if (childNodeId == nodeId) {
      throw StateError('self-slot $nodeId');
    }
    if (isAncestorOf(_doc, nodeId, childNodeId)) {
      throw StateError('cycle: node $nodeId is its own ancestor');
    }
    if (node.slotNodes[slot] == childNodeId) return;
    _commit(_mapNodes((n) {
      if (n.id != nodeId) return n;
      final next = Map<String, String>.from(n.slotNodes)..[slot] = childNodeId;
      return _nodeWithSlotNodes(n, next);
    }));
  }

  /// Locks or unlocks [nodeId] (Track DD — editor-only flag, see
  /// [CanvasNode.locked]). Unknown [nodeId], or a value equal to the current
  /// flag, is a no-op without committing (matching [deleteNode], so history
  /// stays clean). Otherwise undoable and autosaved like every other
  /// mutation; every other field is preserved with the [setNodeResponsive]
  /// deep-copy precedent (plus the Track DD carry).
  void setNodeLocked(String nodeId, bool locked) {
    final index = _doc.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    if (_doc.nodes[index].locked == locked) return;
    _commit(_mapNodes((n) {
      if (n.id != nodeId) return n;
      return CanvasNode(
        id: n.id,
        screenId: n.screenId,
        x: n.x,
        y: n.y,
        items: n.items,
        parentId: n.parentId,
        isRow: n.isRow,
        gap: n.gap,
        mainAxis: n.mainAxis,
        crossAxis: n.crossAxis,
        expand: n.expand,
        flex: n.flex,
        w: n.w,
        h: n.h,
        hiddenOn: Set<String>.from(n.hiddenOn),
        breakpointValues: {
          for (final entry in n.breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        slots: Map<String, String>.from(n.slots),
        slotNodes: Map<String, String>.from(n.slotNodes),
        locked: locked,
      );
    }));
  }

  /// Rebuilds [node] with [slotNodes] (deep-copy precedent: every other
  /// field carried, maps copied never aliased — see [setSlotChild]).
  CanvasNode _nodeWithSlotNodes(CanvasNode node, Map<String, String> slotNodes) =>
      CanvasNode(
        id: node.id,
        screenId: node.screenId,
        x: node.x,
        y: node.y,
        items: node.items,
        parentId: node.parentId,
        isRow: node.isRow,
        gap: node.gap,
        mainAxis: node.mainAxis,
        crossAxis: node.crossAxis,
        expand: node.expand,
        flex: node.flex,
        w: node.w,
        h: node.h,
        hiddenOn: Set<String>.from(node.hiddenOn),
        breakpointValues: {
          for (final entry in node.breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        slots: Map<String, String>.from(node.slots),
        slotNodes: slotNodes,
        locked: node.locked,
      );

  /// Moves the node with [nodeId] under a new parent ([newParentId], null =
  /// the screen root) in one undoable commit. Layout follows the new parent's
  /// kind (row children lay out horizontally, container children stack inside
  /// the parent chrome, leaf children stack below — see COMPOSITION.md §1);
  /// this method only re-points the `parentId` edge. The moved node lands at
  /// the end of its new group in doc order (use [reorderNode] afterwards to
  /// place it elsewhere within the group).
  ///
  /// Validation (all before committing, so history stays clean):
  /// unknown [nodeId] or [newParentId] is a no-op without committing
  /// (matching [deleteNode]); a cross-screen parent throws [StateError]
  /// (`screenId` never changes on move, matching [reorderNode]); a self
  /// parent or a descendant parent throws [StateError] (via [isAncestorOf],
  /// so the doc can never cycle through the UI); an unchanged `parentId`
  /// (same-position) is a no-op without committing. Message strings mirror
  /// [validateNesting] (`self-parent <id>`, `cross-screen parent <pid> for
  /// node <id>`, `cycle: node <id> is its own ancestor`).
  ///
  /// Every other field is preserved with the [setNodeResponsive] deep-copy
  /// precedent (`hiddenOn`/`breakpointValues`/`slots` are copied, never
  /// aliased; `items` rides along untouched).
  void reparentNode(String nodeId, String? newParentId) {
    final index = _doc.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final node = _doc.nodes[index];
    // Track DD (lock): a locked node cannot move anywhere — including back
    // to the screen root — and nothing may move under a locked parent (the
    // frozen-subtree rule). Illegal moves throw [StateError] like the
    // cross-screen/self/cycle refusals below — DnD surfaces these before
    // calling.
    if (node.locked) {
      throw StateError('locked node $nodeId');
    }
    if (newParentId != null) {
      final parentIndex = _doc.nodes.indexWhere((n) => n.id == newParentId);
      if (parentIndex < 0) return;
      final parent = _doc.nodes[parentIndex];
      if (parent.locked) {
        throw StateError('locked parent $newParentId');
      }
      if (parent.screenId != node.screenId) {
        throw StateError(
          'cross-screen parent $newParentId for node $nodeId',
        );
      }
      if (newParentId == nodeId) {
        throw StateError('self-parent $nodeId');
      }
      if (isAncestorOf(_doc, nodeId, newParentId)) {
        throw StateError('cycle: node $nodeId is its own ancestor');
      }
    }
    if (node.parentId == newParentId) return;
    final moved = CanvasNode(
      id: node.id,
      screenId: node.screenId,
      x: node.x,
      y: node.y,
      items: node.items,
      parentId: newParentId,
      isRow: node.isRow,
      gap: node.gap,
      mainAxis: node.mainAxis,
      crossAxis: node.crossAxis,
      expand: node.expand,
      flex: node.flex,
      w: node.w,
      h: node.h,
      hiddenOn: Set<String>.from(node.hiddenOn),
      breakpointValues: {
        for (final entry in node.breakpointValues.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      },
      slots: Map<String, String>.from(node.slots),
      // Track DD carry: slot composition + lock ride every rebuild.
      slotNodes: Map<String, String>.from(node.slotNodes),
      locked: node.locked,
    );
    final rest = List.of(_doc.nodes)..removeAt(index);
    // Land at the end of the new group in doc order: after its last member,
    // else anchored right after the parent itself (child groups) or after
    // the screen's last node (roots) — the `_docIndexForGroupIndex` rule in
    // `design_canvas.dart` for drops.
    var at = rest.length;
    for (var i = rest.length - 1; i >= 0; i--) {
      if (rest[i].screenId == node.screenId &&
          rest[i].parentId == newParentId) {
        at = i + 1;
        break;
      }
    }
    if (at == rest.length) {
      if (newParentId != null) {
        final parentAt = rest.indexWhere((n) => n.id == newParentId);
        if (parentAt >= 0) at = parentAt + 1;
      } else {
        var last = -1;
        for (var i = 0; i < rest.length; i++) {
          if (rest[i].screenId == node.screenId) last = i;
        }
        at = last + 1;
      }
    }
    rest.insert(at, moved);
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: rest,
      theme: _doc.theme,
      meta: _doc.meta,
      states: List.of(_doc.states),
    ));
  }

  /// Groups root-level nodes into a new row container in ONE undoable commit.
  ///
  /// Validation (all before committing, so a refusal leaves history clean):
  /// throws [StateError] when [nodeIds] holds fewer than 2 distinct ids,
  /// names an unknown node, spans more than one screen, or names a
  /// non-root-level node (`parentId != null` — nested nodes must be
  /// un-nested first; only the row's own slot rule applies, never a move
  /// across parents).
  ///
  /// On success appends a row container with the [addRow] defaults (`x`/`y`
  /// 0, empty items, `parentId` null, `isRow` true, `gap`
  /// [kFlowRowGapDefault], null alignment/flex) at the first grouped node's
  /// doc slot, and reparents the nodes into it in [nodeIds] order (children
  /// land directly after the row in doc order, so the flow position is
  /// stable). Every reparented node is rebuilt with the [reparentNode]
  /// deep-copy precedent — all fields preserved (`hiddenOn`/
  /// `breakpointValues`/`slots` copied, never aliased; `items` rides along
  /// untouched) — only `parentId` changes. Returns the row id.
  String groupIntoRow(List<String> nodeIds) {
    final ids = nodeIds.toSet().toList();
    if (ids.length < 2) {
      throw StateError('groupIntoRow needs at least 2 nodes: $nodeIds');
    }
    final byId = {for (final n in _doc.nodes) n.id: n};
    for (final id in ids) {
      if (!byId.containsKey(id)) throw StateError('Unknown node: $id');
    }
    final screenId = byId[ids.first]!.screenId;
    for (final id in ids) {
      if (byId[id]!.screenId != screenId) {
        throw StateError('cross-screen group ${ids.join(',')}');
      }
      if (byId[id]!.parentId != null) {
        throw StateError('non-root node in group: $id');
      }
      // Track DD (lock): locked nodes refuse grouping (same throw precedent
      // as the refusals above — the layers header surfaces it as a SnackBar).
      if (byId[id]!.locked) {
        throw StateError('locked node in group: $id');
      }
    }
    final row = CanvasNode(
      id: uid(),
      screenId: screenId,
      x: 0.0,
      y: 0.0,
      items: const [],
      parentId: null,
      isRow: true,
      gap: kFlowRowGapDefault,
      mainAxis: null,
      crossAxis: null,
      expand: null,
      flex: null,
    );
    final doomed = ids.toSet();
    // Insert slot: count of kept nodes before the first grouped node, so the
    // row takes the first grouped node's position among the roots.
    var at = 0;
    for (final n in _doc.nodes) {
      if (doomed.contains(n.id)) break;
      at++;
    }
    final rest = [
      for (final n in _doc.nodes)
        if (!doomed.contains(n.id)) n,
    ];
    final children = [
      for (final id in ids)
        CanvasNode(
          id: byId[id]!.id,
          screenId: byId[id]!.screenId,
          x: byId[id]!.x,
          y: byId[id]!.y,
          items: byId[id]!.items,
          parentId: row.id,
          isRow: byId[id]!.isRow,
          gap: byId[id]!.gap,
          mainAxis: byId[id]!.mainAxis,
          crossAxis: byId[id]!.crossAxis,
          expand: byId[id]!.expand,
          flex: byId[id]!.flex,
          w: byId[id]!.w,
          h: byId[id]!.h,
          hiddenOn: Set<String>.from(byId[id]!.hiddenOn),
          breakpointValues: {
            for (final entry in byId[id]!.breakpointValues.entries)
              entry.key: Map<String, dynamic>.from(entry.value),
          },
          slots: Map<String, String>.from(byId[id]!.slots),
          // Track DD carry: slot composition + lock ride every rebuild.
          slotNodes: Map<String, String>.from(byId[id]!.slotNodes),
          locked: byId[id]!.locked,
        ),
    ];
    rest.insertAll(at.clamp(0, rest.length), [row, ...children]);
    _commit(ScreenDoc(
      screens: List.of(_doc.screens),
      nodes: rest,
      theme: _doc.theme,
      meta: _doc.meta,
      states: List.of(_doc.states),
    ));
    return row.id;
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
        states: List.of(_doc.states),
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
