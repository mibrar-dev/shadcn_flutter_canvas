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
/// TRACK R1 (app state + action flows): the stage subtree sits under a
/// [StateScope] carrying the preview session (var name → live value,
/// initialized from var defaults and owned by this player — the snapshot
/// [doc] is never mutated). Bound text props (`=var`) resolve through the
/// session at every catalog call site (unknown vars render the raw `=name`
/// string). Taps run [effectiveActionSteps] with navigation-last semantics
/// (see `app_state.dart`: state writes + feedback first, in order, with
/// dialogs awaited; navigations after, in order). Steps touching unknown
/// vars are skipped, never a crash — so deleting a var can never break a
/// running preview.
///
/// TRACK S1 (API actions): `apiCall` steps run in order as immediates (see
/// [partitionSteps]) via [executeApiCall] (`package:http`, 10s timeout per
/// [kApiCallTimeout]). Transport errors, timeouts, and invalid URLs skip the
/// step with a `debugPrint` note (the debug console — never a crash, never a
/// dialog); a success with [ActionStep.saveTo] writes the response body
/// string into the session (coerced per var type, unparseable bodies keep the
/// current value). Secrets note: headers/bodies live in the doc like any
/// other prop (no vault — documented, not solved) and session values are
/// never persisted.
///
/// The player takes an immutable [ScreenDoc] snapshot (preview never edits),
/// themed by [themeOverride] or `doc.theme` via [ThemedCanvas].
///
/// Device frames: the top bar holds a [DevicePicker] (phone 390×844, tablet
/// 768×1024, desktop fluid 1100, desktop 1440, plus a landscape toggle that
/// swaps phone/tablet to 844×390 / 1024×768). Mobile/tablet stages render in
/// a bezel-ish rounded frame from [EditorTokens]; desktop stays frameless
/// fluid. The stage width IS the responsive breakpoint: it resolves a [Tier]
/// via [tierForWidth] (shown as a chip under the stage), so the adaptive-nav
/// demo re-tiers live as the device changes.
///
/// Content area is exempt from the chrome dogfooding rule (user content), but
/// the chrome here (back bar) still uses registry widgets via
/// `lib/shadcn_ui.dart` — no raw Material or Cupertino widgets in this file,
/// except the adaptive-nav DEMO template below, which is a user-content
/// screen preset showcasing the canonical Material responsive nav pattern
/// (NavigationBar/NavigationRail) for later code emission.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/ui/state_scope.dart';
import 'package:canvas_app/ui/phone_frame.dart'
    show
        alignIntrinsicKind,
        applyNodeSize,
        rowCrossAxis,
        rowMainAxis,
        wrapRowChild;
import 'package:canvas_core/canvas_core.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/device_picker.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/responsive.dart';
import 'package:canvas_app/ui/theme_bar.dart';

/// Phone stage width (mirrors [kPreviewDevicePhone.width]). Kept as a named
/// const because `preview_devices_test.dart` asserts against it.
const double kPreviewMobileMaxWidth = 390;

/// Desktop-fluid stage cap (mirrors [kPreviewDeviceDesktopFluid.width]).
/// Kept as a named const because `preview_devices_test.dart` asserts
/// against it.
const double kPreviewWebMaxWidth = 1100;

/// Runs one `apiCall` step over HTTP and returns the response body string,
/// or null when the step was skipped (invalid URL/method, transport error,
/// or timeout — each logged to the debug console via `debugPrint`).
///
/// [client] is injectable so tests pass a `MockClient` and never hit the
/// real network; a null client creates (and closes) a short-lived one.
/// Any HTTP status still yields its body (only transport failures skip).
/// Headers/bodies live in the doc like any other prop (no vault).
Future<String?> executeApiCall(
  ActionStep step, {
  http.Client? client,
  Duration timeout = kApiCallTimeout,
}) async {
  if (step.kind != 'apiCall') return null;
  if (!isApiCallUrlValid(step.url)) {
    debugPrint('[canvas apiCall] skipped: invalid URL "${step.url}".');
    return null;
  }
  if (!kApiCallMethods.contains(step.method)) {
    debugPrint('[canvas apiCall] skipped: unknown method "${step.method}".');
    return null;
  }
  final owned = client ?? http.Client();
  try {
    final uri = Uri.parse(step.url.trim());
    final headers = step.headers.isEmpty ? null : step.headers;
    late final http.Response response;
    if (step.method == 'POST') {
      response = await owned
          .post(uri,
              headers: headers, body: step.body.isEmpty ? null : step.body)
          .timeout(timeout);
    } else {
      response = await owned.get(uri, headers: headers).timeout(timeout);
    }
    return response.body;
  } catch (e) {
    debugPrint(
      '[canvas apiCall] ${step.method} ${step.url} failed: $e (skipped).',
    );
    return null;
  } finally {
    if (client == null) owned.close();
  }
}

/// Preview host over [doc] starting at [startScreenId] (or the first screen).
class PreviewPlayer extends StatefulWidget {
  final ScreenDoc doc;
  final CanvasTheme? themeOverride;
  final String? startScreenId;

  /// Called when back is pressed at the stack root.
  final VoidCallback? onExit;

  /// Injectable HTTP client for `apiCall` steps (tests pass a `MockClient`;
  /// null creates short-lived clients per call). Part of the apiCall
  /// execution surface only.
  final http.Client? httpClient;

  /// Test-only seam for the per-node error boundary (Track FF3): when set,
  /// node catalog builds route through this instead of [buildCatalogItem].
  /// Tests set it to a function that throws for one kind (and delegates to
  /// [buildCatalogItem] otherwise) to prove a crashing widget renders an
  /// inline [_PreviewErrorCard] while siblings still render. Production code
  /// never sets it. Reset it in `tearDown`/`addTearDown` — it is static.
  @visibleForTesting
  static Widget Function(
    String kind,
    Map<String, dynamic> props,
    List<Widget> children,
    Map<String, dynamic> scope,
  )? debugItemBuilder;

  const PreviewPlayer({
    super.key,
    required this.doc,
    this.themeOverride,
    this.startScreenId,
    this.onExit,
    this.httpClient,
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

  /// Device picker state. Internal only (no ctor change): index into
  /// [kPreviewDevices]. Defaults to the CURRENT screen's device (Track FF3 —
  /// see [initState]/[_adoptCurrentScreenDevice]), falling back to phone for
  /// screens without one; a manual picker/landscape choice ([_userPicked])
  /// wins over screen defaults for the rest of the session.
  int _deviceIndex = 0;

  /// Landscape toggle: swaps framed phone/tablet dimensions (844×390 /
  /// 1024×768). Ignored for frameless desktop presets.
  bool _landscape = false;

  /// True once the user picks a device preset or flips the landscape toggle
  /// in this session: per-screen device adoption stops so the manual choice
  /// sticks across navigations.
  bool _userPicked = false;

  @override
  void initState() {
    super.initState();
    _deviceIndex = _deviceIndexForScreen(_currentId);
  }

  /// Picker index for the device of screen [id] (phone when the id is null,
  /// unknown, or the screen stores no device — same fallback as
  /// [specForScreenDevice], so old docs stay phone-width).
  int _deviceIndexForScreen(String? id) {
    final screen = id == null ? null : _screen(id);
    final spec = specForScreenDevice(screen?.device);
    final index = kPreviewDevices.indexWhere((d) => d.id == spec.id);
    return index < 0 ? 0 : index;
  }

  /// Follows the current screen's device unless the user manually picked one
  /// ([_userPicked]). Called after every stack change (push/pop); navigation,
  /// tier, slot, and lock semantics are untouched — only the stage preset.
  void _adoptCurrentScreenDevice() {
    if (_userPicked) return;
    _deviceIndex = _deviceIndexForScreen(_currentId);
  }

  /// Adaptive-nav demo overlay. Behaves like a pushed preview screen: Back
  /// closes it first, then pops the doc stack.
  bool _demoOpen = false;

  /// Preview session: var name → live value, initialized from the var
  /// defaults (see [StateScope] — session-only, the snapshot doc is never
  /// mutated and nothing persists).
  late Map<String, dynamic> _session =
      StateScope.defaultsFor(widget.doc.states);

  String? get _currentId => _stack.isEmpty ? null : _stack.last;

  CanvasScreen? _screen(String id) {
    for (final screen in widget.doc.screens) {
      if (screen.id == id) return screen;
    }
    return null;
  }

  void _onItemTap(CanvasItem item) {
    _runItemAction(item);
  }

  /// Executes an item tap as an ordered action flow (Track R1):
  /// [effectiveActionSteps] partitioned navigation-last (see
  /// `partitionSteps` in canvas_core). `setState` resolves its value
  /// against the live session ([resolveActionValue] — unresolvable values
  /// keep the current value); `showSnackBar`/`showDialog` resolve
  /// whole-value `=var` bindings in their text; conditions evaluate against
  /// the live session (unknown vars are false); `apiCall` runs via
  /// [executeApiCall] (Track S1 — skipped with a debug-console note on
  /// error, response body saved into [ActionStep.saveTo] when set and
  /// known); navigations push known screens in order (unknown targets are
  /// skipped). Legacy single-nav actions flow through the same path as a
  /// one-navigate plan, so old behavior is unchanged.
  Future<void> _runItemAction(CanvasItem item) async {
    final steps = effectiveActionSteps(item.action);
    if (steps.isEmpty) return;
    final knownVars = {for (final v in widget.doc.states) v.name};
    final varsByName = {for (final v in widget.doc.states) v.name: v};
    final plan = partitionSteps(steps, _session, knownVars: knownVars);
    for (final step in plan.immediate) {
      if (!mounted) return;
      switch (step.kind) {
        case 'setState':
          final target = varsByName[step.variable];
          if (target == null) continue;
          final next = resolveActionValue(
            raw: step.value,
            target: target,
            values: _session,
          );
          if (next == null) continue;
          setState(() => _session[step.variable] = next);
        case 'apiCall':
          final body = await executeApiCall(
            step,
            client: widget.httpClient,
          );
          if (body == null) continue;
          final saveTo = step.saveTo;
          if (saveTo.isEmpty) continue;
          final target = varsByName[saveTo];
          if (target == null) {
            debugPrint(
              '[canvas apiCall] unknown saveTo "$saveTo": response discarded.',
            );
            continue;
          }
          final next = parseStateLiteral(body, target.type);
          if (next == null) {
            debugPrint(
              '[canvas apiCall] response not compatible with '
              '${target.type} "$saveTo": skipped.',
            );
            continue;
          }
          if (!mounted) return;
          setState(() => _session[saveTo] = next);
        case 'showSnackBar':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resolveStepText(step.message, _session)),
            ),
          );
        case 'showDialog':
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(resolveStepText(step.title, _session)),
              content: Text(resolveStepText(step.message, _session)),
            ),
          );
        case 'navigate':
        case 'condition':
          break; // Partitioned away — unreachable.
      }
    }
    for (final nav in plan.navigate) {
      if (!mounted) return;
      if (_screen(nav.to) == null) continue;
      setState(() {
        _stack.add(nav.to);
        _adoptCurrentScreenDevice();
      });
    }
  }

  void _onBack() {
    if (_demoOpen) {
      setState(() => _demoOpen = false);
      return;
    }
    if (_stack.length > 1) {
      setState(() {
        _stack.removeLast();
        _adoptCurrentScreenDevice();
      });
    } else {
      widget.onExit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentId == null ? null : _screen(_currentId!);
    final colors = EditorTheme.of(context);
    // ONE-TREE RULE: every device renders the SAME content subtree below
    // ([_stageContent]). Only the stage dimensions and the bezel frame
    // change — the picker must not alter item counts, tap handling, or
    // back-stack behavior.
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
                        _demoOpen
                            ? 'Responsive demo'
                            : (current?.name ?? 'No screens'),
                        style: EditorType.screenLabel
                            .copyWith(color: colors.onSurface),
                      ),
                    ),
                    DevicePicker(
                      selectedIndex: _deviceIndex,
                      onSelect: (index) => setState(() {
                        _deviceIndex = index;
                        _userPicked = true;
                      }),
                      landscape: _landscape,
                      onLandscapeChanged: (value) => setState(() {
                        _landscape = value;
                        _userPicked = true;
                      }),
                    ),
                    const SizedBox(width: 8),
                    shadcn.GhostButton(
                      onPressed: _demoOpen
                          ? null
                          : () => setState(() => _demoOpen = true),
                      child: const Text('Responsive demo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Hairline separator between the chrome bar and the stage so
              // the top bar reads as chrome in both brightnesses.
              Container(
                key: const ValueKey('previewChromeDivider'),
                height: 1,
                color: colors.surfaceContainerHigh,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final spec = resolveDevice(
                      kPreviewDevices[_deviceIndex],
                      landscape: _landscape,
                    );
                    // Clamp the stage to the device geometry but never exceed
                    // the available viewport (narrow windows shrink
                    // gracefully). Framed devices keep their fixed height;
                    // fluid desktop stages fill the available height.
                    final stageWidth = constraints.maxWidth > spec.width
                        ? spec.width
                        : constraints.maxWidth;
                    // Stable frame skeleton: the same widget TYPES wrap the
                    // content on every device (a bare [Container] would
                    // insert/remove DecoratedBox/Padding internally when its
                    // decoration toggles, remounting the content below and
                    // wiping state like the demo's selected tab). Only scalar
                    // params collapse to zero when frameless, so the content
                    // subtree keeps its element position on every switch and
                    // demo selection survives tier changes.
                    final frame = spec.framed ? EditorMetrics.phoneBezel : 0.0;
                    var innerHeight = spec.height == null
                        ? constraints.maxHeight
                        : (spec.height! > constraints.maxHeight
                            ? constraints.maxHeight
                            : spec.height!);
                    // Reserve the bezel inside the available height so the
                    // frame never overflows short viewports (e.g. the 844pt
                    // phone in widget-test viewports).
                    var outerHeight = innerHeight + frame * 2;
                    if (outerHeight > constraints.maxHeight) {
                      outerHeight = constraints.maxHeight;
                    }
                    innerHeight = outerHeight - frame * 2;
                    final outerWidth =
                        stageWidth + frame * 2 > constraints.maxWidth
                            ? constraints.maxWidth
                            : stageWidth + frame * 2;
                    // The canvas IS the breakpoint: preview width resolves
                    // the tier, shown as a chip under the stage.
                    final tier = tierForWidth(stageWidth);
                    final content = _demoOpen
                        ? buildAdaptiveNavDemo()
                        : _stageContent(current, colors, stageWidth);
                    // Track R1: the stage subtree reads live session values
                    // through this scope (bindings resolve live; catalog
                    // call sites below also take the map explicitly, since
                    // `buildCatalogItem` itself has no BuildContext).
                    final scoped = StateScope(
                      values: _session,
                      child: content,
                    );
                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: outerWidth,
                            height: outerHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: spec.framed
                                    ? colors.bezel
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  spec.framed
                                      ? EditorMetrics.phoneOuterRadius
                                      : 0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(frame),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    spec.framed
                                        ? EditorMetrics.phoneInnerRadius
                                        : 0,
                                  ),
                                  child: SizedBox(
                                    key: const ValueKey('previewStage'),
                                    width: stageWidth,
                                    height: innerHeight,
                                    child: scoped,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Center(
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                  // Hairline border: the chip sits over the
                                  // stage edge on frameless presets, where
                                  // the fill alone is low-contrast in light
                                  // mode.
                                  border: Border.all(
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '${tier.name} · ${stageWidth.round()}',
                                  style: EditorType.field.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The doc content subtree — identical for every device (one-tree rule).
  ///
  /// Recursive composition (Track C1 — `canvas/COMPOSITION.md` §1): root
  /// nodes lay out vertically; rows lay out horizontally at any depth;
  /// containers splice built children into their spec slot; leaves with
  /// children stack them below via the fallback column. Childless nodes
  /// take the exact pre-composition path.
  ///
  /// Responsive filtering: [stageWidth] resolves the tier via [tierForWidth]
  /// and nodes hidden on that tier ([isNodeHiddenOnWidth]) are skipped. A
  /// hidden node hides its whole subtree (descendants are skipped even when
  /// individually visible — the cascade walks EVERY ancestor, not just
  /// rows). The active tier's [CanvasNode.breakpointValues] merge over each
  /// item's props at build time (`{...item.props, ...overrides}`), per level.
  ///
  /// Cycle safety: roots are `parentId == null` plus dangling-`parentId`
  /// nodes (same honesty rule as codegen); self-parented/cyclic nodes are
  /// unreachable and never render (`validateNesting` reports them). Every
  /// level additionally filters ids already on its build path, so corrupt
  /// docs terminate.
  ///
  /// Slot semantics (assumed — the doc model stores [CanvasNode.slots] as a
  /// slot-name → item-id map with no renderer contract yet, so this is
  /// deliberately conservative): when a slot KEY names an item id present in
  /// this node, only the named items render (doc order preserved); every
  /// other entry (tier names like `{'tablet': 'i2'}`, future container slot
  /// names) is ignored, so unknown slot shapes can never blank a node. An
  /// empty [slots] map renders all items.
  ///
  /// No per-tier selection state lives here — the subtree stays stateless
  /// across tier switches (the same invariant as [AdaptiveNavDemo]'s
  /// state-outside-the-branch rule), so changing devices never resets widget
  /// state below.
  Widget _stageContent(
    CanvasScreen? current,
    EditorColors colors,
    double stageWidth,
  ) {
    // Track FF3: a doc with zero screens renders a designed empty state
    // (kit widget, theme-aware in both brightnesses) instead of a bare line
    // of text on a blank stage. Chrome (back bar, picker) stays mounted.
    if (current == null) {
      return const Center(
        child: _PreviewEmptyState(
          title: 'No screens yet',
          description: 'Add a screen in the editor to preview it here.',
        ),
      );
    }
    final tierName = tierForWidth(stageWidth).name;
    final byId = {for (final n in widget.doc.nodes) n.id: n};
    // A node is hidden when it — or any ancestor up its parentId chain — is
    // hidden on the active tier (cycle-safe via [seen]).
    bool effectivelyHidden(CanvasNode node) {
      CanvasNode? cursor = node;
      final seen = <String>{};
      while (cursor != null && seen.add(cursor.id)) {
        if (isNodeHiddenOnWidth(stageWidth, cursor.hiddenOn)) return true;
        final parentId = cursor.parentId;
        cursor = parentId == null ? null : byId[parentId];
      }
      return false;
    }

    final roots = [
      for (final node in widget.doc.nodes)
        if (node.screenId == current.id && !effectivelyHidden(node))
          if ((node.parentId == null ||
                  byId[node.parentId] == null ||
                  byId[node.parentId]!.screenId != node.screenId) &&
              !_slotAssignedIds.contains(node.id))
            node,
    ];

    bool hidden(CanvasNode node) => effectivelyHidden(node);

    // Track FF3: a screen with zero visible nodes renders a designed empty
    // state instead of a blank stage. A screen with no nodes at all says so;
    // a screen whose nodes are all filtered on this tier names the tier so
    // the author knows where the content went (responsive visibility, never
    // deleted).
    if (roots.isEmpty) {
      final hasNodes = widget.doc.nodes.any((n) => n.screenId == current.id);
      if (!hasNodes) {
        return const Center(
          child: _PreviewEmptyState(
            title: 'This screen is empty',
            description:
                'Add components on the canvas — they will appear here.',
          ),
        );
      }
      return Center(
        child: _PreviewEmptyState(
          title: 'Nothing to show on $tierName',
          description:
              'Every node on this screen is hidden on the $tierName tier.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final node in roots)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPreviewNode(node, tierName, stageWidth, hidden, {
              node.id,
            }),
          ),
      ],
    );
  }

  /// Ids assigned into named slots anywhere in the doc (every value in any
  /// node's [CanvasNode.slotNodes]).
  ///
  /// FLOW-VS-SLOT RULE (Track AA, canvas parity): slot assignment wins —
  /// these nodes render ONLY inside their slot and are skipped by the flow
  /// (roots in [_stageContent] and children in [_previewChildren], rows
  /// included). The `parentId` edges are untouched; unknown ids skip nothing;
  /// corrupt slot cycles with no live host render nothing (canvas parity).
  Set<String> get _slotAssignedIds => {
        for (final n in widget.doc.nodes)
          for (final id in n.slotNodes.values) id,
      };

  /// Builds [node]'s named-slot widgets (Track AA generic injection, canvas
  /// parity): for each [CanvasNode.slotNodes] entry whose child id resolves
  /// to a visible same-screen node, recursively builds the child through
  /// [_buildPreviewNode] (same tier/hidden/action semantics — hidden children
  /// are omitted — and cycle-safe via [ancestors]), keyed by slot name.
  /// Unknown/missing ids, cross-screen ids, and ids already on the build path
  /// are omitted, never a crash. Callers spread the result over item props
  /// (`{...props, ...slotWidgets}`) so builders read
  /// `props['<slot>'] as Widget?`. No slot names are known here.
  Map<String, Widget> _previewSlotWidgets(
    CanvasNode node,
    String tierName,
    double stageWidth,
    bool Function(CanvasNode) hidden,
    Set<String> ancestors,
  ) {
    if (node.slotNodes.isEmpty) return const {};
    final byId = {for (final n in widget.doc.nodes) n.id: n};
    final out = <String, Widget>{};
    for (final entry in node.slotNodes.entries) {
      final child = byId[entry.value];
      if (child == null) continue;
      if (child.screenId != node.screenId) continue;
      if (child.id == node.id || ancestors.contains(child.id)) continue;
      if (hidden(child)) continue;
      out[entry.key] = _buildPreviewNode(
        child,
        tierName,
        stageWidth,
        hidden,
        {...ancestors, node.id},
      );
    }
    return out;
  }

  /// Visible direct children of [node] for the preview tree: core
  /// [childrenOf] order (document order), same-screen only, hidden subtrees
  /// pruned, self-parents and ids already on the build path ([ancestors])
  /// excluded so corrupt cyclic docs terminate, and slot-assigned nodes
  /// withheld (slot wins — see [_slotAssignedIds]). Never reimplements
  /// traversal — filtering over the core helper.
  List<CanvasNode> _previewChildren(
    CanvasNode node,
    bool Function(CanvasNode) hidden,
    Set<String> ancestors,
  ) {
    final slotIds = _slotAssignedIds;
    return [
      for (final child in childrenOf(widget.doc, node.id))
        if (child.screenId == node.screenId &&
            child.id != node.id &&
            !ancestors.contains(child.id) &&
            !hidden(child) &&
            !slotIds.contains(child.id))
          child,
    ];
  }

  /// Whether [items] (already slot-filtered, breakpoint-merged) render
  /// children inside chrome: a non-row node whose first visible item's kind
  /// is in [kContainerKinds] (`canvas/COMPOSITION.md` §2; first-item rule
  /// documented on [kContainerKinds]).
  bool _isPreviewContainer(CanvasNode node, List<CanvasItem> items) =>
      !node.isRow &&
      items.isNotEmpty &&
      kContainerKinds.contains(items.first.kind);

  /// Recursive preview node builder (see [_stageContent]). Every level
  /// builds its items through [_previewItem] (per-level breakpoint merge via
  /// [visibleItems], per-item tap actions), so nested actions navigate and
  /// nested overrides apply exactly like roots. Node w/h pin via
  /// [applyNodeSizeValues] (same helper as the editor canvas).
  ///
  /// TRACK AA NATURAL-FILL AUDIT: node-content columns here are all
  /// `stretch` + `MainAxisSize.min` (intrinsic heights, full widths) and the
  /// only vertical [Expanded]s in this file sit in bounded chrome (the top
  /// bar's `Scaffold` column and the adaptive-nav demo's fixed stage box) —
  /// never under the unbounded stage `ListView`. Row `stretch` rides
  /// [IntrinsicHeight] (bounded by the tallest child).
  ///
  /// Track Z1 full-bleed parity: fixed-w wraps in [Align] left so the pinned
  /// [SizedBox] keeps exact pixels inside the stretch-tight list (bare
  /// SizedBox would be forced full width); auto fills via stretch columns.
  /// Track AA: top-left (canvas parity — pinned boxes ride the top naturally
  /// inside tight-height slots instead of vertically centering).
  ///
  /// Track FF3 error boundary: the whole node build is guarded — a throwing
  /// catalog builder (bad props, misbehaving widget) renders an inline
  /// [_PreviewErrorCard] for THIS node only, and siblings/ancestors still
  /// render. Unknown kinds are NOT errors (they keep the catalog's honest
  /// `unknown:` fallback); only synchronous throws are caught. Throws during
  /// layout (e.g. unbounded constraints) still surface via FlutterError.
  Widget _buildPreviewNode(
    CanvasNode node,
    String tierName,
    double stageWidth,
    bool Function(CanvasNode) hidden,
    Set<String> ancestors,
  ) {
    try {
      final inner = _buildPreviewNodeInner(
        node,
        tierName,
        stageWidth,
        hidden,
        ancestors,
      );
      if (node.w == null) return applyNodeSize(node, inner);
      return Align(
        alignment: Alignment.topLeft,
        child: applyNodeSize(node, inner),
      );
    } catch (e) {
      final firstKind =
          node.items.isEmpty ? 'empty-node' : node.items.first.kind;
      return _PreviewErrorCard(label: '${node.id} ($firstKind)', message: '$e');
    }
  }

  /// Single catalog call site for the preview tree (leaf items and container
  /// chrome alike): routes through [PreviewPlayer.debugItemBuilder] when a
  /// test sets it, else [buildCatalogItem]. Synchronous throws become an
  /// inline [_PreviewErrorCard] (see [_buildPreviewNode]) — never a blanked
  /// stage.
  Widget _catalogBuild(
    String kind,
    Map<String, dynamic> props, [
    List<Widget> children = const [],
  ]) {
    try {
      final debug = PreviewPlayer.debugItemBuilder;
      if (debug != null) return debug(kind, props, children, _session);
      return buildCatalogItem(kind, props, children, _session);
    } catch (e) {
      return _PreviewErrorCard(label: kind, message: '$e');
    }
  }

  Widget _buildPreviewNodeInner(
    CanvasNode node,
    String tierName,
    double stageWidth,
    bool Function(CanvasNode) hidden,
    Set<String> ancestors,
  ) {
    if (node.isRow) {
      return _buildPreviewRow(node, tierName, stageWidth, hidden, ancestors);
    }
    final items = visibleItems(node, tierName);
    final slots = _previewSlotWidgets(
      node,
      tierName,
      stageWidth,
      hidden,
      ancestors,
    );
    final kids = _previewChildren(node, hidden, ancestors);
    if (kids.isEmpty) {
      // Track Z1 full-bleed parity: stretch so auto nodes fill the stage
      // width (fixed-w keeps pixels via [applyNodeSize]'s SizedBox win).
      // Track AA: every item builds with this node's slotWidgets spread over
      // its props (same generic injection as the canvas renderer).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _previewItem(item, node, tierName, stageWidth, hidden, ancestors),
        ],
      );
    }
    final next = {...ancestors, node.id};
    final builtKids = [
      for (final kid in kids)
        _buildPreviewNode(kid, tierName, stageWidth, hidden, next),
    ];
    if (_isPreviewContainer(node, items)) {
      final first = items.first;
      // Track R1: container chrome resolves bindings through the session.
      // Track FF3: routed through [_catalogBuild] so a throwing container
      // builder degrades to an inline error card, never a blanked stage.
      final built = _catalogBuild(
        first.kind,
        {...first.props, ...slots},
        builtKids,
      );
      final container = first.action == null
          ? built
          : _TapCatcher(
              onTap: () => _onItemTap(first),
              child: built,
            );
      // Track Z1 full-bleed parity: container + fallback columns stretch.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          container,
          for (final item in items.skip(1))
            _previewItem(item, node, tierName, stageWidth, hidden, ancestors),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          _previewItem(item, node, tierName, stageWidth, hidden, ancestors),
        for (var i = 0; i < builtKids.length; i++) ...[
          const SizedBox(height: kFlowScreenGap),
          builtKids[i],
        ],
      ],
    );
  }

  /// One preview row: horizontal `Row` of recursively-built children (doc
  /// order, node `gap` separators, W3 alignment, [wrapRowChild] shares so
  /// kit widgets with internal `Expanded` rows never see unbounded width).
  /// `crossAxis == stretch` needs [IntrinsicHeight] (the surrounding
  /// `ListView` measures with unbounded height), mirroring the canvas
  /// renderer. An empty row renders the same empty `Column` as before.
  Widget _buildPreviewRow(
    CanvasNode node,
    String tierName,
    double stageWidth,
    bool Function(CanvasNode) hidden,
    Set<String> ancestors,
  ) {
    final next = {...ancestors, node.id};
    final kids = _previewChildren(node, hidden, ancestors);
    if (kids.isEmpty) {
      // Track Z1: empty-row placeholder column stretches (no children, but
      // keeps parity; rows themselves are unchanged).
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [],
      );
    }
    final gap = node.gap < 0 ? 0.0 : node.gap;
    final cross = rowCrossAxis(node.crossAxis);
    Widget row = Row(
      mainAxisAlignment: rowMainAxis(node.mainAxis),
      crossAxisAlignment: cross,
      children: [
        for (var i = 0; i < kids.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          wrapRowChild(
            kids[i],
            _buildPreviewNode(kids[i], tierName, stageWidth, hidden, next),
          ),
        ],
      ],
    );
    if (cross == CrossAxisAlignment.stretch) {
      row = IntrinsicHeight(child: row);
    }
    return row;
  }

  List<CanvasItem> visibleItems(CanvasNode node, String tierName) {
    var items = node.items;
    final overrides = node.breakpointValues[tierName];
    if (overrides != null && overrides.isNotEmpty) {
      items = [
        for (final item in items)
          item.copyWith(props: {...item.props, ...overrides}),
      ];
    }
    if (node.slots.isEmpty) return items;
    final named = <String>{
      for (final key in node.slots.keys)
        if (items.any((item) => item.id == key)) key,
    };
    if (named.isEmpty) return items;
    return [
      for (final item in items)
        if (named.contains(item.id)) item
    ];
  }

  /// Action-less items render bare so every gesture reaches the real widget.
  /// Track R1: bound props resolve through the preview session.
  /// Track AA: the host node's slotWidgets spread over the item props (same
  /// generic injection as the canvas renderer; Widget values pass bindings
  /// through untouched).
  /// Track FF3: routed through [_catalogBuild] (guarded — see
  /// [_buildPreviewNode]).
  Widget _previewItem(
    CanvasItem item,
    CanvasNode host,
    String tierName,
    double stageWidth,
    bool Function(CanvasNode) hidden,
    Set<String> ancestors,
  ) {
    final built = alignIntrinsicKind(
      item.kind,
      _catalogBuild(item.kind, {
        ...item.props,
        ..._previewSlotWidgets(host, tierName, stageWidth, hidden, ancestors),
      }),
    );
    if (item.action == null) return built;
    return _TapCatcher(onTap: () => _onItemTap(item), child: built);
  }
}

/// Inline per-node error card (Track FF3): a throwing catalog builder renders
/// THIS for its node while the rest of the stage still renders. Kit
/// [shadcn.Alert] (destructive) so it is token-styled in both brightnesses;
/// the title names the failing kind/node, the content carries the message.
class _PreviewErrorCard extends StatelessWidget {
  final String label;
  final String message;

  const _PreviewErrorCard({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    return shadcn.Alert.destructive(
      title: Text('Preview error: $label'),
      content: Text(message),
    );
  }
}

/// Designed stage empty state (Track FF3): kit [shadcn.EmptyState] in compact
/// size so it fits short stages, theme-aware in both brightnesses. Used for
/// zero-screen docs, zero-node screens, and fully-hidden tiers (see
/// [_PreviewPlayerState._stageContent]).
class _PreviewEmptyState extends StatelessWidget {
  final String title;
  final String description;

  const _PreviewEmptyState({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return shadcn.EmptyState(
      size: shadcn.EmptyStateSize.compact,
      title: Text(title),
      description: Text(description),
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
        if (down != null && (event.position - down).distance <= kTouchSlop) {
          widget.onTap();
        }
      },
      onPointerCancel: (event) => _downs.remove(event.pointer),
      child: widget.child,
    );
  }
}

/// Builds the adaptive-nav demo screen: the canonical responsive nav pattern
/// (LayoutBuilder; <600 → [NavigationBar] bottom, ≥600 → [NavigationRail]
/// side) as a screen preset template for later code emission. Opened from
/// the preview bar's "Responsive demo" button; it fills the device stage so
/// switching devices re-tiers it live (phone → bottom bar, tablet/desktop
/// → side rail).
Widget buildAdaptiveNavDemo() => const AdaptiveNavDemo();

/// Adaptive nav demo: 3 destinations + a body placeholder.
///
/// Selection state ([_index]) lives OUTSIDE the breakpoint branch, so the
/// active destination survives tier switches (the showcase interaction).
class AdaptiveNavDemo extends StatefulWidget {
  const AdaptiveNavDemo({super.key});

  @override
  State<AdaptiveNavDemo> createState() => _AdaptiveNavDemoState();
}

class _AdaptiveNavDemoState extends State<AdaptiveNavDemo> {
  int _index = 0;

  static const _labels = ['Home', 'Search', 'Settings'];
  static const _icons = [
    Icons.home_outlined,
    Icons.search,
    Icons.settings_outlined,
  ];
  static const _activeIcons = [Icons.home, Icons.search, Icons.settings];

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // State stays above this branch: only the nav CHROME differs per tier.
    return ResponsiveBuilder(
      builder: (context, tier, width) {
        final body = Center(
          child: Text('${_labels[_index]} body · ${tier.name}'),
        );
        if (tier == Tier.mobile) {
          return Column(
            children: [
              Expanded(child: body),
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i]),
                      selectedIcon: Icon(_activeIcons[i]),
                      label: _labels[i],
                    ),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    selectedIcon: Icon(_activeIcons[i]),
                    label: Text(_labels[i]),
                  ),
              ],
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
