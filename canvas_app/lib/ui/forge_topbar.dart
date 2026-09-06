/// Forge topbar (Track Y2, FORGE.md §1-1a–1g, §4.1).
///
/// Light editor chrome mounted above the shell columns: logo mark + "Forge",
/// project pill (status dot + `doc.meta.title`), screen-tabs segmented
/// control (select + add + inline double-click rename + × delete on the
/// active tab), undo/redo icon buttons, Open icon, and the Preview / Export
/// Flutter pill actions.
///
/// Stateless vs the store: tabs arrive as [ForgeScreenTab] props mapped by
/// the shell from `store.doc.screens`, and every interaction leaves through
/// callbacks — the widget never imports the store, so it is widget-testable
/// without a shell. "Current screen" is the shell's existing screen
/// selection (`_selectedScreenId` in `main.dart`): tapping a tab calls
/// [onSelectScreen] exactly like a canvas screen tap, and selection state
/// stays in the shell.
///
/// Token rule: chrome reads [EditorColors]/[EditorType] only — no hex
/// literals — except [_kStatusDot], which FORGE.md §3 pins APPROXIMATE
/// `#22C55E` with no token slot (Y2 adds exactly the three §2 fields, so the
/// dot rides as a documented private const until the re-measure pass).
/// The near-black active-tab / Preview fills (spec APPROXIMATE `#111827`)
/// use [EditorColors.onSurface] instead of a literal so the pills stay
/// legible under both chrome modes (light `#1D1B20`, dark `#E4E1E7`).
/// All §3 numbers are APPROXIMATE per FORGE.md §6 (structure/callbacks are
/// tested, not pixels).
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;

import 'editor_buttons.dart';
import 'editor_tokens.dart';

/// Topbar height. APPROXIMATE ~64px (FORGE.md §3).
const double _kTopbarHeight = 64;

/// Logo mark box. APPROXIMATE ~28px, radius ~8px (FORGE.md §3).
const double _kLogoSize = 28;
const double _kLogoRadius = 8;

/// Project-pill status dot. APPROXIMATE ~8px `#22C55E` (FORGE.md §3); see
/// the library doc for why this stays a private const instead of a token.
const Color _kStatusDot = Color(0xFF22C55E);
const double _kStatusDotSize = 8;

/// Screen-tab pill. APPROXIMATE height ~32px, radius ~16px (FORGE.md §3).
const double _kTabHeight = 32;
const double _kTabRadius = 16;

/// Undo/redo/Open/add icon buttons. 32px per FORGE.md §3.
const double _kTopbarIconSize = 32;

/// Gaps between topbar groups. APPROXIMATE 8–12px (FORGE.md §3).
const double _kTopbarGroupGap = 12;
const double _kTopbarActionGap = 8;

/// One screen tab. The shell maps `store.doc.screens` to these (id + name
/// only) so this widget stays store-free.
@immutable
class ForgeScreenTab {
  /// Screen id (matches `CanvasScreen.id`).
  final String id;

  /// Screen name (matches `CanvasScreen.name`).
  final String name;

  const ForgeScreenTab({required this.id, required this.name});
}

/// Forge editor topbar. See the library doc for the data flow.
class ForgeTopbar extends StatefulWidget {
  /// Project title for the pill (`doc.meta.title`).
  final String projectTitle;

  /// Tabs to render, in order (mapped from `store.doc.screens`).
  final List<ForgeScreenTab> screens;

  /// Currently selected screen id (shell-owned; null when none).
  final String? selectedScreenId;

  /// Tap on a tab: the shell selects this screen (same path as a canvas
  /// screen tap — node selection clears, screen selection sets).
  final ValueChanged<String> onSelectScreen;

  /// "+" button: the shell calls `store.addScreen()`.
  final VoidCallback onAddScreen;

  /// Inline-rename commit (double-click the active tab, edit, submit):
  /// the shell calls `store.renameScreen(id, name)`. Empty names never
  /// reach this callback (the edit just cancels).
  final void Function(String id, String name) onRenameScreen;

  /// "×" on the active tab: the shell calls `store.deleteScreen(id)` and
  /// keeps the dangling-action refusal + SnackBar path.
  final ValueChanged<String> onDeleteScreen;

  /// Undo. Null renders the disabled state (`store.canUndo` gating).
  final VoidCallback? onUndo;

  /// Redo. Null renders the disabled state (`store.canRedo` gating).
  final VoidCallback? onRedo;

  /// Preview pill: the shell enters the preview player.
  final VoidCallback onPreview;

  /// Export pill: the shell opens the existing export dialog.
  final VoidCallback onExport;

  /// Folder icon: the shell opens the existing open dialog (FORGE.md §1-1g:
  /// survives as a small topbar icon).
  final VoidCallback onOpen;

  const ForgeTopbar({
    super.key,
    required this.projectTitle,
    required this.screens,
    required this.selectedScreenId,
    required this.onSelectScreen,
    required this.onAddScreen,
    required this.onRenameScreen,
    required this.onDeleteScreen,
    required this.onUndo,
    required this.onRedo,
    required this.onPreview,
    required this.onExport,
    required this.onOpen,
  });

  @override
  State<ForgeTopbar> createState() => _ForgeTopbarState();
}

class _ForgeTopbarState extends State<ForgeTopbar> {
  /// Tab id currently in inline-rename mode (null when none).
  String? _editingId;
  late final TextEditingController _renameController =
      TextEditingController();

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  void _beginRename(ForgeScreenTab tab) {
    setState(() {
      _editingId = tab.id;
      _renameController.text = tab.name;
    });
  }

  void _commitRename() {
    final id = _editingId;
    final name = _renameController.text.trim();
    setState(() => _editingId = null);
    if (id == null || name.isEmpty) return;
    widget.onRenameScreen(id, name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    // A rebuild (undo, delete) can drop the edited tab mid-edit: fall back
    // to the label instead of holding a dangling editing id.
    final ids = {for (final s in widget.screens) s.id};
    final editingId =
        _editingId != null && ids.contains(_editingId) ? _editingId : null;

    return Container(
      height: _kTopbarHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.surfaceContainerHigh),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: _kTopbarGroupGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _logo(colors),
          const SizedBox(width: _kTopbarGroupGap),
          Flexible(child: _projectPill(colors)),
          const SizedBox(width: _kTopbarGroupGap),
          Expanded(
            child: _tabs(colors, editingId),
          ),
          const SizedBox(width: _kTopbarGroupGap),
          EditorIconButton(
            icon: Icons.undo,
            size: _kTopbarIconSize,
            tooltip: 'Undo',
            onPressed: widget.onUndo,
          ),
          const SizedBox(width: _kTopbarActionGap),
          EditorIconButton(
            icon: Icons.redo,
            size: _kTopbarIconSize,
            tooltip: 'Redo',
            onPressed: widget.onRedo,
          ),
          const SizedBox(width: _kTopbarActionGap),
          EditorIconButton(
            icon: Icons.folder_open,
            size: _kTopbarIconSize,
            tooltip: 'Open',
            onPressed: widget.onOpen,
          ),
          const SizedBox(width: _kTopbarActionGap),
          _actionPill(
            label: 'Preview',
            icon: Icons.play_arrow,
            tooltip: 'Preview',
            background: colors.onSurface,
            foreground: colors.surface,
            onPressed: widget.onPreview,
          ),
          const SizedBox(width: _kTopbarActionGap),
          _actionPill(
            label: 'Export Flutter',
            icon: Icons.download,
            tooltip: 'Export Flutter',
            background: colors.accent,
            foreground: colors.onAccent,
            onPressed: widget.onExport,
          ),
        ],
      ),
    );
  }

  /// Zone 1: black rounded-square logo mark + "Forge" 15/600.
  Widget _logo(EditorColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _kLogoSize,
          height: _kLogoSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.onSurface,
            borderRadius: BorderRadius.circular(_kLogoRadius),
          ),
          child: Icon(
            Icons.layers,
            size: 16,
            color: colors.surface,
          ),
        ),
        const SizedBox(width: _kTopbarActionGap),
        Text(
          'Forge',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
              .copyWith(color: colors.onSurface),
        ),
      ],
    );
  }

  /// Zone 2: full-radius project pill (status dot + title 13/500).
  Widget _projectPill(EditorColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(_kTabRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _kStatusDotSize,
            height: _kStatusDotSize,
            decoration: const BoxDecoration(
              color: _kStatusDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: _kTopbarActionGap),
          Flexible(
            child: Text(
              widget.projectTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
                      .copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  /// Zone 3: screen-tabs segmented control + "+" add-tab button.
  Widget _tabs(EditorColors colors, String? editingId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in widget.screens) ...[
            _tab(colors, tab, editingId),
            const SizedBox(width: 4),
          ],
          EditorIconButton(
            icon: Icons.add,
            size: _kTopbarIconSize,
            tooltip: 'Add screen',
            onPressed: widget.onAddScreen,
          ),
        ],
      ),
    );
  }

  Widget _tab(EditorColors colors, ForgeScreenTab tab, String? editingId) {
    final active = tab.id == widget.selectedScreenId;
    if (editingId == tab.id) return _renameEditor(colors);
    if (!active) {
      // Inactive tabs carry only onTap (no double-tap recognizer) so
      // selection stays immediate.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelectScreen(tab.id),
        child: Container(
          height: _kTabHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_kTabRadius),
          ),
          alignment: Alignment.center,
          child: Text(
            tab.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }
    // Active tab: near-black pill (token-adapted, see library doc) with
    // white text; single-tap is a no-op (already current), double-tap on
    // the label renames inline, "×" deletes.
    return Container(
      height: _kTabHeight,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: colors.onSurface,
        borderRadius: BorderRadius.circular(_kTabRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => _beginRename(tab),
            child: Text(
              tab.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)
                      .copyWith(color: colors.surface),
            ),
          ),
          shadcn.Tooltip(
            tooltip: (context) => shadcn.TooltipContainer(
              child: const Text('Delete screen'),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onDeleteScreen(tab.id),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: colors.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Inline rename editor replacing the active tab's label (FORGE.md §4.1:
  /// inline double-click rename). Submit commits; empty cancels.
  Widget _renameEditor(EditorColors colors) {
    return Container(
      constraints: const BoxConstraints(minHeight: _kTabHeight),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(_kTabRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: shadcn.TextField(
              controller: _renameController,
              autofocus: true,
              style: EditorType.field.copyWith(color: colors.onSurface),
              onSubmitted: (_) => _commitRename(),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _commitRename,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.check,
                size: 16,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Zones 5–6: pill action buttons (Preview = near-black pill, Export =
  /// accent-blue pill, white text + icon). Custom skin per FORGE.md §1
  /// ("REBUILD button skin", logic kept): kit buttons follow the component
  /// theme, not these editor tokens — same custom-chrome exception class as
  /// [_SegmentButton]'s container + kit-tooltip idiom.
  Widget _actionPill({
    required String label,
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return shadcn.Tooltip(
      tooltip: (context) => shadcn.TooltipContainer(child: Text(tooltip)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ).copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
