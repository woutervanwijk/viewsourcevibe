import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/url_history_service.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';

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

              _card([
                _settingsTile(
                  context: context,
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme Mode',
                  description: _getThemeModeDescription(settings.themeMode),
                  control: _valueControl(
                      _getThemeModeLabel(settings.themeMode)),
                  onTap: () => _showThemeModeDialog(context, settings),
                ),
                _settingsTile(
                  context: context,
                  icon: Icons.palette_outlined,
                  title: 'Syntax Highlight Theme',
                  description: AppSettings.getThemeMetadata(
                          AppSettings.getBaseThemeName(settings.themeName))
                      .description,
                  control: _valueControl(
                    AppSettings.isThemePair(AppSettings.getBaseThemeName(
                            settings.themeName))
                        ? '${AppSettings.getThemeMetadata(AppSettings.getBaseThemeName(settings.themeName)).name} (Auto)'
                        : AppSettings.getThemeMetadata(settings.themeName)
                            .name,
                  ),
                  onTap: () => _showThemeDialog(context, settings),
                ),
              ]),

              const SizedBox(height: 24),

              // Display Settings Section
              const Text(
                'Display Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _card([
                _settingsTile(
                  context: context,
                  icon: Icons.format_size,
                  title: 'Font Size',
                  description: 'Text size used in the source viewer',
                  control: _valueControl('${settings.fontSize.toInt()}px'),
                  onTap: () => _showFontSizeDialog(context, settings),
                ),
                _settingsTile(
                  context: context,
                  icon: Icons.format_list_numbered,
                  title: 'Show Line Numbers',
                  description: 'Display line numbers in editor',
                  control: Switch(
                    value: settings.showLineNumbers,
                    onChanged: (value) => settings.showLineNumbers = value,
                  ),
                ),
                _settingsTile(
                  context: context,
                  icon: Icons.wrap_text,
                  title: 'Wrap Text',
                  description: 'Enable text wrapping',
                  control: Switch(
                    value: settings.wrapText,
                    onChanged: (value) => settings.wrapText = value,
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // Behavior Settings Section
              const Text(
                'Behavior',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _card([
                _settingsTile(
                  context: context,
                  icon: Icons.public,
                  title: 'Always use Browser',
                  description:
                      'Load pages in browser immediately. Disable to load source via Curl first (the more pure loading option to see e.g. cookie walls, etc. and when sites block Curl requests)',
                  control: Switch(
                    value: settings.useBrowserByDefault,
                    onChanged: (value) =>
                        settings.useBrowserByDefault = value,
                  ),
                ),
                _settingsTile(
                  context: context,
                  icon: Icons.gavel_outlined,
                  title: 'Default site jurisdiction',
                  description:
                      'Legal home assumed for a site when the Sovereignty tab cannot detect it. You can change it per site.',
                  control: DropdownButton<String?>(
                    value: settings.homeJurisdictionSetting,
                    isDense: true,
                    iconSize: 18,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onChanged: (value) =>
                        settings.homeJurisdictionSetting = value,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                            'Auto (${jurisdictionLabel(defaultHomeJurisdiction())})'),
                      ),
                      for (final j in homeJurisdictionChoices)
                        DropdownMenuItem(
                          value: j,
                          child: Text(jurisdictionLabel(j)),
                        ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // Data Section
              const Text(
                'Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _card([
                _settingsTile(
                  context: context,
                  icon: Icons.history,
                  title: 'Clear History',
                  description: 'Remove all saved URLs from history',
                  onTap: () => _confirmClearHistory(context),
                ),
              ]),

              const SizedBox(height: 8),

              _card([
                _settingsTile(
                  context: context,
                  icon: Icons.cached,
                  title: 'Clear Browser Cache',
                  description: 'Clear cached images and files',
                  onTap: () => _clearBrowserCache(context),
                ),
                _settingsTile(
                  context: context,
                  icon: Icons.delete_forever,
                  iconColor: Colors.red,
                  title: 'Clear Everything',
                  description: 'Clear cache, cookies, and local storage',
                  onTap: () => _confirmClearEverything(context),
                ),
              ]),

              const SizedBox(height: 24),
              const Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _card([
                _settingsTile(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'About View Source Vibe',
                  description:
                      'Learn more about the app and development process',
                  onTap: () => _navigateToAboutScreen(context),
                ),
              ]),

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

  Widget _card(List<Widget> tiles) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 50),
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _settingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? description,
    Widget? control,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 22, color: iconColor ?? theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing
                else if (control == null && onTap != null)
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            if (description != null || control != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (description != null)
                    Expanded(
                      child: Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (control != null) ...[
                    const SizedBox(width: 12),
                    control,
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _valueControl(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 13)),
        const Icon(Icons.arrow_forward_ios, size: 14),
      ],
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
        title: const Text('Clear History'),
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

  Future<void> _clearBrowserCache(BuildContext context) async {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    await htmlService.clearBrowserCache();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Browser cache cleared')),
      );
    }
  }

  void _confirmClearEverything(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Everything'),
        content: const Text(
            'Are you sure you want to clear all browser data including cookies, cache, and local storage? You will be logged out of websites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final htmlService =
                  Provider.of<HtmlService>(context, listen: false);
              await htmlService.clearBrowserStorage();
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Browser storage and cookies cleared')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
