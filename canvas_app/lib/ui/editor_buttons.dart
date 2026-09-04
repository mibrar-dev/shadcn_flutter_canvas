/// Shared editor-chrome button primitives, measured from the m3e-canvas
/// reference (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Provides [EditorIconButton] and [EditorSegmented] used by the floating
/// toolbar and zoom controls.
library;

import 'package:flutter/material.dart';

import 'editor_tokens.dart';

/// One entry in an [EditorSegmented] control.
@immutable
class EditorSegmentItem {
  /// Icon shown for this segment.
  final IconData icon;

  /// Tooltip announced on hover / long-press.
  final String tooltip;

  const EditorSegmentItem({required this.icon, required this.tooltip});
}

/// Round icon button used across the editor chrome.
///
/// 40x40 by default ([EditorMetrics.toolbarButtonSize]), fully round, icon at
/// size 20. Transparent by default with a [EditorColors.surfaceContainerHigh]
/// fill on hover. Press scales to 0.94 over 120ms
/// (`Curves.easeOutCubic`, mirrors the reference `.m3-press` class).
/// A null [onPressed] renders the icon in [EditorColors.disabled] and
/// disables taps.
class EditorIconButton extends StatefulWidget {
  /// Icon glyph to show.
  final IconData icon;

  /// Tap handler. Null means disabled.
  final VoidCallback? onPressed;

  /// Optional tooltip message.
  final String? tooltip;

  /// Optional background override. Defaults to transparent / hover fill.
  final Color? background;

  /// Optional foreground override. Defaults to [EditorColors.onSurfaceVariant].
  final Color? foreground;

  /// Button box size (width = height). Defaults to toolbar button size.
  final double size;

  const EditorIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.background,
    this.foreground,
    this.size = EditorMetrics.toolbarButtonSize,
  });

  @override
  State<EditorIconButton> createState() => _EditorIconButtonState();
}

class _EditorIconButtonState extends State<EditorIconButton> {
  static const _pressScale = 0.94;
  static const _pressDuration = Duration(milliseconds: 120);
  static const _iconSize = 20.0;

  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final enabled = widget.onPressed != null;
    final Color effectiveBackground =
        widget.background ??
        (enabled && _hovered ? colors.surfaceContainerHigh : Colors.transparent);
    final Color effectiveForeground = !enabled
        ? colors.disabled
        : (widget.foreground ?? colors.onSurfaceVariant);

    Widget button = MouseRegion(
      onEnter: (_) {
        if (enabled && !_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (enabled && !_pressed) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (_pressed) setState(() => _pressed = false);
        },
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: enabled && _pressed ? _pressScale : 1.0,
          duration: _pressDuration,
          curve: Curves.easeOutCubic,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: effectiveBackground,
              borderRadius: BorderRadius.circular(widget.size / 2),
            ),
            child: Icon(
              widget.icon,
              size: _iconSize,
              color: effectiveForeground,
            ),
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

/// Segmented select/pan-style control from the reference toolbar.
///
/// Segments are [EditorMetrics.toolbarButtonSize] squares with a
/// [EditorMetrics.segmentGap] gap. Outer corners use
/// [EditorMetrics.segmentOuterRadius], touching corners use
/// [EditorMetrics.segmentInnerRadius]. The selected segment uses
/// [EditorColors.toolbarActive] / [EditorColors.onToolbarActive]; the rest use
/// [EditorColors.surfaceContainerHigh] / [EditorColors.onSurfaceVariant].
/// Supports two or more items generically.
class EditorSegmented extends StatelessWidget {
  /// Segments to display (minimum two).
  final List<EditorSegmentItem> items;

  /// Index of the currently selected segment.
  final int selectedIndex;

  /// Called with the tapped segment index.
  final ValueChanged<int> onSelect;

  const EditorSegmented({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  }) : assert(items.length >= 2, 'EditorSegmented needs at least two items');

  BorderRadius _radiusFor(int index) {
    final outer = EditorMetrics.segmentOuterRadius;
    final inner = EditorMetrics.segmentInnerRadius;
    final isFirst = index == 0;
    final isLast = index == items.length - 1;
    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? outer : inner),
      bottomLeft: Radius.circular(isFirst ? outer : inner),
      topRight: Radius.circular(isLast ? outer : inner),
      bottomRight: Radius.circular(isLast ? outer : inner),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: EditorMetrics.segmentGap),
          _SegmentButton(
            item: items[i],
            selected: i == selectedIndex,
            borderRadius: _radiusFor(i),
            onTap: () => onSelect(i),
          ),
        ],
      ],
    );
  }
}

class _SegmentButton extends StatefulWidget {
  final EditorSegmentItem item;
  final bool selected;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.item,
    required this.selected,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  State<_SegmentButton> createState() => _SegmentButtonState();
}

class _SegmentButtonState extends State<_SegmentButton> {
  static const _pressScale = 0.94;
  static const _pressDuration = Duration(milliseconds: 120);
  static const _iconSize = 20.0;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final background =
        widget.selected ? colors.toolbarActive : colors.surfaceContainerHigh;
    final foreground = widget.selected
        ? colors.onToolbarActive
        : colors.onSurfaceVariant;

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
          child: Tooltip(
            message: widget.item.tooltip,
            child: Container(
              width: EditorMetrics.toolbarButtonSize,
              height: EditorMetrics.toolbarButtonSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: widget.borderRadius,
              ),
              child: Icon(
                widget.item.icon,
                size: _iconSize,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
