import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  group('Manual Theme Preservation Tests', () {
    
    test('Theme system should distinguish between auto and manual themes', () async {
      // Test that we can identify theme pairs vs manual themes
      
      // Theme pairs (should auto-switch)
      expect(AppSettings.isThemePair('github'), true);
      expect(AppSettings.isThemePair('atom-one'), true);
      expect(AppSettings.isThemePair('tokyo-night'), true);
      
      // Manual themes (should be preserved)
      expect(AppSettings.isThemePair('vs'), false);
      expect(AppSettings.isThemePair('monokai'), false);
      expect(AppSettings.isThemePair('nord'), false);
      expect(AppSettings.isThemePair('lightfair'), false);
    });
    
    test('Theme metadata should support theme classification', () async {
      // Test that we can properly classify themes
      final allThemes = AppSettings.availableThemes;
      
      // We should have both auto-switching and manual themes
      int themePairs = 0;
      int manualThemes = 0;
      
      for (final theme in allThemes) {
        final baseName = AppSettings.getBaseThemeName(theme);
        if (AppSettings.isThemePair(baseName)) {
          themePairs++;
        } else {
          manualThemes++;
        }
      }
      
      // We should have a mix of both types
      expect(themePairs, greaterThan(0));
      expect(manualThemes, greaterThan(0));
      expect(themePairs + manualThemes, allThemes.length);
    });
    
    test('Theme base name extraction should work for all themes', () async {
      // Test base name extraction
      expect(AppSettings.getBaseThemeName('github'), 'github');
      expect(AppSettings.getBaseThemeName('github-dark'), 'github');
      expect(AppSettings.getBaseThemeName('vs'), 'vs');
      expect(AppSettings.getBaseThemeName('monokai'), 'monokai');
    });
  });
  
  group('Theme Type Identification Tests', () {
    
    test('Theme pairs should be correctly identified', () async {
      // Test all theme pairs
      final themePairs = AppSettings.themePairs;
      expect(themePairs, isNotEmpty);
      
      // Each pair should have both light and dark variants
      for (final pair in themePairs) {
        expect(AppSettings.isThemePair(pair), true);
        
        final lightVariant = AppSettings.getThemeVariant(pair, false);
        final darkVariant = AppSettings.getThemeVariant(pair, true);
        
        expect(lightVariant, isNotNull);
        expect(darkVariant, isNotNull);
        expect(lightVariant, isNot(equals(darkVariant)));
      }
    });
    
    test('Manual themes should be standalone themes', () async {
      // Test that manual themes don't have variants
      final manualThemes = [
        'vs', 'vs2015', 'lightfair',
        'monokai', 'monokai-sublime', 'nord',
        'androidstudio', 'dark'
      ];
      
      for (final theme in manualThemes) {
        expect(AppSettings.isThemePair(theme), false);
        
        // Manual themes should return themselves as base name
        expect(AppSettings.getBaseThemeName(theme), theme);
      }
    });
    
    test('Theme system should support both auto and manual themes', () async {
      // Test that we have a good balance
      final themePairs = AppSettings.themePairs;
      final allThemes = AppSettings.availableThemes;
      
      // Calculate manual themes
      final manualThemes = allThemes.where((theme) {
        final baseName = AppSettings.getBaseThemeName(theme);
        return !AppSettings.isThemePair(baseName);
      }).toList();
      
      // We should have both types
      expect(themePairs.length, greaterThan(0));
      expect(manualThemes.length, greaterThan(0));
      
      // Print some info
      // Debug info removed to avoid print statements in production code
      // print('Theme pairs: ${themePairs.length}');
      // print('Manual themes: ${manualThemes.length}');
      // print('Total themes: ${allThemes.length}');
    });
  });
}