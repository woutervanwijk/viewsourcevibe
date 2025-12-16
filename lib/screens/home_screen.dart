import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/widgets/file_viewer.dart';
import 'package:htmlviewer/widgets/toolbar.dart';
import 'package:htmlviewer/widgets/url_input.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    // Listen to HTML service changes to scroll to top when file loads
    final htmlService = context.read<HtmlService>();
    htmlService.addListener(_onFileLoaded);
  }

  @override
  void dispose() {
    final htmlService = context.read<HtmlService>();
    htmlService.removeListener(_onFileLoaded);
    _scrollController?.dispose();
    super.dispose();
  }

  void _onFileLoaded() {
    // Scroll to top when a new file is loaded
    if (_scrollController!.hasClients) {
      _scrollController?.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _scrollController ??= PrimaryScrollController.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibe HTML Viewer', style: TextStyle(fontSize: 18)),
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
                  return Center(
                    child: Text(
                      'No file loaded. Tap the folder icon to open a file.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(153), // 60% opacity
                      ),
                    ),
                  );
                }

                // Show a subtle indicator if this is the sample file
                final currentFile = htmlService.currentFile;
                final isSampleFile = currentFile != null &&
                    (currentFile.path.contains('sample.html') ||
                     currentFile.path.contains('assets'));

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
                              scrollController: _scrollController,
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
