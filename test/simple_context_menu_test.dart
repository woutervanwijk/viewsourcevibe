import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:view_source_vibe/widgets/code_editor_with_context_menu.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('Simple Context Menu Tests', () {
    
    testWidgets('Context menu widget should be created successfully', (WidgetTester tester) async {
      // Create a controller with some test content
      final controller = CodeLineEditingController.fromText('test content');
      
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeEditorWithContextMenu(
              controller: controller,
              readOnly: true,
              scrollController: CodeScrollController(
                verticalScroller: ScrollController(),
              ),
              style: CodeEditorStyle(),
            ),
          ),
        ),
      );
      
      // Verify the widget is created
      expect(find.byType(CodeEditorWithContextMenu), findsOneWidget);
      
      // Clean up
      controller.dispose();
    });

    testWidgets('Context menu widget should handle read-only mode', (WidgetTester tester) async {
      // Create controllers for both modes
      final readOnlyController = CodeLineEditingController.fromText('read only');
      final editableController = CodeLineEditingController.fromText('editable');
      
      // Test read-only mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeEditorWithContextMenu(
              controller: readOnlyController,
              readOnly: true,
              scrollController: CodeScrollController(
                verticalScroller: ScrollController(),
              ),
              style: CodeEditorStyle(),
            ),
          ),
        ),
      );
      
      expect(find.byType(CodeEditorWithContextMenu), findsOneWidget);
      
      // Test editable mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeEditorWithContextMenu(
              controller: editableController,
              readOnly: false,
              scrollController: CodeScrollController(
                verticalScroller: ScrollController(),
              ),
              style: CodeEditorStyle(),
            ),
          ),
        ),
      );
      
      expect(find.byType(CodeEditorWithContextMenu), findsOneWidget);
      
      // Clean up
      readOnlyController.dispose();
      editableController.dispose();
    });
  });
}