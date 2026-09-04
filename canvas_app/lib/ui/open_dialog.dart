/// Import-by-paste Open dialog (HANDOFF P1-7).
///
/// The toolbar `folder_open` action is inert and there is deliberately no
/// file-picker dependency: a design is imported by pasting either a full
/// share link (any text containing [kShareFragmentPrefix]) or raw doc JSON.
/// Every size and color comes from [EditorMetrics]/[EditorColors].
library;

import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/ui/editor_tokens.dart';

/// Shows the Open dialog; on successful import calls store.replaceDoc and
/// closes. Never throws.
Future<void> showOpenDialog(BuildContext context, CanvasStore store) async {
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => _OpenDialog(store: store),
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

class _OpenDialog extends StatefulWidget {
  final CanvasStore store;

  const _OpenDialog({required this.store});

  @override
  State<_OpenDialog> createState() => _OpenDialogState();
}

class _OpenDialogState extends State<_OpenDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _import() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Paste a share link or doc JSON first.');
      return;
    }
    try {
      widget.store.replaceDoc(_parseImport(_controller.text));
    } catch (e) {
      setState(() => _error = 'Could not open that input: $e');
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EditorMetrics.tileRadius),
      ),
      title: Text(
        'Open design',
        style: EditorType.sectionHeader.copyWith(color: colors.onSurface),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paste a share link or doc JSON.',
            style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: EditorMetrics.tileGap),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            style: EditorType.field.copyWith(color: colors.onSurface),
            cursorColor: colors.onSurfaceVariant,
            decoration: InputDecoration(
              hintText: 'Share link or doc JSON',
              hintStyle:
                  EditorType.field.copyWith(color: colors.onSurfaceVariant),
              filled: true,
              fillColor: colors.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(EditorMetrics.tileRadius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(EditorMetrics.tileRadius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(EditorMetrics.tileRadius),
                borderSide: BorderSide.none,
              ),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: EditorType.field.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: _import,
          child: Text(
            'Import',
            style: EditorType.field.copyWith(color: colors.onSurface),
          ),
        ),
      ],
    );
  }
}
