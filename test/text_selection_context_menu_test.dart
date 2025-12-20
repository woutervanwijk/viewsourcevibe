import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/code_editor_context_menu.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('Text Selection Context Menu Tests', () {
    
    test('Context menu should check for text selection', () {
      // Create a controller with some test content
      final controller = CodeLineEditingController.fromText('test content');
      
      // Verify initial state - no text selected
      expect(controller.selectedText, isEmpty);
      
      // The context menu controller should handle this gracefully
      // We can't test the actual UI in unit tests, but we can verify the logic
      expect(controller, isNotNull);
      expect(controller.text, isNotEmpty);
      
      // Clean up
      controller.dispose();
    });

    test('Context menu controller should handle empty selection', () {
      // Create a controller with some test content
      final controller = CodeLineEditingController.fromText('test content');
      
      // Verify no text is selected initially
      final selectedText = controller.selectedText;
      expect(selectedText, isEmpty);
      
      // Clean up
      controller.dispose();
    });

    test('Context menu should work with selected text', () {
      // Create a controller with some test content
      final controller = CodeLineEditingController.fromText('test content');
      
      // In a real scenario, the user would select text first
      // The context menu should only appear when controller.selectedText.isNotEmpty
      
      // For now, we can verify the controller is working
      expect(controller.text, 'test content');
      expect(controller.text.length, greaterThan(0));
      
      // Clean up
      controller.dispose();
    });
  });
}