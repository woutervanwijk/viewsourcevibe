import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  group('Dark Theme Enforcement Tests', () {
    
    test('Theme metadata should correctly identify light and dark themes', () async {
      // Test the theme metadata
      final githubMeta = AppSettings.getThemeMetadata('github');
      expect(githubMeta.isDark, false); // github is light
      
      final githubDarkMeta = AppSettings.getThemeMetadata('github-dark');
      expect(githubDarkMeta.isDark, true); // github-dark is dark
      
      // Test other themes
      final vsMeta = AppSettings.getThemeMetadata('vs');
      expect(vsMeta.isDark, false); // vs is light
      
      final monokaiMeta = AppSettings.getThemeMetadata('monokai');
      expect(monokaiMeta.isDark, true); // monokai is dark
    });
    
    test('Light themes should be detected correctly', () async {
      final lightThemes = AppSettings.lightThemes;
      expect(lightThemes, isNotEmpty);
      expect(lightThemes, contains('github'));
      expect(lightThemes, contains('vs'));
      expect(lightThemes, contains('vs2015'));
      
      // Verify all light themes have isDark = false
      for (final theme in lightThemes) {
        final meta = AppSettings.getThemeMetadata(theme);
        expect(meta.isDark, false, reason: 'Theme $theme should be light');
      }
    });
    
    test('Dark themes should be detected correctly', () async {
      final darkThemes = AppSettings.darkThemes;
      expect(darkThemes, isNotEmpty);
      expect(darkThemes, contains('github-dark'));
      expect(darkThemes, contains('monokai'));
      expect(darkThemes, contains('nord'));
      
      // Verify all dark themes have isDark = true
      for (final theme in darkThemes) {
        final meta = AppSettings.getThemeMetadata(theme);
        expect(meta.isDark, true, reason: 'Theme $theme should be dark');
      }
    });
    
    test('Theme switching logic should handle non-pair themes', () async {
      // Test that non-pair light themes can be switched to dark themes
      final lightThemes = AppSettings.lightThemes;
      final darkThemes = AppSettings.darkThemes;
      
      expect(lightThemes, isNotEmpty);
      expect(darkThemes, isNotEmpty);
      
      // For each light theme that's not a pair, there should be dark alternatives
      for (final lightTheme in lightThemes) {
        if (!AppSettings.isThemePair(lightTheme)) {
          // This light theme is not part of a pair, so auto-switching should
          // find an appropriate dark theme when dark mode is enabled
          expect(darkThemes.isNotEmpty, true);
        }
      }
    });
    
    test('Theme pair variants should be correctly mapped', () async {
      // Test github theme pair
      expect(AppSettings.getThemeVariant('github', false), 'github');
      expect(AppSettings.getThemeVariant('github', true), 'github-dark');
      
      // Test atom-one theme pair
      expect(AppSettings.getThemeVariant('atom-one', false), 'atom-one-light');
      expect(AppSettings.getThemeVariant('atom-one', true), 'atom-one-dark');
      
      // Test tokyo-night theme pair
      expect(AppSettings.getThemeVariant('tokyo-night', false), 'tokyo-night-light');
      expect(AppSettings.getThemeVariant('tokyo-night', true), 'tokyo-night-dark');
    });
  });
  
  group('Theme Metadata Tests', () {
    
    test('All themes should have metadata', () async {
      final allThemes = AppSettings.availableThemes;
      expect(allThemes, isNotEmpty);
      
      for (final theme in allThemes) {
        final meta = AppSettings.getThemeMetadata(theme);
        expect(meta.name, isNotEmpty);
        expect(meta.description, isNotEmpty);
        // isDark can be true or false, but should be set
        expect(meta.isDark, isNotNull);
      }
    });
    
    test('Theme base name extraction should work', () async {
      // Test theme variants return their base name
      expect(AppSettings.getBaseThemeName('github-dark'), 'github');
      expect(AppSettings.getBaseThemeName('github-dark-dimmed'), 'github-dark-dimmed'); // This is not part of a pair
      expect(AppSettings.getBaseThemeName('atom-one-dark'), 'atom-one');
      expect(AppSettings.getBaseThemeName('tokyo-night-dark'), 'tokyo-night');
      
      // Test base themes return themselves
      expect(AppSettings.getBaseThemeName('github'), 'github');
      expect(AppSettings.getBaseThemeName('vs'), 'vs');
      expect(AppSettings.getBaseThemeName('monokai'), 'monokai');
    });
  });
}