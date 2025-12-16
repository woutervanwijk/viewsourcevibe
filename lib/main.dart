import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/screens/home_screen.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/models/settings.dart';
import 'package:htmlviewer/services/platform_sharing_handler.dart';
import 'package:htmlviewer/widgets/shared_content_wrapper.dart';

void main() async {
  // Initialize Flutter binding before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  final htmlService = HtmlService();
  final appSettings = AppSettings();

  // Initialize settings persistence
  await appSettings.initialize();

  // Setup system dark mode listener
  final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
  final systemBrightness = platformDispatcher.platformBrightness;
  
  debugPrint('Initial system brightness: $systemBrightness');
  
  // Set initial dark mode based on system (only if in system mode)
  if (appSettings.themeMode == ThemeModeOption.system) {
    debugPrint('Theme mode is system, setting initial dark mode');
    appSettings.darkMode = systemBrightness == Brightness.dark;
  } else {
    debugPrint('Theme mode is ${appSettings.themeMode}, not setting initial dark mode');
  }
  
  // Listen for system brightness changes
  platformDispatcher.onPlatformBrightnessChanged = () {
    final newBrightness = platformDispatcher.platformBrightness;
    final newDarkMode = newBrightness == Brightness.dark;
    
    debugPrint('System brightness changed to: $newBrightness');
    
    if (appSettings.darkMode != newDarkMode) {
      debugPrint('Updating app dark mode to: $newDarkMode');
      appSettings.darkMode = newDarkMode;
    }
  };

  // Setup platform sharing handler
  PlatformSharingHandler.setup();

  // Load sample file in debug mode for easier testing
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    // We're in debug mode
    try {
      await htmlService.loadSampleFile();
    } catch (e) {
      debugPrint('Failed to load sample file: $e');
      // Continue anyway - app will work without sample file
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => htmlService),
        ChangeNotifierProvider(create: (_) => appSettings),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    
    // Determine the effective theme mode based on user preference
    ThemeMode effectiveThemeMode;
    switch (settings.themeMode) {
      case ThemeModeOption.system:
        // Use system preference
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        effectiveThemeMode = platformBrightness == Brightness.dark 
            ? ThemeMode.dark 
            : ThemeMode.light;
        break;
      case ThemeModeOption.light:
        effectiveThemeMode = ThemeMode.light;
        break;
      case ThemeModeOption.dark:
        effectiveThemeMode = ThemeMode.dark;
        break;
    }
    
    return MaterialApp(
      title: 'Vibe HTML Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        brightness: Brightness.dark,
      ),
      themeMode: effectiveThemeMode,
      home: SharedContentWrapper(child: const HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
