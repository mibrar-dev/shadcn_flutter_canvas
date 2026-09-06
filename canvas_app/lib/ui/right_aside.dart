/// Four-tab right aside: Design | Code | Prompt | Audit, with
/// selection-driven auto-switch (FORGE.md §1-4a — the 4-pill deviation from
/// the 2-pill reference, so Prompt/Audit keep their home).
///
/// Fills the shell-fixed 320px column (see [EditorMetrics.promptPanelWidth]).
/// Tab auto-switch rule: a non-null [RightAside.nodeId] selects the Design
/// tab, a null one selects the Prompt tab. Tapping a tab overrides the auto
/// choice until the selection changes again. The Code and Audit tabs are
/// manual-only (selection never auto-opens them); the Audit list recomputes
/// from the live doc on every store notification, so its counts stay fresh
/// with no Re-run button.
///
/// Empty-inspector hints and prompt error states live in [InspectorPanel] and
/// [PromptPanel] respectively and are not duplicated here.
library;

import 'package:canvas_app/canvas/audit.dart' as audit;
import 'package:canvas_app/canvas/canvas_store.dart' hide ChangeNotifier;
import 'package:canvas_app/canvas/component_catalog.dart' as catalog;
import 'package:canvas_app/canvas/component_registry.dart' as registry;
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/code_peek.dart';
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/prompt_panel.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

/// Right aside with Design, Code, Prompt, and Audit tabs.
///
/// The shell integrator places this in the fixed-width right column:
/// `SizedBox(width: EditorMetrics.ffInspectorWidth, child: RightAside(...))`.
/// The Design tab hosts the FF6 grouped [InspectorPanel] (collapsible
/// Layout / Style / Content / State sections); the Code tab keeps the
/// read-only [CodePeek] mount (BUILD_SPEC §9.2-5c, unchanged).
class RightAside extends StatelessWidget {
  const RightAside({
    super.key,
    required this.store,
    this.nodeId,
    this.itemId,
    this.onSelectNode,
    this.onSelectScreen,
    this.onDuplicate,
    this.onDelete,
  });

  /// Undoable editor state; forwarded to the tab bodies.
  final CanvasStore store;

  /// Selected node id; non-null auto-selects the Inspector tab.
  final String? nodeId;

  /// Selected item id within [nodeId]; passed straight to [InspectorPanel].
  final String? itemId;

  /// Audit-issue tap targets, mirroring the [LayersPanel] seam the shell
  /// already owns (`ValueChanged<String?>` collapse/setter style). A node
  /// issue taps [onSelectNode] with its node id, a screen issue taps
  /// [onSelectScreen] with its screen id; doc-level issues (oversized,
  /// coverage summary) are not tappable. Null callbacks (the shell default
  /// until its owner wires them) make taps a graceful no-op — the Audit tab
  /// still lists and counts every issue.
  final ValueChanged<String?>? onSelectNode;
  final ValueChanged<String?>? onSelectScreen;

  /// Forge SELECTED-card actions (FORGE.md §1-4e, Y5 pass-through): the
  /// inspector's Duplicate/Delete row calls these with the selected node
  /// id. The shell wires them to `store.duplicateNode`/`store.deleteNode`
  /// (Y6); null renders the row's buttons disabled.
  final ValueChanged<String>? onDuplicate;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: double.infinity,
      // FF6 grouped-properties host (BUILD_SPEC §9.2-5a): the FF side-panel
      // background token, so the inspector reads as the FlutterFlow
      // properties column under both chrome modes.
      color: colors.panelBg,
      child: _RightAsideBody(
        store: store,
        nodeId: nodeId,
        itemId: itemId,
        onSelectNode: onSelectNode,
        onSelectScreen: onSelectScreen,
        onDuplicate: onDuplicate,
        onDelete: onDelete,
      ),
    );
  }
}

/// Known component kinds for the audit's unknown-kind check: every catalog
/// kind plus every registry kind (canvas-ready builders and honest
/// placeholders alike). Computed once — both sources are fixed at compile
/// time. `lib/canvas/audit.dart` stays Flutter-free, so the surface is
/// assembled here on the UI side and passed in via `catalogKinds`.
final Set<String> _kKnownAuditKinds = {
  for (final entry in catalog.kCatalog) entry.kind,
  for (final entry in registry.kRegistry) entry.kind,
};

/// Audit-list vertical rhythm: one gap between rows and around headers.
/// NOTE: [EditorMetrics] carries no 8px token (its steps are 3/4/6/12), so
/// the rhythm lives here as a single named constant — the same compromise
/// as the inspector's own gap constant in `inspector_panel.dart`.
const double _kAuditGap = 8.0;

/// "1 error" / "2 errors" for the Audit tab tooltip legend.
String _countLabel(int count, String one, String many) =>
    count == 1 ? '1 $one' : '$count $many';

/// Forwards pure-Dart store notifications to Flutter listeners.
/// Same sanctioned `Listenable` adapter pattern as `design_canvas.dart` and
/// `inspector_panel.dart`.
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

/// Stateful inner body so [RightAside] keeps its exact stateless contract
/// while this widget owns the [_StoreRelay] lifetime and the tab-override
/// state.
class _RightAsideBody extends StatefulWidget {
  final CanvasStore store;
  final String? nodeId;
  final String? itemId;
  final ValueChanged<String?>? onSelectNode;
  final ValueChanged<String?>? onSelectScreen;
  final ValueChanged<String>? onDuplicate;
  final ValueChanged<String>? onDelete;

  const _RightAsideBody({
    required this.store,
    this.nodeId,
    this.itemId,
    this.onSelectNode,
    this.onSelectScreen,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  State<_RightAsideBody> createState() => _RightAsideBodyState();
}

class _RightAsideBodyState extends State<_RightAsideBody> {
  late final _StoreRelay _relay = _StoreRelay(widget.store);

  /// Whether a selection existed on the last build; a change clears the
  /// user's manual tab override so the auto-switch rule re-applies.
  late bool _hadSelection = widget.nodeId != null;

  /// Manual tab override from tapping the header; null means "follow the
  /// auto-switch rule".
  int? _overrideIndex;

  @override
  void didUpdateWidget(covariant _RightAsideBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasSelection = widget.nodeId != null;
    if (hasSelection != _hadSelection) {
      _hadSelection = hasSelection;
      _overrideIndex = null;
    }
  }

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
        // The audit recomputes from the live doc on every store
        // notification, so the tab counts and the list re-run automatically
        // on each doc change — no Re-run button needed.
        final issues = audit.auditDoc(
          widget.store.doc,
          catalogKinds: _kKnownAuditKinds,
        );
        var errors = 0;
        var warnings = 0;
        var infos = 0;
        for (final issue in issues) {
          switch (issue.severity) {
            case audit.AuditSeverity.error:
              errors++;
            case audit.AuditSeverity.warning:
              warnings++;
            case audit.AuditSeverity.info:
              infos++;
          }
        }
        // Tab order: 0 Design (inspector), 1 Code (code-peek), 2 Prompt,
        // 3 Audit. Auto-switch lands on Design with a selection, Prompt
        // without; Code and Audit are manual-only.
        final index = _overrideIndex ?? (widget.nodeId != null ? 0 : 2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(EditorMetrics.panelInset),
              child: _TabHeader(
                selectedIndex: index,
                onSelect: (i) => setState(() => _overrideIndex = i),
                errorCount: errors,
                warningCount: warnings,
                infoCount: infos,
              ),
            ),
            Expanded(
              child: switch (index) {
                0 => InspectorPanel(
                  store: widget.store,
                  nodeId: widget.nodeId,
                  itemId: widget.itemId,
                  onDuplicate: widget.onDuplicate,
                  onDelete: widget.onDelete,
                ),
                1 => CodePeek(
                  doc: widget.store.doc,
                  nodeId: widget.nodeId,
                  itemId: widget.itemId,
                ),
                3 => AuditPanel(
                  issues: issues,
                  onSelectNode: widget.onSelectNode,
                  onSelectScreen: widget.onSelectScreen,
                ),
                _ => PromptPanel(doc: widget.store.doc),
              },
            ),
          ],
        );
      },
    );
  }
}

/// Four-segment tab header (FORGE.md §1-4a: Design | Code | Prompt | Audit).
/// [EditorSegmented] does not fit here — it is icon-only fixed 40px squares
/// with no text labels — so this is a minimal full-width four-text-tab row
/// built from the same tokens and corner conventions (outer
/// [EditorMetrics.segmentOuterRadius], touching
/// [EditorMetrics.segmentInnerRadius], [EditorMetrics.segmentGap]).
/// Selected tab uses [EditorColors.toolbarActive] /
/// [EditorColors.onToolbarActive], matching the reference toolbar convention.
///
/// The Audit segment carries live `errors/warnings/infos` counts in its
/// label (`Audit 1/2/3`) with the legend in its tooltip — four tabs share
/// the 320px column, so the slash-compact form keeps every label on one
/// line; the tooltip spells out `1 error, 2 warnings, 3 infos`.
class _TabHeader extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final int errorCount;
  final int warningCount;
  final int infoCount;

  const _TabHeader({
    required this.selectedIndex,
    required this.onSelect,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
  });

  @override
  Widget build(BuildContext context) {
    final outer = EditorMetrics.segmentOuterRadius;
    final inner = EditorMetrics.segmentInnerRadius;
    final auditLabel = 'Audit $errorCount/$warningCount/$infoCount';
    final segments = [
      _TabSegment(
        key: const ValueKey('aside-tab-design'),
        label: 'Design',
        icon: Icons.tune,
        tooltip: 'Design',
        selected: selectedIndex == 0,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(outer),
          bottomLeft: Radius.circular(outer),
          topRight: Radius.circular(inner),
          bottomRight: Radius.circular(inner),
        ),
        onTap: () => onSelect(0),
      ),
      _TabSegment(
        key: const ValueKey('aside-tab-code'),
        label: 'Code',
        icon: Icons.code,
        tooltip: 'Code',
        selected: selectedIndex == 1,
        borderRadius: BorderRadius.all(Radius.circular(inner)),
        onTap: () => onSelect(1),
      ),
      _TabSegment(
        key: const ValueKey('aside-tab-prompt'),
        label: 'Prompt',
        icon: Icons.auto_awesome,
        tooltip: 'Prompt',
        selected: selectedIndex == 2,
        borderRadius: BorderRadius.all(Radius.circular(inner)),
        onTap: () => onSelect(2),
      ),
      _TabSegment(
        key: const ValueKey('aside-tab-audit'),
        label: auditLabel,
        icon: Icons.fact_check,
        tooltip:
            'Audit: ${_countLabel(errorCount, 'error', 'errors')}, '
            '${_countLabel(warningCount, 'warning', 'warnings')}, '
            '${_countLabel(infoCount, 'info', 'infos')}',
        selected: selectedIndex == 3,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(inner),
          bottomLeft: Radius.circular(inner),
          topRight: Radius.circular(outer),
          bottomRight: Radius.circular(outer),
        ),
        onTap: () => onSelect(3),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(width: EditorMetrics.segmentGap),
          Expanded(child: segments[i]),
        ],
      ],
    );
  }
}

class _TabSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final String tooltip;
  final bool selected;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  /// Segment glyph size; matches the icon size inside [EditorSegmented]
  /// segments (`editor_buttons.dart`), which has no [EditorMetrics] token.
  static const _tabIconSize = 20.0;

  const _TabSegment({
    super.key,
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final background =
        selected ? colors.toolbarActive : colors.surfaceContainerHigh;
    final foreground =
        selected ? colors.onToolbarActive : colors.onSurfaceVariant;
    return shadcn.Tooltip(
      tooltip: (context) =>
          shadcn.TooltipContainer(child: Text(tooltip)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: EditorMetrics.toolbarHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: borderRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: _tabIconSize, color: foreground),
              const SizedBox(width: EditorMetrics.tileGap),
              Flexible(
                child: Text(
                  label,
                  style: EditorType.readout.copyWith(color: foreground),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fourth right-aside tab: the static doc audit (UI-Check parity).
///
/// Renders precomputed [issues] (the parent body runs `auditDoc` on the
/// live doc inside its store relay, so this list re-runs automatically on
/// every doc change — there is deliberately no Re-run button) grouped by
/// severity: Errors, then Warnings, then Infos. An empty error+warning set
/// shows an `All clear` header above the info summaries.
///
/// Tapping a node issue calls [onSelectNode] with its node id; tapping a
/// screen issue calls [onSelectScreen] with its screen id (the same
/// `ValueChanged<String?>` seam style as [LayersPanel.onSelectNode]).
/// Doc-level issues carry no target and are not tappable. Null callbacks
/// make taps a no-op.
///
/// Chrome styling only: [EditorTheme]/[EditorMetrics]/[EditorType] plus kit
/// widgets (`shadcn.Card`, severity badges, kit tooltips) — no hardcoded
/// colors, no raw Material interactive widgets (taps use [GestureDetector],
/// the same precedent as [_TabSegment]).
class AuditPanel extends StatelessWidget {
  const AuditPanel({
    super.key,
    required this.issues,
    this.onSelectNode,
    this.onSelectScreen,
  });

  /// Precomputed `auditDoc` findings for the live doc, in catalog order.
  final List<audit.AuditIssue> issues;

  /// Called with the node id when a node-targeted issue is tapped.
  final ValueChanged<String?>? onSelectNode;

  /// Called with the screen id when a screen-targeted issue is tapped.
  final ValueChanged<String?>? onSelectScreen;

  /// Severity badge: error is destructive, warning secondary, info outline.
  Widget _severityBadge(audit.AuditSeverity severity) {
    return switch (severity) {
      audit.AuditSeverity.error =>
        shadcn.DestructiveBadge(child: const Text('Error')),
      audit.AuditSeverity.warning =>
        shadcn.SecondaryBadge(child: const Text('Warning')),
      audit.AuditSeverity.info =>
        shadcn.OutlineBadge(child: const Text('Info')),
    };
  }

  /// Group header text (`Errors (2)`).
  String _groupTitle(audit.AuditSeverity severity, int count) {
    final label = switch (severity) {
      audit.AuditSeverity.error => 'Errors',
      audit.AuditSeverity.warning => 'Warnings',
      audit.AuditSeverity.info => 'Infos',
    };
    return '$label ($count)';
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final errors = [
      for (final issue in issues)
        if (issue.severity == audit.AuditSeverity.error) issue,
    ];
    final warnings = [
      for (final issue in issues)
        if (issue.severity == audit.AuditSeverity.warning) issue,
    ];
    final infos = [
      for (final issue in issues)
        if (issue.severity == audit.AuditSeverity.info) issue,
    ];
    final allClear = errors.isEmpty && warnings.isEmpty;
    return ListView(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      children: [
        if (allClear)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(EditorMetrics.panelInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: _kAuditGap),
                  Text(
                    'All clear',
                    style: EditorType.sectionHeader.copyWith(
                      color: colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: _kAuditGap),
                  Text(
                    'No errors or warnings in this doc.',
                    style: EditorType.tileLabel.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        for (final group in [errors, warnings, infos])
          if (group.isNotEmpty) ...[
            shadcn.Card(
              padding: const EdgeInsets.all(EditorMetrics.panelInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _groupTitle(group.first.severity, group.length),
                    style: EditorType.sectionHeader,
                  ),
                  const SizedBox(height: _kAuditGap),
                  for (var i = 0; i < group.length; i++) ...[
                    if (i > 0) const SizedBox(height: _kAuditGap),
                    _issueRow(context, group[i], i),
                  ],
                ],
              ),
            ),
            const SizedBox(height: EditorMetrics.panelInset),
          ],
      ],
    );
  }

  /// One finding row: severity badge + message + stable check code, with a
  /// chevron when the issue has a live tap target. The row key carries the
  /// doc-order index so widget tests can address findings stably.
  Widget _issueRow(BuildContext context, audit.AuditIssue issue, int index) {
    final colors = EditorTheme.of(context);
    final nodeId = issue.nodeId;
    final screenId = issue.screenId;
    final VoidCallback? onTap = nodeId != null
        ? (onSelectNode == null ? null : () => onSelectNode!(nodeId))
        : (screenId != null && onSelectScreen != null
              ? () => onSelectScreen!(screenId)
              : null);
    return GestureDetector(
      key: ValueKey('audit-issue-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _severityBadge(issue.severity),
          const SizedBox(width: _kAuditGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.message,
                  style: EditorType.tileLabel.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: _kAuditGap / 2),
                Text(
                  issue.code,
                  style: EditorType.tileLabel.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: _kAuditGap),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}
