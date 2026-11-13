import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/url_history_service.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';
import 'package:view_source_vibe/widgets/section_box.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            // Readable line length on tablets and desktop.
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Appearance'),
                  SectionBox(children: [
                    _settingsTile(
                      context: context,
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      description: _getThemeModeDescription(settings.themeMode),
                      below: SegmentedButton<ThemeModeOption>(
                        segments: [
                          for (final mode in ThemeModeOption.values)
                            ButtonSegment(
                              value: mode,
                              label: Text(_getThemeModeLabel(mode)),
                            ),
                        ],
                        selected: {settings.themeMode},
                        showSelectedIcon: false,
                        style: ButtonStyle(shape: kUiButtonShape),
                        onSelectionChanged: (s) => settings.themeMode = s.first,
                      ),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.palette_outlined,
                      title: 'Syntax highlight theme',
                      description: AppSettings.getThemeMetadata(
                              AppSettings.getBaseThemeName(settings.themeName))
                          .description,
                      control: _valueControl(
                        context,
                        AppSettings.isThemePair(AppSettings.getBaseThemeName(
                                settings.themeName))
                            ? '${AppSettings.getThemeMetadata(AppSettings.getBaseThemeName(settings.themeName)).name} (Auto)'
                            : AppSettings.getThemeMetadata(settings.themeName)
                                .name,
                      ),
                      onTap: () => _showThemeDialog(context, settings),
                    ),
                  ]),
                  const SectionLabel('Source viewer'),
                  SectionBox(children: [
                    _settingsTile(
                      context: context,
                      icon: Icons.format_size,
                      title: 'Font size',
                      description: 'Text size used in the source viewer',
                      control: _valueControl(
                          context, '${settings.fontSize.toInt()}px'),
                      onTap: () => _showFontSizeDialog(context, settings),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.format_list_numbered,
                      title: 'Show line numbers',
                      description: 'Display line numbers in the editor',
                      control: Switch(
                        value: settings.showLineNumbers,
                        onChanged: (value) => settings.showLineNumbers = value,
                      ),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.wrap_text,
                      title: 'Wrap text',
                      description: 'Wrap long lines instead of scrolling',
                      control: Switch(
                        value: settings.wrapText,
                        onChanged: (value) => settings.wrapText = value,
                      ),
                    ),
                  ]),
                  const SectionLabel('Loading pages'),
                  SectionBox(children: [
                    _settingsTile(
                      context: context,
                      icon: Icons.language,
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
                      icon: Icons.vertical_align_bottom,
                      title: 'Load lazy content',
                      description:
                          'Scroll the page once after it loads (and back to the top), so lazy images and embeds are actually fetched and measured in the Page size tab instead of estimated',
                      control: Switch(
                        value: settings.scrollToLoadLazy,
                        onChanged: (value) => settings.scrollToLoadLazy = value,
                      ),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.no_flash_outlined,
                      title: 'Disable browser cache',
                      description:
                          'The in-app browser never uses its cache: every page and resource is downloaded fresh (like the Fresh load measurement)',
                      control: Switch(
                        value: settings.disableBrowserCache,
                        onChanged: (value) =>
                            settings.disableBrowserCache = value,
                      ),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.cookie_outlined,
                      title: 'Always clean cookies',
                      description:
                          'Clear all cookies before every page load, so each visit starts without cookies (consent walls and paywalls may reappear)',
                      control: Switch(
                        value: settings.cleanCookies,
                        onChanged: (value) => settings.cleanCookies = value,
                      ),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.battery_saver_outlined,
                      title: 'Low resource mode',
                      description:
                          'For older devices: pause the Browser/Reader WebView while its tab is hidden, require a tap before media plays, and let the system reclaim memory from hidden pages',
                      control: Switch(
                        value: settings.lowResourceMode,
                        onChanged: (value) => settings.lowResourceMode = value,
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
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(kUiRadius),
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface,
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
                  const SectionLabel('Data'),
                  SectionBox(children: [
                    _settingsTile(
                      context: context,
                      icon: Icons.history,
                      title: 'Clear history',
                      description: 'Remove all saved URLs from history',
                      onTap: () => _confirmClearHistory(context),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.cached,
                      title: 'Clear browser cache',
                      description: 'Clear cached images and files',
                      onTap: () => _clearBrowserCache(context),
                    ),
                    _settingsTile(
                      context: context,
                      icon: Icons.delete_forever_outlined,
                      iconColor: scheme.error,
                      title: 'Clear everything',
                      description: 'Clear cache, cookies, and local storage',
                      onTap: () => _confirmClearEverything(context),
                    ),
                  ]),
                  const SectionLabel('About'),
                  SectionBox(children: [
                    _settingsTile(
                      context: context,
                      icon: Icons.info_outline,
                      title: 'About View Source Vibe',
                      description:
                          'Learn more about the app and development process',
                      onTap: () => _navigateToAboutScreen(context),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: () => settings.resetToDefaults(),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset to defaults'),
                      style: ButtonStyle(shape: kUiButtonShape),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? description,
    Widget? control,
    Widget? below,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        // Icon at the top, control centered on the whole tile height.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                widthFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon,
                      size: 22, color: iconColor ?? theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (below != null) ...[
                      const SizedBox(height: 10),
                      below,
                    ],
                  ],
                ),
              ),
              // Control (switch, value, chevron) to the right of the text.
              if (control != null || onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: control ??
                        Icon(Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueControl(BuildContext context, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }

  // Helper method to get theme mode label
  String _getThemeModeLabel(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return 'System';
      case ThemeModeOption.light:
        return 'Light';
      case ThemeModeOption.dark:
        return 'Dark';
    }
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
