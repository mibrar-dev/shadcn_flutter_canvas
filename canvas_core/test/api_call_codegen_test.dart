/// Track S1: codegen goldens for `apiCall` — async method, http import, and
/// dep handling (single + bundle). Legacy output stays byte-identical when
/// no apiCall steps exist (pinned by the existing goldens).
library;

import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

const kApiSources = {
  'registry/components/button/button.dart': '''
import 'package:flutter/widgets.dart';

class Button extends StatelessWidget {
  const Button({super.key});
}
''',
};

const kApiBundleSources = {
  '{installPath}/components/control/button/button.dart':
      'class Button extends StatelessWidget {}',
};

ScreenDoc _apiDoc() => ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Done', 'x': 480.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i1',
              'kind': 'button',
              'label': 'Load',
              'action': {
                'to': 's1',
                'transition': 'slide',
                'steps': [
                  {
                    'kind': 'apiCall',
                    'url': 'https://api.example.com/items',
                    'method': 'GET',
                    'headers': {},
                    'body': '',
                    'saveTo': 'result',
                  },
                  {'kind': 'navigate', 'to': 's2', 'transition': 'slide'},
                ],
              },
            },
          ],
        },
      ],
      'states': [
        {'name': 'result', 'type': 'string', 'default': ''},
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'API', 'brief': ''},
    });

void main() {
  test('single-file emits async method + http import + pubspec dep', () {
    final out = buildSingleFile(_apiDoc(), kApiSources);

    expect(
      out,
      contains('Future<void> _onTap_i1(BuildContext context) async {'),
    );
    expect(out, contains("import 'package:http/http.dart' as http;"));
    expect(out, contains('await http.get('));
    expect(out, contains('_result = _apiBody0;'));
    expect(out, contains("pushNamed('/done')"));
    expect(out, contains('pubspec: gap, data_widget, http'));

    // Deterministic.
    expect(buildSingleFile(_apiDoc(), kApiSources), out);
  });

  test('single-file legacy docs keep byte-identical headers (no http)', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Home', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Go'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'T', 'brief': ''},
    });
    final out = buildSingleFile(doc, kApiSources);
    expect(out.contains('package:http'), isFalse);
    expect(out.contains('http'), isFalse);
    expect(out, contains("import 'package:flutter/widgets.dart';"));
  });

  test('bundle emits async method + http import + pubspec patch entry', () {
    final bundle = buildCleanBundle(_apiDoc(), kApiBundleSources);
    final screen = bundle.files['lib/ui/screens/home_screen.dart']!;

    expect(
      screen,
      contains('Future<void> _onTap_i1(BuildContext context) async {'),
    );
    expect(screen, contains("import 'package:http/http.dart' as http;"));
    expect(screen, contains('await http.get('));
    expect(screen, contains('_result = _apiBody0;'));
    expect(bundle.pubspecPatch, contains('http: ^1.2.2'));
  });

  test('bundle legacy docs carry no http dep or import', () {
    final doc = ScreenDoc.fromJson({
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
      ],
      'nodes': [
        {
          'id': 'n1',
          'screenId': 's1',
          'x': 0.0,
          'y': 0.0,
          'items': [
            {'id': 'i1', 'kind': 'button', 'label': 'Pay'},
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'T', 'brief': ''},
    });
    final bundle = buildCleanBundle(doc, kApiBundleSources);
    expect(bundle.pubspecPatch.contains('http'), isFalse);
    expect(
      bundle.files['lib/ui/screens/pay_screen.dart']!.contains('package:http'),
      isFalse,
    );
  });
}
