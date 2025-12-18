import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Theme Settings Tests', () {
    test('Theme settings default values', () {
      final settings = AppSettings();

      // Test default values (without initialization)
      expect(settings.darkMode, false);
      expect(settings.themeName, 'github');
      expect(AppSettings.availableThemes.length, 15);
      expect(AppSettings.availableThemes, contains('github'));
      expect(AppSettings.availableThemes, contains('github-dark'));
      expect(AppSettings.availableThemes, contains('dark'));
    });

    test('Theme switching without persistence', () {
      final settings = AppSettings();

      // Test dark mode toggle
      settings.darkMode = true;
      expect(settings.darkMode, true);

      settings.darkMode = false;
      expect(settings.darkMode, false);

      // Test theme name switching
      settings.themeName = 'atom-one-dark';
      expect(settings.themeName, 'atom-one-dark');

      settings.themeName = 'github';
      expect(settings.themeName, 'github');
    });
  });

  group('HTML Service Theme Tests', () {
    test('Available themes list contains valid themes', () {
      final availableThemes = AppSettings.availableThemes;

      // Test that all themes in the list are valid
      expect(availableThemes, contains('github'));
      expect(availableThemes, contains('github-dark'));
      expect(availableThemes, contains('atom-one-dark'));
      expect(availableThemes, contains('dark'));
      expect(availableThemes, contains('lightfair'));

      // Test that we removed non-existent themes
      expect(availableThemes, isNot(contains('solarized-light')));
      expect(availableThemes, isNot(contains('dracula')));
    });

    test('Theme settings integration', () {
      final settings = AppSettings();

      // Test that theme settings can be changed
      settings.themeName = 'github-dark';
      expect(settings.themeName, 'github-dark');

      settings.themeName = 'monokai';
      expect(settings.themeName, 'monokai');
    });
  });
}
