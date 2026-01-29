import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:view_source_vibe/widgets/code_find_panel.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('CodeFindPanelView should render correctly',
      (WidgetTester tester) async {
    // Build our widget and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeFindPanelView(
            controller: CodeFindController(CodeLineEditingController()),
            readOnly: false,
          ),
        ),
      ),
    );

    // Verify that the find field is present
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Find'), findsOneWidget);

    // Verify that the options are present
    expect(find.text('Case sensitive'), findsOneWidget);
    expect(find.text('Whole word'), findsOneWidget);
    expect(find.text('Regex'), findsOneWidget);

    // Verify that action buttons are present
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
  });

  testWidgets(
      'CodeFindPanelView should show replace field when Replace button is pressed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeFindPanelView(
            controller: CodeFindController(CodeLineEditingController()),
            readOnly: false,
          ),
        ),
      ),
    );

    // Initially, replace field should not be visible
    expect(find.text('Replace with'), findsNothing);

    // Tap the Replace button
    await tester.tap(find.text('Replace').last);
    await tester.pump();

    // Now replace field should be visible
    expect(find.text('Replace with'), findsOneWidget);
    expect(find.text('Replace All'), findsOneWidget);
  });
}
