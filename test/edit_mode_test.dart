import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('Edit Mode Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('Initial state should not be in edit mode', () {
      expect(htmlService.editMode, false);
      expect(htmlService.hasUnsavedChanges, false);
    });

    test('Toggle edit mode should work', () async {
      // Load a file first
      final testFile = HtmlFile(
        name: 'test.txt',
        path: 'test',
        content: 'Hello World',
        lastModified: DateTime.now(),
        size: 11,
        isUrl: false,
      );
      await htmlService.loadFile(testFile);

      // Enter edit mode
      htmlService.toggleEditMode();
      expect(htmlService.editMode, true);
      expect(htmlService.hasUnsavedChanges, false);

      // Exit edit mode (no changes) - this should work since there are no changes
      htmlService.toggleEditMode();
      expect(htmlService.editMode, false);
    });

    test('Save changes should work', () async {
      final testFile = HtmlFile(
        name: 'test.txt',
        path: 'test',
        content: 'Hello World',
        lastModified: DateTime.now(),
        size: 11,
        isUrl: false,
      );
      await htmlService.loadFile(testFile);

      // Enter edit mode
      htmlService.toggleEditMode();
      expect(htmlService.editMode, true);

      // Simulate content change using test method
      htmlService.simulateContentChange('Hello World Updated');

      expect(htmlService.hasUnsavedChanges, true);

      // Save changes (using the save button method)
      htmlService.saveChanges();
      expect(htmlService.editMode, false);
      expect(htmlService.hasUnsavedChanges, false);
      expect(htmlService.currentFile?.content, 'Hello World Updated');
    });

    test('Cancel edits should revert to original content', () async {
      final testFile = HtmlFile(
        name: 'test.txt',
        path: 'test',
        content: 'Hello World',
        lastModified: DateTime.now(),
        size: 11,
        isUrl: false,
      );
      await htmlService.loadFile(testFile);

      // Enter edit mode
      htmlService.toggleEditMode();
      expect(htmlService.editMode, true);

      // Simulate content change using test method
      htmlService.simulateContentChange('Hello World Updated');

      expect(htmlService.hasUnsavedChanges, true);

      // Cancel edits (using the cancel button method) - without confirmation for testing
      final result = await htmlService.discardChanges(showConfirmation: false);
      expect(result, true); // Should succeed
      expect(htmlService.editMode, false);
      expect(htmlService.hasUnsavedChanges, false);
      expect(htmlService.currentFile?.content, 'Hello World'); // Should revert to original
    });

    test('Cancel edits with confirmation should show dialog', () async {
      final testFile = HtmlFile(
        name: 'test.txt',
        path: 'test',
        content: 'Hello World',
        lastModified: DateTime.now(),
        size: 11,
        isUrl: false,
      );
      await htmlService.loadFile(testFile);

      // Enter edit mode
      htmlService.toggleEditMode();
      expect(htmlService.editMode, true);

      // Simulate content change using test method
      htmlService.simulateContentChange('Hello World Updated');

      expect(htmlService.hasUnsavedChanges, true);

      // Cancel edits with confirmation but no context (should succeed since no dialog can be shown)
      final result = await htmlService.discardChanges(showConfirmation: true);
      expect(result, true); // Should succeed without context (no confirmation possible)
      expect(htmlService.editMode, false); // Should exit edit mode
      expect(htmlService.currentFile?.content, 'Hello World'); // Should revert to original
    });

    test('Discard changes should revert to original content', () async {
      final testFile = HtmlFile(
        name: 'test.txt',
        path: 'test',
        content: 'Hello World',
        lastModified: DateTime.now(),
        size: 11,
        isUrl: false,
      );
      await htmlService.loadFile(testFile);

      // Enter edit mode
      htmlService.toggleEditMode();

      // Simulate content change using test method
      htmlService.simulateContentChange('Hello World Updated');

      expect(htmlService.hasUnsavedChanges, true);

      // Discard changes
      htmlService.discardChanges();
      expect(htmlService.editMode, false);
      expect(htmlService.hasUnsavedChanges, false);
      expect(htmlService.currentFile?.content, 'Hello World');
    });

    test('Loading new file should reset edit mode', () async {
      final testFile = HtmlFile(
        name: 'test.txt',
        path: 'test',
        content: 'Hello World',
        lastModified: DateTime.now(),
        size: 11,
        isUrl: false,
      );
      await htmlService.loadFile(testFile);

      // Enter edit mode
      htmlService.toggleEditMode();
      expect(htmlService.editMode, true);

      // Load new file
      final newFile = HtmlFile(
        name: 'test2.txt',
        path: 'test2',
        content: 'New Content',
        lastModified: DateTime.now(),
        size: 11,
        isUrl: false,
      );
      await htmlService.loadFile(newFile);

      expect(htmlService.editMode, false);
      expect(htmlService.currentFile?.name, 'test2.txt');
    });
  });
}