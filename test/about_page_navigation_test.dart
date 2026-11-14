import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/screens/about_screen.dart';

void main() {
  testWidgets('About page shows app info and closes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'About'), findsOneWidget);
    expect(find.text('View Source Vibe'), findsOneWidget);
    expect(find.text('KEY FEATURES'), findsOneWidget);
    expect(find.textContaining('© '), findsOneWidget);

    // The hard-coded version must match pubspec.yaml.
    final version = RegExp(r'^version:\s*([\d.]+)', multiLine: true)
        .firstMatch(File('pubspec.yaml').readAsStringSync())!
        .group(1);
    expect(find.textContaining('Version $version'), findsOneWidget);

    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsNothing);
  });
}
