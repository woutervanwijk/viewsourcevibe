import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/widgets/file_viewer.dart';
import 'package:htmlviewer/widgets/toolbar.dart';
import 'package:htmlviewer/widgets/url_input.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibe HTML Viewer'),
        actions: const [
          Toolbar(),
        ],
      ),
      body: Column(
        children: [
          const UrlInput(),
          Expanded(
            child: Consumer<HtmlService>(
              builder: (context, htmlService, child) {
                if (htmlService.currentFile == null) {
                  return const Center(
                    child: Text(
                      'No file loaded. Tap the folder icon to open a file.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Show a subtle indicator if this is the sample file
                final isSampleFile =
                    htmlService.currentFile!.path.contains('sample.html') ||
                        htmlService.currentFile!.path.contains('assets');

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
                    Expanded(child: FileViewer(file: htmlService.currentFile!)),
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
