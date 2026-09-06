/// G1 contract test (Track G prep): pins the scaffold-only surface.
///
/// Asserts the new `src/emit/` types exist and behave (tagged values +
/// collapse rules, import collector, name allocator, stateful detection,
/// project shells) and documents the G2/G3/G4 contract. Direct `src/`
/// imports: barrel exports in `canvas_core.dart` land in G4 (that file is
/// outside the G1 allowlist).
library;

import 'package:canvas_core/src/emit/emit_context.dart';
import 'package:canvas_core/src/emit/project_writer.dart';
import 'package:canvas_core/src/emit/tagged_value.dart';
import 'package:canvas_core/src/emit/widget_emitter.dart';
import 'package:canvas_core/src/screen_doc.dart';
import 'package:test/test.dart';

void main() {
  group('tagged values (§6.1)', () {
    test('primitives emit literals', () {
      expect(TaggedValue.parse({r'$': 'double', 'v': 16})?.toDart('T'),
          '16.0');
      expect(
          TaggedValue.parse({r'$': 'int', 'v': 2})?.toDart('T'), '2');
      expect(
          TaggedValue.parse({r'$': 'bool', 'v': true})?.toDart('T'), 'true');
    });

    test('strings are single-quoted and escaped', () {
      expect(TaggedValue.parse({r'$': 'string', 'v': "it's"})?.toDart('T'),
          r"'it\'s'");
    });

    test('enums emit Owner.name', () {
      expect(
        TaggedValue.parse({
          r'$': 'enum',
          'v': {'owner': 'MainAxisAlignment', 'name': 'start'},
        })?.toDart('T'),
        'MainAxisAlignment.start',
      );
    });

    test('token colors resolve via theme, never a hex', () {
      final v = TaggedValue.parse({
        r'$': 'color',
        'v': {'kind': 'token', 'token': 'primary'},
      })!;
      final out = v.toDart('Theme.of(context)');
      expect(out, 'Theme.of(context).colorScheme.primary');
      expect(out, isNot(contains('#')));
      expect(out, isNot(contains('0x')));
    });

    test('literal colors emit ARGB', () {
      expect(
        TaggedValue.parse({
          r'$': 'color',
          'v': {'kind': 'literal', 'argb': 0xFFEF4444},
        })?.toDart('T'),
        'Color(0xFFEF4444)',
      );
    });

    test('edgeInsets collapse: all / symmetric / fromLTRB / zero', () {
      EdgeInsetsValue insets(double l, double t, double r, double b) =>
          EdgeInsetsValue(left: l, top: t, right: r, bottom: b);
      expect(insets(16, 16, 16, 16).toDart('T'), 'EdgeInsets.all(16)');
      expect(insets(16, 8, 16, 8).toDart('T'),
          'EdgeInsets.symmetric(horizontal: 16, vertical: 8)');
      expect(insets(16, 8, 4, 2).toDart('T'),
          'EdgeInsets.fromLTRB(16, 8, 4, 2)');
      expect(insets(0, 0, 0, 0).toDart('T'), 'EdgeInsets.zero');
    });

    test('uniform radius collapses to circular', () {
      const uniform = BorderRadiusValue(
          topLeft: 12, topRight: 12, bottomRight: 12, bottomLeft: 12);
      expect(uniform.toDart('T'), 'BorderRadius.circular(12)');
      const mixed = BorderRadiusValue(
          topLeft: 12, topRight: 4, bottomRight: 4, bottomLeft: 4);
      expect(mixed.toDart('T'), contains('BorderRadius.only('));
    });

    test('alignment collapses to named constants', () {
      expect(const AlignmentValue(0, -1).toDart('T'), 'Alignment.topCenter');
      expect(const AlignmentValue(0, 0).toDart('T'), 'Alignment.center');
      expect(const AlignmentValue(0.5, 0.25).toDart('T'),
          'Alignment(0.5, 0.25)');
    });

    test('icon / asset / textStyle', () {
      expect(
          TaggedValue.parse({r'$': 'icon', 'v': 'add'})?.toDart('T'),
          'Icons.add');
      expect(
          TaggedValue.parse(
              {r'$': 'asset', 'v': 'assets/logo.png'})?.toDart('T'),
          "'assets/logo.png'");
      expect(
        TaggedValue.parse({
          r'$': 'textStyle',
          'v': {'token': 'titleLarge'},
        })?.toDart('Theme.of(context)'),
        'Theme.of(context).textTheme.titleLarge',
      );
    });

    test('unknown tags and malformed envelopes parse to null (never throw)',
        () {
      expect(TaggedValue.parse({'no': 'envelope'}), isNull);
      expect(TaggedValue.parse({r'$': 'nope', 'v': 1}), isNull);
      expect(TaggedValue.parse({r'$': 'double', 'v': 'x'}), isNull);
      expect(TaggedValue.parse(null), isNull);
    });

    test('§6.3 worked example: collapsed insets + token color + radius', () {
      final padding = TaggedValue.parse({
        r'$': 'edgeInsets',
        'v': {'l': 16, 't': 16, 'r': 16, 'b': 16},
      })!;
      final color = TaggedValue.parse({
        r'$': 'color',
        'v': {'kind': 'token', 'token': 'primary'},
      })!;
      final radius = TaggedValue.parse({
        r'$': 'borderRadius',
        'v': {'tl': 12, 'tr': 12, 'br': 12, 'bl': 12},
      })!;
      const theme = 'Theme.of(context)';
      expect(padding.toDart(theme), 'EdgeInsets.all(16)');
      expect(color.toDart(theme), '$theme.colorScheme.primary');
      expect(radius.toDart(theme), 'BorderRadius.circular(12)');
    });
  });

  group('EmitContext (§6.4)', () {
    test('import collector dedupes and orders dart/package/relative', () {
      final imports = ImportCollector()
        ..add('package:b/b.dart')
        ..add('dart:async')
        ..add('package:a/a.dart')
        ..add('package:a/a.dart')
        ..add('widgets/foo.dart');
      expect(imports.lines, [
        "import 'dart:async';",
        "import 'package:a/a.dart';",
        "import 'package:b/b.dart';",
        "import 'widgets/foo.dart';",
      ]);
    });

    test('import collector supports as-prefixes', () {
      final imports = ImportCollector()..add('package:t/t.dart', asPrefix: 't');
      expect(imports.lines, ["import 'package:t/t.dart' as t;"]);
    });

    test('import collector renders hide/show combinators, unions re-adds',
        () {
      final imports = ImportCollector()
        ..add('package:k/k.dart', hide: const ['Theme', 'Column'])
        ..add('package:k/k.dart', hide: const ['Column', 'Row'])
        ..add('package:s/s.dart', asPrefix: 's', show: const ['A']);
      expect(imports.lines, [
        "import 'package:k/k.dart' hide Column, Row, Theme;",
        "import 'package:s/s.dart' as s show A;",
      ]);
      // Conflicting prefixes keep the first registration; hides merge.
      final prefixed = ImportCollector()
        ..add('package:t/t.dart', asPrefix: 'a', hide: const ['X'])
        ..add('package:t/t.dart', asPrefix: 'b', hide: const ['Y']);
      expect(prefixed.lines, ["import 'package:t/t.dart' as a hide X, Y;"]);
    });

    test('overlong imports wrap before each combinator (dart format shape)',
        () {
      final imports = ImportCollector()
        ..add(
          'package:flutter_shadcn_kit/flutter_shadcn_kit.dart',
          hide: const [
            'Column',
            'Expanded',
            'Flex',
            'Flexible',
            'Positioned',
            'Row',
            'Stack',
            'Theme',
          ],
        );
      expect(imports.lines, [
        "import 'package:flutter_shadcn_kit/flutter_shadcn_kit.dart'\n"
            '    hide Column, Expanded, Flex, Flexible, Positioned, Row,'
            ' Stack, Theme;',
      ]);
    });

    test('name allocator is unique, sanitized, digit-guarded', () {
      final names = NameAllocator();
      expect(names.allocate('emailController'), 'emailController');
      expect(names.allocate('emailController'), 'emailController2');
      expect(names.allocate('email-controller!'), 'emailcontroller');
      expect(names.allocate('9lives'), '_9lives');
      expect(names.allocate('class'), isNot('class'));
    });

    test('unbound emitChild throws a descriptive StateError', () {
      final ctx = EmitContext();
      final node = CanvasNode(
          id: 'n1', screenId: 's1', x: 0, y: 0, items: const []);
      expect(() => ctx.emitChild(node), throwsStateError);
    });

    test('bound emitChild recurses via the driver', () {
      final ctx = EmitContext()
        ..emitNode = (node) => 'Text(${node.id})';
      final node = CanvasNode(
          id: 'n1', screenId: 's1', x: 0, y: 0, items: const []);
      expect(ctx.emitChild(node), 'Text(n1)');
    });
  });

  group('EmitterRegistry (§8.2 shape)', () {
    test('register/lookup/hasRealEmitter round-trip', () {
      final registry = EmitterRegistry()..register(_FakeTextEmitter());
      expect(registry.hasRealEmitter('text'), isTrue);
      expect(registry.hasRealEmitter('button'), isFalse);
      expect(registry.lookup('text'), isA<_FakeTextEmitter>());
      expect(registry.emitterCount, 1);
    });

    test('driftKinds tracks bound kinds without emitters (gate 7)', () {
      final registry = EmitterRegistry()
        ..registerBinding(const KindBinding(
          type: 'button',
          isContainer: false,
          renderDescription: 'catalog buildButton',
        ));
      expect(registry.driftKinds, contains('button'));
      registry.register(_FakeButtonEmitter());
      expect(registry.driftKinds, isEmpty);
    });

    test('placeholder is honest text, never a crash', () {
      expect(placeholderFor('frobnicate'), contains('frobnicate'));
    });
  });

  group('project writer (§8.4)', () {
    test('slugify is lower_snake and digit-guarded', () {
      expect(slugifyScreen('Login Screen'), 'login_screen');
      expect(slugifyScreen('9 lives!'), 'screen_9_lives');
      expect(slugifyScreen(''), 'screen');
    });

    test('stateful detection: text_field/switch/checkbox/tabs force a model',
        () {
      for (final kind in kCertainStatefulKinds) {
        expect(needsModel(['button', kind]), isTrue, reason: kind);
      }
      expect(needsModel(['button', 'card', 'text']), isFalse);
    });

    test('stateless pages get no model file; stateful pages do', () {
      final stateless = buildPageFile(
        slug: 'home',
        needsModelFlag: false,
        body: 'const Text(1)',
        importLines: const [],
      );
      expect(stateless, contains('extends StatelessWidget'));
      expect(stateless, isNot(contains('Model')));
      final stateful = buildPageFile(
        slug: 'login',
        needsModelFlag: true,
        body: 'const Text(1)',
        importLines: const [],
      );
      expect(stateful, contains('extends StatefulWidget'));
      expect(stateful, contains('LoginModel'));
      expect(stateful, contains('initState'));
      expect(stateful, contains('dispose'));
      expect(pageFilePath('login'),
          'lib/pages/login/login_page.dart');
      expect(modelFilePath('login'),
          'lib/pages/login/login_model.dart');
    });

    test('model shell wires controllers + dispose', () {
      final model = buildModelFile(
        slug: 'login',
        controllerNames: const ['emailController'],
        boolFields: const ['rememberMe'],
      );
      expect(model, contains('class LoginModel'));
      expect(model, contains('emailController.dispose()'));
      expect(model, contains('bool rememberMe = false'));
    });

    test('responsiveLeaf never duplicates subtrees', () {
      expect(responsiveLeaf(base: 'EdgeInsets.all(16)'), 'EdgeInsets.all(16)');
      expect(
        responsiveLeaf(base: 'EdgeInsets.all(16)', md: 'EdgeInsets.all(32)'),
        'responsiveValue(context, base: EdgeInsets.all(16), '
        'md: EdgeInsets.all(32))',
      );
      expect(
        responsiveLeaf(base: 'EdgeInsets.all(16)', md: 'EdgeInsets.all(16)'),
        'EdgeInsets.all(16)',
      );
    });

    test('pubspec pins kit always, go_router only when multi-screen', () {
      final single = buildPubspec(appName: 'app', screenCount: 1);
      expect(single, contains('flutter_shadcn_kit'));
      expect(single, isNot(contains('go_router')));
      final multi = buildPubspec(appName: 'app', screenCount: 2);
      expect(multi, contains('go_router'));
    });

    test('scaffoldProject emits the §8.4 file shape', () {
      final doc = ScreenDoc(
        screens: const [
          CanvasScreen(id: 's1', name: 'Home', x: 0, y: 0, bg: '#fff'),
        ],
        nodes: const [],
        theme: const CanvasTheme(
            paletteKey: 'default', dark: false, shape: 'm', motion: 'm'),
        meta: const DocMeta(title: '', brief: ''),
        states: const [],
      );
      final files =
          scaffoldProject(appName: 'demo', doc: doc).map((f) => f.path);
      expect(
        files,
        containsAll([
          'pubspec.yaml',
          'analysis_options.yaml',
          'lib/main.dart',
          'lib/theme/app_theme.dart',
        ]),
      );
      expect(files, isNot(contains('lib/routes/app_router.dart')));
    });
  });
}

class _FakeTextEmitter implements WidgetEmitter {
  @override
  String get type => 'text';

  @override
  String emit(
    CanvasItem item,
    CanvasNode node,
    List<String> childExprs,
    EmitContext ctx,
  ) =>
      'Text(1)';
}

class _FakeButtonEmitter implements WidgetEmitter {
  @override
  String get type => 'button';

  @override
  String emit(
    CanvasItem item,
    CanvasNode node,
    List<String> childExprs,
    EmitContext ctx,
  ) =>
      'Button()';
}
