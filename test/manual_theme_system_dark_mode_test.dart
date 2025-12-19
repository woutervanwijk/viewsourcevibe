import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('Manual Theme Preservation with System Dark Mode Changes', () {
    late AppSettings settings;
    late SharedPreferences mockPrefs;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
      
      settings = AppSettings();
      await settings.initialize();
    });

    test('Manual theme selection should not auto-switch when system dark mode changes', () async {
      // Start with system theme mode
      settings.themeMode = ThemeModeOption.system;
      
      // Select a manual theme (not a theme pair)
      settings.themeName = 'monokai'; // This should set _preserveManualThemeSelection = true
      
      // Verify manual theme is selected
      expect(settings.themeName, 'monokai');
      
      // Change system dark mode from false to true
      settings.darkMode = true;
      
      // Theme should NOT change - should remain 'monokai'
      expect(settings.themeName, 'monokai', reason: 'Manual theme should be preserved when system dark mode changes');
      
      // Change system dark mode back to false
      settings.darkMode = false;
      
      // Theme should still NOT change - should remain 'monokai'
      expect(settings.themeName, 'monokai', reason: 'Manual theme should be preserved when system dark mode changes back');
    });

    test('Theme pair should auto-switch when system dark mode changes', () async {
      // Start with system theme mode
      settings.themeMode = ThemeModeOption.system;
      
      // Select a theme pair (github)
      settings.themeName = 'github'; // This should set _preserveManualThemeSelection = false
      
      // Verify theme pair is selected
      expect(settings.themeName, 'github');
      
      // Change system dark mode to true
      settings.darkMode = true;
      
      // Theme SHOULD change to dark variant
      expect(settings.themeName, 'github-dark', reason: 'Theme pair should auto-switch to dark variant');
      
      // Change system dark mode back to false
      settings.darkMode = false;
      
      // Theme SHOULD change back to light variant
      expect(settings.themeName, 'github', reason: 'Theme pair should auto-switch back to light variant');
    });

    test('Manual theme selection should persist across theme mode changes', () async {
      // Select a manual theme
      settings.themeName = 'vs'; // This should set _preserveManualThemeSelection = true
      
      // Change theme mode to dark
      settings.themeMode = ThemeModeOption.dark;
      
      // Theme should NOT change - should remain 'vs'
      expect(settings.themeName, 'vs', reason: 'Manual theme should be preserved when theme mode changes to dark');
      
      // Change theme mode to light
      settings.themeMode = ThemeModeOption.light;
      
      // Theme should still NOT change - should remain 'vs'
      expect(settings.themeName, 'vs', reason: 'Manual theme should be preserved when theme mode changes to light');
      
      // Change theme mode back to system
      settings.themeMode = ThemeModeOption.system;
      
      // Theme should still NOT change - should remain 'vs'
      expect(settings.themeName, 'vs', reason: 'Manual theme should be preserved when theme mode changes back to system');
    });

    test('Switching from manual theme to theme pair should enable auto-switching', () async {
      // Select a manual theme
      settings.themeName = 'monokai'; // This should set _preserveManualThemeSelection = true
      
      // Verify manual theme is selected
      expect(settings.themeName, 'monokai');
      
      // Switch to a theme pair
      settings.themeName = 'github'; // This should set _preserveManualThemeSelection = false
      
      // Change system dark mode to true
      settings.darkMode = true;
      
      // Now theme SHOULD auto-switch to dark variant
      expect(settings.themeName, 'github-dark', reason: 'Theme pair should auto-switch after switching from manual theme');
    });

    test('Multiple manual theme changes should all be preserved', () async {
      // Select first manual theme
      settings.themeName = 'vs';
      expect(settings.themeName, 'vs');
      
      // Change system dark mode
      settings.darkMode = true;
      expect(settings.themeName, 'vs', reason: 'First manual theme should be preserved');
      
      // Select second manual theme
      settings.themeName = 'monokai';
      expect(settings.themeName, 'monokai');
      
      // Change system dark mode again
      settings.darkMode = false;
      expect(settings.themeName, 'monokai', reason: 'Second manual theme should be preserved');
      
      // Select third manual theme
      settings.themeName = 'nord';
      expect(settings.themeName, 'nord');
      
      // Change system dark mode again
      settings.darkMode = true;
      expect(settings.themeName, 'nord', reason: 'Third manual theme should be preserved');
    });
  });
}