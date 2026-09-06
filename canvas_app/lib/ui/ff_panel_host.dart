/// Rail → panel switching host (Track FF2, BUILD_SPEC §9.1-2b, §9.3 FF2).
///
/// Renders the shell-owned panel for the selected [FfRailDestination] in a
/// ~280px column: a group header (destination label in
/// [EditorColors.groupHeaderFg]) over an [IndexedStack] so inactive panels
/// keep their state (scroll position, search query) while hidden.
///
/// Stateless vs the store, like [FfNavRail]: panels arrive as prebuilt
/// widgets and the selection as a prop — the widget never imports the store,
/// so it is widget-testable without a shell. Destinations without a panel
/// render an empty box (the Assets v1 stub lands here at FF4 time).
///
/// Token rule: chrome reads [EditorColors]/[EditorMetrics]/[EditorType]
/// only — no hex literals, no magic numbers (structure/callbacks are tested,
/// not pixels, per §12 rule 4).
library;

import 'package:flutter/material.dart';

import 'editor_tokens.dart';
import 'ff_nav_rail.dart';

/// Rail-switched panel column. See the library doc for the data flow.
class FfPanelHost extends StatelessWidget {
  /// Currently selected destination (shell-owned, mirrors [FfNavRail]).
  final FfRailDestination selected;

  /// Prebuilt panel per destination. Missing destinations render empty.
  final Map<FfRailDestination, Widget> panels;

  const FfPanelHost({
    super.key,
    required this.selected,
    required this.panels,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Container(
      width: EditorMetrics.ffPanelWidth,
      decoration: BoxDecoration(
        color: colors.panelBg,
        border: Border(
          right: BorderSide(color: colors.surfaceContainerHigh),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(EditorMetrics.panelInset),
            child: Text(
              selected.label,
              style: EditorType.sectionHeader.copyWith(
                color: colors.groupHeaderFg,
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: selected.index,
              children: [
                for (final destination in FfRailDestination.values)
                  panels[destination] ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
