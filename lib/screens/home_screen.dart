import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/file_viewer.dart';
import 'package:view_source_vibe/widgets/toolbar.dart';
import 'package:view_source_vibe/widgets/url_input.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AboutScreen(),
              ),
            );
          },
          child: Row(
            children: [
              // App icon to the left of the title
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Image.asset(
                  'assets/icon.webp',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
              const Text(
                'View\nSource\nVibe',
                style: TextStyle(fontSize: 10, height: 1),
                // textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: const [
          Toolbar(),
        ],
        centerTitle: false,
      ),
      body: Column(
        children: [
          const UrlInput(),
          Expanded(
            child: Consumer<HtmlService>(
              builder: (context, htmlService, child) {
                if (htmlService.currentFile == null) {
                  return Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          'No file loaded\n\nEnter an url to view the source\nOr share a file or url to this app\nOr tap the folder icon to open a local file',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(153), // 60% opacity
                          ),
                        ),
                      ));
                }

                // Show a subtle indicator if this is the sample file
                final currentFile = htmlService.currentFile;
                final isSampleFile = currentFile != null &&
                    (currentFile.path.contains('sample.html') ||
                        currentFile.path.contains('assets') ||
                        currentFile.path.contains('fallback'));

                return Column(
                  children: [
                    if (isSampleFile)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        color: const Color.fromRGBO(
                            21, 101, 192, 0.1), // Blue with 10% opacity
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Sample file loaded (Debug Mode)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: currentFile != null
                          ? FileViewer(
                              file: currentFile,
                            )
                          : const Center(
                              child: Text('File data is not available'),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
