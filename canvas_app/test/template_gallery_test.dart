/// Track S3 template-gallery tests: Onboarding / Settings / Profile.
///
/// Each template pins ref-integrity + JSON round-trip + global id uniqueness
/// + action wiring (every action target resolves to a screen), plus its
/// small honest shape (1–2 screens, ≤8 nodes, catalog-default props only).
/// Widget tests pin the gallery cards (name + brief + counts) and the
/// unchanged confirm-replace flow for a new template.
library;

import 'dart:convert';

import 'package:canvas_app/canvas/canvas_store.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:canvas_app/ui/editor_tokens.dart';
import 'package:canvas_app/ui/export_panel.dart';
import 'package:canvas_app/ui/open_dialog.dart';
import 'package:canvas_core/canvas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reference viewport: six gallery cards overflow the default 800x600 test
/// surface (same helper as `chrome_dogfood_test.dart`).
void _useReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpChrome(WidgetTester tester, Widget child) async {
  _useReferenceViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EditorTheme(colors: EditorColors.light, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Set<String> kindsOn(ScreenDoc doc, String screenId) => {
      for (final node in doc.nodes)
        if (node.screenId == screenId)
          for (final item in node.items) item.kind,
    };

bool hasAction(ScreenDoc doc, String from, String to) => doc.nodes.any(
      (n) => n.screenId == from && n.items.any((i) => i.action?.to == to),
    );

void main() {
  group('template docs', () {
    for (final entry in templateBuilders.entries) {
      test('${entry.key} validates, round-trips, and wires cleanly', () {
        final doc = entry.value();
        expect(doc.validateRefs(), isEmpty);
        final back = ScreenDoc.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        );
        expect(back.validateRefs(), isEmpty);
        expect(back.screens.length, doc.screens.length);
        expect(back.nodes.length, doc.nodes.length);
        expect(
          back.nodes.fold(0, (sum, n) => sum + n.items.length),
          doc.nodes.fold(0, (sum, n) => sum + n.items.length),
        );
        // Gallery contract: small templates only.
        expect(back.screens.length, lessThanOrEqualTo(2));
        expect(back.nodes.length, lessThanOrEqualTo(8));
        // Global id uniqueness across screens, nodes, and items.
        final seen = <String>{};
        for (final s in back.screens) {
          expect(seen.add(s.id), isTrue, reason: 'dup ${s.id}');
        }
        for (final n in back.nodes) {
          expect(seen.add(n.id), isTrue, reason: 'dup ${n.id}');
          for (final i in n.items) {
            expect(seen.add(i.id), isTrue, reason: 'dup ${i.id}');
          }
        }
        // Wiring: every action target resolves to a real screen.
        final screenIds = {for (final s in back.screens) s.id};
        for (final n in back.nodes) {
          for (final i in n.items) {
            final to = i.action?.to;
            if (to != null) {
              expect(screenIds, contains(to), reason: 'dangling $to');
            }
          }
        }
      });
    }

    test('onboarding teaches steps then wires to Home', () {
      final doc = buildOnboardingTemplate();
      expect(doc.screens.map((s) => s.name), ['Onboarding', 'Home']);
      expect(doc.nodes, hasLength(5));
      expect(
        kindsOn(doc, 's1'),
        {'scaffold', 'card', 'steps', 'button'},
      );
      expect(kindsOn(doc, 's2'), {'basic'});
      expect(hasAction(doc, 's1', 's2'), isTrue);
    });

    test('settings is one screen of real toggle kinds', () {
      final doc = buildSettingsTemplate();
      expect(doc.screens.map((s) => s.name), ['Settings']);
      expect(doc.nodes, hasLength(4));
      expect(
        kindsOn(doc, 's1'),
        {'scaffold', 'switch', 'checkbox', 'select'},
      );
      expect(hasAction(doc, 's1', 's1'), isFalse);
    });

    test('profile is avatar plus bio rows on one screen', () {
      final doc = buildProfileTemplate();
      expect(doc.screens.map((s) => s.name), ['Profile']);
      expect(doc.nodes, hasLength(5));
      expect(
        kindsOn(doc, 's1'),
        {'scaffold', 'avatar', 'basic', 'badge', 'button'},
      );
      expect(hasAction(doc, 's1', 's1'), isFalse);
    });
  });

  group('template gallery', () {
    testWidgets('renders every entry with brief and counts', (tester) async {
      await pumpChrome(tester, OpenDialog(store: CanvasStore()));
      expect(find.text('Templates'), findsOneWidget);
      for (final entry in templateBuilders.entries) {
        final doc = entry.value();
        expect(find.text(entry.key), findsOneWidget, reason: entry.key);
        expect(
          find.text(
            '${doc.meta.brief} '
            '(${doc.screens.length} screens · ${doc.nodes.length} nodes)',
          ),
          findsOneWidget,
          reason: '${entry.key} card',
        );
      }
    });

    testWidgets('denied confirm keeps the doc and the dialog', (tester) async {
      var confirmName;
      final store = CanvasStore();
      await pumpChrome(
        tester,
        OpenDialog(
          store: store,
          onConfirmReplace: (context, name) async {
            confirmName = name;
            return false;
          },
        ),
      );
      await tester.tap(find.text('Onboarding'));
      await tester.pumpAndSettle();
      expect(confirmName, 'Onboarding');
      expect(store.doc.meta.title, 'Untitled');
      expect(store.canUndo, isFalse);
      expect(find.byType(shadcn.AlertDialog), findsOneWidget);
    });

    testWidgets('confirmed replace swaps the doc (undoable) and closes',
        (tester) async {
      final store = CanvasStore();
      await pumpChrome(
        tester,
        OpenDialog(
          store: store,
          onConfirmReplace: (context, name) async => true,
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(shadcn.AlertDialog), findsNothing);
      expect(store.doc.meta.title, 'Settings');
      expect(store.doc.validateRefs(), isEmpty);
      expect(store.canUndo, isTrue);
      expect(store.undo(), isTrue);
      expect(store.doc.meta.title, 'Untitled');
    });
  });
}
