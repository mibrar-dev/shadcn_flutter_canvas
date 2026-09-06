/// Pure-Dart ScreenDoc model (no Flutter imports — reused by the CLI).
///
/// Manual `toJson`/`fromJson`, no codegen. Every double parses via
/// `(v as num).toDouble()` because `jsonDecode` yields `int` for whole
/// numbers and `as double` would crash on those.
library;

import 'app_state.dart';

/// Flow layout spacing (single source of truth; canvas_app imports these,
/// canvas_core stays Flutter-free so the CLI can share it).
///
/// The screen root is an implicit vertical Column: [kFlowScreenGap] is the
/// vertical gap between root children and [kFlowScreenPadding] the inner
/// screen padding. Row containers space their children with the node's own
/// `gap`, which defaults to [kFlowRowGapDefault].
const double kFlowScreenGap = 12.0;
const double kFlowScreenPadding = 16.0;
const double kFlowRowGapDefault = 8.0;

/// Responsive tiers known to the doc model (single source of truth; the
/// app-side [Tier] enum mirrors these names in `canvas_app/lib/ui/responsive.dart`).
const Set<String> kResponsiveTiers = {'mobile', 'tablet', 'desktop'};

/// Minimum explicit node size in logical px (Track U2).
///
/// Drag handles and inspector steppers clamp to this floor: below it text
/// overflows and hit targets go missing. The store itself stays permissive
/// (any positive finite value loads) so hand-written JSON is never rejected;
/// the UI re-clamps on the next drag.
const double kMinNodeSize = 48.0;

/// Maximum explicit node width in logical px (Track U2): the widest per-screen
/// device stage (`desktop-wide`, 1440 — see `device_picker.dart`). Inspector
/// steppers clamp here; drag handles clamp to the narrower live stage width.
const double kMaxNodeWidth = 1440.0;

/// Maximum explicit node height in logical px (Track U2): the fixed stage
/// height shared by every per-screen device (see `EditorMetrics`).
const double kMaxNodeHeight = 709.0;

/// Migrates a legacy absolute-layout doc to flow layout.
///
/// Pure function: root nodes (`parentId == null`, i.e. every node in a
/// legacy doc) are rewritten in `(y, x)` order so list order becomes the
/// flow order; `x`/`y` values are PRESERVED as metadata (the flow renderer
/// ignores them). `theme`/`meta`/`screens` are untouched, and row-child
/// nodes (`parentId != null`) keep their original relative order.
///
/// Row detection is explicitly OUT of scope for v1: no auto-grouping is
/// attempted. Heuristic grouping (e.g. "nodes sharing a baseline form a
/// row") guesses intent from pixels and corrupts layouts often enough that
/// rows must be created explicitly by the user instead.
ScreenDoc migrateToFlow(ScreenDoc doc) {
  final roots = [
    for (final n in doc.nodes)
      if (n.parentId == null) n,
  ]..sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });
  final children = [
    for (final n in doc.nodes)
      if (n.parentId != null) n,
  ];
  return ScreenDoc(
    screens: doc.screens,
    nodes: [...roots, ...children],
    theme: doc.theme,
    meta: doc.meta,
    states: List<AppStateVar>.of(doc.states),
  );
}

/// Direct children of [nodeId] in document order.
///
/// Unknown [nodeId] (or a doc where nothing points at it) yields empty.
/// Pure structural lookup over `parentId` edges; kind-agnostic (any node
/// may parent — see COMPOSITION.md §1).
List<CanvasNode> childrenOf(ScreenDoc doc, String nodeId) => [
      for (final n in doc.nodes)
        if (n.parentId == nodeId) n,
    ];

/// All transitive descendants of [nodeId] (breadth-first, document order
/// within each level), excluding [nodeId] itself even when a cycle leads
/// back to it.
///
/// Cycle-safe: each id is visited at most once, so `A→B→A` terminates.
/// Ids are assumed unique (the store's `uid()` enforces this); duplicate
/// ids collapse to first-seen.
List<CanvasNode> descendants(ScreenDoc doc, String nodeId) {
  final seen = <String>{nodeId};
  final out = <CanvasNode>[];
  final queue = <CanvasNode>[];
  for (final child in childrenOf(doc, nodeId)) {
    if (seen.add(child.id)) {
      queue.add(child);
      out.add(child);
    }
  }
  var cursor = 0;
  while (cursor < queue.length) {
    final parent = queue[cursor++];
    for (final child in childrenOf(doc, parent.id)) {
      if (seen.add(child.id)) {
        queue.add(child);
        out.add(child);
      }
    }
  }
  return out;
}

/// Whether [ancestorId] is reachable from [nodeId] by following `parentId`
/// hops (≥1 hop).
///
/// Strict in acyclic docs (`isAncestorOf(doc, x, x)` is false). A
/// self-parented node is its own ancestor by construction (one hop leads
/// back to itself), which is what makes [validateNesting] cycles detectable
/// through this helper. Cycle-safe (visited guard) and tolerant: unknown
/// ids and dangling edges yield false, never a throw (a dangling `parentId`
/// names no node, so the walk stops instead of claiming it as an ancestor).
bool isAncestorOf(ScreenDoc doc, String ancestorId, String nodeId) {
  final byId = {for (final n in doc.nodes) n.id: n};
  final seen = <String>{nodeId};
  CanvasNode? cursor = byId[nodeId];
  while (cursor != null) {
    final parentId = cursor.parentId;
    if (parentId == null) return false;
    final parent = byId[parentId];
    if (parent == null) return false;
    if (parentId == ancestorId) return true;
    if (!seen.add(parentId)) return false;
    cursor = parent;
  }
  return false;
}

/// Structural nesting problems in document order (at most one per node).
///
/// Checks, in order per node: unknown parent (no node carries `parentId`
/// as its id), self-parent, cross-screen parent (`screenId` mismatch —
/// moves never change screens), and cycles (the node is its own ancestor,
/// e.g. `A→B→A`). Roots (`parentId == null`) are always fine.
///
/// Kind-agnostic by design: any kind may parent any kind (COMPOSITION.md
/// §1) — container-ness is an app-side render concern, not a structural
/// error. Message strings are stable (exact-match tested):
/// `unknown parent <pid> for node <id>`,
/// `cross-screen parent <pid> for node <id>`, `self-parent <id>`,
/// `cycle: node <id> is its own ancestor`.
List<String> validateNesting(ScreenDoc doc) {
  final byId = {for (final n in doc.nodes) n.id: n};
  final problems = <String>[];
  for (final node in doc.nodes) {
    final parentId = node.parentId;
    if (parentId == null) continue;
    final parent = byId[parentId];
    if (parent == null) {
      problems.add('unknown parent $parentId for node ${node.id}');
    } else if (parentId == node.id) {
      problems.add('self-parent ${node.id}');
    } else if (parent.screenId != node.screenId) {
      problems.add('cross-screen parent $parentId for node ${node.id}');
    } else if (isAncestorOf(doc, node.id, parentId)) {
      problems.add('cycle: node ${node.id} is its own ancestor');
    }
  }
  return problems;
}

/// Top-level canvas document.
///
/// [states] holds the typed app-state variables (Track R1 — see
/// `app_state.dart`): a missing JSON key parses to `[]` (old docs stay
/// static), while [toJson] always emits the key (even empty) so the shape
/// is stable for readers.
class ScreenDoc {
  final List<CanvasScreen> screens;
  final List<CanvasNode> nodes;
  final CanvasTheme theme;
  final DocMeta meta;
  final List<AppStateVar> states;

  const ScreenDoc({
    required this.screens,
    required this.nodes,
    required this.theme,
    required this.meta,
    this.states = const [],
  });

  factory ScreenDoc.fromJson(Map<String, dynamic> json) {
    for (final key in ['screens', 'nodes', 'theme', 'meta']) {
      if (!json.containsKey(key)) {
        throw FormatException('ScreenDoc missing required key: $key');
      }
    }
    return ScreenDoc(
      screens: (json['screens'] as List)
          .map((s) => CanvasScreen.fromJson(s as Map<String, dynamic>))
          .toList(),
      nodes: (json['nodes'] as List)
          .map((n) => CanvasNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      theme: CanvasTheme.fromJson(json['theme'] as Map<String, dynamic>),
      meta: DocMeta.fromJson(json['meta'] as Map<String, dynamic>),
      // Backward compatible: old docs lack this key.
      states: (json['states'] as List?)
              ?.map((s) => AppStateVar.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'screens': screens.map((s) => s.toJson()).toList(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'theme': theme.toJson(),
        'meta': meta.toJson(),
        'states': [for (final v in states) v.toJson()],
      };

  /// Pure ref-integrity check: every navigation must match a screen id.
  ///
  /// Items with multi-step actions check their navigate steps (recursing
  /// into conditions); legacy single-nav items check `action.to`. A legacy
  /// `to` alongside non-empty steps is ignored (the steps are authoritative
  /// — the store keeps `to` synced to the last navigate step for old
  /// readers, but integrity follows what the runtime executes).
  List<String> validateRefs() {
    final ids = {for (final s in screens) s.id};
    final dangling = <String>[];
    for (final node in nodes) {
      for (final item in node.items) {
        final action = item.action;
        if (action == null) continue;
        if (action.steps.isNotEmpty) {
          for (final to in navigateTargetsOf(action.steps)) {
            if (!ids.contains(to)) {
              dangling.add('dangling action ${item.id} -> missing screen $to');
            }
          }
        } else if (!ids.contains(action.to)) {
          dangling.add(
            'dangling action ${item.id} -> missing screen ${action.to}',
          );
        }
      }
    }
    return dangling;
  }
}

/// A phone screen on the canvas.
///
/// [device] is the per-screen preview device id (`phone` / `tablet` /
/// `desktop-fluid` / `desktop-wide`, mirroring the `PreviewDeviceSpec` ids in
/// `canvas_app/lib/ui/device_picker.dart`); null means the phone default.
/// A missing JSON key parses to null so old docs stay phone-width, and
/// [toJson] omits the key when null (backward-compatible round-trip).
class CanvasScreen {
  final String id;
  final String name;
  final double x;
  final double y;
  final String bg;
  final String? device;

  const CanvasScreen({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.bg,
    this.device,
  });

  factory CanvasScreen.fromJson(Map<String, dynamic> json) => CanvasScreen(
        id: json['id'] as String,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        bg: json['bg'] as String,
        device: json['device'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'bg': bg,
        if (device != null) 'device': device,
      };
}

/// A flow-layout container of items on a screen.
///
/// `parentId == null` means the node sits in the screen-root vertical flow.
/// Any node may parent children via `parentId` (composition model — see
/// `canvas/COMPOSITION.md` §1); `isRow == true` additionally makes the node
/// a horizontal container whose children lay out in a `Row`. `gap` is the
/// container spacing (row separators today; column separators for nested
/// containers), ignored for childless leaves. `x`/`y` are kept as metadata
/// for legacy docs; the flow renderer ignores them and uses list order
/// instead.
///
/// W3 container alignment/flex:
/// `mainAxis` (`start|center|end|spaceBetween|spaceAround|spaceEvenly`,
/// null = Flutter default start) and `crossAxis`
/// (`start|center|end|stretch`, null = default center for rows) live on the
/// ROW container. `expand` (`none|flex|expanded`, null/none = default) and
/// `flex` (default 1 when expand is flex/expanded and flex is null) live on
/// the CHILD node.
///
/// Responsive visibility/overrides (FlutterFlow parity):
/// `hiddenOn` lists the tiers the node is hidden on (subset of
/// [kResponsiveTiers], empty = always visible); `breakpointValues` holds
/// per-tier prop overrides keyed by tier name
/// (e.g. `{'tablet': {'columns': 2}}`); `slots` holds per-tier slot
/// overrides mapping slot name → item id or value
/// (e.g. `{'tablet': 'item-id'}`). Render-time filtering and inspector
/// editing of these fields are app-side concerns (later batch); the model
/// only stores, validates, and round-trips them.
///
/// Explicit node size (Track U2): `w`/`h` are fixed logical-px sizes, null =
/// auto (today's behavior, backward compatible). SIZING SEMANTICS
/// (auto/fixed × context — canvas, preview, and both codegen emitters share
/// this table):
///
/// | w/h    | root/column leaf         | row child                    | row/container node          |
/// |--------|------------------------------|------------------------------|-----------------------------|
/// | auto   | intrinsic size, flow-stacked | EQUAL share of free space    | row: full width; container: |
/// | (null) | (today's behavior)           | via tight flex (the U2 fix — | shrink-wraps content        |
/// |        |                              | was loose `Flexible`, which  | (today's behavior)          |
/// |        |                              | shrink-wrapped to ~45px)     |                             |
/// | fixed  | exact px (`SizedBox`)        | `w`: exact px, flex ignored; | row: fixed width container; |
/// |        |                              | `h`-only: flex cell + fixed  | `h`: fixed body height      |
/// |        |                              | inner height                 |                             |
///
/// Overflow: fixed widths wider than the stage overflow VISIBLY (honest
/// authoring signal, same Row in canvas and export). No scrolling (a
/// scrollable Row gives unbounded width, which detonates tight flex and kit
/// internals) and no clipping (clip hides content without silencing the
/// overflow). Handles clamp drags to the live stage, so oversize only
/// arrives via the inspector or hand-written JSON.
///
/// Heights: rows default to `center` (today's behavior); a fixed `h` centers
/// per the row's `crossAxis` (under `stretch` the tight row height wins, per
/// standard Flutter constraints).
///
/// RESPONSIVE DECISION (v1: fixed sizes + `hiddenOn` only; per-tier sizes
/// explicitly DEFERRED): node-level per-tier overrides would ride the
/// existing `breakpointValues` tier maps, but EVERY merge site spreads those
/// maps into ITEM props (`phone_frame._nodeItems`, `preview_player`,
/// both codegen `_withProps`) — reserved `w`/`h` keys would leak into
/// component props. Filtering them needs `preview_player.dart`, which is
/// owned by another batch, so v1 keeps sizes tier-independent and `w`/`h`
/// keys inside `breakpointValues` stay inert item-prop overrides. A fixed
/// size applies on every tier the node is visible on.
///
/// COPY-SITE CONTRACT: `w`/`h` ride every `CanvasNode` reconstruction or an
/// unrelated edit silently drops the size. Current carriers: every mutator
/// in `canvas_store.dart`, both codegen `_withProps` copies, and group/ungroup
/// helpers. KNOWN GAP (not this batch): `selection_model._withParentId`
/// (ungroup path) rebuilds without `w`/`h` — ungrouping a sized node resets
/// it to auto.
class CanvasNode {
  final String id;
  final String screenId;
  final double x;
  final double y;
  final List<CanvasItem> items;
  final String? parentId;
  final bool isRow;
  final double gap;
  final String? mainAxis;
  final String? crossAxis;
  final String? expand;
  final int? flex;

  /// Fixed logical-px width, or null for auto (see the sizing table on
  /// [CanvasNode]). Missing JSON keys parse to null; [toJson] omits nulls so
  /// unsized docs round-trip byte-identically.
  final double? w;

  /// Fixed logical-px height, or null for auto (see the sizing table on
  /// [CanvasNode]). Missing JSON keys parse to null; [toJson] omits nulls.
  final double? h;

  /// Tiers this node is hidden on (subset of [kResponsiveTiers]).
  ///
  /// Serialized as a sorted list under JSON key `hiddenOn`; a missing key
  /// parses to empty (always visible). Unknown tier strings throw
  /// [FormatException] (fail fast).
  final Set<String> hiddenOn;

  /// Per-tier prop overrides keyed by tier name.
  ///
  /// Serialized as a map under JSON key `breakpointValues`; a missing key
  /// parses to empty (no overrides).
  final Map<String, Map<String, dynamic>> breakpointValues;

  /// Per-tier slot overrides mapping slot name → item id or value.
  ///
  /// Serialized as a map under JSON key `slots`; a missing key parses to
  /// empty (no overrides).
  final Map<String, String> slots;

  const CanvasNode({
    required this.id,
    required this.screenId,
    required this.x,
    required this.y,
    required this.items,
    this.parentId,
    this.isRow = false,
    this.gap = kFlowRowGapDefault,
    this.mainAxis,
    this.crossAxis,
    this.expand,
    this.flex,
    this.w,
    this.h,
    this.hiddenOn = const {},
    this.breakpointValues = const {},
    this.slots = const {},
  });

  factory CanvasNode.fromJson(Map<String, dynamic> json) {
    final hiddenRaw = (json['hiddenOn'] as List?)
            ?.map((e) => e as String)
            .toList() ??
        <String>[];
    for (final tier in hiddenRaw) {
      if (!kResponsiveTiers.contains(tier)) {
        throw FormatException('CanvasNode unknown hiddenOn tier: $tier');
      }
    }
    final breakpointRaw =
        (json['breakpointValues'] as Map?) ?? const <String, dynamic>{};
    final slotsRaw = (json['slots'] as Map?) ?? const <String, dynamic>{};
    return CanvasNode(
      id: json['id'] as String,
      screenId: json['screenId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      items: (json['items'] as List)
          .map((i) => CanvasItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      // Backward compatible: old docs lack these keys.
      parentId: json['parentId'] as String?,
      isRow: (json['isRow'] as bool?) ?? false,
      gap: (json['gap'] as num?)?.toDouble() ?? kFlowRowGapDefault,
      mainAxis: json['mainAxis'] as String?,
      crossAxis: json['crossAxis'] as String?,
      expand: json['expand'] as String?,
      flex: (json['flex'] as num?)?.toInt(),
      // Backward compatible + int-tolerant (same JSON-doubles trap as `gap`).
      w: (json['w'] as num?)?.toDouble(),
      h: (json['h'] as num?)?.toDouble(),
      hiddenOn: hiddenRaw.toSet(),
      breakpointValues: {
        for (final entry in breakpointRaw.entries)
          entry.key as String:
              Map<String, dynamic>.from(entry.value as Map),
      },
      slots: {
        for (final entry in slotsRaw.entries)
          entry.key as String: entry.value as String,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'screenId': screenId,
        'x': x,
        'y': y,
        'items': items.map((i) => i.toJson()).toList(),
        'parentId': parentId,
        'isRow': isRow,
        'gap': gap,
        'mainAxis': mainAxis,
        'crossAxis': crossAxis,
        'expand': expand,
        'flex': flex,
        // Omit-when-null (unlike the always-written keys above): unsized
        // docs keep byte-identical JSON.
        if (w != null) 'w': w,
        if (h != null) 'h': h,
        'hiddenOn': (hiddenOn.toList()..sort()),
        'breakpointValues': {
          for (final entry in breakpointValues.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        'slots': Map<String, String>.from(slots),
      };
}

/// A single component instance. All keys besides `id`/`kind`/`action`
/// are component props (e.g. `label`, `variant`).
class CanvasItem {
  final String id;
  final String kind;
  final Map<String, dynamic> props;
  final NodeAction? action;

  const CanvasItem({
    required this.id,
    required this.kind,
    this.props = const {},
    this.action,
  });

  factory CanvasItem.fromJson(Map<String, dynamic> json) {
    final rest = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('kind')
      ..remove('action');
    return CanvasItem(
      id: json['id'] as String,
      kind: json['kind'] as String,
      props: rest,
      action: json['action'] == null
          ? null
          : NodeAction.fromJson(json['action'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        ...props,
        if (action != null) 'action': action!.toJson(),
      };

  CanvasItem copyWith({
    String? id,
    String? kind,
    Map<String, dynamic>? props,
    NodeAction? Function()? action,
  }) =>
      CanvasItem(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        props: props ?? Map<String, dynamic>.from(this.props),
        action: action == null ? this.action : action(),
      );
}

/// Tap behavior: navigate to another screen, optionally via an ordered
/// multi-step action flow (Track R1 — see `app_state.dart`).
///
/// [steps] is empty for legacy single-nav actions (a missing JSON key parses
/// to `[]`, and [toJson] omits the key when empty, so legacy docs keep
/// byte-identical JSON). When non-empty the steps are authoritative and the
/// legacy [to]/[transition] are ignored at runtime (the store keeps them
/// synced to the last navigate step for old readers).
class NodeAction {
  final String to;
  final String transition;
  final List<ActionStep> steps;

  const NodeAction({
    required this.to,
    required this.transition,
    this.steps = const [],
  });

  factory NodeAction.fromJson(Map<String, dynamic> json) => NodeAction(
        to: json['to'] as String,
        transition: json['transition'] as String,
        steps: (json['steps'] as List?)
                ?.map((s) => ActionStep.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'to': to,
        'transition': transition,
        if (steps.isNotEmpty) 'steps': [for (final s in steps) s.toJson()],
      };
}

/// The steps an item tap executes: [action.steps] when non-empty (the
/// authoritative flow), else the legacy single navigate, else nothing.
/// Shared by preview, codegen, and the inspector's step editor.
List<ActionStep> effectiveActionSteps(NodeAction? action) {
  if (action == null) return const [];
  if (action.steps.isNotEmpty) return action.steps;
  return [ActionStep.navigate(to: action.to, transition: action.transition)];
}

/// Canvas-wide theme selection.
///
/// `chrome` is the optional app-chrome (editor shell) theme override; null
/// means the chrome follows the main (components) theme (current behavior,
/// backward compatible). Chrome is editor-only and never leaks into export
/// (prompt_builder/codegen keep using the main/components theme).
/// Chrome-of-chrome is not supported: a nested chrome's own `chrome` is
/// always null (fromJson forces it).
class CanvasTheme {
  final String paletteKey;
  final bool dark;
  final String shape;
  final String motion;

  /// The app-chrome theme override; null = chrome follows the main theme.
  final CanvasTheme? chrome;

  const CanvasTheme({
    required this.paletteKey,
    required this.dark,
    required this.shape,
    required this.motion,
    this.chrome,
  });

  factory CanvasTheme.fromJson(Map<String, dynamic> json) {
    for (final key in ['paletteKey', 'dark', 'shape', 'motion']) {
      if (!json.containsKey(key)) {
        throw FormatException('CanvasTheme missing required key: $key');
      }
    }
    CanvasTheme? chrome;
    if (json.containsKey('chrome') && json['chrome'] != null) {
      final raw = json['chrome'];
      if (raw is! Map) {
        throw FormatException('CanvasTheme chrome must be an object');
      }
      final cmap = Map<String, dynamic>.from(raw);
      for (final key in ['paletteKey', 'dark', 'shape', 'motion']) {
        if (!cmap.containsKey(key)) {
          throw FormatException(
            'CanvasTheme chrome missing required key: $key',
          );
        }
      }
      // Chrome-of-chrome is not supported: nested chrome forced null.
      chrome = CanvasTheme(
        paletteKey: cmap['paletteKey'] as String,
        dark: cmap['dark'] as bool,
        shape: cmap['shape'] as String,
        motion: cmap['motion'] as String,
      );
    }
    return CanvasTheme(
      paletteKey: json['paletteKey'] as String,
      dark: json['dark'] as bool,
      shape: json['shape'] as String,
      motion: json['motion'] as String,
      chrome: chrome,
    );
  }

  Map<String, dynamic> toJson() => {
        'paletteKey': paletteKey,
        'dark': dark,
        'shape': shape,
        'motion': motion,
        if (chrome != null) 'chrome': chrome!.toJson(),
      };

  /// Effective chrome theme: the override when set, else the main theme.
  CanvasTheme get effectiveChrome => chrome ?? this;
}

/// Document title/brief.
class DocMeta {
  final String title;
  final String brief;

  const DocMeta({required this.title, required this.brief});

  factory DocMeta.fromJson(Map<String, dynamic> json) => DocMeta(
        title: json['title'] as String,
        brief: json['brief'] as String,
      );

  Map<String, dynamic> toJson() => {'title': title, 'brief': brief};
}
