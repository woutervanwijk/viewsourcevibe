import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/models/settings.dart';
import 'package:flutter/material.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('System Theme Integration Tests', () {
    test('ThemeModeOption enum values', () {
      // Test that all theme mode options are available
      expect(ThemeModeOption.values.length, 3);
      expect(ThemeModeOption.values, contains(ThemeModeOption.system));
      expect(ThemeModeOption.values, contains(ThemeModeOption.light));
      expect(ThemeModeOption.values, contains(ThemeModeOption.dark));
    });

    test('Settings default theme mode is system', () {
      final settings = AppSettings();
      
      // Default should be system
      expect(settings.themeMode, ThemeModeOption.system);
    });

    test('Theme mode can be changed', () {
      final settings = AppSettings();
      
      // Test changing to light mode
      settings.themeMode = ThemeModeOption.light;
      expect(settings.themeMode, ThemeModeOption.light);
      
      // Test changing to dark mode
      settings.themeMode = ThemeModeOption.dark;
      expect(settings.themeMode, ThemeModeOption.dark);
      
      // Test changing back to system
      settings.themeMode = ThemeModeOption.system;
      expect(settings.themeMode, ThemeModeOption.system);
    });

    test('Reset to defaults sets theme mode to system', () {
      final settings = AppSettings();
      
      // Change theme mode
      settings.themeMode = ThemeModeOption.light;
      expect(settings.themeMode, ThemeModeOption.light);
      
      // Reset to defaults
      settings.resetToDefaults();
      expect(settings.themeMode, ThemeModeOption.system);
    });
  });

  group('Theme Mode to Flutter ThemeMode Mapping', () {
    test('System theme mode mapping with light brightness', () {
      final effectiveThemeMode = _getEffectiveThemeMode(
        ThemeModeOption.system, 
        Brightness.light
      );
      expect(effectiveThemeMode, ThemeMode.light);
    });

    test('System theme mode mapping with dark brightness', () {
      final effectiveThemeMode = _getEffectiveThemeMode(
        ThemeModeOption.system, 
        Brightness.dark
      );
      expect(effectiveThemeMode, ThemeMode.dark);
    });

    test('Light theme mode mapping ignores system brightness', () {
      final effectiveThemeMode = _getEffectiveThemeMode(
        ThemeModeOption.light, 
        Brightness.dark // Should be ignored
      );
      expect(effectiveThemeMode, ThemeMode.light);
    });

    test('Dark theme mode mapping ignores system brightness', () {
      final effectiveThemeMode = _getEffectiveThemeMode(
        ThemeModeOption.dark, 
        Brightness.light // Should be ignored
      );
      expect(effectiveThemeMode, ThemeMode.dark);
    });
  });
}

// Helper function to simulate theme mode mapping logic from main.dart
ThemeMode _getEffectiveThemeMode(ThemeModeOption themeModeOption, Brightness platformBrightness) {
  switch (themeModeOption) {
    case ThemeModeOption.system:
      return platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    case ThemeModeOption.light:
      return ThemeMode.light;
    case ThemeModeOption.dark:
      return ThemeMode.dark;
  }
}

