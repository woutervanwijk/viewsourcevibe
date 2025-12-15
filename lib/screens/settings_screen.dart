import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/models/settings.dart';

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
                      // Dark Mode Toggle
                      SwitchListTile(
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Enable dark theme'),
                        value: settings.darkMode,
                        onChanged: (value) => settings.darkMode = value,
                        secondary: const Icon(Icons.dark_mode),
                      ),
                      
                      // Theme Selection
                      ListTile(
                        title: const Text('Syntax Highlight Theme'),
                        subtitle: Text(settings.themeName),
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
                'Behavior Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SwitchListTile(
                    title: const Text('Auto Detect Language'),
                    subtitle: const Text('Automatically detect file language'),
                    value: settings.autoDetectLanguage,
                    onChanged: (value) => settings.autoDetectLanguage = value,
                    secondary: const Icon(Icons.language),
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

  void _showThemeDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: SingleChildScrollView(
          child: Column(
            children: AppSettings.availableThemes.map((theme) => 
              ListTile(
                title: Text(theme),
                trailing: settings.themeName == theme 
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  settings.themeName = theme;
                  Navigator.of(context).pop();
                },
              )
            ).toList(),
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
            children: AppSettings.availableFontSizes.map((size) => 
              ListTile(
                title: Text('${size.toInt()}px'),
                trailing: settings.fontSize == size 
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  settings.fontSize = size;
                  Navigator.of(context).pop();
                },
              )
            ).toList(),
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
}