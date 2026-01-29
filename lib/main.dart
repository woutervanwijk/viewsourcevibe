import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/screens/home_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';
import 'package:view_source_vibe/services/file_system_service.dart';
import 'package:view_source_vibe/services/app_state_service.dart';
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
    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri, htmlService);
      }
    }, onError: (err) {
      debugPrint('Error in URI stream: $err');
    });

    // The subscription is kept alive by the appLinks object
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
  // Handle content:// URIs (Android content provider)
  else if (uri.scheme == 'content') {
    debugPrint('Opening content URI: ${uri.toString()}');
    try {
      // Content URIs should be handled by the Android native code
      // This typically happens when files are shared from Google Docs, etc.
      // The Android code should have already processed this and provided file content
      // If we get here, it means the Android code didn't handle it properly
      debugPrint('Content URI not handled by Android: ${uri.toString()}');
      
      // Fallback: try to load it as a file if possible
      // This is a last resort and may not work for all content URIs
      final errorContent = uri.toString().contains('com.google.android.apps.docs')
        ? (uri.toString().contains('storage') || uri.toString().contains('enc%3Dencoded')
            ? '''Google Drive File Could Not Be Loaded

This file was shared from Google Drive using a content URI:

${uri.toString()}

Google Drive uses security measures that may prevent direct file access. Here's how to share this file:

📱 Google Drive Sharing Guide:

1. Open Google Drive app
2. Find and open the file
3. Tap the three-dot menu (⋮) in the top-right corner
4. Select "Download" to save the file to your device
5. Then share the downloaded file from your file manager

Alternative methods:
- Use "Share link" to create a shareable web link
- Use "Send a copy" to email the file
- Use "Open with" and choose this app to open directly
- Use "Make available offline" then share the local copy

💡 Tip: Google Drive files shared directly may not be accessible due to Google's security policies. Download first, then share!

🔧 Advanced Option:
If you're sharing from Google Drive:
1. Long-press the file
2. Tap "Share"
3. Choose "Save to Files" or "Download"
4. Then share the downloaded file

If you continue to have issues, try using a different file manager app to share the file.'''
            : '''Google Docs File Could Not Be Loaded

This file was shared from Google Docs using an encrypted content URI:

${uri.toString()}

Google Docs uses special security measures that prevent direct file access. Here's how to share this file:

📱 Google Docs Sharing Guide:

1. Open the file in Google Docs
2. Tap the three-dot menu (⋮) in the top-right corner
3. Select "Share & export"
4. Choose "Save as" to download the file to your device
5. Then share the downloaded file from your file manager

Alternative methods:
- Use "Copy to" to save to Google Drive, then share from Drive
- Use "Send a copy" to email the file to yourself
- Use "Print" and save as PDF, then share the PDF

💡 Tip: Google Docs files shared directly may not be accessible due to Google's security policies. Always save a copy first!''')
        : '''Content File Could Not Be Loaded

This file was shared from an Android app using a content URI:

${uri.toString()}

The Android sharing handler should have processed this file and extracted its content, but this failed. Possible reasons:

1. The file is protected by Android security restrictions
2. The sharing app doesn't provide proper file access permissions
3. The file format is not supported
4. The file is too large or corrupted

Try these solutions:
- Open the file in the original app and use "Share as text" instead
- Save the file to your device storage first, then share it
- Use a different app to share the file
- Contact the app developer for support''';
      
      final htmlFile = HtmlFile(
        name: 'Content File Error',
        path: uri.toString(),
        content: errorContent,
        lastModified: DateTime.now(),
        size: errorContent.length,
        isUrl: false,
      );
      await htmlService.loadFile(htmlFile);
    } catch (e) {
      debugPrint('Error loading content URI: $e');
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
  final fileSystemService = FileSystemService();
  final appStateService = await AppStateService.create();

  // Add app lifecycle observer to save state when app goes to background
  final appLifecycleObserver = AppLifecycleObserver(htmlService, appStateService);
  WidgetsBinding.instance.addObserver(appLifecycleObserver);

  // Initialize settings persistence
  await appSettings.initialize();

  // Initialize file system service
  try {
    await fileSystemService.initialize();
  } catch (e) {
    debugPrint('❌ Error initializing FileSystemService: $e');
    // Continue even if file system initialization fails
  }

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

  // Setup unified sharing service (will be initialized in MyApp)
  // UnifiedSharingService.initialize(context);

  // Setup URL scheme handling for deep linking
  setupUrlHandling(htmlService);

  // Load saved app state if available (only if not in debug mode or if no deep link was handled)
  bool shouldRestoreState = true;
  
  // Check if we're in debug mode - if so, load sample file instead of restoring state
  if (kDebugMode) {
    // We're in debug mode
    try {
      await htmlService.loadSampleFile();
      shouldRestoreState = false; // Don't restore state if we loaded a sample file
    } catch (e) {
      debugPrint('Failed to load sample file: $e');
      // Continue anyway - app will work without sample file
    }
  }

  // Restore app state if we should and if there's saved state
  if (shouldRestoreState) {
    try {
      final savedState = appStateService.loadAppState();
      if (savedState != null) {
        debugPrint('🔄 Restoring app state from previous session');
        
        // Restore the file/URL if available
        if (savedState.filePath != null && savedState.filePath!.isNotEmpty) {
          if (savedState.isUrl == true) {
            // It's a URL
            try {
              await htmlService.loadFromUrl(savedState.filePath!);
              debugPrint('🌐 Restored URL: ${savedState.filePath}');
            } catch (e) {
              debugPrint('❌ Failed to restore URL: $e');
            }
          } else {
            // It's a local file - we need to reload it from the filesystem
            try {
              final file = File(savedState.filePath!);
              if (await file.exists()) {
                final content = await file.readAsString();
                final htmlFile = HtmlFile(
                  name: savedState.fileName ?? savedState.filePath!.split('/').last,
                  path: savedState.filePath!,
                  content: content,
                  lastModified: await file.lastModified(),
                  size: await file.length(),
                  isUrl: false,
                );
                await htmlService.loadFile(htmlFile);
                debugPrint('📁 Restored file: ${savedState.filePath}');
              } else {
                debugPrint('❌ File no longer exists: ${savedState.filePath}');
              }
            } catch (e) {
              debugPrint('❌ Failed to restore file: $e');
            }
          }
        }
        
        // Restore scroll positions after the file is loaded
        if (savedState.scrollPosition != null || savedState.horizontalScrollPosition != null) {
          // We'll restore scroll positions after the UI is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            htmlService.restoreScrollPosition(savedState.scrollPosition);
            htmlService.restoreHorizontalScrollPosition(savedState.horizontalScrollPosition);
            debugPrint('📜 Restored scroll positions');
          });
        }
        
        // Restore content type if available
        if (savedState.contentType != null && savedState.contentType!.isNotEmpty) {
          htmlService.selectedContentType = savedState.contentType;
          debugPrint('🎨 Restored content type: ${savedState.contentType}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error restoring app state: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => htmlService),
        ChangeNotifierProvider(create: (_) => appSettings),
        ChangeNotifierProvider(create: (_) => appStateService),
        Provider<FileSystemService>(create: (_) => fileSystemService),
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

    // Initialize unified sharing service when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UnifiedSharingService.initialize(context);
    });

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

class AppLifecycleObserver with WidgetsBindingObserver {
  final HtmlService htmlService;
  final AppStateService appStateService;

  AppLifecycleObserver(this.htmlService, this.appStateService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // App is going to background or being closed - save state
      debugPrint('📱 App going to background, saving state...');
      htmlService.saveCurrentState(appStateService);
    }
  }
}
