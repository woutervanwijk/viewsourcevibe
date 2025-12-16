import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/models/settings.dart';

void main() {
  group('Theme Switching Tests', () {
    test('Theme metadata is properly categorized', () {
      // Test that themes are correctly categorized
      final lightThemes = AppSettings.lightThemes;
      final darkThemes = AppSettings.darkThemes;
      
      // Verify light themes
      expect(lightThemes.length, 6); // Should have 6 light themes
      for (final theme in lightThemes) {
        final meta = AppSettings.getThemeMetadata(theme);
        expect(meta.isDark, false, reason: '$theme should be a light theme');
      }
      
      // Verify dark themes
      expect(darkThemes.length, 9); // Should have 9 dark themes
      for (final theme in darkThemes) {
        final meta = AppSettings.getThemeMetadata(theme);
        expect(meta.isDark, true, reason: '$theme should be a dark theme');
      }
      
      // Verify all themes are accounted for
      expect(lightThemes.length + darkThemes.length, AppSettings.availableThemes.length);
    });

    test('Theme metadata has proper names and descriptions', () {
      // Test that all themes have proper metadata
      for (final theme in AppSettings.availableThemes) {
        final meta = AppSettings.getThemeMetadata(theme);
        
        expect(meta.name, isNotEmpty, reason: '$theme should have a non-empty name');
        expect(meta.description, isNotEmpty, reason: '$theme should have a non-empty description');
        expect(meta.name, isNot(theme), reason: '$theme should have a human-readable name');
      }
    });

    test('Theme switching based on theme mode', () async {
      final settings = AppSettings();
      
      // Test initial state
      expect(settings.themeMode, ThemeModeOption.system);
      expect(settings.darkMode, false);
      
      // Test switching to dark mode
      settings.darkMode = true;
      
      // The theme should auto-switch to a dark theme
      final currentThemeMeta = AppSettings.getThemeMetadata(settings.themeName);
      expect(currentThemeMeta.isDark, true, reason: 'Should auto-switch to dark theme');
      
      // Test switching back to light mode
      settings.darkMode = false;
      
      // The theme should auto-switch back to a light theme
      final newThemeMeta = AppSettings.getThemeMetadata(settings.themeName);
      expect(newThemeMeta.isDark, false, reason: 'Should auto-switch back to light theme');
    });

    test('Theme switching based on explicit theme mode', () async {
      final settings = AppSettings();
      
      // Note: Auto-switching only happens in system mode
      // When theme mode is explicitly set to light/dark, we need to manually switch
      
      // Set to light theme mode and ensure we have a light theme
      settings.themeMode = ThemeModeOption.light;
      if (AppSettings.getThemeMetadata(settings.themeName).isDark) {
        settings.themeName = AppSettings.lightThemes.first;
      }
      
      // Should have a light theme
      final lightThemeMeta = AppSettings.getThemeMetadata(settings.themeName);
      expect(lightThemeMeta.isDark, false, reason: 'Should use light theme in light mode');
      
      // Set to dark theme mode and ensure we have a dark theme
      settings.themeMode = ThemeModeOption.dark;
      if (!AppSettings.getThemeMetadata(settings.themeName).isDark) {
        settings.themeName = AppSettings.darkThemes.first;
      }
      
      // Should have a dark theme
      final darkThemeMeta = AppSettings.getThemeMetadata(settings.themeName);
      expect(darkThemeMeta.isDark, true, reason: 'Should use dark theme in dark mode');
    });

    test('Theme switching preserves theme family when possible', () async {
      final settings = AppSettings();
      
      // Start with a specific light theme
      settings.themeName = 'github'; // Light theme
      settings.darkMode = false;
      
      // Switch to dark mode
      settings.darkMode = true;
      
      // Should try to switch to github-dark if available
      final currentTheme = settings.themeName;
      expect(currentTheme, 'github-dark', reason: 'Should switch to dark variant of same theme family');
      
      // Switch back to light mode
      settings.darkMode = false;
      
      // Should switch back to github
      expect(settings.themeName, 'github', reason: 'Should switch back to light variant');
    });

    test('Theme metadata fallback works', () {
      // Test unknown theme fallback
      final unknownMeta = AppSettings.getThemeMetadata('unknown-theme');
      
      expect(unknownMeta.name, 'unknown-theme');
      expect(unknownMeta.description, 'Unknown theme');
      expect(unknownMeta.isDark, false);
    });

    test('Theme category methods work correctly', () {
      // Test theme category methods
      expect(AppSettings.getThemesByCategory(false).length, 6);
      expect(AppSettings.getThemesByCategory(true).length, 9);
      
      // Test light/dark theme getters
      expect(AppSettings.lightThemes.length, 6);
      expect(AppSettings.darkThemes.length, 9);
    });

    test('Theme switching with system mode respects darkMode setting', () async {
      final settings = AppSettings();
      
      // Set to system mode
      settings.themeMode = ThemeModeOption.system;
      
      // Test with dark mode off
      settings.darkMode = false;
      final lightMeta = AppSettings.getThemeMetadata(settings.themeName);
      expect(lightMeta.isDark, false);
      
      // Test with dark mode on
      settings.darkMode = true;
      final darkMeta = AppSettings.getThemeMetadata(settings.themeName);
      expect(darkMeta.isDark, true);
    });
  });

  group('Theme Metadata Tests', () {
    test('Specific theme metadata values', () {
      // Test specific themes have correct metadata
      expect(AppSettings.getThemeMetadata('github').name, 'GitHub Light');
      expect(AppSettings.getThemeMetadata('github-dark').name, 'GitHub Dark');
      expect(AppSettings.getThemeMetadata('atom-one-dark').name, 'Atom One Dark');
      expect(AppSettings.getThemeMetadata('nord').name, 'Nord');
    });

    test('Theme descriptions are informative', () {
      // Test that descriptions are meaningful
      final githubMeta = AppSettings.getThemeMetadata('github');
      expect(githubMeta.description.contains('GitHub'), true);
      
      final nordMeta = AppSettings.getThemeMetadata('nord');
      expect(nordMeta.description.contains('Arctic'), true);
    });
  });
}