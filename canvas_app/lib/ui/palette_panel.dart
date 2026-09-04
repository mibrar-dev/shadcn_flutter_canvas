/// Left-rail palette of draggable catalog tiles.
///
/// Dogfooding rule: tiles use registry widgets ([shadcn.Card] + badges) via
/// `lib/shadcn_ui.dart` — no raw Material or Cupertino widgets in here.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;

/// Draggable tile list for every catalog entry.
class PalettePanel extends StatelessWidget {
  final List<CatalogEntry>? entries;

  const PalettePanel({super.key, this.entries});

  List<CatalogEntry> get _entries => entries ?? kCatalog;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      shrinkWrap: true,
      children: [
        for (final entry in _entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Draggable<String>(
              data: entry.kind,
              feedback: SizedBox(width: 200, child: _tile(entry)),
              childWhenDragging: Opacity(opacity: 0.4, child: _tile(entry)),
              child: _tile(entry),
            ),
          ),
      ],
    );
  }

  Widget _tile(CatalogEntry entry) {
    return shadcn.Card(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          shadcn.PrimaryBadge(child: Text(entry.kind)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
