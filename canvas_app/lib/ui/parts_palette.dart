/// Searchable sectioned parts palette, measured from the m3e-canvas reference
/// (https://lnkiai.github.io/m3e-canvas/) at a 1440x900 viewport.
/// Uses [EditorMetrics] / [EditorColors] for every size and color.
/// Tiles source from [kRegistry] (grouped by [kRegistrySectionOrder]) and
/// stay draggable by kind, so drop/drop-target behavior is unchanged.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
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
      color: colors.surface,
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
              Tooltip(
                message: 'Collapse',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    hoverColor: colors.surfaceContainerHigh,
                    onTap: widget.onCollapse,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: EditorMetrics.searchWidth,
            height: EditorMetrics.searchHeight,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: EditorType.field.copyWith(color: colors.onSurface),
              cursorColor: colors.onSurfaceVariant,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: EditorType.field.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    EditorMetrics.searchRadius,
                  ),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    EditorMetrics.searchRadius,
                  ),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    EditorMetrics.searchRadius,
                  ),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'No parts match',
                      style: EditorType.tileLabel.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
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

/// One collapsible section with a 2-column tile grid body.
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
        InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: colors.surfaceContainerHigh,
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
                      color: colors.onSurface,
                    ),
                  ),
                ),
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
            child: Wrap(
              spacing: EditorMetrics.tileGap,
              runSpacing: EditorMetrics.tileGap,
              children: [
                for (final entry in entries)
                  Draggable<String>(
                    data: entry.kind,
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: Opacity(
                        opacity: 0.9,
                        child: _TileContent(entry: entry),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: _TileContent(entry: entry),
                    ),
                    child: _PressableTile(entry: entry),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tile with hover lift and press scale per the reference motion spec.
class _PressableTile extends StatefulWidget {
  final RegistryEntry entry;

  const _PressableTile({required this.entry});

  @override
  State<_PressableTile> createState() => _PressableTileState();
}

class _PressableTileState extends State<_PressableTile> {
  bool _hovered = false;
  bool _pressed = false;

  // Draggable swaps `child` for `childWhenDragging` when a drag starts,
  // unmounting this tile mid-gesture; the trailing pointer-up/exit events
  // then arrive post-dispose. Guard everything (DDC-proven crash:
  // "setState() called after dispose" on every web drop).
  void _setHovered(bool v) {
    if (mounted) setState(() => _hovered = v);
  }

  void _setPressed(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedSlide(
          offset: _hovered && !_pressed ? const Offset(0, -0.014) : Offset.zero,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: _TileContent(entry: widget.entry),
          ),
        ),
      ),
    );
  }
}

/// Fixed 114x72 tile: centered icon over the part label.
class _TileContent extends StatelessWidget {
  final RegistryEntry entry;

  const _TileContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    return Tooltip(
      message: entry.label,
      child: Container(
        width: EditorMetrics.tileWidth,
        height: EditorMetrics.tileHeight,
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(EditorMetrics.tileRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              entry.icon,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              _tileLabel(entry.kind),
              style: EditorType.tileLabel.copyWith(
                color: colors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
