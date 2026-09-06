/// Import-by-paste Open dialog (HANDOFF P1-7), extended by Track R2 with
/// project-file affordances: save-to-file, load-from-file (web), and
/// "New from template" starters.
///
/// The toolbar `folder_open` action opens this dialog. A design is imported
/// by pasting either a full share link (any text containing
/// [kShareFragmentPrefix]) or raw doc JSON; on web builds a `.json` file can
/// be picked instead (the file text flows through the SAME [_parseImport]
/// path — extended, not forked). Every size and color comes from
/// [EditorMetrics]/[EditorColors].
library;

import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/export_panel.dart';

/// Shows the Open dialog; on successful import calls store.replaceDoc and
/// closes. Never throws.
///
/// The R2 sinks are injectable for tests (defaults: web Blob download /
/// web file picker); [onConfirmReplace] defaults to [confirmReplaceDoc].
Future<void> showOpenDialog(
  BuildContext context,
  CanvasStore store, {
  DownloadSink? onDownload,
  PickFileSink? onPickFile,
  ConfirmReplace? onConfirmReplace,
  bool? isWebOverride,
}) async {
  try {
    await shadcn.showDialog<void>(
      context: context,
      builder: (_) => OpenDialog(
        store: store,
        onDownload: onDownload,
        onPickFile: onPickFile,
        onConfirmReplace: onConfirmReplace,
        isWebOverride: isWebOverride,
      ),
    );
  } catch (_) {
    // Dialog presentation must never throw to the toolbar caller.
  }
}

/// Parses pasted import text: share-link [decode] first (extracting the
/// `#d=...` fragment when a full link was pasted), then raw doc JSON via
/// [ScreenDoc.fromJson]. Throws on bad input; the dialog renders it inline.
ScreenDoc _parseImport(String text) {
  final trimmed = text.trim();
  final at = trimmed.indexOf(kShareFragmentPrefix);
  try {
    return decode(at < 0 ? trimmed : trimmed.substring(at));
  } catch (_) {
    // Not a valid share link — fall through to raw doc JSON.
  }
  return ScreenDoc.fromJson(jsonDecode(trimmed) as Map<String, dynamic>);
}

class OpenDialog extends StatefulWidget {
  final CanvasStore store;

  /// Download sink for save-to-file; same default/guard as [ExportDialog].
  final DownloadSink? onDownload;

  /// File-picker sink for load-from-file; defaults to [pickTextFile].
  final PickFileSink? onPickFile;

  /// Destructive-replace confirmation; defaults to [confirmReplaceDoc].
  final ConfirmReplace? onConfirmReplace;

  /// Overrides [kIsWeb] (tests run on the VM, where web is always false).
  final bool? isWebOverride;

  const OpenDialog({
    super.key,
    required this.store,
    this.onDownload,
    this.onPickFile,
    this.onConfirmReplace,
    this.isWebOverride,
  });

  @override
  State<OpenDialog> createState() => _OpenDialogState();
}

class _OpenDialogState extends State<OpenDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  String? _notice;

  bool get _isWeb => widget.isWebOverride ?? kIsWeb;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _import() {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        _error = 'Paste a share link or doc JSON first.';
        _notice = null;
      });
      return;
    }
    try {
      widget.store.replaceDoc(_parseImport(_controller.text));
    } catch (e) {
      setState(() {
        _error = 'Could not open that input: $e';
        _notice = null;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Shared import tail for picked files: same [_parseImport] as paste.
  void _importText(String text) {
    try {
      widget.store.replaceDoc(_parseImport(text));
    } catch (e) {
      setState(() {
        _error = 'Could not open that file: $e';
        _notice = null;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _loadFromFile() async {
    if (!_isWeb) {
      setState(() {
        _error = null;
        _notice = kNonWebDownloadMessage;
      });
      return;
    }
    late final String? text;
    try {
      text = await (widget.onPickFile ?? pickTextFile)();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not read that file: $e';
          _notice = null;
        });
      }
      return;
    }
    if (text == null) return; // Picker cancelled — stay open, stay silent.
    if (mounted) _importText(text);
  }

  Future<void> _saveToFile() async {
    if (!_isWeb) {
      setState(() {
        _error = null;
        _notice = kNonWebDownloadMessage;
      });
      return;
    }
    final doc = widget.store.doc;
    final filename = exportFileName(title: doc.meta.title, extension: 'json');
    try {
      await (widget.onDownload ?? downloadBytes)(
        utf8.encode(docJsonText(doc)),
        filename,
        kTextMimeType,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not save that file: $e';
          _notice = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _error = null;
        _notice = 'Saved $filename';
      });
    }
  }

  Future<void> _newFromTemplate(String name) async {
    final confirmed = await (widget.onConfirmReplace ?? confirmReplaceDoc)(
      context,
      name,
    );
    if (!confirmed) return; // Denied or dismissed — stay open, stay silent.
    if (mounted) {
      widget.store.replaceDoc(templateBuilders[name]!());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    // Gallery entries resolve their description + counts from the built doc
    // (meta.brief), so the cards can never drift from the templates.
    final templates = <String, ScreenDoc>{
      for (final entry in templateBuilders.entries) entry.key: entry.value(),
    };
    return shadcn.AlertDialog(
      title: Text(
        'Open design',
        style: EditorType.sectionHeader.copyWith(color: colors.onSurface),
      ),
      content: ConstrainedBox(
        // The kit dialog caps width (560) but not height: bound the scroll
        // region to a viewport fraction so the gallery scrolls instead of
        // overflowing short screens (a ratio, not a fixed pixel budget).
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste a share link or doc JSON.',
                style:
                    EditorType.field.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: EditorMetrics.tileGap),
              shadcn.TextField(
                controller: _controller,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                style: EditorType.field.copyWith(color: colors.onSurface),
                cursorColor: colors.onSurfaceVariant,
                placeholder: Text(
                  'Share link or doc JSON',
                  style:
                      EditorType.field.copyWith(color: colors.onSurfaceVariant),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: EditorMetrics.tileGap),
                Text(
                  _error!,
                  style: EditorType.field.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (_notice != null) ...[
                const SizedBox(height: EditorMetrics.tileGap),
                Text(
                  _notice!,
                  style:
                      EditorType.field.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: EditorMetrics.tileGap),
              Row(
                children: [
                  shadcn.TextButton(
                    onPressed: _loadFromFile,
                    child: const Text('Load from file…'),
                  ),
                  shadcn.TextButton(
                    onPressed: _saveToFile,
                    child: const Text('Save to file'),
                  ),
                ],
              ),
              const SizedBox(height: EditorMetrics.tileGap),
              Text(
                'Templates',
                style:
                    EditorType.sectionHeader.copyWith(color: colors.onSurface),
              ),
              Text(
                'New from template (replaces the current design).',
                style:
                    EditorType.field.copyWith(color: colors.onSurfaceVariant),
              ),
              if (templates.isEmpty)
                Text(
                  'No templates available.',
                  style:
                      EditorType.field.copyWith(color: colors.onSurfaceVariant),
                ),
              for (final entry in templates.entries)
                Padding(
                  padding: const EdgeInsets.only(top: EditorMetrics.tileGap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: shadcn.TextButton(
                      onPressed: () => _newFromTemplate(entry.key),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key),
                          Text(
                            '${entry.value.meta.brief} '
                            '(${entry.value.screens.length} screens · '
                            '${entry.value.nodes.length} nodes)',
                            style: EditorType.field.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        shadcn.TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        shadcn.TextButton(
          onPressed: _import,
          child: const Text('Import'),
        ),
      ],
    );
  }
}
