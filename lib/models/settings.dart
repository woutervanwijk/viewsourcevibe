import 'package:flutter/material.dart';

class AppSettings with ChangeNotifier {
  // Theme settings
  bool _darkMode = false;
  String _themeName = 'github';

  // Display settings
  double _fontSize = 14.0;
  bool _showLineNumbers = true;

  // Behavior settings
  bool _wrapText = false;
  bool _autoDetectLanguage = true;

  // Getters
  bool get darkMode => _darkMode;
  String get themeName => _themeName;
  double get fontSize => _fontSize;
  bool get showLineNumbers => _showLineNumbers;
  bool get wrapText => _wrapText;
  bool get autoDetectLanguage => _autoDetectLanguage;

  // Setters with notification
  set darkMode(bool value) {
    if (_darkMode != value) {
      _darkMode = value;
      notifyListeners();
    }
  }

  set themeName(String value) {
    if (_themeName != value) {
      _themeName = value;
      notifyListeners();
    }
  }

  set fontSize(double value) {
    if (_fontSize != value) {
      _fontSize = value;
      notifyListeners();
    }
  }

  set showLineNumbers(bool value) {
    if (_showLineNumbers != value) {
      _showLineNumbers = value;
      notifyListeners();
    }
  }

  set wrapText(bool value) {
    if (_wrapText != value) {
      _wrapText = value;
      notifyListeners();
    }
  }

  set autoDetectLanguage(bool value) {
    if (_autoDetectLanguage != value) {
      _autoDetectLanguage = value;
      notifyListeners();
    }
  }

  // Reset to defaults
  void resetToDefaults() {
    _darkMode = false;
    _themeName = 'github';
    _fontSize = 14.0;
    _showLineNumbers = true;
    _wrapText = false;
    _autoDetectLanguage = true;
    notifyListeners();
  }

  // Available themes
  static List<String> get availableThemes => [
        'github',
        'androidstudio',
        'atom-one-dark',
        'vs2015',
        'solarized-light',
        'monokai-sublime',
      ];

  // Available font sizes
  static List<double> get availableFontSizes => [12.0, 14.0, 16.0, 18.0, 20.0];
}
