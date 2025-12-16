import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme mode options
enum ThemeModeOption { system, light, dark }

class AppSettings with ChangeNotifier {
  static const String _prefsDarkMode = 'darkMode';
  static const String _prefsThemeName = 'themeName';
  static const String _prefsThemeMode = 'themeMode'; // system, light, dark
  static const String _prefsFontSize = 'fontSize';
  static const String _prefsShowLineNumbers = 'showLineNumbers';
  static const String _prefsWrapText = 'wrapText';
  static const String _prefsAutoDetectLanguage = 'autoDetectLanguage';

  // Shared Preferences instance
  SharedPreferences? _prefs;

  // Theme settings
  ThemeModeOption _themeMode = ThemeModeOption.system; // Default to system
  bool _darkMode = false;
  String _themeName = 'github';

  // Display settings
  double _fontSize = 14.0;
  bool _showLineNumbers = true;

  // Behavior settings
  bool _wrapText = false;
  bool _autoDetectLanguage = true;

  // Getters
  ThemeModeOption get themeMode => _themeMode;
  bool get darkMode => _darkMode;
  String get themeName => _themeName;
  double get fontSize => _fontSize;
  bool get showLineNumbers => _showLineNumbers;
  bool get wrapText => _wrapText;
  bool get autoDetectLanguage => _autoDetectLanguage;

  // Setters with notification and persistence
  set themeMode(ThemeModeOption value) {
    if (_themeMode != value) {
      _themeMode = value;
      _saveSetting(_prefsThemeMode, value.name);
      notifyListeners();
    }
  }

  set darkMode(bool value) {
    if (_darkMode != value) {
      _darkMode = value;
      _saveSetting(_prefsDarkMode, value);
      notifyListeners();
    }
  }

  set themeName(String value) {
    if (_themeName != value) {
      _themeName = value;
      _saveSetting(_prefsThemeName, value);
      notifyListeners();
    }
  }

  set fontSize(double value) {
    if (_fontSize != value) {
      _fontSize = value;
      _saveSetting(_prefsFontSize, value);
      notifyListeners();
    }
  }

  set showLineNumbers(bool value) {
    if (_showLineNumbers != value) {
      _showLineNumbers = value;
      _saveSetting(_prefsShowLineNumbers, value);
      notifyListeners();
    }
  }

  set wrapText(bool value) {
    if (_wrapText != value) {
      _wrapText = value;
      _saveSetting(_prefsWrapText, value);
      notifyListeners();
    }
  }

  set autoDetectLanguage(bool value) {
    if (_autoDetectLanguage != value) {
      _autoDetectLanguage = value;
      _saveSetting(_prefsAutoDetectLanguage, value);
      notifyListeners();
    }
  }

  // Initialize shared preferences
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  // Load settings from shared preferences
  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    // Load theme mode - default to system if not set
    final themeModeString = _prefs!.getString(_prefsThemeMode) ?? 'system';
    _themeMode = ThemeModeOption.values.firstWhere(
      (e) => e.name == themeModeString,
      orElse: () => ThemeModeOption.system,
    );
    
    _darkMode = _prefs!.getBool(_prefsDarkMode) ?? false;
    _themeName = _prefs!.getString(_prefsThemeName) ?? 'github';
    _fontSize = _prefs!.getDouble(_prefsFontSize) ?? 14.0;
    _showLineNumbers = _prefs!.getBool(_prefsShowLineNumbers) ?? true;
    _wrapText = _prefs!.getBool(_prefsWrapText) ?? false;
    _autoDetectLanguage = _prefs!.getBool(_prefsAutoDetectLanguage) ?? true;
  }

  // Save a setting to shared preferences
  Future<void> _saveSetting(String key, dynamic value) async {
    if (_prefs == null) return;

    if (value is bool) {
      await _prefs!.setBool(key, value);
    } else if (value is String) {
      await _prefs!.setString(key, value);
    } else if (value is double) {
      await _prefs!.setDouble(key, value);
    }
  }

  // Reset to defaults
  void resetToDefaults() {
    _themeMode = ThemeModeOption.system;
    _darkMode = false;
    _themeName = 'github';
    _fontSize = 14.0;
    _showLineNumbers = true;
    _wrapText = false;
    _autoDetectLanguage = true;
    
    // Save the default values
    _saveAllSettings();
    
    notifyListeners();
  }

  // Save all settings
  Future<void> _saveAllSettings() async {
    if (_prefs == null) return;

    await _saveSetting(_prefsDarkMode, _darkMode);
    await _saveSetting(_prefsThemeName, _themeName);
    await _saveSetting(_prefsFontSize, _fontSize);
    await _saveSetting(_prefsShowLineNumbers, _showLineNumbers);
    await _saveSetting(_prefsWrapText, _wrapText);
    await _saveSetting(_prefsAutoDetectLanguage, _autoDetectLanguage);
  }

  // Available themes
  static List<String> get availableThemes => [
        'github',
        'github-dark',
        'github-dark-dimmed',
        'androidstudio',
        'atom-one-dark',
        'atom-one-light',
        'vs',
        'vs2015',
        'monokai-sublime',
        'monokai',
        'nord',
        'tokyo-night-dark',
        'tokyo-night-light',
        'dark',
        'lightfair',
      ];

  // Available font sizes
  static List<double> get availableFontSizes => [12.0, 14.0, 16.0, 18.0, 20.0];
}