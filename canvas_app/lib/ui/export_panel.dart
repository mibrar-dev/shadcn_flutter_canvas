/// Track R2 export/share loop: code export + project files + templates.
///
/// One place for everything the toolbar Export action and the Open dialog's
/// project-file affordances need:
///
/// * pure payload builders ([buildExportSingleFile], [buildExportBundle],
///   [docJsonText]) over the checked-in closure maps in
///   `canvas/_impl/embedded_sources.dart` (same wiring the codegen docs
///   prescribe for the future export UI);
/// * filename shaping ([exportSlug], [exportFileName]: doc title + date);
/// * six minimal starter templates ([buildBlankTemplate],
///   [buildLoginTemplate], [buildShowcaseTemplate],
///   [buildOnboardingTemplate], [buildSettingsTemplate],
///   [buildProfileTemplate]);
/// * the [ExportDialog] (download ZIP / download single `.dart` / copy
///   single-file / copy share link / copy AI prompt / save doc JSON).
///
/// DOWNLOAD MECHANISM (web): `png_export.dart` only captures PNG bytes — it
/// has no file-download path, so there was no precedent to mirror. Downloads
/// use the canonical Flutter-web mechanism instead: a JS `Blob` + object URL
/// + programmatic `<a download>` click (see `export_download_web.dart`),
/// revoked after the click. `dart:js_interop` does not compile on the VM
/// test platform, so that file sits behind the `export_download.dart`
/// conditional export (stub elsewhere, throwing [UnsupportedError]); the
/// dialogs additionally guard with a [kIsWeb] check and render
/// [kNonWebDownloadMessage] inline (documented non-web guard). Tests never
/// touch the browser: downloads, clipboard copies, and file picks are
/// injectable sinks ([DownloadSink]/[CopySink]/[PickFileSink]).
library;

import 'dart:async';
import 'dart:convert';

import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:canvas_app/canvas/_impl/embedded_sources.dart';
import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/export_download.dart';

export 'export_download.dart';

/// Sink that persists downloaded bytes (filename + MIME type included).
typedef DownloadSink = Future<void> Function(
  List<int> bytes,
  String filename,
  String mimeType,
);

/// Sink that copies text to the clipboard.
typedef CopySink = Future<void> Function(String text);

/// Sink that lets the user pick a text file; null when cancelled.
typedef PickFileSink = Future<String?> Function();

/// Confirmation hook for destructive template replaces (injectable in tests).
typedef ConfirmReplace = Future<bool> Function(
  BuildContext context,
  String templateName,
);

/// MIME type for the bundle ZIP download.
const kZipMimeType = 'application/zip';

/// MIME type for single-file / doc-JSON text downloads.
const kTextMimeType = 'text/plain;charset=utf-8';

/// Builds the self-contained single-file Dart program for [doc].
///
/// Closure emission over the checked-in maps (see `codegen_single.dart`).
String buildExportSingleFile(ScreenDoc doc) => buildSingleFile(
      doc,
      kEmbeddedSources,
      extraImports: kEmbeddedImports,
      partOf: kEmbeddedParts,
    );

/// Builds the installable clean-folders bundle for [doc] (screens +
/// manifest + pubspec patch + [BundleManifest.zipBytes]).
BundleManifest buildExportBundle(ScreenDoc doc) =>
    buildCleanBundle(doc, kEmbeddedSources);

/// Pretty doc JSON with a trailing newline (same encoding the seed scripts
/// write), used for save-to-file and file-import round-trips.
String docJsonText(ScreenDoc doc) =>
    '${const JsonEncoder.withIndent('  ').convert(doc.toJson())}\n';

/// URL-safe slug of a doc title for filenames: lowercase, non-alphanumerics
/// become `-`, collapsed and trimmed; empty titles become `'design'`.
String exportSlug(String title) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'design' : slug;
}

/// `<slug>-<YYYYMMDD>.<extension>` filename for an export of the doc titled
/// [title] (defaults to now; pass [date] in tests for determinism).
String exportFileName({
  required String title,
  required String extension,
  DateTime? date,
}) {
  final at = date ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${exportSlug(title)}-${at.year}${two(at.month)}${two(at.day)}'
      '.$extension';
}

// Web download/pick implementations live in export_download_web.dart (stub
// in export_download_stub.dart), reached through the export_download.dart
// facade's [downloadBytes]/[pickTextFile] — the dialogs' defaults below.

// ---------------------------------------------------------------------------
// Starter templates (minimal inline docs, not the full seed scripts).
//
// Props mirror the `CatalogEntry.defaults` in
// `lib/canvas/component_catalog.dart` verbatim (only the props named here
// are overridden). Every template validates with empty [ScreenDoc.validateRefs]
// and JSON round-trips (pinned by `test/export_panel_test.dart`).
// ---------------------------------------------------------------------------

/// "Blank": one empty screen, clean-slate dark, no chrome.
ScreenDoc buildBlankTemplate() => ScreenDoc(
      screens: const [
        CanvasScreen(
          id: 's1',
          name: 'Screen 1',
          x: 0.0,
          y: 0.0,
          bg: 'surface',
        ),
      ],
      nodes: const [],
      theme: const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
      meta: const DocMeta(
        title: 'Blank',
        brief: 'Start from an empty screen.',
      ),
    );

/// "Login flow": the `seed_login_journey.dart` step-4 shape, minimal —
/// Login (scaffold + card + email/password inputs + sign-in button) wired to
/// Home (basic + back button), supabase light + clean-slate dark chrome.
ScreenDoc buildLoginTemplate() => ScreenDoc(
      screens: const [
        CanvasScreen(
          id: 's1',
          name: 'Login',
          x: 0.0,
          y: 0.0,
          bg: 'surface',
          device: 'phone',
        ),
        CanvasScreen(
          id: 's2',
          name: 'Home',
          x: 420.0,
          y: 0.0,
          bg: 'surface',
          device: 'phone',
        ),
      ],
      nodes: [
        _templateNode('n1', 's1', 0, 'scaffold', const {
          'title': 'Login',
          'body': 'Welcome',
        }),
        _templateNode('n2', 's1', 1, 'card', const {
          'title': 'Welcome back',
          'description': 'Sign in to continue',
          'showFooter': false,
        }),
        _templateNode('n3', 's1', 2, 'input', const {
          'placeholder': 'you@example.com',
          'label': 'Email',
          'initialValue': '',
          'disabled': false,
          'obscure': false,
          'readOnly': false,
        }),
        _templateNode('n4', 's1', 3, 'input', const {
          'placeholder': '••••••••',
          'label': 'Password',
          'initialValue': '',
          'disabled': false,
          'obscure': true,
          'readOnly': false,
        }),
        _templateNode(
          'n5',
          's1',
          4,
          'button',
          const {
            'label': 'Sign in',
            'variant': 'primary',
            'size': 'md',
            'disabled': false,
          },
          const NodeAction(to: 's2', transition: 'slide'),
        ),
        _templateNode('n6', 's2', 0, 'basic', const {
          'title': 'Home',
          'subtitle': 'Subtitle',
          'content': 'You are signed in.',
          'showLeading': true,
          'showTrailing': true,
        }),
        _templateNode(
          'n7',
          's2',
          1,
          'button',
          const {
            'label': 'Back to Login',
            'variant': 'primary',
            'size': 'md',
            'disabled': false,
          },
          const NodeAction(to: 's1', transition: 'fade'),
        ),
      ],
      theme: const CanvasTheme(
        paletteKey: 'supabase',
        dark: false,
        shape: 'rounded',
        motion: 'standard',
        chrome: CanvasTheme(
          paletteKey: 'clean-slate',
          dark: true,
          shape: 'rounded',
          motion: 'standard',
        ),
      ),
      meta: const DocMeta(
        title: 'Login flow',
        brief: 'Sign-in form wired to a home screen.',
      ),
    );

/// "Showcase": the `seed_full_palette.dart` Showcase-screen shape, minimal —
/// a Showcase screen (scaffold + card/basic/badge content + out-leg button)
/// with the Display return leg, clean-slate dark, no chrome.
ScreenDoc buildShowcaseTemplate() => ScreenDoc(
      screens: const [
        CanvasScreen(
          id: 's1',
          name: 'Showcase',
          x: 0.0,
          y: 0.0,
          bg: 'surface',
        ),
        CanvasScreen(
          id: 's2',
          name: 'Display',
          x: 420.0,
          y: 0.0,
          bg: 'surface',
        ),
      ],
      nodes: [
        _templateNode('n1', 's1', 0, 'scaffold', const {
          'title': 'Showcase',
          'body': 'Welcome',
        }),
        _templateNode('n2', 's1', 1, 'card', const {
          'title': 'Title',
          'description': 'Description',
          'showFooter': false,
        }),
        _templateNode('n3', 's1', 2, 'basic', const {
          'title': 'Title',
          'subtitle': 'Subtitle',
          'content': 'Content',
          'showLeading': true,
          'showTrailing': true,
        }),
        _templateNode('n4', 's1', 3, 'badge', const {
          'label': 'New',
          'variant': 'primary',
        }),
        _templateNode(
          'n5',
          's1',
          4,
          'button',
          const {
            'label': 'Open Display section',
            'variant': 'primary',
            'size': 'md',
            'disabled': false,
          },
          const NodeAction(to: 's2', transition: 'slide'),
        ),
        _templateNode('n6', 's2', 0, 'basic', const {
          'title': 'Display',
          'subtitle': 'Subtitle',
          'content': 'Content',
          'showLeading': true,
          'showTrailing': true,
        }),
        _templateNode(
          'n7',
          's2',
          1,
          'button',
          const {
            'label': 'Back to Showcase',
            'variant': 'primary',
            'size': 'md',
            'disabled': false,
          },
          const NodeAction(to: 's1', transition: 'fade'),
        ),
      ],
      theme: const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
      meta: const DocMeta(
        title: 'Showcase',
        brief: 'Mini-app with a two-screen tap chain.',
      ),
    );

/// "Onboarding": guided intro (scaffold + card + steps + get-started button)
/// wired to Home (basic), clean-slate dark, no chrome.
ScreenDoc buildOnboardingTemplate() => ScreenDoc(
      screens: const [
        CanvasScreen(
          id: 's1',
          name: 'Onboarding',
          x: 0.0,
          y: 0.0,
          bg: 'surface',
          device: 'phone',
        ),
        CanvasScreen(
          id: 's2',
          name: 'Home',
          x: 420.0,
          y: 0.0,
          bg: 'surface',
          device: 'phone',
        ),
      ],
      nodes: [
        _templateNode('n1', 's1', 0, 'scaffold', const {
          'title': 'Onboarding',
          'body': 'Welcome',
        }),
        _templateNode('n2', 's1', 1, 'card', const {
          'title': 'Welcome',
          'description': "Let's get you set up",
          'showFooter': false,
        }),
        _templateNode('n3', 's1', 2, 'steps', const {
          'step1': 'Create an account',
          'detail1': 'Sign up in seconds',
          'step2': 'Make it yours',
          'detail2': 'Pick a theme and avatar',
        }),
        _templateNode(
          'n4',
          's1',
          3,
          'button',
          const {
            'label': 'Get started',
            'variant': 'primary',
            'size': 'md',
            'disabled': false,
          },
          const NodeAction(to: 's2', transition: 'slide'),
        ),
        _templateNode('n5', 's2', 0, 'basic', const {
          'title': 'Home',
          'subtitle': 'Subtitle',
          'content': "You're all set.",
          'showLeading': true,
          'showTrailing': true,
        }),
      ],
      theme: const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
      meta: const DocMeta(
        title: 'Onboarding',
        brief: 'Guided intro steps wired to a home screen.',
      ),
    );

/// "Settings": one screen (scaffold + switch + checkbox + theme select),
/// clean-slate dark, no chrome. No actions — every control is local state.
ScreenDoc buildSettingsTemplate() => ScreenDoc(
      screens: const [
        CanvasScreen(
          id: 's1',
          name: 'Settings',
          x: 0.0,
          y: 0.0,
          bg: 'surface',
          device: 'phone',
        ),
      ],
      nodes: [
        _templateNode('n1', 's1', 0, 'scaffold', const {
          'title': 'Settings',
          'body': 'Welcome',
        }),
        _templateNode('n2', 's1', 1, 'switch', const {
          'value': true,
          'disabled': false,
        }),
        _templateNode('n3', 's1', 2, 'checkbox', const {
          'value': false,
          'disabled': false,
          'tristate': false,
        }),
        _templateNode('n4', 's1', 3, 'select', const {
          'placeholder': 'Theme',
          'option1': 'Light',
          'option2': 'Dark',
          'value': 'Light',
          'disabled': false,
        }),
      ],
      theme: const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
      meta: const DocMeta(
        title: 'Settings',
        brief: 'Toggles and a theme picker on one screen.',
      ),
    );

/// "Profile": one screen (scaffold + avatar + bio + badge + edit button),
/// clean-slate dark, no chrome. No actions — single screen.
ScreenDoc buildProfileTemplate() => ScreenDoc(
      screens: const [
        CanvasScreen(
          id: 's1',
          name: 'Profile',
          x: 0.0,
          y: 0.0,
          bg: 'surface',
          device: 'phone',
        ),
      ],
      nodes: [
        _templateNode('n1', 's1', 0, 'scaffold', const {
          'title': 'Profile',
          'body': 'Welcome',
        }),
        _templateNode('n2', 's1', 1, 'avatar', const {
          'initials': 'JD',
          'size': 40.0,
        }),
        _templateNode('n3', 's1', 2, 'basic', const {
          'title': 'Jane Doe',
          'subtitle': '@jane',
          'content': 'Design engineer.',
          'showLeading': false,
          'showTrailing': true,
        }),
        _templateNode('n4', 's1', 3, 'badge', const {
          'label': 'Pro',
          'variant': 'secondary',
        }),
        _templateNode('n5', 's1', 4, 'button', const {
          'label': 'Edit profile',
          'variant': 'primary',
          'size': 'md',
          'disabled': false,
        }),
      ],
      theme: const CanvasTheme(
        paletteKey: 'clean-slate',
        dark: true,
        shape: 'rounded',
        motion: 'standard',
      ),
      meta: const DocMeta(
        title: 'Profile',
        brief: 'Avatar, bio, badge, and an edit button.',
      ),
    );

/// The starter templates in display order: label → builder.
const templateBuilders = <String, ScreenDoc Function()>{
  'Blank': buildBlankTemplate,
  'Login flow': buildLoginTemplate,
  'Showcase': buildShowcaseTemplate,
  'Onboarding': buildOnboardingTemplate,
  'Settings': buildSettingsTemplate,
  'Profile': buildProfileTemplate,
};

/// One single-item node for the templates above ([row] sets the flow `y`).
CanvasNode _templateNode(
  String id,
  String screenId,
  int row,
  String kind,
  Map<String, dynamic> props, [
  NodeAction? action,
]) =>
    CanvasNode(
      id: id,
      screenId: screenId,
      x: 0.0,
      y: row * 48.0,
      items: [
        CanvasItem(
          id: 'i$id',
          kind: kind,
          props: props,
          action: action,
        ),
      ],
    );

/// Destructive-replace confirmation in the open dialog's idiom
/// (`shadcn.showDialog` + [shadcn.AlertDialog] with Cancel/Replace actions).
/// `replaceDoc` is undoable, so the copy says undo restores the design.
/// Never throws (a presentation failure denies the replace).
Future<bool> confirmReplaceDoc(
  BuildContext context,
  String templateName,
) async {
  try {
    final result = await shadcn.showDialog<bool>(
      context: context,
      builder: (_) => shadcn.AlertDialog(
        title: Text(
          'Start from $templateName?',
          style: EditorType.sectionHeader
              .copyWith(color: EditorTheme.of(context).onSurface),
        ),
        content: Text(
          'This replaces the current design. Undo restores it.',
          style: EditorType.field
              .copyWith(color: EditorTheme.of(context).onSurfaceVariant),
        ),
        actions: [
          shadcn.TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          shadcn.TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return result ?? false;
  } catch (_) {
    return false;
  }
}

/// Shows the export dialog; on download/copy actions runs the injected sink
/// (or the web/clipboard default) and reports inline. Never throws.
Future<void> showExportDialog(
  BuildContext context,
  CanvasStore store, {
  DownloadSink? onDownload,
  CopySink? onCopy,
  bool? isWebOverride,
}) async {
  try {
    await shadcn.showDialog<void>(
      context: context,
      builder: (_) => ExportDialog(
        store: store,
        onDownload: onDownload,
        onCopy: onCopy,
        isWebOverride: isWebOverride,
      ),
    );
  } catch (_) {
    // Dialog presentation must never throw to the toolbar caller.
  }
}

/// Export dialog: every code/project-file action in one place.
///
/// Share-link and prompt copies reuse the existing pure functions
/// ([encode], [buildPrompt]) — the prompt viewer itself stays in
/// `prompt_panel.dart` and is not duplicated here.
class ExportDialog extends StatefulWidget {
  final CanvasStore store;

  /// Download sink; defaults to the web Blob+anchor download with the
  /// documented non-web guard ([kNonWebDownloadMessage]).
  final DownloadSink? onDownload;

  /// Copy sink; defaults to [Clipboard.setData].
  final CopySink? onCopy;

  /// Overrides [kIsWeb] (tests run on the VM, where web is always false).
  final bool? isWebOverride;

  /// Track G4: the exporter mode the dialog opens in. The single-file path
  /// is demoted to [ExportMode.inlineSourcesExperimental]; the dialog
  /// defaults to [ExportMode.bundle]. Mode-wiring only — every option below
  /// keeps working in either mode.
  final ExportMode initialMode;

  const ExportDialog({
    super.key,
    required this.store,
    this.onDownload,
    this.onCopy,
    this.isWebOverride,
    this.initialMode = ExportMode.bundle,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  /// Inline "Copied" confirmation lifetime (mirrors `prompt_panel.dart`).
  static const _copyReset = Duration(seconds: 2);

  String? _error;
  String? _notice;
  bool _working = false;
  Timer? _copyTimer;

  /// Track G4: active exporter mode (see [ExportDialog.initialMode]).
  late ExportMode _mode;

  bool get _isWeb => widget.isWebOverride ?? kIsWeb;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _say({String? error, String? notice}) => setState(() {
        _error = error;
        _notice = notice;
      });

  Future<void> _download(List<int> bytes, String filename, String mime) async {
    if (!_isWeb) {
      _say(notice: kNonWebDownloadMessage);
      return;
    }
    setState(() => _working = true);
    try {
      await (widget.onDownload ?? downloadBytes)(bytes, filename, mime);
    } catch (e) {
      if (mounted) _say(error: 'Download failed: $e');
      return;
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (mounted) _say(notice: 'Download started: $filename');
  }

  Future<void> _copy(String text) async {
    try {
      await (widget.onCopy ??
          (String s) => Clipboard.setData(ClipboardData(text: s)))(text);
    } catch (e) {
      if (mounted) _say(error: 'Copy failed: $e');
      return;
    }
    if (mounted) _say(notice: 'Copied');
    _copyTimer?.cancel();
    _copyTimer = Timer(_copyReset, () {
      if (mounted) {
        setState(() {
          if (_notice == 'Copied') _notice = null;
        });
      }
    });
  }

  void _downloadZip() {
    final doc = widget.store.doc;
    late final BundleManifest bundle;
    try {
      bundle = buildExportBundle(doc);
    } catch (e) {
      _say(error: 'Could not build the bundle: $e');
      return;
    }
    _download(
      bundle.zipBytes,
      exportFileName(title: doc.meta.title, extension: 'zip'),
      kZipMimeType,
    );
  }

  void _downloadSingle() {
    final doc = widget.store.doc;
    late final String code;
    try {
      code = buildExportSingleFile(doc);
    } catch (e) {
      _say(error: 'Could not build the file: $e');
      return;
    }
    _download(
      utf8.encode(code),
      exportFileName(title: doc.meta.title, extension: 'dart'),
      kTextMimeType,
    );
  }

  void _copySingle() {
    late final String code;
    try {
      code = buildExportSingleFile(widget.store.doc);
    } catch (e) {
      _say(error: 'Could not build the file: $e');
      return;
    }
    _copy(code);
  }

  void _copyShareLink() {
    late final String link;
    try {
      link = encode(widget.store.doc);
    } on StateError catch (e) {
      _say(error: 'Share link too large: ${e.message}');
      return;
    } catch (e) {
      _say(error: 'Could not build the share link: $e');
      return;
    }
    _copy(link);
  }

  void _copyPrompt() {
    late final String prompt;
    try {
      prompt = buildPrompt(widget.store.doc);
    } on StateError catch (e) {
      _say(error: 'Could not build the prompt: ${e.message}');
      return;
    }
    _copy(prompt);
  }

  void _saveDocJson() {
    final doc = widget.store.doc;
    _download(
      utf8.encode(docJsonText(doc)),
      exportFileName(title: doc.meta.title, extension: 'json'),
      kTextMimeType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = EditorTheme.of(context);
    Widget option(String label, VoidCallback? onPressed) => Align(
          alignment: Alignment.centerLeft,
          child: shadcn.TextButton(
            onPressed: _working ? null : onPressed,
            child: Text(label),
          ),
        );
    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: EditorMetrics.tileGap),
          child: Text(
            title,
            style: EditorType.sectionHeader.copyWith(color: colors.onSurface),
          ),
        );
    return shadcn.AlertDialog(
      title: Text(
        'Export design',
        style: EditorType.sectionHeader.copyWith(color: colors.onSurface),
      ),
      content: ConstrainedBox(
        // The kit dialog caps width (560) but not height: bound the scroll
        // region to a viewport fraction so the option list scrolls instead
        // of overflowing short screens (a ratio, not a fixed pixel budget).
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Code, share links, and project files.',
                style:
                    EditorType.field.copyWith(color: colors.onSurfaceVariant),
              ),
              if (widget.store.doc.screens.isEmpty) ...[
                const SizedBox(height: EditorMetrics.tileGap),
                Text(
                  'Nothing to export yet — add a screen first.',
                  style:
                      EditorType.field.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              section('Code'),
              // Track G4: exporter-mode switch (mode-wiring only — every
              // option below keeps working in either mode; the switch
              // records the active path and labels the demoted single-file
              // path experimental). No dialog redesign.
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<ExportMode>(
                  segments: const [
                    ButtonSegment(
                      value: ExportMode.bundle,
                      label: Text('Project'),
                    ),
                    ButtonSegment(
                      value: ExportMode.inlineSourcesExperimental,
                      label: Text('Inline sources (experimental)'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (modes) {
                    if (modes.isNotEmpty) {
                      setState(() => _mode = modes.single);
                    }
                  },
                ),
              ),
              Text(
                _mode == ExportMode.bundle
                    ? 'Project ZIP is the supported path: clean folders '
                        'depending on flutter_shadcn_kit.'
                    : 'Inline single-file is experimental: kit sources are '
                        'inlined by the legacy linker (kept, not load-bearing).',
                style:
                    EditorType.field.copyWith(color: colors.onSurfaceVariant),
              ),
              option('Download project ZIP', _downloadZip),
              option('Download single .dart file', _downloadSingle),
              option('Copy single-file code', _copySingle),
              section('Share'),
              option('Copy share link', _copyShareLink),
              option('Copy AI prompt', _copyPrompt),
              section('Project files'),
              option('Save doc JSON to file', _saveDocJson),
              if (_error != null || _notice != null) ...[
                const SizedBox(height: EditorMetrics.tileGap),
                Text(
                  _error ?? _notice!,
                  style: EditorType.field.copyWith(
                    color: _error != null
                        ? Theme.of(context).colorScheme.error
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        shadcn.TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
