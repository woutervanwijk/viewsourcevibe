import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme metadata class
class ThemeMetadata {
  final String name;
  final String description;
  final bool isDark;

  const ThemeMetadata({
    required this.name,
    required this.description,
    required this.isDark,
  });
}

// Theme mode options
enum ThemeModeOption { system, light, dark }

class AppSettings with ChangeNotifier {
  static const String _prefsDarkMode = 'darkMode';
  static const String _prefsThemeName = 'themeName';
  static const String _prefsThemeMode = 'themeMode'; // system, light, dark
  static const String _prefsFontSize = 'fontSize';
  static const String _prefsShowLineNumbers = 'showLineNumbers';
  static const String _prefsWrapText = 'wrapText';

  // Shared Preferences instance
  SharedPreferences? _prefs;

  // Theme settings
  ThemeModeOption _themeMode = ThemeModeOption.system; // Default to system
  bool _darkMode = false;
  String _themeName = 'github';

  // Display settings
  double _fontSize = 16.0;
  bool _showLineNumbers = true;

  // Behavior settings
  bool _wrapText = false;

  // Getters
  ThemeModeOption get themeMode => _themeMode;
  bool get darkMode => _darkMode;
  String get themeName => _themeName;
  double get fontSize => _fontSize;
  bool get showLineNumbers => _showLineNumbers;
  bool get wrapText => _wrapText;

  // Setters with notification and persistence
  set themeMode(ThemeModeOption value) {
    if (_themeMode != value) {
      _themeMode = value;
      _saveSetting(_prefsThemeMode, value.name);
      
      // Auto-switch theme based on the new theme mode
      // This ensures theme switching works for all theme modes, not just system
      _autoSwitchThemeBasedOnMode();
      
      notifyListeners();
    }
  }

  set darkMode(bool value) {
    if (_darkMode != value) {
      debugPrint('Dark mode changing from $_darkMode to $value');
      _darkMode = value;
      _saveSetting(_prefsDarkMode, value);

      // Auto-switch theme based on dark mode for ALL theme modes
      // This ensures theme switching works whether theme mode is system, light, or dark
      debugPrint('Auto-switching theme based on dark mode change');
      _autoSwitchThemeBasedOnMode();

      notifyListeners();
    }
  }

  /// Theme preferences for intelligent theme switching
  /// Maps themes to their preferred light/dark counterparts
  static final Map<String, String> _themePreferences = {
    // Light themes → Dark preferences
    'vs': 'monokai',           // VS light → Monokai dark
    'vs2015': 'nord',          // VS2015 light → Nord dark
    'lightfair': 'androidstudio', // Lightfair → Android Studio dark
    
    // Dark themes → Light preferences  
    'monokai': 'vs',            // Monokai dark → VS light
    'monokai-sublime': 'vs2015', // Monokai Sublime → VS2015 light
    'nord': 'lightfair',        // Nord dark → Lightfair light
    'androidstudio': 'github',  // Android Studio dark → GitHub light
    'dark': 'github',           // Dark → GitHub light
    
    // Theme pairs are handled separately, but we can add preferences
    'github': 'github-dark',    // GitHub light → GitHub dark
    'github-dark': 'github',    // GitHub dark → GitHub light
    'atom-one': 'atom-one-dark', // Atom One light → Atom One dark
    'atom-one-dark': 'atom-one', // Atom One dark → Atom One light
    'tokyo-night': 'tokyo-night-dark', // Tokyo Night light → Tokyo Night dark
    'tokyo-night-dark': 'tokyo-night', // Tokyo Night dark → Tokyo Night light
  };

  /// Track whether the user has manually selected a specific theme
  /// When true, preserve their exact theme choice regardless of light/dark mode
  bool _preserveManualThemeSelection = false;

  /// Automatically switch syntax theme based on current theme mode and dark mode
  void _autoSwitchThemeBasedOnMode() {
    final isDarkTheme = _getEffectiveDarkMode();
    final baseThemeName = AppSettings.getBaseThemeName(_themeName);

    debugPrint(
        'Auto-switching theme: current=$_themeName, base=$baseThemeName, desiredDark=$isDarkTheme, preserveManual=$_preserveManualThemeSelection');

    // If user has manually selected a specific theme, preserve their choice
    // This is the PRIMARY check that should prevent ALL auto-switching for manual selections
    if (_preserveManualThemeSelection) {
      debugPrint('Preserving manually selected theme: $_themeName (blocking all auto-switching)');
      return; // Don't auto-switch manual selections
    }

    // Check if the current theme is part of a theme pair
    if (AppSettings.isThemePair(baseThemeName)) {
      // Get the appropriate variant for the current dark mode
      final appropriateVariant =
          AppSettings.getThemeVariant(baseThemeName, isDarkTheme);

      debugPrint(
          'Theme pair detected. Switching to variant: $appropriateVariant');

      if (_themeName != appropriateVariant) {
        _themeName = appropriateVariant;
        _saveSetting(_prefsThemeName, appropriateVariant);
        debugPrint('Switched from $_themeName to $appropriateVariant');
      } else {
        debugPrint('Already using correct variant: $appropriateVariant');
      }
    } else {
      // Theme is not part of a pair - check if we need to switch to maintain dark/light consistency
      final currentThemeMeta = AppSettings.getThemeMetadata(_themeName);
      
      if (isDarkTheme && !currentThemeMeta.isDark) {
        // We're in dark mode but using a light theme - switch to a dark theme
        debugPrint('Dark mode enabled but using light theme, switching to dark theme');
        
        // Try to find the preferred dark theme for this light theme
        final preferredDarkTheme = _themePreferences[_themeName] ?? _themePreferences[baseThemeName];
        
        if (preferredDarkTheme != null && AppSettings.getThemeMetadata(preferredDarkTheme).isDark) {
          // Use the preferred dark theme
          _themeName = preferredDarkTheme;
          _saveSetting(_prefsThemeName, preferredDarkTheme);
          debugPrint('Switched from light theme $_themeName to preferred dark theme $preferredDarkTheme');
        } else {
          // Fallback to a sensible default dark theme
          _themeName = 'github-dark';
          _saveSetting(_prefsThemeName, 'github-dark');
          debugPrint('Switched from light theme $_themeName to default dark theme github-dark');
        }
      } else if (!isDarkTheme && currentThemeMeta.isDark) {
        // We're in light mode but using a dark theme - switch to a light theme
        debugPrint('Light mode enabled but using dark theme, switching to light theme');
        
        // Try to find the preferred light theme for this dark theme
        final preferredLightTheme = _themePreferences[_themeName] ?? _themePreferences[baseThemeName];
        
        if (preferredLightTheme != null && !AppSettings.getThemeMetadata(preferredLightTheme).isDark) {
          // Use the preferred light theme
          _themeName = preferredLightTheme;
          _saveSetting(_prefsThemeName, preferredLightTheme);
          debugPrint('Switched from dark theme $_themeName to preferred light theme $preferredLightTheme');
        } else {
          // Fallback to a sensible default light theme
          _themeName = 'github';
          _saveSetting(_prefsThemeName, 'github');
          debugPrint('Switched from dark theme $_themeName to default light theme github');
        }
      } else {
        debugPrint('Theme matches current mode, no switching needed');
      }
    }
  }

  /// Get the effective dark mode based on theme mode setting
  bool _getEffectiveDarkMode() {
    switch (_themeMode) {
      case ThemeModeOption.system:
        return _darkMode; // Use the darkMode setting
      case ThemeModeOption.light:
        return false;
      case ThemeModeOption.dark:
        return true;
    }
  }

  set themeName(String value) {
    if (_themeName != value) {
      _themeName = value;
      _saveSetting(_prefsThemeName, value);
      
      // Check if this is a manual theme selection (not a theme pair)
      final baseThemeName = AppSettings.getBaseThemeName(value);
      if (!AppSettings.isThemePair(baseThemeName)) {
        // User has selected a specific non-pair theme - preserve their choice
        _preserveManualThemeSelection = true;
        debugPrint('Manual theme selection detected: $value - will preserve this choice (blocking all auto-switching)');
      } else {
        // This is a theme pair - allow auto-switching
        _preserveManualThemeSelection = false;
        debugPrint('Theme pair selection detected: $value - will auto-switch variants');
      }
      
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
    _fontSize = _prefs!.getDouble(_prefsFontSize) ?? 16.0;
    _showLineNumbers = _prefs!.getBool(_prefsShowLineNumbers) ?? true;
    _wrapText = _prefs!.getBool(_prefsWrapText) ?? false;

    // Auto-switch theme if in system mode and theme doesn't match current dark mode
    if (_themeMode == ThemeModeOption.system) {
      _autoSwitchThemeBasedOnMode();
    }
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
    _fontSize = 16.0;
    _showLineNumbers = true;
    _wrapText = false;

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
  }

  // Theme categories and metadata
  static final Map<String, ThemeMetadata> _themeMetadata = {
    // Light themes
    'github': ThemeMetadata(
      name: 'GitHub', // Single name for theme pairs
      description: 'Classic theme inspired by GitHub (auto-switches)',
      isDark: false,
    ),
    'atom-one': ThemeMetadata(
      name: 'Atom One', // Single name for theme pairs
      description: 'Clean theme from Atom editor (auto-switches)',
      isDark: false,
    ),
    'tokyo-night': ThemeMetadata(
      name: 'Tokyo Night', // Single name for theme pairs
      description: 'Popular theme inspired by Tokyo nights (auto-switches)',
      isDark: false,
    ),
    'vs': ThemeMetadata(
      name: 'Visual Studio',
      description: 'Light theme based on Visual Studio',
      isDark: false,
    ),
    'vs2015': ThemeMetadata(
      name: 'Visual Studio 2015',
      description: 'Modern light theme from VS 2015',
      isDark: false,
    ),
    'lightfair': ThemeMetadata(
      name: 'Lightfair',
      description: 'Soft and pleasant light theme',
      isDark: false,
    ),

    // Dark themes (kept for internal use, but not shown in UI)
    'github-dark': ThemeMetadata(
      name: 'GitHub Dark',
      description: 'Dark theme inspired by GitHub',
      isDark: true,
    ),
    'github-dark-dimmed': ThemeMetadata(
      name: 'GitHub Dark Dimmed',
      description: 'Softer dark theme with dimmed colors',
      isDark: true,
    ),
    'atom-one-dark': ThemeMetadata(
      name: 'Atom One Dark',
      description: 'Popular dark theme from Atom editor',
      isDark: true,
    ),
    'monokai-sublime': ThemeMetadata(
      name: 'Monokai Sublime',
      description: 'Enhanced Monokai theme from Sublime Text',
      isDark: true,
    ),
    'monokai': ThemeMetadata(
      name: 'Monokai',
      description: 'Classic Monokai dark theme',
      isDark: true,
    ),
    'nord': ThemeMetadata(
      name: 'Nord',
      description: 'Arctic-inspired dark theme with cool colors',
      isDark: true,
    ),
    'tokyo-night-dark': ThemeMetadata(
      name: 'Tokyo Night Dark',
      description: 'Dark theme inspired by Tokyo nights',
      isDark: true,
    ),
    'androidstudio': ThemeMetadata(
      name: 'Android Studio',
      description: 'Dark theme based on Android Studio',
      isDark: true,
    ),
    'dark': ThemeMetadata(
      name: 'Dark',
      description: 'Simple dark theme with high contrast',
      isDark: true,
    ),
  };

  // Available themes (all)
  static List<String> get availableThemes => _themeMetadata.keys.toList();

  // Get theme metadata
  static ThemeMetadata getThemeMetadata(String themeName) {
    return _themeMetadata[themeName] ??
        ThemeMetadata(
          name: themeName,
          description: 'Unknown theme',
          isDark: false,
        );
  }

  // Get themes by category
  static List<String> getThemesByCategory(bool isDark) {
    return _themeMetadata.entries
        .where((entry) => entry.value.isDark == isDark)
        .map((entry) => entry.key)
        .toList();
  }

  // Get light themes
  static List<String> get lightThemes => getThemesByCategory(false);

  // Get dark themes
  static List<String> get darkThemes => getThemesByCategory(true);

  // Theme pairs that have both light and dark variants
  static final Map<String, Map<bool, String>> _themePairs = {
    'github': {
      false: 'github', // Light variant
      true: 'github-dark', // Dark variant
    },
    'atom-one': {
      false: 'atom-one-light', // Light variant
      true: 'atom-one-dark', // Dark variant
    },
    'tokyo-night': {
      false: 'tokyo-night-light', // Light variant
      true: 'tokyo-night-dark', // Dark variant
    },
  };

  // Get theme pairs (only themes that have both light and dark variants)
  static List<String> get themePairs => _themePairs.keys.toList();

  // Get the appropriate theme variant based on dark mode
  static String getThemeVariant(String themePair, bool isDark) {
    return _themePairs[themePair]?[isDark] ?? themePair;
  }

  // Check if a theme is a pair (has both light and dark variants)
  static bool isThemePair(String themeName) {
    return _themePairs.containsKey(themeName);
  }

  // Get the base theme name for a variant
  static String getBaseThemeName(String themeVariant) {
    // Check if this variant belongs to any theme pair
    for (final entry in _themePairs.entries) {
      if (entry.value.values.contains(themeVariant)) {
        return entry.key;
      }
    }
    return themeVariant; // Return as-is if not a variant
  }

  // Available font sizes
  static List<double> get availableFontSizes =>
      [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0];
}
