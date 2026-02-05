import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/url_history_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme Settings Section
              const Text(
                'Theme Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Theme Mode Selection
                      ListTile(
                        title: const Text('Theme Mode'),
                        subtitle: Text(_getThemeModeLabel(settings.themeMode)),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _showThemeModeDialog(context, settings),
                      ),

                      // Syntax Highlight Theme
                      ListTile(
                        title: const Text('Syntax Highlight Theme'),
                        subtitle: Text(
                          AppSettings.isThemePair(AppSettings.getBaseThemeName(
                                  settings.themeName))
                              ? '${AppSettings.getThemeMetadata(AppSettings.getBaseThemeName(settings.themeName)).name} (Auto)'
                              : AppSettings.getThemeMetadata(settings.themeName)
                                  .name,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _showThemeDialog(context, settings),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Display Settings Section
              const Text(
                'Display Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Font Size
                      ListTile(
                        title: const Text('Font Size'),
                        subtitle: Text('${settings.fontSize.toInt()}px'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _showFontSizeDialog(context, settings),
                      ),

                      // Line Numbers Toggle
                      SwitchListTile(
                        title: const Text('Show Line Numbers'),
                        subtitle: const Text('Display line numbers in editor'),
                        value: settings.showLineNumbers,
                        onChanged: (value) => settings.showLineNumbers = value,
                        secondary: const Icon(Icons.format_list_numbered),
                      ),

                      // Text Wrap Toggle
                      SwitchListTile(
                        title: const Text('Wrap Text'),
                        subtitle: const Text('Enable text wrapping'),
                        value: settings.wrapText,
                        onChanged: (value) => settings.wrapText = value,
                        secondary: const Icon(Icons.wrap_text),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Behavior Settings Section
              const Text(
                'Behavior',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Browser Default Toggle
                      SwitchListTile(
                        title: const Text('Always use Browser'),
                        subtitle: const Text(
                            'Load pages in browser immediately. Disable to load source via Curl first (the more pure loading option to see e.g. cookie walls, etc. and when sites block Curl requests)'),
                        value: settings.useBrowserByDefault,
                        onChanged: (value) =>
                            settings.useBrowserByDefault = value,
                        secondary: const Icon(Icons.public),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Data Section
              const Text(
                'Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListTile(
                    title: const Text('Clear Search History'),
                    subtitle: const Text('Remove all saved URLs from history'),
                    trailing: const Icon(Icons.delete_outline),
                    onTap: () => _confirmClearHistory(context),
                  ),
                ),
              ),
              const Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListTile(
                    title: const Text('About View Source Vibe'),
                    subtitle: const Text(
                        'Learn more about the app and development process'),
                    trailing: const Icon(Icons.info_outline),
                    onTap: () => _navigateToAboutScreen(context),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Reset and Close Buttons
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => settings.resetToDefaults(),
                      child: const Text('Reset to Defaults'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get theme mode label
  String _getThemeModeLabel(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return 'Follow system settings';
      case ThemeModeOption.light:
        return 'Always light theme';
      case ThemeModeOption.dark:
        return 'Always dark theme';
    }
  }

  void _showThemeModeDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme Mode'),
        content: SingleChildScrollView(
          child: Column(
            children: ThemeModeOption.values
                .map((mode) => ListTile(
                      title: Text(_getThemeModeLabel(mode)),
                      subtitle: Text(_getThemeModeDescription(mode)),
                      trailing: settings.themeMode == mode
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        settings.themeMode = mode;
                        Navigator.of(context).pop();
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Helper method to get theme mode description
  String _getThemeModeDescription(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return 'Automatically switch between light and dark based on system settings';
      case ThemeModeOption.light:
        return 'Always use light theme regardless of system settings';
      case ThemeModeOption.dark:
        return 'Always use dark theme regardless of system settings';
    }
  }

  void _showThemeDialog(BuildContext context, AppSettings settings) {
    // Get theme pairs that auto-switch based on dark mode
    final themePairs = AppSettings.themePairs;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Syntax Theme'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Auto-Switching Themes (Recommended)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Text(
                'These themes automatically switch between light/dark variants',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),

              // Theme pairs section
              ...themePairs.map((themePair) {
                final meta = AppSettings.getThemeMetadata(themePair);
                final baseThemeName =
                    AppSettings.getBaseThemeName(settings.themeName);

                return ListTile(
                  title: Text(meta.name),
                  subtitle: Text(
                    meta.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: baseThemeName == themePair
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    // Set the base theme name, auto-switching will handle the variant
                    final variant = AppSettings.getThemeVariant(
                        themePair, settings.darkMode);
                    settings.themeName = variant;
                    Navigator.of(context).pop();
                  },
                );
              }),

              const Divider(),

              // Individual themes section (for advanced users)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Individual Themes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Text(
                'These themes do not auto-switch',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),

              // Individual themes (non-paired themes)
              ...AppSettings.availableThemes
                  .where((theme) =>
                          !AppSettings.isThemePair(theme) &&
                          !theme.contains('-') // Exclude variants
                      )
                  .map((theme) {
                final meta = AppSettings.getThemeMetadata(theme);
                return ListTile(
                  title: Text(meta.name),
                  subtitle: Text(
                    meta.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: settings.themeName == theme
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    settings.themeName = theme;
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Font Size'),
        content: SingleChildScrollView(
          child: Column(
            children: AppSettings.availableFontSizes
                .map((size) => ListTile(
                      title: Text('${size.toInt()}px'),
                      trailing: settings.fontSize == size
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        settings.fontSize = size;
                        Navigator.of(context).pop();
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToAboutScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AboutScreen(),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Search History'),
        content: const Text(
            'Are you sure you want to clear your entire search history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Provider.of<UrlHistoryService>(context, listen: false)
                  .clearHistory();
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search history cleared')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
