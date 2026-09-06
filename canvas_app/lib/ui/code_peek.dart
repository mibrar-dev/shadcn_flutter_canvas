/// Forge code-peek tab (Track Y5, FORGE.md §1-4b, §4.3).
///
/// Read-only whole-doc code viewer mounted on the right-aside Code pill: a
/// selection header (`Kind · id` — the same idiom as the inspector's
/// `_nodeShortLabel` — or `No selection`), then `buildExportSingleFile(doc)`
/// in a read-only kit surface plus Copy + Refresh buttons.
///
/// REGENERATION RULE (FORGE.md §4.3, §6.4): whole-doc single-file codegen on
/// every keystroke would jank, so the output resolves on mount (tab-open),
/// on selection change ([nodeId]/[itemId]), and on manual Refresh — never on
/// doc edits alone. A stale peek after an off-tab edit (e.g. a
/// keyboard-shortcut duplicate while the Code tab is open) waits for Refresh
/// by design. v1 is whole-doc; per-selection scoping is follow-up
/// (FORGE.md §4.3).
///
/// Chrome styling only: [EditorTheme]/[EditorMetrics]/[EditorType] plus kit
/// widgets (`shadcn.Card`, `shadcn.OutlineButton`, `shadcn.TextButton`) — no
/// hardcoded colors, no raw Material interactive widgets.
library;

import 'dart:async';

import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/export_panel.dart'
    show CopySink, buildExportSingleFile;

/// Read-only whole-doc generated-code viewer (the right-aside Code tab).
///
/// [doc] feeds the generator; [nodeId]/[itemId] feed the selection header
/// only (v1 emits whole-doc code regardless of selection). [onCopy] is the
/// clipboard sink (the `export_panel.dart` idiom); it defaults to
/// [Clipboard.setData] and is injectable in widget tests.
class CodePeek extends StatefulWidget {
  /// Document the code is generated from.
  final ScreenDoc doc;

  /// Selected node id, for the header label only.
  final String? nodeId;

  /// Selected item id within [nodeId], for the header label only.
  final String? itemId;

  /// Copy sink; defaults to the platform clipboard.
  final CopySink? onCopy;

  const CodePeek({
    super.key,
    required this.doc,
    this.nodeId,
    this.itemId,
    this.onCopy,
  });

  @override
  State<CodePeek> createState() => _CodePeekState();
}

class _CodePeekState extends State<CodePeek> {
  /// Inline "Copied" confirmation lifetime (mirrors `prompt_panel.dart`).
  static const _copyReset = Duration(seconds: 2);

  /// Code body text size/leading (mirrors `prompt_panel.dart` — the
  /// reference code text has no type token).
  static const _bodyFontSize = 12.0;
  static const _bodyHeight = 1.5;

  late String _code;
  late bool _isError;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _resolve(widget.doc);
  }

  @override
  void didUpdateWidget(covariant CodePeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Selection change regenerates (new header + fresh whole-doc code).
    // Doc-identity changes alone deliberately do NOT: the generator runs
    // on open/selection-change/Refresh only, never per keystroke
    // (FORGE.md §4.3).
    if (widget.nodeId != oldWidget.nodeId ||
        widget.itemId != oldWidget.itemId) {
      _resolve(widget.doc);
      _copyTimer?.cancel();
      _copied = false;
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _resolve(ScreenDoc doc) {
    try {
      _code = buildExportSingleFile(doc);
      _isError = false;
    } on StateError catch (e) {
      _code = e.message;
      _isError = true;
    } catch (e) {
      _code = 'Could not build the file: $e';
      _isError = true;
    }
  }

  void _refresh() => setState(() => _resolve(widget.doc));

  Future<void> _copy() async {
    if (_isError) return;
    try {
      await (widget.onCopy ??
          (String s) => Clipboard.setData(ClipboardData(text: s)))(_code);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(_copyReset, () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  /// Selection header label: the inspector's `<Kind> · <id>` idiom resolved
  /// against [doc] (item kind when [itemId] hits, else the node's first
  /// item kind, else the row/empty fallback), or `No selection` when nothing
  /// (or a stale id) is selected.
  String _selectionLabel(ScreenDoc doc, String? nodeId, String? itemId) {
    String titleOf(String kind) {
      if (kind.isEmpty) return 'Empty';
      return '${kind[0].toUpperCase()}${kind.substring(1)}';
    }

    if (nodeId == null) return 'No selection';
    for (final node in doc.nodes) {
      if (node.id != nodeId) continue;
      if (node.isRow) return 'Row · ${node.id}';
      if (itemId != null) {
        for (final item in node.items) {
          if (item.id == itemId) return '${titleOf(item.kind)} · ${node.id}';
        }
      }
      if (node.items.isEmpty) return 'Empty · ${node.id}';
      return '${titleOf(node.items.first.kind)} · ${node.id}';
    }
    return 'No selection';
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final emptyDoc = widget.doc.screens.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _selectionLabel(widget.doc, widget.nodeId, widget.itemId),
            key: const ValueKey('code-peek-selection'),
            style: EditorType.readout.copyWith(color: colors.onSurface),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: EditorMetrics.tileGap),
          if (emptyDoc)
            Expanded(
              child: Center(
                child: Text(
                  'Nothing to export yet — add a screen first.',
                  key: const ValueKey('code-peek-empty'),
                  style: EditorType.tileLabel.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: shadcn.Card(
                padding: const EdgeInsets.all(EditorMetrics.panelInset),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _code,
                    key: const ValueKey('code-peek-code'),
                    style: TextStyle(
                      fontSize: _bodyFontSize,
                      height: _bodyHeight,
                      color:
                          _isError ? colors.onSurface : colors.onSurfaceVariant,
                      fontStyle: _isError ? FontStyle.italic : FontStyle.normal,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          if (!emptyDoc) ...[
            const SizedBox(height: EditorMetrics.tileGap),
            Row(
              children: [
                shadcn.OutlineButton(
                  key: const ValueKey('code-peek-refresh'),
                  size: shadcn.ButtonSize.small,
                  onPressed: _refresh,
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: EditorMetrics.tileGap),
                shadcn.TextButton(
                  key: const ValueKey('code-peek-copy'),
                  onPressed: _isError ? null : _copy,
                  child: const Text('Copy'),
                ),
                if (_copied) ...[
                  const SizedBox(width: EditorMetrics.tileGap),
                  Text(
                    'Copied',
                    style: EditorType.tileLabel.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
