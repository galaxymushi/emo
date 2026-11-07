import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emo/models.dart';
import 'package:emo/services/command_engine.dart';
import 'package:emo/theme.dart';
import 'package:emo/widgets/glass.dart';

void main() {
  const device = DeviceState(available: true, brightness: 0.5, volumeMusic: 0.4);

  group('CommandParser', () {
    test('turns the torch on', () {
      final parsed = CommandParser.parse('turn on the torch', device, const []);
      expect(parsed.kind, IntentKind.torch);
      expect(parsed.on, isTrue);
    });

    test('reads brightness as a percentage', () {
      final parsed = CommandParser.parse('set brightness to 60%', device, const []);
      expect(parsed.kind, IntentKind.brightness);
      expect(parsed.value, closeTo(0.6, 0.001));
    });

    test('routes volume to the media stream', () {
      final parsed = CommandParser.parse('set media volume to 30%', device, const []);
      expect(parsed.kind, IntentKind.volume);
      expect(parsed.mode, 'music');
      expect(parsed.value, closeTo(0.3, 0.001));
    });

    test('falls back honestly on unknown input', () {
      final parsed = CommandParser.parse('make me a sandwich', device, const []);
      expect(parsed.kind, IntentKind.unknown);
    });
  });

  testWidgets('primary button responds to taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: EmoTheme.light(),
        home: Scaffold(
          body: Center(
            child: PrimaryButton(label: 'Start', onTap: () => taps++),
          ),
        ),
      ),
    );
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(taps, 1);
  });
}
