/// Forge Library panel (Track Y3 — FORGE.md §1-2a/2b/2c, §3 "Left Library").
///
/// Rebuilds the old "Parts" palette as the Forge Library: eyebrow + title +
/// helper header, the same kit search field, and sectioned 2-column tile
/// cards sourced from [kRegistry] in [kRegistrySectionOrder] order.
///
/// Tile anatomy (FORGE.md §3): icon chip (tinted rounded square) + name
/// (humanized kind) + one-line manifest-desc ellipsis + a full-width dashed
/// "+ Add" button at the tile bottom. Each tile's "+ Add" button carries
/// `ValueKey('forge-add-<kind>')` so widget tests can target one kind.
///
/// Tap-to-add reuses the DnD creation path: [_PartsPaletteState._addPart]
/// funnels through [DesignCanvas.onAccept] — the exact method palette drops
/// land in via `ScreenSurface.onDropKind` — with an explicit append index, so
/// catalog defaults, the `row` branch, and undo semantics are identical to
/// drops by construction (no second creation path). DnD itself is unchanged
/// in behavior: `Draggable<String>` with `data` = kind, the same
/// transparent-material drag feedback, and the same `childWhenDragging` dim.
///
/// Search still filters via [registryMatchesQuery] (word-start, kind words
/// only) and sections stay collapsible (forced open while a query is active).
///
/// Token notes (FORGE.md §5/§6 — `editor_tokens.dart` is frozen for Y2's
/// agent, and every §3 number is APPROXIMATE): every *color* comes from
/// [EditorTheme]/[EditorColors] (no hex literals); sizes/type reuse
/// [EditorMetrics]/[EditorType] with `copyWith` derivations where no token
/// exists yet (17px title, 11px eyebrow, 12px desc, 32px icon chip). The icon
/// chip tint uses `surfaceContainerHigh` until Y2's `accent` token lands. The
/// dashed "+ Add" border is a local [CustomPainter] — a documented FORGE.md
/// §2 exception in the same class as the registry's `_DashPainter`.
///
/// Deferred to the Y6 cutover (needs `main.dart` shell wiring, owned by the
/// other agent): the "Library | Layers" pills and the bottom "Theme"
/// disclosure. Until then the panel takes an optional [PartsPalette.store]:
/// without it the "+ Add" buttons render disabled; Y6 passes the live store
/// plus the selected screen id.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/component_registry.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/design_canvas.dart';
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

/// Icon chip box (FORGE.md §3 APPROXIMATE ~32px; no token exists yet and
/// `editor_tokens.dart` is frozen for Y2's agent — see the file docs).
const double _kIconChipSize = 32;

/// Glyph size inside the icon chip.
const double _kIconChipGlyph = 18;

/// Forge Library: eyebrow/title/helper header, kit search field, and
/// sectioned 2-column tile cards with tap-to-add.
class PartsPalette extends StatefulWidget {
  /// Called when the collapse button at the panel's top-right is tapped.
  final VoidCallback? onCollapse;

  /// Live store for tap-to-add. Null (the pre-Y6 shell mount) renders the
  /// "+ Add" buttons disabled; Y6 passes the shell store plus the selected
  /// screen id. Additive optional param — `const PartsPalette()` still
  /// compiles, so the pre-cutover shell is untouched.
  final CanvasStore? store;

  /// Screen tap-to-add appends to (the shell's selected screen; `'s1'` keeps
  /// single-screen hosts and widget tests working).
  final String screenId;

  /// Fires with the fresh node id after a tap-to-add, so the shell can
  /// select/reveal it (Y6 wiring).
  final ValueChanged<String>? onNodeAdded;

  const PartsPalette({
    super.key,
    this.onCollapse,
    this.store,
    this.screenId = 's1',
    this.onNodeAdded,
  });

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

  /// Tap-to-add through the SAME creation path palette drops use.
  ///
  /// Drops land in [DesignCanvas.onAccept] (via `ScreenSurface.onDropKind`),
  /// so calling it here inherits the catalog defaults, the `row`
  /// container branch, and the store's commit/undo behavior by construction
  /// instead of inventing a second creation path. The explicit [index] is
  /// the current root count on [PartsPalette.screenId], so taps append;
  /// `Offset.zero` metadata matches what [CanvasStore.addRow] itself stores
  /// (the flow renderer lays out by doc order and ignores x/y).
  void _addPart(String kind) {
    final store = widget.store;
    if (store == null) return;
    var at = 0;
    for (final n in store.doc.nodes) {
      if (n.screenId == widget.screenId && n.parentId == null) at++;
    }
    final id = DesignCanvas(store: store, screenId: widget.screenId)
        .onAccept(kind, Offset.zero, index: at);
    widget.onNodeAdded?.call(id);
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WIDGETS · FLUTTER',
                      style: EditorType.tileLabel.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                        height: EditorMetrics.toolbarButtonGap),
                    Text(
                      'Library',
                      style: EditorType.tileLabel.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
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
          const SizedBox(height: EditorMetrics.toolbarButtonGap),
          Text(
            'Drag a tile onto the canvas, or tap + Add to append it to the current screen.',
            style: EditorType.tileLabel.copyWith(
              fontWeight: FontWeight.w400,
              color: colors.onSurfaceVariant,
            ),
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
                              onAdd: widget.store == null
                                  ? null
                                  : _addPart,
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

  /// Tap-to-add sink (kind → node); null while the panel has no store, which
  /// renders every "+ Add" button disabled until Y6 wires it.
  final ValueChanged<String>? onAdd;

  const _Section({
    required this.name,
    required this.entries,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final onAdd = this.onAdd;
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
                      color: colors.onSurfaceVariant,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Two columns at any panel width (Y6 narrows 320 → ~300);
                // unbounded fallback keeps tests/tools with loose
                // constraints on the old measured tile width.
                final gap = EditorMetrics.tileGap;
                final max = constraints.maxWidth;
                final tileWidth =
                    max.isFinite ? (max - gap) / 2 : EditorMetrics.tileWidth;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final entry in entries)
                      SizedBox(
                        width: tileWidth,
                        child: Draggable<String>(
                          data: entry.kind,
                          feedback: Material(
                            type: MaterialType.transparency,
                            child: Opacity(
                              opacity: 0.9,
                              child: SizedBox(
                                width: tileWidth,
                                child: _LibraryTile(entry: entry),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.4,
                            child: _LibraryTile(entry: entry),
                          ),
                          child: _PressableTile(
                            child: _LibraryTile(
                              entry: entry,
                              addButtonKey:
                                  ValueKey('forge-add-${entry.kind}'),
                              onAdd: onAdd == null
                                  ? null
                                  : () => onAdd(entry.kind),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Tile with hover lift and press scale per the reference motion spec.
class _PressableTile extends StatefulWidget {
  final Widget child;

  const _PressableTile({required this.child});

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
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Forge tile card: icon chip + name row, one-line manifest desc, and the
/// full-width dashed "+ Add" button at the bottom.
class _LibraryTile extends StatelessWidget {
  final RegistryEntry entry;

  /// Tap-to-add handler; null renders the "+ Add" button disabled (panel
  /// mounted without a store — pre-Y6 shell).
  final VoidCallback? onAdd;

  /// Key for the "+ Add" button (`ValueKey('forge-add-<kind>')` on the live
  /// tile; null on drag feedback/dimming copies so the key stays unique).
  final Key? addButtonKey;

  const _LibraryTile({
    required this.entry,
    this.onAdd,
    this.addButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    final name = _tileLabel(entry.kind);
    // The `row` pseudo-kind's manifest label IS its name — a second
    // identical line would duplicate the tile's text (and break the
    // one-tile-per-kind DnD regression tests), so the desc line renders
    // only when it adds information.
    final showDesc = entry.label != name;
    return shadcn.Tooltip(
      tooltip: (context) =>
          shadcn.TooltipContainer(child: Text(entry.label)),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(EditorMetrics.tileRadius),
          border: Border.all(
            color: colors.onSurfaceVariant.withValues(alpha: 0.22),
          ),
        ),
        padding: const EdgeInsets.all(EditorMetrics.panelInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: _kIconChipSize,
                  height: _kIconChipSize,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(
                      EditorMetrics.segmentInnerRadius,
                    ),
                  ),
                  child: Icon(
                    entry.icon,
                    size: _kIconChipGlyph,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: EditorMetrics.tileGap),
                Expanded(
                  child: Text(
                    name,
                    style: EditorType.tileLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (showDesc) ...[
              const SizedBox(height: EditorMetrics.toolbarButtonGap),
              Text(
                entry.label,
                style: EditorType.tileLabel.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: EditorMetrics.tileGap),
            CustomPaint(
              painter: _DashedBorder(
                color:
                    colors.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              child: SizedBox(
                width: double.infinity,
                child: shadcn.GhostButton(
                  key: addButtonKey,
                  onPressed: onAdd,
                  size: shadcn.ButtonSize.small,
                  density: shadcn.ButtonDensity.compact,
                  child: const Text('+ Add'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle border for the "+ Add" button — the FORGE.md §2
/// documented exception (no kit dashed-box exists), following the same dash
/// idiom as the registry's `_DashPainter`.
class _DashedBorder extends CustomPainter {
  final Color color;

  const _DashedBorder({required this.color});

  static const _dash = 5.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(EditorMetrics.segmentInnerRadius),
        ),
      );
    final metrics = path.computeMetrics().single;
    var distance = 0.0;
    while (distance < metrics.length) {
      final end = (distance + _dash).clamp(0.0, metrics.length);
      canvas.drawPath(metrics.extractPath(distance, end), paint);
      distance += _dash + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder oldDelegate) =>
      oldDelegate.color != color;
}
