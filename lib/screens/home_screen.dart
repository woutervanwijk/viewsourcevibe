import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/widgets/file_viewer.dart';
import 'package:htmlviewer/widgets/search_bar.dart' as custom_search;
import 'package:htmlviewer/widgets/toolbar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTML Viewer'),
        actions: const [
          Toolbar(),
        ],
      ),
      body: Column(
        children: [
          const custom_search.SearchBar(),
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
                
                return FileViewer(file: htmlService.currentFile!);
              },
            ),
          ),
        ],
      ),
    );
  }
}