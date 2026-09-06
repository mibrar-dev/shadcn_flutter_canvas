/// Searchable sectioned parts palette, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Uses [EditorMetrics] / [EditorColors] for every size and color.
/// Tiles source from [kRegistry] (grouped by [kRegistrySectionOrder]) and
/// stay draggable by kind, so drop/drop-target behavior is unchanged.
///
/// Track FF4 (BUILD_SPEC §9.2 row 3b): FlutterFlow-style list rows — one
/// full-width row per kind (small preview affordance + kind name) with the
/// "Layout Primitives" section first. The DnD payload contract
/// (`Draggable<String>` data = kind) and the search behavior
/// ([registryMatchesQuery] word-start matching) are unchanged.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';

/// Legacy section map from the 19-kind era (section → kinds). The palette
/// widget now renders from [kRegistry] via [registrySectionEntries];
/// retained for API compatibility.
const Map<String, List<String>> kPartSections = <String, List<String>>{
  'Components': <String>[
    'button',
    'card',
    'input',
    'badge',
    'switch',
    'avatar',
    'checkbox',
    'divider',
    'progress',
    'tabs',
    'accordion',
    'select',
    'radio_group',
    'skeleton',
    'breadcrumb',
    'dialog',
    'tooltip',
    'toast',
    'drawer',
  ],
  'Layout': <String>[
    'row',
  ],
};

/// Resolves a section kind to tile content: [kCatalog] first, else
/// [kContainerTiles] (a synthetic entry carrying the container label with the
/// same tile chrome and `Draggable` data = kind). Null when the kind names
/// neither — sections skip those, as before.
CatalogEntry? resolvePaletteEntry(String kind) {
  for (final entry in kCatalog) {
    if (entry.kind == kind) return entry;
  }
  final tile = kContainerTiles[kind];
  if (tile == null) return null;
  // Container tiles render structurally on canvas (never via this build),
  // so the builder is inert by construction.
  return CatalogEntry(
    kind: kind,
    label: tile.label,
    defaults: const {},
    build: (_) => const SizedBox(),
  );
}

/// Human label for a kind id: `radio_group` → `Radio Group` (plain kinds
/// like `button` → `Button` are unchanged).
String _tileLabel(String kind) {
  return kind
      .split('_')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Searchable 2-column tile grid replacing the old flat palette list.
class PartsPalette extends StatefulWidget {
  /// Called when the collapse button at the panel's top-right is tapped.
  final VoidCallback? onCollapse;

  const PartsPalette({super.key, this.onCollapse});

  @override
  State<PartsPalette> createState() => _PartsPaletteState();
}

class _PartsPaletteState extends State<PartsPalette> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  final Set<String> _collapsed = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final q = _query.trim();

    final visible = <String, List<RegistryEntry>>{};
    for (final section in kRegistrySectionOrder) {
      final entries = registrySectionEntries(section);
      if (q.isEmpty) {
        visible[section] = entries;
      } else {
        // Word-start matching only ([registryMatchesQuery]): 'row' matches
        // the Row tile, never Breadcrumb's 'arrow' separator text.
        final matches =
            entries.where((e) => registryMatchesQuery(e, q)).toList();
        if (matches.isNotEmpty) visible[section] = matches;
      }
    }

    return Container(
      // FF4: the palette is a full-height panel — the host gives the width,
      // this container owns the panel background.
      color: colors.panelBg,
      padding: const EdgeInsets.only(
        top: 16,
        left: EditorMetrics.panelInset,
        right: EditorMetrics.panelInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parts',
                style: EditorType.sectionHeader.copyWith(
                  color: colors.onSurface,
                ),
              ),
              shadcn.Tooltip(
                tooltip: (context) => shadcn.TooltipContainer(
                  child: const Text('Collapse'),
                ),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: shadcn.IconButton.ghost(
                    icon: Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: widget.onCollapse,
                    size: shadcn.ButtonSize.small,
                    density: shadcn.ButtonDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: EditorMetrics.searchWidth,
            height: EditorMetrics.searchHeight,
            child: shadcn.TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: EditorType.field.copyWith(color: colors.onSurface),
              cursorColor: colors.onSurfaceVariant,
              placeholder: Text(
                'Search',
                style: EditorType.field.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              features: [
                shadcn.InputLeadingFeature(
                  Icon(
                    Icons.search,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 20,
                          color: colors.disabled,
                        ),
                        const SizedBox(height: EditorMetrics.tileGap),
                        Text(
                          'No parts match',
                          style: EditorType.sectionHeader.copyWith(
                            color: colors.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: EditorMetrics.tileGap),
                        Text(
                          'Try a different search term.',
                          style: EditorType.tileLabel.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final section in visible.entries)
                            _Section(
                              name: section.key,
                              entries: section.value,
                              collapsed: q.isNotEmpty
                                  ? false
                                  : _collapsed.contains(section.key),
                              onToggle: () => setState(() {
                                if (_collapsed.contains(section.key)) {
                                  _collapsed.remove(section.key);
                                } else {
                                  _collapsed.add(section.key);
                                }
                              }),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One collapsible section with a full-width list-row body (FF4: the tile
/// grid becomes FlutterFlow-style rows — kind preview + name per kind).
class _Section extends StatelessWidget {
  final String name;
  final List<RegistryEntry> entries;
  final bool collapsed;
  final VoidCallback onToggle;

  const _Section({
    required this.name,
    required this.entries,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.widgets,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: EditorType.sectionHeader.copyWith(
                      color: colors.groupHeaderFg,
                    ),
                  ),
                ),
                Text(
                  '${entries.length}',
                  style: EditorType.tileLabel.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries)
                  Draggable<String>(
                    // DnD payload contract (unchanged): the kind string —
                    // the canvas accept path resolves it via the catalog.
                    data: entry.kind,
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: Opacity(
                        opacity: 0.9,
                        child: SizedBox(
                          width: EditorMetrics.ffPanelWidth,
                          child: _PaletteRowContent(entry: entry),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: _PaletteRowContent(entry: entry),
                    ),
                    child: _PaletteRow(entry: entry),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Hoverable list row around [_PaletteRowContent].
///
/// Draggable swaps `child` for `childWhenDragging` when a drag starts,
/// unmounting this row mid-gesture; the trailing pointer-exit event then
/// arrives post-dispose. Guard everything (DDC-proven crash:
/// "setState() called after dispose" on every web drop).
class _PaletteRow extends StatefulWidget {
  final RegistryEntry entry;

  const _PaletteRow({required this.entry});

  @override
  State<_PaletteRow> createState() => _PaletteRowState();
}

class _PaletteRowState extends State<_PaletteRow> {
  bool _hovered = false;

  void _setHovered(bool v) {
    if (mounted) setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.grab,
      child: _PaletteRowContent(entry: widget.entry, hovered: _hovered),
    );
  }
}

/// One full-width palette row (FF4): a small preview affordance (the kind
/// icon on a token tile) beside the kind name, with a drag-hint glyph.
///
/// The kind label text is exactly [_tileLabel] of the kind, so one row
/// carries one label — search tests keep counting it.
class _PaletteRowContent extends StatelessWidget {
  final RegistryEntry entry;

  /// Hover state (drives the row wash + preview tile).
  final bool hovered;

  const _PaletteRowContent({required this.entry, this.hovered = false});

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return shadcn.Tooltip(
      tooltip: (context) => shadcn.TooltipContainer(child: Text(entry.label)),
      child: Container(
        decoration: BoxDecoration(
          color: hovered ? colors.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(EditorMetrics.segmentInnerRadius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: EditorMetrics.panelInset,
          vertical: EditorMetrics.tileGap,
        ),
        child: Row(
          children: [
            Container(
              width: EditorMetrics.ffCompactButtonSize,
              height: EditorMetrics.ffCompactButtonSize,
              decoration: BoxDecoration(
                color: hovered ? colors.panelBg : colors.surfaceContainerHigh,
                borderRadius:
                    BorderRadius.circular(EditorMetrics.segmentInnerRadius),
              ),
              child: Icon(
                entry.icon,
                size: EditorMetrics.ffRailIconSize,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: EditorMetrics.panelInset),
            Expanded(
              child: Text(
                _tileLabel(entry.kind),
                style: EditorType.tileLabel.copyWith(
                  color: colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
              ),
            ),
            Icon(
              Icons.drag_indicator,
              size: EditorMetrics.ffRailIconSize,
              color: colors.disabled,
            ),
          ],
        ),
      ),
    );
  }
}
