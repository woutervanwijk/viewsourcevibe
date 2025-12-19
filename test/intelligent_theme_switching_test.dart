import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  group('Intelligent Theme Switching Tests', () {
    
    test('Theme system should support diverse theme options', () async {
      // Test that we have a good selection of themes
      final lightThemes = AppSettings.lightThemes;
      final darkThemes = AppSettings.darkThemes;
      final allThemes = AppSettings.availableThemes;
      
      expect(lightThemes, isNotEmpty);
      expect(darkThemes, isNotEmpty);
      expect(allThemes.length, greaterThan(10));
      
      // We should have a good balance of light and dark themes
      expect(lightThemes.length, greaterThan(3));
      expect(darkThemes.length, greaterThan(5));
    });
    
    test('Theme metadata should be comprehensive', () async {
      // Test that all themes have proper metadata
      final allThemes = AppSettings.availableThemes;
      
      for (final theme in allThemes) {
        final meta = AppSettings.getThemeMetadata(theme);
        expect(meta.name, isNotEmpty);
        expect(meta.description, isNotEmpty);
        expect(meta.isDark, isNotNull); // Should be either true or false
      }
    });
    
    test('Theme pairs should be properly identified', () async {
      // Test theme pair detection
      expect(AppSettings.isThemePair('github'), true);
      expect(AppSettings.isThemePair('atom-one'), true);
      expect(AppSettings.isThemePair('tokyo-night'), true);
      
      // Non-pair themes
      expect(AppSettings.isThemePair('vs'), false);
      expect(AppSettings.isThemePair('monokai'), false);
      expect(AppSettings.isThemePair('nord'), false);
    });
    
    test('Theme variants should map correctly', () async {
      // Test theme variant mapping
      expect(AppSettings.getThemeVariant('github', false), 'github');
      expect(AppSettings.getThemeVariant('github', true), 'github-dark');
      
      expect(AppSettings.getThemeVariant('atom-one', false), 'atom-one-light');
      expect(AppSettings.getThemeVariant('atom-one', true), 'atom-one-dark');
    });
  });
  
  group('Theme Switching Logic Tests', () {
    
    test('Theme switching should handle all available themes', () async {
      // Test that we have a comprehensive theme system
      final lightThemes = AppSettings.lightThemes;
      final darkThemes = AppSettings.darkThemes;
      
      // We should have multiple options for both light and dark
      expect(lightThemes.length, greaterThan(3));
      expect(darkThemes.length, greaterThan(5));
      
      // All light themes should be properly classified
      for (final theme in lightThemes) {
        expect(AppSettings.getThemeMetadata(theme).isDark, false);
      }
      
      // All dark themes should be properly classified
      for (final theme in darkThemes) {
        expect(AppSettings.getThemeMetadata(theme).isDark, true);
      }
    });
    
    test('Theme base name extraction should work', () async {
      // Test that we can extract base names from variants
      expect(AppSettings.getBaseThemeName('github-dark'), 'github');
      expect(AppSettings.getBaseThemeName('atom-one-dark'), 'atom-one');
      expect(AppSettings.getBaseThemeName('tokyo-night-dark'), 'tokyo-night');
      
      // Base themes should return themselves
      expect(AppSettings.getBaseThemeName('github'), 'github');
      expect(AppSettings.getBaseThemeName('vs'), 'vs');
    });
  });
}