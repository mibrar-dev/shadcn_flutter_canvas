import 'package:canvas_app/canvas/component_catalog.dart';
import 'package:canvas_app/shadcn_ui.dart' as shadcn;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog seeds five entries with labels and defaults', () {
    expect(
      kCatalog.map((e) => e.kind),
      containsAll(['button', 'card', 'input', 'badge', 'switch']),
    );
    expect(kCatalog, hasLength(5));
    for (final entry in kCatalog) {
      expect(entry.label, isNotEmpty, reason: '${entry.kind} label');
      expect(entry.defaults, isNotEmpty, reason: '${entry.kind} defaults');
    }
    expect(findEntry('button'), isNotNull);
    expect(findEntry('nope'), isNull);
  });

  test('button defaults mirror plan Task 3 JSON', () {
    expect(findEntry('button')!.defaults, {
      'label': 'Button',
      'variant': 'primary',
      'size': 'md',
      'disabled': false,
    });
  });

  test('button builder maps variants to real widgets', () {
    const base = {'label': 'Go', 'size': 'md', 'disabled': false};
    expect(
      buildCatalogItem('button', {...base, 'variant': 'primary'}),
      isA<shadcn.PrimaryButton>(),
    );
    expect(
      buildCatalogItem('button', {...base, 'variant': 'secondary'}),
      isA<shadcn.SecondaryButton>(),
    );
    expect(
      buildCatalogItem('button', {...base, 'variant': 'outline'}),
      isA<shadcn.OutlineButton>(),
    );
    expect(
      buildCatalogItem('button', {...base, 'variant': 'ghost'}),
      isA<shadcn.GhostButton>(),
    );
    expect(
      buildCatalogItem('button', {...base, 'variant': 'destructive'}),
      isA<shadcn.DestructiveButton>(),
    );
    expect(
      buildCatalogItem('button', {...base, 'variant': 'link'}),
      isA<shadcn.LinkButton>(),
    );
    // Unknown variants fall back to primary, never crash.
    expect(
      buildCatalogItem('button', {...base, 'variant': 'bogus'}),
      isA<shadcn.PrimaryButton>(),
    );
  });

  testWidgets('button renders label for every variant', (tester) async {
    for (final variant in [
      'primary',
      'secondary',
      'outline',
      'ghost',
      'destructive',
      'link',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('button', {
              'label': 'Go',
              'variant': variant,
              'size': 'md',
              'disabled': false,
            }),
          ),
        ),
      );
      expect(find.text('Go'), findsOneWidget);
    }
  });

  testWidgets('card renders title, description, and optional footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('card', {
            'title': 'T',
            'description': 'D',
            'showFooter': true,
          }),
        ),
      ),
    );
    expect(find.byType(shadcn.Card), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildCatalogItem('card', {'showFooter': false})),
      ),
    );
    expect(find.text('Action'), findsNothing);
  });

  testWidgets('input renders placeholder and optional label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildCatalogItem('input', {
            'placeholder': 'Type here',
            'label': 'Email',
            'disabled': false,
            'obscure': false,
          }),
        ),
      ),
    );
    expect(find.byType(shadcn.TextField), findsOneWidget);
    expect(find.text('Type here'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('badge renders every style', (tester) async {
    const styles = {
      'primary': shadcn.PrimaryBadge,
      'secondary': shadcn.SecondaryBadge,
      'destructive': shadcn.DestructiveBadge,
      'outline': shadcn.OutlineBadge,
    };
    for (final style in styles.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildCatalogItem('badge', {
              'label': 'New',
              'variant': style.key,
            }),
          ),
        ),
      );
      expect(find.byType(style.value), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    }
  });

  testWidgets('switch renders and toggles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildCatalogItem('switch', {'value': false})),
      ),
    );
    expect(find.byType(shadcn.Switch), findsOneWidget);
    await tester.tap(find.byType(shadcn.Switch));
    await tester.pump();
    expect(tester.widget<shadcn.Switch>(find.byType(shadcn.Switch)).value, isTrue);
  });

  testWidgets('builders tolerate empty props (defaults kick in)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              buildCatalogItem('button', {}),
              buildCatalogItem('input', {}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Button'), findsOneWidget);
    expect(find.text('Type here'), findsOneWidget);
  });

  testWidgets('fallbackBuilder renders placeholder plus kind label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildCatalogItem('mystery', {}))),
    );
    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.text('unknown: mystery'), findsOneWidget);
  });
}
