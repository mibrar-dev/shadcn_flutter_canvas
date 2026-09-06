/// Forge topbar, FlutterFlow-dense reskin (Track FF3, BUILD_SPEC §9.1-1a–1f,
/// §9.3 FF3; Track Y2 origin, FORGE.md §1-1a–1g, §4.1).
///
/// Dense 56px bar ([EditorMetrics.ffTopbarHeight]): logo mark + project pill
/// (status dot + `doc.meta.title`), page dropdown ([shadcn.Select] over the
/// screen list + add + inline rename + delete — the tab strip is gone),
/// undo/redo icon buttons, Open icon, the embedded device strip
/// ([DevicePickerEmbed]) and zoom strip ([ZoomControlsEmbed]), and the
/// Run / Deploy pill actions.
///
/// Stateless vs the store: screens arrive as [ForgeScreenTab] props mapped by
/// the shell from `store.doc.screens`, device/zoom arrive as shell-owned
/// values, and every interaction leaves through callbacks — the widget never
/// imports the store, so it is widget-testable without a shell. "Current
/// screen" is the shell's existing screen selection (`_selectedScreenId` in
/// `main.dart`): picking a page calls [onSelectScreen] exactly like a canvas
/// screen tap, and selection state stays in the shell.
///
/// Kept verbatim from Y2: every callback/store path (select/add/rename/
/// delete/undo/redo/preview/export/open), the inline-rename empty-guard, the
/// dangling-edit fallback, the single `Icons.add` add affordance and the
/// single active-screen `Icons.close` delete affordance (shell tests address
/// both by icon). The pill *labels* read Run/Deploy per §9.1 (callbacks stay
/// `onPreview`/`onExport`); the pill *tooltips* already carry the Run/Deploy
/// names.
///
/// Token rule: chrome reads [EditorColors]/[EditorType] only — no hex
/// literals — except [_kStatusDot], which FORGE.md §3 pins APPROXIMATE
/// `#22C55E` with no token slot. The near-black Preview fill (spec
/// APPROXIMATE `#111827`) uses [EditorColors.onSurface] instead of a literal
/// so the pill stays legible under both chrome modes. All §3 numbers are
/// APPROXIMATE per FORGE.md §6 (structure/callbacks are tested, not pixels).
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/shadcn_ui.dart' as shadcn;

import 'device_picker.dart';
import 'editor_buttons.dart';
import 'editor_tokens.dart';
import 'zoom_controls.dart';

/// Logo mark box. APPROXIMATE ~28px, radius ~8px (FORGE.md §3).
const double _kLogoSize = 28;
const double _kLogoRadius = 8;

/// Project-pill status dot. APPROXIMATE ~8px `#22C55E` (FORGE.md §3); see
/// the library doc for why this stays a private const instead of a token.
const Color _kStatusDot = Color(0xFF22C55E);
const double _kStatusDotSize = 8;

/// Page dropdown width. APPROXIMATE ~160px (FF3; dropdown replaces the tab
/// strip, so this is new chrome, not a measured value).
const double _kPageSelectWidth = 160;

/// Undo/redo/Open/add/edit/delete icon buttons. 32px per FORGE.md §3.
const double _kTopbarIconSize = 32;

/// Gaps between topbar groups. APPROXIMATE 8–12px (FORGE.md §3).
const double _kTopbarGroupGap = 12;
const double _kTopbarActionGap = 8;

/// One screen entry. The shell maps `store.doc.screens` to these (id + name
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

  /// Pages to render, in order (mapped from `store.doc.screens`).
  final List<ForgeScreenTab> screens;

  /// Currently selected screen id (shell-owned; null when none).
  final String? selectedScreenId;

  /// Pick a page: the shell selects this screen (same path as a canvas
  /// screen tap — node selection clears, screen selection sets).
  final ValueChanged<String> onSelectScreen;

  /// "+" button: the shell calls `store.addScreen()`.
  final VoidCallback onAddScreen;

  /// Inline-rename commit (edit icon by the dropdown, edit, submit):
  /// the shell calls `store.renameScreen(id, name)`. Empty names never
  /// reach this callback (the edit just cancels).
  final void Function(String id, String name) onRenameScreen;

  /// Delete button on the selected page: the shell calls
  /// `store.deleteScreen(id)` and keeps the dangling-action refusal +
  /// SnackBar path.
  final ValueChanged<String> onDeleteScreen;

  /// Undo. Null renders the disabled state (`store.canUndo` gating).
  final VoidCallback? onUndo;

  /// Redo. Null renders the disabled state (`store.canRedo` gating).
  final VoidCallback? onRedo;

  /// Run pill: the shell enters the preview player.
  final VoidCallback onPreview;

  /// Deploy pill: the shell opens the existing export dialog.
  final VoidCallback onExport;

  /// Folder icon: the shell opens the existing open dialog (FORGE.md §1-1g:
  /// survives as a small topbar icon).
  final VoidCallback onOpen;

  /// Embedded device strip selection (index into `kPreviewDevices`,
  /// shell-owned). Null (with [onDeviceSelect]/[onLandscapeChanged]) hides
  /// the strip — the shell wires this at the FF7 cutover.
  final int? deviceSelectedIndex;

  /// Device tap: the shell applies the preset (same contract as
  /// [DevicePicker.onSelect]).
  final ValueChanged<int>? onDeviceSelect;

  /// Whether the landscape toggle is on (shell-owned).
  final bool landscape;

  /// Landscape flip (same contract as [DevicePicker.onLandscapeChanged]).
  final ValueChanged<bool>? onLandscapeChanged;

  /// Embedded zoom strip value (shell-owned zoom fraction). Null (with
  /// [onZoomIn]/[onZoomOut]/[onZoomFit]) hides the strip.
  final double? zoom;

  /// Zoom in one step (same contract as [ZoomControlsEmbed.onZoomIn]).
  final VoidCallback? onZoomIn;

  /// Zoom out one step.
  final VoidCallback? onZoomOut;

  /// Fit the screen into view.
  final VoidCallback? onZoomFit;

  /// Whether snap guides are on (forwarded to the zoom strip).
  final bool showGuides;

  /// Grid-icon toggle for the zoom strip. Null hides the grid button.
  final ValueChanged<bool>? onShowGuidesChanged;

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
    this.deviceSelectedIndex,
    this.onDeviceSelect,
    this.landscape = false,
    this.onLandscapeChanged,
    this.zoom,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomFit,
    this.showGuides = true,
    this.onShowGuidesChanged,
  });

  @override
  State<ForgeTopbar> createState() => _ForgeTopbarState();
}

class _ForgeTopbarState extends State<ForgeTopbar> {
  /// Tab id currently in inline-rename mode (null when none).
  String? _editingId;
  late final TextEditingController _renameController = TextEditingController();

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  /// The selected tab when the id still resolves (null when the selection
  /// is empty or dangling after an undo/delete).
  ForgeScreenTab? get _activeTab {
    final id = widget.selectedScreenId;
    if (id == null) return null;
    for (final tab in widget.screens) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  String _nameFor(String id) {
    for (final tab in widget.screens) {
      if (tab.id == id) return tab.name;
    }
    return id;
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

  /// Embedded device strip, or null when unwired/out of range (the shell
  /// wires it at the FF7 cutover; until then the topbar stays device-free).
  Widget? _deviceStrip() {
    final index = widget.deviceSelectedIndex;
    final onSelect = widget.onDeviceSelect;
    final onLandscape = widget.onLandscapeChanged;
    if (index == null || onSelect == null || onLandscape == null) return null;
    if (index < 0 || index >= kPreviewDevices.length) return null;
    return DevicePickerEmbed(
      selectedIndex: index,
      onSelect: onSelect,
      landscape: widget.landscape,
      onLandscapeChanged: onLandscape,
    );
  }

  /// Embedded zoom strip, or null when unwired (same cutover story as the
  /// device strip).
  Widget? _zoomStrip() {
    final zoom = widget.zoom;
    final onZoomIn = widget.onZoomIn;
    final onZoomOut = widget.onZoomOut;
    final onZoomFit = widget.onZoomFit;
    if (zoom == null || onZoomIn == null || onZoomOut == null) return null;
    if (onZoomFit == null) return null;
    return ZoomControlsEmbed(
      zoom: zoom,
      onZoomIn: onZoomIn,
      onZoomOut: onZoomOut,
      onFit: onZoomFit,
      showGuides: widget.showGuides,
      onShowGuidesChanged: widget.onShowGuidesChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    // A rebuild (undo, delete) can drop the edited tab mid-edit: fall back
    // to the dropdown instead of holding a dangling editing id.
    final ids = {for (final s in widget.screens) s.id};
    final editingTab = _editingId != null && ids.contains(_editingId)
        ? _nameFor(_editingId!)
        : null;
    final deviceStrip = _deviceStrip();
    final zoomStrip = _zoomStrip();

    return Container(
      height: EditorMetrics.ffTopbarHeight,
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
          editingTab == null ? _pageSelector(colors) : _renameEditor(colors),
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
          if (deviceStrip != null) ...[
            const SizedBox(width: _kTopbarGroupGap),
            deviceStrip,
          ],
          if (zoomStrip != null) ...[
            const SizedBox(width: _kTopbarGroupGap),
            zoomStrip,
          ],
          const Spacer(),
          _actionPill(
            label: 'Run',
            icon: Icons.play_arrow,
            tooltip: 'Run preview',
            background: colors.onSurface,
            foreground: colors.surface,
            onPressed: widget.onPreview,
          ),
          const SizedBox(width: _kTopbarActionGap),
          _actionPill(
            label: 'Deploy',
            icon: Icons.download,
            tooltip: 'Deploy / export project',
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
        borderRadius: BorderRadius.circular(16),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
                  .copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  /// Zone 3: page dropdown (replaces the tab strip) + add + rename + delete.
  ///
  /// The dropdown is a kit [shadcn.Select] over the screen ids (the
  /// `_optionSelect` idiom from `theme_panels.dart`): picking an entry calls
  /// [ForgeTopbar.onSelectScreen] with the id, exactly like tapping a tab
  /// did. Rename (edit icon) and delete (`Icons.close`) address the selected
  /// page only, so at most one close glyph exists — the shell delete tests
  /// keep addressing it by icon.
  Widget _pageSelector(EditorColors colors) {
    final active = _activeTab;
    return Row(
      key: const ValueKey('ff-page-selector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _kPageSelectWidth,
          child: shadcn.Select<String>(
            value: active?.id,
            placeholder: Text(
              widget.screens.isEmpty ? 'No pages' : 'Select page',
            ),
            itemBuilder: (context, id) => Text(_nameFor(id)),
            onChanged: (v) {
              if (v != null) widget.onSelectScreen(v);
            },
            popup: shadcn.SelectPopup(
              items: shadcn.SelectItemList(
                children: [
                  for (final tab in widget.screens)
                    shadcn.SelectItemButton(
                      value: tab.id,
                      child: Text(tab.name),
                    ),
                ],
              ),
            ).call,
          ),
        ),
        const SizedBox(width: _kTopbarActionGap),
        EditorIconButton(
          icon: Icons.add,
          size: _kTopbarIconSize,
          tooltip: 'Add screen',
          onPressed: widget.onAddScreen,
        ),
        if (active != null) ...[
          const SizedBox(width: _kTopbarActionGap),
          EditorIconButton(
            icon: Icons.edit,
            size: _kTopbarIconSize,
            tooltip: 'Rename page',
            onPressed: () => _beginRename(active),
          ),
          const SizedBox(width: _kTopbarActionGap),
          EditorIconButton(
            icon: Icons.close,
            size: _kTopbarIconSize,
            tooltip: 'Delete screen',
            onPressed: () => widget.onDeleteScreen(active.id),
          ),
        ],
      ],
    );
  }

  /// Inline rename editor replacing the page selector (inline rename
  /// survives the tab-strip removal: the edit icon opens it, submit commits;
  /// empty cancels).
  Widget _renameEditor(EditorColors colors) {
    return Container(
      key: const ValueKey('ff-page-selector'),
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
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

  /// Zones 5–6: pill action buttons (Run = near-black pill, Deploy =
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
