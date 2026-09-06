/// Track G2: `code_builder` migration tests (mechanical, per kind — NOT a
/// redesign).
///
/// * `toExpression`: the §6.1 tagged-value → AST bridge against HAND-WRITTEN
///   raw sources (golden-first for the new layer: no expected string here
///   was produced by running an emitter).
/// * `parity`: each of the 10 primitive AST emitters against its legacy
///   `_bundleX` string output, compared FORMAT-NORMALIZED (both sides
///   through `dart_style` with comments stripped): same program, two
///   mechanisms. Byte-identity is explicitly NOT claimed — the legacy path
///   hand-shapes multi-line blocks, the AST path is canonical post-format
///   (the G4 cutover re-bases goldens post-format; see docs/BUILD_G2_*.md).
/// * `page wiring`: needsModel/model-plan/responsive-leaf assembly.
/// * `fixtures`: the four hand-written `g2_*.json` → `.expected.dart` pairs,
///   byte-exact, plus whole-file reformat idempotence (gate-3 direction).
library;

import 'dart:convert';
import 'dart:io';

import 'package:canvas_core/canvas_core.dart';
import 'package:code_builder/code_builder.dart' hide EnumValue;
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';

/// Raw (unformatted) source of an AST node: deterministic by construction,
/// so hand-written expectations are meaningful without a format pass.
String _raw(Expression e) => e.accept(DartEmitter()).toString();

/// Raw source of a tagged envelope through the AST bridge.
String _taggedRaw(Map<String, Object?> envelope, [String theme = 'T']) =>
    _raw(TaggedValue.parse(envelope)!.toExpression(theme));

/// Format-normalized program form: comments stripped (trace comments are
/// byte-level, pinned by the golden fixtures — parity is program-level),
/// then trailing commas before closers removed on BOTH sides (the legacy
/// path hand-shapes full splits with trailing commas; the AST path lets
/// `dart_style` lay out — without them both collapse/split identically),
/// wrapped in the same stub and formatted.
String _norm(String src) {
  final uncommented = src
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
  // NOTE: Dart's replaceAll has no $1 backreferences — mapped form.
  // The newline is optional so single-line emitter raws (`Alignment(0.5,
  // 0.25, )`) normalize too.
  final uncomma = uncommented
      .replaceAllMapped(
        RegExp(r',(\s*\n?\s*[)\]}])'),
        (m) => m.group(1)!,
      )
      .replaceAll(RegExp(r',\s*$'), '');
  return DartFormatter().format('final _v = $uncomma;\n');
}

ScreenDoc _doc(
  String kind,
  Map<String, dynamic> itemProps, [
  List<String> kidTexts = const [],
  Map<String, dynamic>? nodeExtras,
]) {
  return ScreenDoc.fromJson({
    'screens': [
      {'id': 's1', 'name': 'P', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
    ],
    'nodes': [
      {
        'id': 'n0',
        'screenId': 's1',
        'x': 0.0,
        'y': 0.0,
        ...?nodeExtras,
        'items': [
          {'id': 'i0', 'kind': kind, ...itemProps},
        ],
      },
      for (var i = 0; i < kidTexts.length; i++)
        {
          'id': 'k$i',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'parentId': 'n0',
          'items': [
            {'id': 'ik$i', 'kind': 'text', 'text': kidTexts[i]},
          ],
        },
    ],
    'theme': {
      'paletteKey': 'slate',
      'dark': false,
      'shape': 'rounded',
      'motion': 'standard',
    },
    'meta': {'title': 'P', 'brief': ''},
  });
}

/// Legacy bundle body at depth 0 (mirrors the F3 harness: 6-space screen
/// indent stripped; canonical-indentation invariant re-pinned here).
String _legacyBodyOf(ScreenDoc doc) {
  final bundle = buildCleanBundle(doc, const {});
  final path = bundle.files.keys.singleWhere(
    (k) => k.startsWith('lib/ui/screens/'),
  );
  final lines = bundle.files[path]!.split('\n');
  final start = lines.indexWhere((l) => l == '      children: [');
  expect(start, greaterThanOrEqualTo(0));
  const footer = ['      ],', '    );', '  }', '}', ''];
  expect(lines.sublist(lines.length - footer.length), footer);
  return lines
      .sublist(start + 1, lines.length - footer.length)
      .map((l) => l.substring(6))
      .join('\n');
}

/// AST-side body for [doc]'s root node: kid blocks stand in as opaque
/// [Code] (the legacy `text` emission, pinned by F3 — hand-transcribed, not
/// generated: `WrappedText(child: Text('…'))`).
String _astBodyOf(ScreenDoc doc, AstEmitter emitter) {
  final node = doc.nodes.firstWhere((n) => n.id == 'n0');
  final item = node.items.single;
  final kids = [
    for (final n in doc.nodes)
      if (n.parentId == 'n0')
        CodeExpression(Code(
          "WrappedText(child: Text('${(n.items.single.props['text'] as String)}'))",
        )),
  ];
  return formatExpression(
    emitter.emitExpr(item, node, kids, EmitContext()),
  );
}

void _expectParity(
  String kind,
  Map<String, dynamic> props, [
  List<String> kids = const [],
  Map<String, dynamic>? nodeExtras,
]) {
  final doc = _doc(kind, props, kids, nodeExtras);
  final emitter = primitiveEmitters.singleWhere((e) => e.type == kind);
  expect(
    _norm(_astBodyOf(doc, emitter)),
    _norm(_legacyBodyOf(doc)),
    reason: '$kind parity ${jsonEncode(props)} kids=$kids',
  );
}

ScreenDoc _fixtureDoc(String name) => ScreenDoc.fromJson(
      jsonDecode(
        File('test/fixtures/$name.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

/// Expected page/model code: the `.expected.dart` fixture minus its
/// non-compiled doc header (everything through the `library;` line — the
/// same mechanism as F's golden, which the analyzer needs but emission
/// never produces).
String _fixtureExpected(String name) {
  final lines =
      File('test/fixtures/$name.expected.dart').readAsStringSync().split('\n');
  final lib = lines.indexWhere((l) => l == 'library;');
  expect(lib, greaterThanOrEqualTo(0));
  return lines.sublist(lib + 1).join('\n').trimLeft();
}

void main() {
  group('g2 toExpression (§6.1 bridge, hand-written raw sources)', () {
    test('token colors compose the theme chain, never a hex', () {
      final out = _taggedRaw({
        r'$': 'color',
        'v': {'kind': 'token', 'token': 'primary'},
      }, 'Theme.of(context)');
      expect(out, 'Theme.of(context).colorScheme.primary');
      expect(out, isNot(contains('0x')));
    });

    test('literal colors stay ARGB', () {
      expect(
        _taggedRaw({
          r'$': 'color',
          'v': {'kind': 'literal', 'argb': 0xFFEF4444},
        }),
        'Color(0xFFEF4444)',
      );
    });

    test('scalars mirror toDart', () {
      expect(_taggedRaw({r'$': 'double', 'v': 16}), '16.0');
      expect(_taggedRaw({r'$': 'int', 'v': 2}), '2');
      expect(_taggedRaw({r'$': 'bool', 'v': true}), 'true');
      expect(_taggedRaw({r'$': 'string', 'v': 'Hi'}), "'Hi'");
      expect(
        _taggedRaw({
          r'$': 'enum',
          'v': {'owner': 'MainAxisAlignment', 'name': 'start'},
        }),
        'MainAxisAlignment.start',
      );
    });

    test('edgeInsets collapse in the bridge', () {
      Map<String, Object?> insets(int l, int t, int r, int b) => {
            r'$': 'edgeInsets',
            'v': {'l': l, 't': t, 'r': r, 'b': b},
          };
      expect(_taggedRaw(insets(16, 16, 16, 16)), 'const EdgeInsets.all(16)');
      expect(
        _taggedRaw(insets(16, 8, 16, 8)),
        'const EdgeInsets.symmetric(horizontal: 16, vertical: 8)',
      );
      expect(
        _taggedRaw(insets(16, 8, 4, 2)),
        'const EdgeInsets.fromLTRB(16, 8, 4, 2)',
      );
      expect(_taggedRaw(insets(0, 0, 0, 0)), 'EdgeInsets.zero');
    });

    test('radius + alignment collapse in the bridge', () {
      Map<String, Object?> radius(int tl, int tr, int br, int bl) => {
            r'$': 'borderRadius',
            'v': {'tl': tl, 'tr': tr, 'br': br, 'bl': bl},
          };
      expect(
        _taggedRaw(radius(12, 12, 12, 12)),
        'const BorderRadius.circular(12)',
      );
      expect(
        _taggedRaw(radius(12, 4, 4, 4)),
        contains('BorderRadius.only('),
      );
      expect(
        _taggedRaw({
          r'$': 'alignment',
          'v': {'x': 0.0, 'y': -1.0},
        }),
        'Alignment.topCenter',
      );
      expect(
        _norm(_raw(TaggedValue.parse({
          r'$': 'alignment',
          'v': {'x': 0.5, 'y': 0.25},
        })!.toExpression('T'))),
        _norm('Alignment(0.5, 0.25)'),
      );
    });

    test('icon / asset / textStyle compose accessors', () {
      expect(_taggedRaw({r'$': 'icon', 'v': 'add'}), 'Icons.add');
      expect(
        _taggedRaw({r'$': 'asset', 'v': 'assets/logo.png'}),
        "'assets/logo.png'",
      );
      expect(
        _taggedRaw({
          r'$': 'textStyle',
          'v': {'token': 'titleLarge'},
        }, 'Theme.of(context)'),
        'Theme.of(context).textTheme.titleLarge',
      );
    });

    test('custom theme accessors flow through', () {
      expect(
        _taggedRaw({
          r'$': 'color',
          'v': {'kind': 'token', 'token': 'primary'},
        }, 'T'),
        'T.colorScheme.primary',
      );
    });

    test('§6.3 worked-example trio as one raw AST source', () {
      final ctx = EmitContext();
      final expr = const ContainerEmitter().emitExpr(
        CanvasItem.fromJson({
          'id': 'c',
          'kind': 'container',
          'padding': {
            r'$': 'edgeInsets',
            'v': {'l': 16, 't': 16, 'r': 16, 'b': 16},
          },
          'color': {
            r'$': 'color',
            'v': {'kind': 'token', 'token': 'primary'},
          },
          'radius': {
            r'$': 'borderRadius',
            'v': {'tl': 12, 'tr': 12, 'br': 12, 'bl': 12},
          },
        }),
        CanvasNode(id: 'n', screenId: 's', x: 0, y: 0, items: const []),
        [
          CodeExpression(Code(
            "Text('Hello', style: Theme.of(context).textTheme.titleLarge)",
          )),
        ],
        ctx,
      );
      // Hand-specified per §6.3 (behavioral fragments, never transcribed
      // from emitter output): collapsed insets, const insertion, ONE
      // BoxDecoration (§6.2), token accessors — never a hex. Layout
      // (trailing commas, splits) is the formatter's business, pinned by
      // the page fixtures instead.
      final raw = _raw(expr);
      expect(raw, startsWith('Container('));
      expect(raw, contains('padding: const EdgeInsets.all(16)'));
      expect(
        'BoxDecoration('.allMatches(raw).length,
        1,
        reason: '§6.2: color + radius fuse into ONE decoration',
      );
      expect(raw, contains('color: Theme.of(context).colorScheme.primary'));
      expect(raw, contains('borderRadius: BorderRadius.circular(12)'));
      expect(raw, isNot(contains('0x')));
      expect(raw, isNot(contains('#')));
      expect(
        raw,
        contains(
          "child: Text('Hello', style: Theme.of(context).textTheme.titleLarge)",
        ),
      );
    });
  });

  group('g2 formatExpression (one dart_style pass)', () {
    test('short expressions stay one line', () {
      expect(
        formatExpression(refer('Spacer').newInstance([], {})),
        'Spacer()',
      );
    });

    test('constOf prefixes deterministically', () {
      expect(
        _raw(constOf(refer('EdgeInsets').newInstanceNamed('all', [
          CodeExpression(Code('16')),
        ]))),
        'const EdgeInsets.all(16)',
      );
    });

    test('long expressions split at depth 0', () {
      final out = formatExpression(
        refer('Container').newInstance([], {
          'color': CodeExpression(
              Code('Theme.of(context).colorScheme.primary')),
          'padding': CodeExpression(Code('const EdgeInsets.all(16)')),
        }),
      );
      expect(out, startsWith('Container(\n'));
      expect(out, contains('\n  color: '));
      expect(out, endsWith('\n)'));
    });
  });

  group('g2 importDirectives (collector → AST)', () {
    test('dart/package/relative order + as-prefixes survive', () {
      final collector = ImportCollector()
        ..add('package:kit/tabs.dart', asPrefix: 'tabs')
        ..add('package:flutter/material.dart')
        ..add('dart:async')
        ..add('pages/home/home_model.dart');
      final lines = [
        for (final d in importDirectives(collector))
          d.accept(DartEmitter()).toString(),
      ];
      expect(lines, [
        "import 'dart:async';",
        "import 'package:flutter/material.dart';",
        "import 'package:kit/tabs.dart' as tabs;",
        "import 'pages/home/home_model.dart';",
      ]);
    });
  });

  group('g2 primitiveRegistry (§8.2 mechanics)', () {
    test('all ten primitives registered with bindings', () {
      final registry = primitiveRegistry();
      expect(registry.emitterCount, 10);
      for (final kind in primitiveContainerKinds.followedBy(['spacer'])) {
        expect(registry.hasRealEmitter(kind), isTrue, reason: kind);
      }
      expect(registry.driftKinds, isEmpty);
    });

    test('container binding carries its correctness rules', () {
      final registry = primitiveRegistry();
      expect(registry.boundKinds, contains('container'));
    });

    test('adapters format canonically', () {
      final ctx = EmitContext();
      final adapter = ExprAdapter(const SpacerEmitter());
      final out = adapter.emit(
        const CanvasItem(id: 's', kind: 'spacer'),
        CanvasNode(id: 'n', screenId: 's', x: 0, y: 0, items: const []),
        const [],
        ctx,
      );
      expect(out, 'const Spacer()');
      expect(ctx.imports.lines,
          ["import 'package:flutter/material.dart';"]);
    });
  });

  group('g2 parity: AST emitters vs legacy _bundleX (format-normalized)', () {
    test('container: bare / literal color / token color', () {
      _expectParity('container', {});
      _expectParity('container', {'color': 0xFFEF4444});
      _expectParity('container', {
        'color': {
          r'$': 'color',
          'v': {'kind': 'token', 'token': 'primary'},
        },
      });
    });

    test('container: §6.2 decoration merge (token + radius + padding)', () {
      _expectParity('container', {
        'padding': {
          r'$': 'edgeInsets',
          'v': {'l': 16, 't': 16, 'r': 16, 'b': 16},
        },
        'color': {
          r'$': 'color',
          'v': {'kind': 'token', 'token': 'primary'},
        },
        'radius': {
          r'$': 'borderRadius',
          'v': {'tl': 12, 'tr': 12, 'br': 12, 'bl': 12},
        },
      });
    });

    test('container: gradient + shadows + border (all-literal const)', () {
      _expectParity('container', {
        'color': '#EF4444',
        'border': {
          'color': 0xFF000000,
          'width': 2,
        },
        'gradient': {
          'colors': [0xFFFFFFFF, 0xFF000000],
          'begin': {'x': -1.0, 'y': 0.0},
          'end': {'x': 1.0, 'y': 0.0},
        },
        'shadow': [
          {
            'color': 0x40000000,
            'blur': 8,
            'spread': 0,
            'offset': {'x': 0, 'y': 2},
          },
        ],
      });
    });

    test('container: 1 child splices into child:, 2 wrap in Column', () {
      _expectParity('container', {}, ['A']);
      _expectParity('container', {}, ['A', 'B']);
    });

    test('column / row: axes + gaps + separators', () {
      _expectParity('column', {});
      _expectParity('column', {
        'mainAxis': 'center',
        'crossAxis': 'stretch',
        'gap': 4,
      }, [
        'A',
        'B',
      ]);
      _expectParity('row', {'mainAxis': 'spaceBetween'}, ['A', 'B']);
    });

    test('stack / padding / center / align', () {
      _expectParity('stack', {
        'alignment': 'bottomRight',
        'fit': 'expand',
      }, [
        'A',
        'B',
      ]);
      _expectParity('padding', {});
      _expectParity('padding', {
        'padding': {
          r'$': 'edgeInsets',
          'v': {'l': 4, 't': 2, 'r': 4, 'b': 2},
        },
      }, [
        'A',
      ]);
      _expectParity('center', {}, ['A']);
      _expectParity('center', {});
      _expectParity('align', {
        'alignment': {
          r'$': 'alignment',
          'v': {'x': 0.0, 'y': -1.0},
        },
      });
    });

    test('expanded / sized_box / spacer', () {
      _expectParity('expanded', {'flex': 2}, ['A']);
      _expectParity('expanded', {});
      _expectParity('sized_box', {});
      _expectParity('sized_box', {'width': 120, 'height': 48});
      _expectParity('spacer', {});
      _expectParity('spacer', {'flex': 3});
    });

    // Responsive tablet overrides are NEW §8.4 leaf-rule behavior (the
    // legacy path duplicates subtrees per tier behind a LayoutBuilder, so
    // no parity exists by design). Expectations below are hand-specified
    // from the leaf rule, never transcribed from emitter output.
    test('sized_box height honors the tablet leaf (hand-specified)', () {
      final doc = _doc('sized_box', {'height': 48}, [], {
        'breakpointValues': {
          'tablet': {'height': 96},
        },
      });
      final node = doc.nodes.firstWhere((n) => n.id == 'n0');
      final out = formatExpression(
        const SizedBoxEmitter().emitExpr(
          node.items.single,
          node,
          const [],
          EmitContext(),
        ),
      );
      expect(
        out,
        'SizedBox(height: '
        'responsiveValue(context, base: 48, md: 96))',
      );
    });

    test('container padding honors the tablet leaf (hand-specified)', () {
      final doc = _doc(
        'container',
        {
          'padding': {
            r'$': 'edgeInsets',
            'v': {'l': 16, 't': 16, 'r': 16, 'b': 16},
          },
        },
        [],
        {
          'breakpointValues': {
            'tablet': {
              'padding': {
                r'$': 'edgeInsets',
                'v': {'l': 32, 't': 32, 'r': 32, 'b': 32},
              },
            },
          },
        },
      );
      final node = doc.nodes.firstWhere((n) => n.id == 'n0');
      final out = _norm(formatExpression(
        const ContainerEmitter().emitExpr(
          node.items.single,
          node,
          const [],
          EmitContext(),
        ),
      ));
      expect(
        out,
        _norm(
          'Container(padding: responsiveValue(context, '
          'base: const EdgeInsets.all(16), md: const EdgeInsets.all(32)))',
        ),
      );
    });
  });

  group('g2 page wiring (priority (d))', () {
    test('pageKindsFor sees nested stateful leaves (primitives-aware)', () {
      final doc = _doc('container', {}, []);
      final nested = ScreenDoc.fromJson({
        ...doc.toJson(),
        'nodes': [
          ...(doc.toJson()['nodes'] as List),
          {
            'id': 'k9',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'parentId': 'n0',
            'items': [
              {'id': 'email', 'kind': 'text_field'},
            ],
          },
        ],
      });
      expect(pageKindsFor(nested, 's1'), contains('text_field'));
      expect(needsModel(pageKindsFor(nested, 's1')), isTrue);
      expect(needsModel(pageKindsFor(_doc('container', {}, []), 's1')),
          isFalse);
    });

    test('planModelFields allocates controllers + bools in doc order', () {
      final doc = ScreenDoc.fromJson({
        'screens': [
          {'id': 's1', 'name': 'Login', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        ],
        'nodes': [
          {
            'id': 'n1',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'email', 'kind': 'text_field'},
            ],
          },
          {
            'id': 'n2',
            'screenId': 's1',
            'x': 0.0,
            'y': 0.0,
            'items': [
              {'id': 'rememberMe', 'kind': 'switch'},
            ],
          },
        ],
        'theme': {
          'paletteKey': 'slate',
          'dark': false,
          'shape': 'rounded',
          'motion': 'standard',
        },
        'meta': {'title': 'Login', 'brief': ''},
      });
      final plan = planModelFields(doc, 's1', NameAllocator());
      expect(plan.controllers, ['emailController']);
      expect(plan.bools, ['rememberMe']);
    });

    test('responsiveLeafValue: tablet feeds md:, desktop fallback', () {
      expect(
        responsiveLeafValue(
            base: 'a', tierCodes: {'tablet': 'b', 'desktop': 'c'}),
        'responsiveValue(context, base: a, md: b)',
      );
      expect(
        responsiveLeafValue(base: 'a', tierCodes: {'desktop': 'c'}),
        'responsiveValue(context, base: a, md: c)',
      );
      expect(
        responsiveLeafValue(base: 'a', tierCodes: {}),
        'a',
      );
    });

    test('withTabletLeaf falls back on unparseable overrides', () {
      final node = CanvasNode.fromJson({
        'id': 'n',
        'screenId': 's',
        'x': 0.0,
        'y': 0.0,
        'items': [],
        'breakpointValues': {
          'tablet': {'height': 'tall'},
        },
      });
      final base = leaf('48');
      expect(
        identical(
          withTabletLeaf(
            base: base,
            node: node,
            prop: 'height',
            renderMd: (raw) {
              final dim = primDim(raw);
              return dim == null ? null : formatPrimNum(dim);
            },
          ),
          base,
        ),
        isTrue,
      );
    });

    test('emitPage: stateless gets no model; stateful gets one', () {
      final stateless = emitPage(
        slug: 'home',
        kinds: const ['container'],
        body: 'Container()',
        imports: ImportCollector(),
      );
      expect(stateless.model, isNull);
      expect(stateless.page.content, contains('extends StatelessWidget'));
      expect(stateless.page.content, isNot(contains('Model')));

      final stateful = emitPage(
        slug: 'login',
        kinds: const ['text_field'],
        body: 'Container()',
        imports: ImportCollector(),
        modelPlan: (
          controllers: ['emailController'],
          bools: ['rememberMe'],
        ),
      );
      expect(stateful.model, isNotNull);
      expect(stateful.page.content, contains('LoginModel'));
      expect(stateful.model!.content, contains('emailController.dispose()'));
    });

    test('emitPage: collector drives extra imports, shell owns material', () {
      final imports = ImportCollector()
        ..add('package:flutter/material.dart')
        ..add('package:kit/tabs.dart', asPrefix: 'tabs');
      final emitted = emitPage(
        slug: 'home',
        kinds: const ['container'],
        body: 'Container()',
        imports: imports,
      );
      expect(
        emitted.page.content,
        contains("import 'package:flutter/material.dart';\n"
            "import 'package:kit/tabs.dart' as tabs;"),
      );
    });
  });

  group('g2 fixtures (golden-first, byte-exact)', () {
    for (final name in [
      'g2_token_container',
      'g2_collapse',
      'g2_responsive_leaf',
    ]) {
      test('$name page matches the hand-written golden', () {
        final doc = _fixtureDoc(name);
        final screen = doc.screens.single;
        final files = emitPrimitivePageFiles(doc: doc, screen: screen);
        expect(files.length, 1);
        expect(files.single.content, _fixtureExpected(name));
        // Gate-3 direction: canonical output reformats to itself.
        expect(DartFormatter().format(files.single.content),
            files.single.content);
      });
    }

    test('g2_model_split page + model match the hand-written goldens', () {
      final doc = _fixtureDoc('g2_model_split');
      final screen = doc.screens.single;
      final files = emitPrimitivePageFiles(doc: doc, screen: screen);
      expect(files.length, 2);
      final byPath = {for (final f in files) f.path: f.content};
      expect(byPath['lib/pages/login/login_page.dart'],
          _fixtureExpected('g2_model_split'));
      expect(byPath['lib/pages/login/login_model.dart'],
          _fixtureExpected('g2_model_split_model'));
      for (final f in files) {
        expect(DartFormatter().format(f.content), f.content,
            reason: f.path);
      }
    });
  });
}
