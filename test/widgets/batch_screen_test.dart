import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/screens/batch_screen.dart';
import 'package:view_source_vibe/services/batch_runner.dart';

import '../support/fake_batch_target.dart';

Future<BatchRunner> pumpBatchScreen(WidgetTester tester,
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final runner = BatchRunner(FakeBatchTarget());
  await tester.pumpWidget(ChangeNotifierProvider<BatchRunner>.value(
      value: runner, child: const MaterialApp(home: BatchScreen())));
  await tester.pumpAndSettle();
  return runner;
}

void main() {
  testWidgets('the site count follows the text', (tester) async {
    await pumpBatchScreen(tester);
    await tester.enterText(
        find.byType(TextField), 'kvk.nl\njavascript:x\nexample.com');
    await tester.pump();
    expect(find.text('2 site(s)'), findsOneWidget);
    expect(find.text('1 line(s) skipped: javascript:x'), findsOneWidget);
  });

  testWidgets('Start is disabled without sites', (tester) async {
    await pumpBatchScreen(tester);
    expect(find.text('One site per line'), findsOneWidget);
    ButtonStyleButton start() =>
        tester.widget(find.widgetWithText(FilledButton, 'Start'));
    expect(start().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'kvk.nl');
    await tester.pump();
    expect(start().onPressed, isNotNull);
  });

  testWidgets('the list is restored and saved', (tester) async {
    await pumpBatchScreen(tester, prefs: {'batch_urls': 'kvk.nl\nexample.com'});
    expect(find.text('2 site(s)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a.nl');
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('batch_urls'), 'a.nl');
  });

  testWidgets('both switches show their default', (tester) async {
    await pumpBatchScreen(tester);
    expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(
                SwitchListTile, 'Clear site data before each site'))
            .value,
        isTrue);
    expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(
                SwitchListTile, 'Also measure a fresh load (slower)'))
            .value,
        isFalse);
  });
}
