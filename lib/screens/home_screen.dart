import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/file_viewer.dart';
import 'package:view_source_vibe/widgets/toolbar.dart';
import 'package:view_source_vibe/widgets/url_input.dart';
import 'package:view_source_vibe/widgets/probe_results_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
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
        ),
        actions: const [
          Toolbar(),
        ],
        centerTitle: false,
      ),
      body: Column(
        children: [
          Consumer<HtmlService>(
            builder: (context, htmlService, child) {
              return const UrlInput();
            },
          ),
          Expanded(
            child: Consumer<HtmlService>(
              builder: (context, htmlService, child) {
                if (htmlService.currentFile == null) {
                  return Padding(
                      padding: const EdgeInsets.all(8),
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

                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          currentFile != null
                              ? FileViewer(
                                  file: currentFile,
                                  scrollController: _scrollController,
                                )
                              : const Center(
                                  child: Text('File data is not available'),
                                ),
                          // Overlay Probe Results if active
                          const ProbeResultsOverlay(),
                        ],
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
