import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:htmlviewer/models/settings.dart';

void main() {
  // Initialize Flutter binding for testing
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up method channel for shared preferences
  const MethodChannel('plugins.flutter.io/shared_preferences')
    .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    });

  group('Auto Theme Switching Tests', () {
    late AppSettings settings;

    setUp(() async {
      settings = AppSettings();
      try {
        await settings.initialize();
      } catch (e) {
        // Handle initialization errors gracefully in tests
        debugPrint('Settings initialization error in test: $e');
      }
    });

    tearDown(() {
      settings.dispose();
    });

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

    test('Auto theme switching should work in system mode', () async {
      // Set to system mode
      settings.themeMode = ThemeModeOption.system;
      
      // Start with light mode
      settings.darkMode = false;
      
      // Set a theme pair
      settings.themeName = 'github'; // This should stay as 'github' in light mode
      
      expect(settings.themeName, 'github');
      
      // Switch to dark mode - should auto-switch to dark variant
      settings.darkMode = true;
      
      // Give it a moment to process
      await Future.delayed(Duration(milliseconds: 100));
      
      // Should have auto-switched to github-dark
      expect(AppSettings.getBaseThemeName(settings.themeName), 'github');
      expect(settings.themeName, 'github-dark');
    });

    test('Auto theme switching should not affect non-paired themes', () async {
      // Set to system mode
      settings.themeMode = ThemeModeOption.system;
      
      // Set a non-paired theme
      settings.themeName = 'vs';
      
      // Switch dark mode - should not change the theme
      settings.darkMode = true;
      
      // Give it a moment to process
      await Future.delayed(Duration(milliseconds: 100));
      
      // Should still be 'vs' (no auto-switching for non-paired themes)
      expect(settings.themeName, 'vs');
    });

    test('Theme metadata should show auto-switching status', () {
      // Paired themes should have auto-switching in their description
      final githubMeta = AppSettings.getThemeMetadata('github');
      expect(githubMeta.description, contains('auto-switches'));
      
      final atomOneMeta = AppSettings.getThemeMetadata('atom-one');
      expect(atomOneMeta.description, contains('auto-switches'));
      
      // Non-paired themes should not have auto-switching in description
      final vsMeta = AppSettings.getThemeMetadata('vs');
      expect(vsMeta.description, isNot(contains('auto-switches')));
    });

    test('Theme switching should preserve theme family when possible', () async {
      // Set to system mode
      settings.themeMode = ThemeModeOption.system;
      
      // Start with atom-one in light mode
      settings.darkMode = false;
      settings.themeName = 'atom-one-light';
      
      // Switch to dark mode
      settings.darkMode = true;
      
      // Give it a moment to process
      await Future.delayed(Duration(milliseconds: 100));
      
      // Should switch to atom-one-dark (same family)
      expect(settings.themeName, 'atom-one-dark');
    });
  });
}