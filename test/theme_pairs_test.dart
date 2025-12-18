import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  group('Theme Pairs Tests', () {
    
    test('Theme pairs should be correctly identified', () {
      final themePairs = AppSettings.themePairs;
      
      expect(themePairs, contains('github'));
      expect(themePairs, contains('atom-one'));
      expect(themePairs, contains('tokyo-night'));
      expect(themePairs.length, 3); // Should have 3 theme pairs
    });

    test('Theme variants should be correctly mapped', () {
      // Test GitHub theme pair
      expect(AppSettings.getThemeVariant('github', false), 'github');
      expect(AppSettings.getThemeVariant('github', true), 'github-dark');
      
      // Test Atom One theme pair
      expect(AppSettings.getThemeVariant('atom-one', false), 'atom-one-light');
      expect(AppSettings.getThemeVariant('atom-one', true), 'atom-one-dark');
      
      // Test Tokyo Night theme pair
      expect(AppSettings.getThemeVariant('tokyo-night', false), 'tokyo-night-light');
      expect(AppSettings.getThemeVariant('tokyo-night', true), 'tokyo-night-dark');
    });

    test('Base theme name should be correctly identified', () {
      // Test that variants map back to their base theme
      expect(AppSettings.getBaseThemeName('github'), 'github');
      expect(AppSettings.getBaseThemeName('github-dark'), 'github');
      
      expect(AppSettings.getBaseThemeName('atom-one-light'), 'atom-one');
      expect(AppSettings.getBaseThemeName('atom-one-dark'), 'atom-one');
      
      expect(AppSettings.getBaseThemeName('tokyo-night-light'), 'tokyo-night');
      expect(AppSettings.getBaseThemeName('tokyo-night-dark'), 'tokyo-night');
      
      // Non-paired themes should return themselves
      expect(AppSettings.getBaseThemeName('vs'), 'vs');
      expect(AppSettings.getBaseThemeName('nord'), 'nord');
    });

    test('Theme pair detection should work correctly', () {
      // Paired themes should be detected
      expect(AppSettings.isThemePair('github'), true);
      expect(AppSettings.isThemePair('atom-one'), true);
      expect(AppSettings.isThemePair('tokyo-night'), true);
      
      // Non-paired themes should not be detected
      expect(AppSettings.isThemePair('vs'), false);
      expect(AppSettings.isThemePair('nord'), false);
      expect(AppSettings.isThemePair('lightfair'), false);
      
      // Variants should not be detected as pairs
      expect(AppSettings.isThemePair('github-dark'), false);
      expect(AppSettings.isThemePair('atom-one-light'), false);
    });

    test('Theme metadata should show auto-switching status', () {
      // Paired themes should have auto-switching in their description
      final githubMeta = AppSettings.getThemeMetadata('github');
      expect(githubMeta.description, contains('auto-switches'));
      expect(githubMeta.name, 'GitHub'); // Single name
      
      final atomOneMeta = AppSettings.getThemeMetadata('atom-one');
      expect(atomOneMeta.description, contains('auto-switches'));
      expect(atomOneMeta.name, 'Atom One'); // Single name
      
      // Non-paired themes should not have auto-switching in description
      final vsMeta = AppSettings.getThemeMetadata('vs');
      expect(vsMeta.description, isNot(contains('auto-switches')));
      expect(vsMeta.name, 'Visual Studio'); // Full name
    });

    test('Theme pairs should only include themes with both variants', () {
      final themePairs = AppSettings.themePairs;
      
      // Verify each theme pair has both light and dark variants
      for (final pair in themePairs) {
        final lightVariant = AppSettings.getThemeVariant(pair, false);
        final darkVariant = AppSettings.getThemeVariant(pair, true);
        
        expect(lightVariant, isNotNull);
        expect(darkVariant, isNotNull);
        expect(lightVariant, isNot(darkVariant));
      }
    });

    test('Theme switching logic should handle edge cases', () {
      // Test with non-existent theme pair
      expect(AppSettings.getThemeVariant('non-existent', false), 'non-existent');
      expect(AppSettings.getThemeVariant('non-existent', true), 'non-existent');
      
      // Test base theme name with non-existent variant
      expect(AppSettings.getBaseThemeName('non-existent-variant'), 'non-existent-variant');
    });
  });
}