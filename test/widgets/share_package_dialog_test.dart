import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/widgets/share_package_dialog.dart';

Future<bool?> _open(WidgetTester tester, String tap) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (c) => TextButton(
              onPressed: () async => result = await confirmSharePackage(c),
              child: const Text('go')))));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  expect(find.text('Share inspection package?'), findsOneWidget);
  expect(find.textContaining('can include personal data'), findsOneWidget);
  await tester.tap(find.text(tap));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('cancel does not share', (tester) async {
    expect(await _open(tester, 'Cancel'), isFalse);
  });

  testWidgets('share only after the user confirms', (tester) async {
    expect(await _open(tester, 'Share'), isTrue);
  });
}
