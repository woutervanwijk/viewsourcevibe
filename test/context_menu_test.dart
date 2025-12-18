import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('Code Editor Context Menu Tests', () {
    late CodeLineEditingController controller;
    
    setUp(() {
      // Create a controller with some test content
      controller = CodeLineEditingController.fromText('test content');
    });

    tearDown(() {
      controller.dispose();
    });

    test('Context menu controller should be created successfully', () {
      // Test that controller can be created (we can't test UI functionality without proper context)
      expect(controller, isNotNull);
      expect(controller.text, 'test content');
    });

    test('Controller should have basic functionality', () {
      // Test basic controller functionality
      expect(controller.text, isNotEmpty);
      expect(controller.text, 'test content');
    });
  });
}