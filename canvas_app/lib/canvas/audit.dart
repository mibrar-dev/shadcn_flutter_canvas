/// Static doc audit: the canvas trust layer (Android-Studio-UI-Check parity).
///
/// Android Studio ships no drag-and-drop builder for Compose — production
/// confidence comes from preview + Layout Inspector + UI Check
/// (accessibility/adaptive audits). This file is the canvas equivalent: pure
/// static analysis over [ScreenDoc] that says what is broken or risky. No
/// runtime hooks needed; every check is deterministic (same doc in, same
/// issues out — no I/O, no randomness, no wall-clock).
///
/// Pure Dart, zero Flutter imports — same constraint as the rest of
/// `lib/canvas/` (the file compiles for the CLI). The UI lives in
/// `lib/ui/right_aside.dart` (Audit tab), which passes the known-kind
/// surface in via [catalogKinds] because the catalog/registry themselves are
/// Flutter-side and cannot be imported here.
///
/// Check catalog (code → what it flags, severity):
///
/// | code | severity | flags |
/// |---|---|---|
/// | `dangling-action` | error | tap actions pointing at missing screens. Reuses [ScreenDoc.validateRefs] semantics — that method is CALLED, not reimplemented; each returned string becomes one issue (message verbatim, so its stable format stays exact-match testable), enriched with the owning node/screen ids by lookup. Actions to deleted screens are covered here — there is deliberately no second action check. |
/// | `unknown-kind` | warning | item kinds absent from [catalogKinds]. Skipped entirely when [catalogKinds] is null (no known-kind surface provided). Registry placeholder kinds are "known" — only truly-unknown kinds flag (they render as placeholders and export `TODO`s). |
/// | `hidden-everywhere` | warning | nodes whose `hiddenOn` covers every tier in [kResponsiveTiers] — pruned to `SizedBox.shrink()` at every viewport, so they never render. |
/// | `empty-screen` | warning | screens with zero nodes. |
/// | `empty-node` | warning | non-row nodes with zero items (rows are structural containers that legitimately carry no items, so they are excluded — otherwise every row would flag). |
/// | `duplicate-screen-name` | warning | screens sharing a name with an earlier screen in screen order (exact, case-sensitive match — `'Home'` vs `'home'` are distinct, mirroring the id-keyed codegen which never confuses them). Only the 2nd+ occurrences flag. |
/// | `hidden-override` | warning | responsive sanity: `breakpointValues` entries keyed by a tier that is also in `hiddenOn` — per-tier overrides that can never render (stale after hiding). |
/// | `oversized-doc` | warning/error | doc scale: warning past [kAuditLargeDocNodes] nodes, error past [kAuditHugeDocNodes]. Rationale: every canvas pass (render, preview rebuild, codegen, this audit) is linear in node count; past ~100 nodes the layers/audit lists and preview rebuilds get sluggish on low-end web, and past ~300 the export becomes hard to review — usually a sign the doc should split across screens. Static heuristic, not a measurement. Triggers when the count EXCEEDS the threshold (boundary counts are clean). |
/// | `tap-coverage` | info | summary, always emitted exactly once and always last: `X/Y items have tap actions (Z%)` (percent rounded to the nearest integer; `0/0` when the doc has no items). A clean doc still reports its coverage — that is the point of a summary. |
///
/// Ordering: grouped by check in the table order above, document order
/// (nodes) / screen order (screens) within a check. At most one
/// `oversized-doc` and exactly one `tap-coverage` per run.
library;

import 'package:canvas_core/canvas_core.dart';

/// Finding severity: errors break navigation/rendering, warnings mark risky
/// or dead content, infos summarize.
enum AuditSeverity { error, warning, info }

/// One audit finding.
///
/// [code] is one of the check-catalog codes documented above (stable —
/// panel tests and the Audit tab key off it). [message] is human-readable
/// and names the offending ids. [nodeId]/[screenId] locate the finding for
/// tap-to-select; both null for doc-level issues (`oversized-doc`,
/// `tap-coverage`).
class AuditIssue {
  final AuditSeverity severity;
  final String code;
  final String message;
  final String? nodeId;
  final String? screenId;

  const AuditIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.nodeId,
    this.screenId,
  });

  @override
  bool operator ==(Object other) =>
      other is AuditIssue &&
      other.severity == severity &&
      other.code == code &&
      other.message == message &&
      other.nodeId == nodeId &&
      other.screenId == screenId;

  @override
  int get hashCode => Object.hash(severity, code, message, nodeId, screenId);

  @override
  String toString() =>
      'AuditIssue(${severity.name}, $code, $message, node=$nodeId, screen=$screenId)';
}

/// Node count past which a doc earns an `oversized-doc` warning.
/// See the check-catalog rationale above.
const int kAuditLargeDocNodes = 100;

/// Node count past which a doc earns an `oversized-doc` error.
/// See the check-catalog rationale above.
const int kAuditHugeDocNodes = 300;

/// Runs every check in the catalog above over [doc].
///
/// [catalogKinds] is the caller-provided known-kind surface (catalog ∪
/// registry); null skips the `unknown-kind` check.
List<AuditIssue> auditDoc(ScreenDoc doc, {Set<String>? catalogKinds}) {
  final issues = <AuditIssue>[
    ..._danglingActionIssues(doc),
    if (catalogKinds != null) ..._unknownKindIssues(doc, catalogKinds),
    ..._hiddenEverywhereIssues(doc),
    ..._hiddenOverrideIssues(doc),
    ..._emptyNodeIssues(doc),
    ..._emptyScreenIssues(doc),
    ..._duplicateScreenNameIssues(doc),
    ..._oversizedDocIssues(doc),
    _tapCoverageIssue(doc),
  ];
  return issues;
}

/// `dangling-action`: one error per [ScreenDoc.validateRefs] finding.
///
/// The ref-integrity semantics live in `validateRefs` — this check calls it
/// and only enriches: each stable message string
/// (`dangling action <item> -> missing screen <to>`) is parsed back to its
/// item id and attributed to the owning node/screen. A finding is never
/// dropped when attribution fails (unparseable message or unknown item):
/// it is still reported with null ids.
List<AuditIssue> _danglingActionIssues(ScreenDoc doc) {
  final owner = <String, (String, String)>{};
  for (final node in doc.nodes) {
    for (final item in node.items) {
      owner.putIfAbsent(item.id, () => (node.id, node.screenId));
    }
  }
  final pattern = RegExp(r'^dangling action (\S+) -> missing screen (\S+)$');
  final issues = <AuditIssue>[];
  for (final message in doc.validateRefs()) {
    final ownerOf = owner[pattern.firstMatch(message)?.group(1)];
    issues.add(
      AuditIssue(
        severity: AuditSeverity.error,
        code: 'dangling-action',
        message: message,
        nodeId: ownerOf?.$1,
        screenId: ownerOf?.$2,
      ),
    );
  }
  return issues;
}

/// `unknown-kind`: one warning per item whose kind is outside [catalogKinds].
List<AuditIssue> _unknownKindIssues(ScreenDoc doc, Set<String> catalogKinds) {
  return [
    for (final node in doc.nodes)
      for (final item in node.items)
        if (!catalogKinds.contains(item.kind))
          AuditIssue(
            severity: AuditSeverity.warning,
            code: 'unknown-kind',
            message:
                'Unknown kind "${item.kind}" (node ${node.id}, item ${item.id}): '
                'not in the catalog or registry; renders a placeholder.',
            nodeId: node.id,
            screenId: node.screenId,
          ),
  ];
}

/// `hidden-everywhere`: one warning per node hidden on every known tier.
List<AuditIssue> _hiddenEverywhereIssues(ScreenDoc doc) {
  return [
    for (final node in doc.nodes)
      if (node.hiddenOn.containsAll(kResponsiveTiers))
        AuditIssue(
          severity: AuditSeverity.warning,
          code: 'hidden-everywhere',
          message: 'Node ${node.id} is hidden on all tiers '
              '(${(node.hiddenOn.toList()..sort()).join(', ')}) '
              'and never renders.',
          nodeId: node.id,
          screenId: node.screenId,
        ),
  ];
}

/// `hidden-override`: one warning per node whose per-tier overrides target
/// a tier it is hidden on.
List<AuditIssue> _hiddenOverrideIssues(ScreenDoc doc) {
  return [
    for (final node in doc.nodes)
      if (node.breakpointValues.keys
          .toSet()
          .intersection(node.hiddenOn)
          .isNotEmpty)
        AuditIssue(
          severity: AuditSeverity.warning,
          code: 'hidden-override',
          message: 'Node ${node.id} hides tier(s) '
              '${((node.breakpointValues.keys.toSet().intersection(node.hiddenOn)).toList()..sort()).join(', ')} '
              'but still carries breakpoint overrides for them; '
              'the overrides never render.',
          nodeId: node.id,
          screenId: node.screenId,
        ),
  ];
}

/// `empty-node`: one warning per non-row node with zero items.
/// Rows are structural containers — excluding them keeps every row from
/// flagging by design.
List<AuditIssue> _emptyNodeIssues(ScreenDoc doc) {
  return [
    for (final node in doc.nodes)
      if (!node.isRow && node.items.isEmpty)
        AuditIssue(
          severity: AuditSeverity.warning,
          code: 'empty-node',
          message: 'Node ${node.id} has no items and renders nothing.',
          nodeId: node.id,
          screenId: node.screenId,
        ),
  ];
}

/// `empty-screen`: one warning per screen with zero nodes.
List<AuditIssue> _emptyScreenIssues(ScreenDoc doc) {
  final counts = <String, int>{};
  for (final node in doc.nodes) {
    counts[node.screenId] = (counts[node.screenId] ?? 0) + 1;
  }
  return [
    for (final screen in doc.screens)
      if ((counts[screen.id] ?? 0) == 0)
        AuditIssue(
          severity: AuditSeverity.warning,
          code: 'empty-screen',
          message: 'Screen "${screen.name}" (${screen.id}) has no nodes.',
          screenId: screen.id,
        ),
  ];
}

/// `duplicate-screen-name`: one warning per screen whose name repeats an
/// earlier screen's (exact, case-sensitive).
List<AuditIssue> _duplicateScreenNameIssues(ScreenDoc doc) {
  final seen = <String>{};
  return [
    for (final screen in doc.screens)
      if (!seen.add(screen.name))
        AuditIssue(
          severity: AuditSeverity.warning,
          code: 'duplicate-screen-name',
          message:
              'Duplicate screen name "${screen.name}" (screen ${screen.id}).',
          screenId: screen.id,
        ),
  ];
}

/// `oversized-doc`: at most one finding — error past [kAuditHugeDocNodes],
/// warning past [kAuditLargeDocNodes], none at or below the thresholds.
List<AuditIssue> _oversizedDocIssues(ScreenDoc doc) {
  final count = doc.nodes.length;
  if (count > kAuditHugeDocNodes) {
    return [
      AuditIssue(
        severity: AuditSeverity.error,
        code: 'oversized-doc',
        message: 'Doc has $count nodes (over $kAuditHugeDocNodes): preview '
            'rebuilds and exports get slow and hard to review; '
            'consider splitting screens.',
      ),
    ];
  }
  if (count > kAuditLargeDocNodes) {
    return [
      AuditIssue(
        severity: AuditSeverity.warning,
        code: 'oversized-doc',
        message: 'Doc has $count nodes (over $kAuditLargeDocNodes): canvas '
            'interactions and preview rebuilds slow down; '
            'consider splitting screens.',
      ),
    ];
  }
  return const [];
}

/// `tap-coverage`: the info summary — always exactly one, always last.
AuditIssue _tapCoverageIssue(ScreenDoc doc) {
  var total = 0;
  var withAction = 0;
  for (final node in doc.nodes) {
    for (final item in node.items) {
      total++;
      if (item.action != null) withAction++;
    }
  }
  if (total == 0) {
    return const AuditIssue(
      severity: AuditSeverity.info,
      code: 'tap-coverage',
      message: 'Tap coverage: no items yet (0/0).',
    );
  }
  final percent = ((100 * withAction) / total).round();
  return AuditIssue(
    severity: AuditSeverity.info,
    code: 'tap-coverage',
    message:
        'Tap coverage: $withAction/$total items have tap actions ($percent%).',
  );
}
