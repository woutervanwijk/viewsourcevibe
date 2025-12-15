import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/screens/home_screen.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/models/settings.dart';

void main() async {
  // Initialize Flutter binding before any async operations
  WidgetsFlutterBinding.ensureInitialized();
  
  final htmlService = HtmlService();
  
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
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTML Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}