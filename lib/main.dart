import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/screens/home_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/platform_sharing_handler.dart';
import 'package:view_source_vibe/widgets/shared_content_wrapper.dart';
import 'package:app_links/app_links.dart';
import 'package:universal_io/io.dart';

/// Sets up URL scheme handling for deep linking
Future<void> setupUrlHandling(HtmlService htmlService) async {
  try {
    // Initialize AppLinks
    final appLinks = AppLinks();

    // Handle initial link when app is launched
    final initialUri = await appLinks.getInitialAppLink();
    if (initialUri != null) {
      await _handleDeepLink(initialUri, htmlService);
    }

    // Listen for link changes while app is running
    final subscription = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri, htmlService);
      }
    }, onError: (err) {
      debugPrint('Error in URI stream: $err');
    });

    // Store the subscription to keep it alive
    // In a real app, you might want to manage this subscription lifecycle
    // For this app, we'll let it run for the lifetime of the app
  } catch (e) {
    debugPrint('Error setting up URL handling: $e');
  }
}

/// Handles deep links from URL schemes
Future<void> _handleDeepLink(Uri uri, HtmlService htmlService) async {
  debugPrint('Handling deep link: $uri');

  // Handle viewsourcevibe://open?url=... scheme
  if (uri.scheme == 'viewsourcevibe' && uri.host == 'open') {
    final url = uri.queryParameters['url'];
    if (url != null && url.isNotEmpty) {
      debugPrint('Opening URL from deep link: $url');
      try {
        await htmlService.loadFromUrl(url);
      } catch (e) {
        debugPrint('Error loading URL from deep link: $e');
      }
    }
  }
  // Handle viewsourcevibe://text?content=... scheme
  else if (uri.scheme == 'viewsourcevibe' && uri.host == 'text') {
    final content = uri.queryParameters['content'];
    if (content != null && content.isNotEmpty) {
      debugPrint('Opening text content from deep link: $content');
      try {
        final htmlFile = HtmlFile(
          name: '',
          path: 'shared://text',
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: false,
        );
        await htmlService.loadFile(htmlFile);
      } catch (e) {
        debugPrint('Error loading text from deep link: $e');
      }
    }
  }
  // Handle viewsourcevibe://file?path=... scheme
  else if (uri.scheme == 'viewsourcevibe' && uri.host == 'file') {
    final filePath = uri.queryParameters['path'];
    if (filePath != null && filePath.isNotEmpty) {
      debugPrint('Opening file from deep link: $filePath');
      try {
        // Handle file:// URLs by converting to proper file paths
        String normalizedFilePath = filePath;
        if (filePath.startsWith('file:///')) {
          normalizedFilePath = filePath.replaceFirst('file:///', '/');
        } else if (filePath.startsWith('file///')) {
          normalizedFilePath = filePath.replaceFirst('file///', '/');
        } else if (filePath.startsWith('file://')) {
          normalizedFilePath = filePath.replaceFirst('file://', '/');
        }

        // Read file from filesystem
        final file = File(normalizedFilePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final fileName = normalizedFilePath.split('/').last;

          final htmlFile = HtmlFile(
            name: fileName,
            path: normalizedFilePath,
            content: content,
            lastModified: await file.lastModified(),
            size: await file.length(),
            isUrl: false,
          );
          await htmlService.loadFile(htmlFile);
        } else {
          debugPrint('File does not exist: $normalizedFilePath');
        }
      } catch (e) {
        debugPrint('Error loading file from deep link: $e');
      }
    }
  }
  // Handle http/https URLs directly
  else if (uri.scheme == 'http' || uri.scheme == 'https') {
    debugPrint('Opening web URL: ${uri.toString()}');
    try {
      await htmlService.loadFromUrl(uri.toString());
    } catch (e) {
      debugPrint('Error loading web URL: $e');
    }
  }
}

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

  // Set initial dark mode based on system (only if in system mode)
  if (appSettings.themeMode == ThemeModeOption.system) {
    debugPrint('Theme mode is system, setting initial dark mode');
    appSettings.darkMode = systemBrightness == Brightness.dark;
  } else {
    debugPrint(
        'Theme mode is ${appSettings.themeMode}, not setting initial dark mode');
  }

  // Listen for system brightness changes
  platformDispatcher.onPlatformBrightnessChanged = () {
    final newBrightness = platformDispatcher.platformBrightness;
    final newDarkMode = newBrightness == Brightness.dark;

    // debugPrint('System brightness changed to: $newBrightness');

    if (appSettings.darkMode != newDarkMode) {
      debugPrint('Updating app dark mode to: $newDarkMode');
      appSettings.darkMode = newDarkMode;
    }
  };

  // Setup platform sharing handler
  PlatformSharingHandler.setup();

  // Setup URL scheme handling for deep linking
  setupUrlHandling(htmlService);

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
      title: 'View Source Vibe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
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
          backgroundColor: Color(0xFF1E1E1E), // Dark background for dark theme
          surfaceTintColor: Color(0xFF1E1E1E),
        ),
        brightness: Brightness.dark,
      ),
      themeMode: effectiveThemeMode,
      home: SharedContentWrapper(child: const HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
