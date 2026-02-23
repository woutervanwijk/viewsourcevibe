import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/screens/about_screen.dart';

void main() {
  testWidgets('About page content test', (WidgetTester tester) async {
    // Build the about screen directly
    await tester.pumpWidget(const MaterialApp(
      home: AboutScreen(),
    ));

    // Verify the about screen displays correctly
    expect(find.text('About View Source Vibe'), findsOneWidget);
    expect(find.text('Cross-Platform Source Code Viewer'), findsOneWidget);
    expect(find.text('Version 1.0.1'), findsOneWidget);
    expect(find.text('© 2025 Wouter van Wijk & Mistral Vibe & Gemini & Claude'),
        findsOneWidget);

    // Verify key sections are present
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Key Features'), findsOneWidget);
    expect(find.text('Development Process'), findsOneWidget);
    expect(find.text('Mistral Vibe AI Collaboration'), findsOneWidget);
    expect(find.text('Technical Details'), findsOneWidget);
    expect(find.text('Copyright & Collaboration'), findsOneWidget);

    // Verify some feature items are present
    expect(find.text('📱 Cross-platform support for iOS and Android'),
        findsOneWidget);
    expect(find.text('🎨 Beautiful syntax highlighting with multiple themes'),
        findsOneWidget);
    expect(
        find.text('🤖 AI-enhanced development with Mistral Vibe intelligence'),
        findsOneWidget);

    // Verify close button works
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}
