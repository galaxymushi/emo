import 'package:emo/models.dart';
import 'package:emo/services/command_engine.dart';
import 'package:flutter_test/flutter_test.dart';

ParsedCommand parse(String text) =>
    CommandParser.parse(text, const DeviceState(), const <Routine>[]);

void main() {
  group('memory intents', () {
    test('saves a remembered fact', () {
      final command = parse('remember that I like tea');
      expect(command.kind, IntentKind.remember);
      expect(command.target, 'I like tea');
    });

    test('saves the boss name', () {
      final command = parse('my name is sam');
      expect(command.kind, IntentKind.remember);
      expect(command.mode, 'name');
      expect(command.target, 'sam');
    });

    test('recalls what Emo knows', () {
      expect(parse('what do you remember').kind, IntentKind.recall);
      expect(parse('what do you know about me').kind, IntentKind.recall);
    });

    test('forgets one fact or everything', () {
      final one = parse('forget that I like tea');
      expect(one.kind, IntentKind.forget);
      expect(one.mode, 'one');
      expect(one.target, 'I like tea');

      final all = parse('forget everything');
      expect(all.kind, IntentKind.forget);
      expect(all.mode, 'all');
    });
  });

  test('phone commands still parse normally', () {
    expect(parse('turn on the torch').kind, IntentKind.torch);
    expect(parse('open WhatsApp').kind, IntentKind.openApp);
    expect(parse('message mum i am on my way').kind, IntentKind.message);
  });
}
