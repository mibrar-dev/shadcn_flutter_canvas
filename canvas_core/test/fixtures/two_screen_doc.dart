import 'package:canvas_core/canvas_core.dart';

/// Two-screen Pay → Done fixture for exporter golden tests.
///
/// 2 screens, 1 tap action (`Pay` button pushes `/done`), slate/light theme.
ScreenDoc buildTwoScreenDoc() => ScreenDoc.fromJson(<String, dynamic>{
      'screens': [
        {'id': 's1', 'name': 'Pay', 'x': 0.0, 'y': 0.0, 'bg': 'surface'},
        {'id': 's2', 'name': 'Done', 'x': 420.0, 'y': 0.0, 'bg': 'surface'},
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
              'label': 'Pay',
              'variant': 'primary',
              'action': {'to': 's2', 'transition': 'slide'},
            },
          ],
        },
        {
          'id': 'n2',
          'screenId': 's2',
          'x': 16.0,
          'y': 96.0,
          'items': [
            {
              'id': 'i2',
              'kind': 'card',
              'title': 'Done',
              'description': 'Payment complete',
            },
          ],
        },
      ],
      'theme': {
        'paletteKey': 'slate',
        'dark': false,
        'shape': 'rounded',
        'motion': 'standard',
      },
      'meta': {'title': 'Checkout', 'brief': '2-screen pay flow'},
    });
