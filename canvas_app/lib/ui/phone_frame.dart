/// Fixed 390x844 phone frame rendering one screen's nodes.
///
/// Content area is exempt from the chrome dogfooding rule (user content), but
/// it still builds nodes through [buildCatalogItem], so unknown kinds render
/// [fallbackBuilder] output instead of crashing.
library;

import 'package:flutter/material.dart';

import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/canvas/screen_doc.dart';

/// Phone-sized canvas surface for a single [screen].
class PhoneFrame extends StatelessWidget {
  final CanvasScreen screen;
  final List<CanvasNode> nodes;
  final String? selectedNodeId;
  final ValueChanged<String>? onSelectNode;

  const PhoneFrame({
    super.key,
    required this.screen,
    required this.nodes,
    this.selectedNodeId,
    this.onSelectNode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 390,
        height: 844,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                for (final node in nodes)
                  Positioned(
                    left: node.x,
                    top: node.y,
                    child: GestureDetector(
                      onTap: () => onSelectNode?.call(node.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: node.id == selectedNodeId
                            ? BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final item in node.items)
                              buildCatalogItem(item.kind, item.props),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
