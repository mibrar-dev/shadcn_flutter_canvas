/// Two-tab right aside: Inspector | Prompt with selection-driven auto-switch.
///
/// Fills the shell-fixed 320px column (see [EditorMetrics.promptPanelWidth]).
/// Tab auto-switch rule: a non-null [RightAside.nodeId] selects the Inspector
/// tab, a null one selects the Prompt tab. Tapping a tab overrides the auto
/// choice until the selection changes again.
///
/// Empty-inspector hints and prompt error states live in [InspectorPanel] and
/// [PromptPanel] respectively and are not duplicated here.
library;

import 'package:canvas_app/canvas/canvas_store.dart' hide ChangeNotifier;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/inspector_panel.dart';
import 'package:canvas_app/ui/prompt_panel.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

/// Right aside with Inspector and Prompt tabs.
///
/// The shell integrator places this in the fixed-width right column:
/// `SizedBox(width: EditorMetrics.promptPanelWidth, child: RightAside(...))`.
class RightAside extends StatelessWidget {
  const RightAside({super.key, required this.store, this.nodeId, this.itemId});

  /// Undoable editor state; forwarded to both tab bodies.
  final CanvasStore store;

  /// Selected node id; non-null auto-selects the Inspector tab.
  final String? nodeId;

  /// Selected item id within [nodeId]; passed straight to [InspectorPanel].
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: double.infinity,
      color: colors.surface,
      child: _RightAsideBody(store: store, nodeId: nodeId, itemId: itemId),
    );
  }
}

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

  const _RightAsideBody({
    required this.store,
    this.nodeId,
    this.itemId,
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
        final index = _overrideIndex ?? (widget.nodeId != null ? 0 : 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(EditorMetrics.panelInset),
              child: _TabHeader(
                selectedIndex: index,
                onSelect: (i) => setState(() => _overrideIndex = i),
              ),
            ),
            Expanded(
              child: index == 0
                  ? InspectorPanel(
                      store: widget.store,
                      nodeId: widget.nodeId,
                      itemId: widget.itemId,
                    )
                  : PromptPanel(doc: widget.store.doc),
            ),
          ],
        );
      },
    );
  }
}

/// Two-segment tab header. [EditorSegmented] does not fit here — it is
/// icon-only fixed 40px squares with no text labels — so this is a minimal
/// full-width two-text-tab row built from the same tokens and corner
/// conventions (outer [EditorMetrics.segmentOuterRadius], touching
/// [EditorMetrics.segmentInnerRadius], [EditorMetrics.segmentGap]).
/// Selected tab uses [EditorColors.toolbarActive] /
/// [EditorColors.onToolbarActive], matching the reference toolbar convention.
class _TabHeader extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _TabHeader({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final outer = EditorMetrics.segmentOuterRadius;
    final inner = EditorMetrics.segmentInnerRadius;
    return Row(
      children: [
        Expanded(
          child: _TabSegment(
            label: 'Inspector',
            icon: Icons.tune,
            tooltip: 'Inspector',
            selected: selectedIndex == 0,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(outer),
              bottomLeft: Radius.circular(outer),
              topRight: Radius.circular(inner),
              bottomRight: Radius.circular(inner),
            ),
            onTap: () => onSelect(0),
          ),
        ),
        const SizedBox(width: EditorMetrics.segmentGap),
        Expanded(
          child: _TabSegment(
            label: 'Prompt',
            icon: Icons.auto_awesome,
            tooltip: 'Prompt',
            selected: selectedIndex == 1,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(inner),
              bottomLeft: Radius.circular(inner),
              topRight: Radius.circular(outer),
              bottomRight: Radius.circular(outer),
            ),
            onTap: () => onSelect(1),
          ),
        ),
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
    return Tooltip(
      message: tooltip,
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
              Text(
                label,
                style: EditorType.readout.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
