import 'package:canvas_core/canvas_core.dart';
import 'package:test/test.dart';

import 'fixtures/two_screen_doc.dart';

/// Golden prompt for [buildTwoScreenDoc].
///
/// Update only by editing the fixture and reviewing the diff.
const kTwoScreenGoldenPrompt = '''
# Checkout

2-screen pay flow

Target: 390x844 logical pixels, Android and iOS, ThemeMode.system.

Palette (slate, light):
- background: #FFFFFF
- foreground: #020617
- primary: #334155
- muted: #F1F5F9

Theme:
- shape: rounded (radius 0.625rem, shadcn preset)
- mode: light
- motion: standard

Screens:

## /pay (Pay)
- button "Pay" (variant primary) at (16, 96)

## /done (Done)
- card "Done" (description Payment complete) at (16, 96)

Behavior:
- Tapping Pay pushes /done.

Style notes:
- button: use Button with the theme variant; map disabled to enabled=false.
- card: use Card with title and description slots.

Rules:
- Follow flutter_lints.
- Read colors via Theme.of(context); no hard-coded colors.
- Add gap and data_widget to pubspec dependencies where used.
- Use real data with validation and empty states.
''';

void main() {
  test('buildPrompt golden: two-screen Pay->Done doc', () {
    expect(buildPrompt(buildTwoScreenDoc()), kTwoScreenGoldenPrompt);
  });

  test('effectivePrompt returns override when provided', () {
    final doc = buildTwoScreenDoc();
    expect(effectivePrompt(doc, override: 'custom'), 'custom');
    expect(effectivePrompt(doc), buildPrompt(doc));
  });
}
