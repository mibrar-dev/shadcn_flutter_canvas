/// Right-hand prompt panel, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Header row (settings, regenerate pill, collapse) above the generated
/// paste-into-AI prompt in a selectable monospace area, plus a Copy button.
library;

import 'dart:async';

import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_buttons.dart';
import 'editor_tokens.dart';

/// Regenerate pill leading icon size from the spec.
const _pillIconSize = 18.0;

/// Right aside prompt panel: regenerable [buildPrompt] output for [doc].
///
/// The generated text is cached in state and only recomputed when [doc]
/// changes identity or the pill button is tapped, since [buildPrompt] is an
/// expensive pure function. A [StateError] from [buildPrompt] (dangling
/// screen references) is rendered as an error message instead of crashing.
class PromptPanel extends StatefulWidget {
  /// Document the prompt is generated from.
  final ScreenDoc doc;

  /// Collapse callback for the trailing chevron button.
  final VoidCallback? onCollapse;

  const PromptPanel({super.key, required this.doc, this.onCollapse});

  @override
  State<PromptPanel> createState() => _PromptPanelState();
}

class _PromptPanelState extends State<PromptPanel> {
  /// Inline "Copied" confirmation lifetime.
  static const _copyReset = Duration(seconds: 2);

  /// Body text size; the reference prompt text has no type token.
  static const _bodyFontSize = 12.0;

  /// Body line height from the spec.
  static const _bodyHeight = 1.5;

  late String _text;
  late bool _isError;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _resolve(widget.doc);
  }

  @override
  void didUpdateWidget(covariant PromptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.doc, oldWidget.doc)) {
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
      _text = buildPrompt(doc);
      _isError = false;
    } on StateError catch (e) {
      _text = e.message;
      _isError = true;
    }
  }

  void _regenerate() => setState(() => _resolve(widget.doc));

  Future<void> _copy() async {
    if (_isError) return;
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(_copyReset, () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: EditorMetrics.promptPanelWidth,
      color: colors.surface,
      padding: const EdgeInsets.all(EditorMetrics.panelInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: EditorMetrics.toolbarHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                EditorIconButton(
                  icon: Icons.tune,
                  tooltip: 'Settings',
                  onPressed: () {},
                ),
                const SizedBox(width: EditorMetrics.toolbarButtonGap),
                _RegeneratePill(onTap: _regenerate),
                const SizedBox(width: EditorMetrics.toolbarButtonGap),
                EditorIconButton(
                  icon: Icons.chevron_right,
                  tooltip: 'Collapse',
                  onPressed: widget.onCollapse,
                ),
              ],
            ),
          ),
          const SizedBox(height: EditorMetrics.tileGap),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius:
                    BorderRadius.circular(EditorMetrics.tileRadius),
              ),
              padding: const EdgeInsets.all(EditorMetrics.panelInset),
              child: SingleChildScrollView(
                child: SelectableText(
                  _text,
                  style: TextStyle(
                    fontSize: _bodyFontSize,
                    height: _bodyHeight,
                    color: _isError
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontStyle:
                        _isError ? FontStyle.italic : FontStyle.normal,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: EditorMetrics.tileGap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _isError ? null : _copy,
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                ),
                child: const Text('Copy'),
              ),
              if (_copied) ...[
                const SizedBox(width: EditorMetrics.tileGap),
                Text(
                  'Copied',
                  style: EditorType.tileLabel
                      .copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Wide pill button that regenerates the prompt from the current document.
///
/// Height [EditorMetrics.toolbarHeight], fully round, filled
/// [EditorColors.surfaceContainerHigh]; mirrors the reference header pill.
class _RegeneratePill extends StatefulWidget {
  /// Called when the pill is tapped.
  final VoidCallback onTap;

  const _RegeneratePill({required this.onTap});

  @override
  State<_RegeneratePill> createState() => _RegeneratePillState();
}

class _RegeneratePillState extends State<_RegeneratePill> {
  static const _pressScale = 0.94;
  static const _pressDuration = Duration(milliseconds: 120);

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (!_pressed) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (_pressed) setState(() => _pressed = false);
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? _pressScale : 1.0,
          duration: _pressDuration,
          curve: Curves.easeOutCubic,
          child: Container(
            height: EditorMetrics.toolbarHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: EditorMetrics.tileRadius,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius:
                  BorderRadius.circular(EditorMetrics.searchRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: _pillIconSize,
                  color: colors.toolbarActive,
                ),
                const SizedBox(width: EditorMetrics.tileGap),
                Text(
                  'Prompt',
                  style: EditorType.readout
                      .copyWith(color: colors.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
