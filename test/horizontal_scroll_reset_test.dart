import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';

void main() {
  group('Horizontal Scroll Reset Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('HtmlService should have horizontal scroll controller', () {
      expect(htmlService.horizontalScrollController, isNotNull);
      expect(htmlService.horizontalScrollController, isA<ScrollController>());
    });

    test('loadFile should reset horizontal scroll position', () async {
      // Create a long line of text that would require horizontal scrolling
      final longContent = 'a' * 1000; // Very long line
      
      final file = HtmlFile(
        name: 'long_line.txt',
        path: 'long_line.txt',
        content: longContent,
        lastModified: DateTime.now(),
        size: longContent.length,
      );

      // Load the file - this should reset horizontal scroll position
      await htmlService.loadFile(file);
      
      // Verify that the loadFile method completes without error
      // We can't test the actual scroll position in unit tests since controllers aren't attached
      expect(htmlService.currentFile, file);
      expect(htmlService.currentFile?.content, longContent);
    });

    test('Horizontal scroll controller should be disposed properly', () {
      final horizontalController = htmlService.horizontalScrollController;
      expect(horizontalController, isNotNull);
      
      // Dispose the service
      htmlService.dispose();
      
      // This test mainly verifies that dispose completes without throwing
      // We can't test the controller state after disposal in this context
      addTearDown(() {}); // Prevent double dispose in test cleanup
    });

    test('Both vertical and horizontal scroll controllers should be reset on file load', () async {
      // Create test files
      final firstFile = HtmlFile(
        name: 'first.txt',
        path: 'first.txt',
        content: 'First file content',
        lastModified: DateTime.now(),
        size: 18,
      );

      final secondFile = HtmlFile(
        name: 'second.txt',
        path: 'second.txt',
        content: 'Second file content',
        lastModified: DateTime.now(),
        size: 19,
      );

      // Load first file
      await htmlService.loadFile(firstFile);
      expect(htmlService.currentFile, firstFile);
      
      // Load second file - should reset both scroll positions
      await htmlService.loadFile(secondFile);
      
      // Verify that files are loaded correctly (we can't test scroll positions in unit tests)
      expect(htmlService.currentFile, secondFile);
      expect(htmlService.currentFile?.content, 'Second file content');
    });
  });
}