import 'package:emo/app_state.dart';
import 'package:emo/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Intelligence section opens cloud setup', (tester) async {
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SettingsScreen(state: state))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Intelligence'), findsOneWidget);
    expect(find.text('Cloud brain'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Cloud setup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cloud setup'));
    await tester.pumpAndSettle();

    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('Test connection'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    expect(find.text('gpt-4o-mini'), findsWidgets);
  });

  testWidgets('Notifications section shows alert controls', (tester) async {
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SettingsScreen(state: state))),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Reply notifications'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Reply notifications'), findsOneWidget);
    expect(find.text('Update notifications'), findsOneWidget);
    expect(find.text('App updates'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
  });
}
