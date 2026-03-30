import 'package:flutter/material.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/monaco_source_viewer_editor.dart';

class FullScreenEditor extends StatelessWidget {
  final HtmlFile file;
  final AppSettings settings;
  final HtmlService htmlService;

  const FullScreenEditor({
    super.key,
    required this.file,
    required this.settings,
    required this.htmlService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${file.name} - Full Screen Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close Full Screen',
          ),
        ],
      ),
      body: Column(
        children: [
          // Editor content (full screen, no toolbar)
          Expanded(
            child: FutureBuilder<Widget>(
              future: MonacoSourceViewerEditor.buildEditor(
                content: htmlService.isBeautifyEnabled
                    ? (htmlService.getBeautifiedContentSync(
                            file.content, file.extension) ??
                        file.content)
                    : file.content,
                extension: file.extension,
                context: context,
                verticalController: ScrollController(),
                horizontalController: htmlService.isBeautifyEnabled
                    ? htmlService.horizontalScrollController
                    : null,
                activeFindController: htmlService.activeFindController,
                onFindControllerChanged: (controller) {
                  // No need to update in full screen mode as it's a separate instance
                },
                fontSize: settings.fontSize,
                fontFamily: 'Courier',
                themeName: settings.themeName,
                wrapText: settings.wrapText,
                showLineNumbers: settings.showLineNumbers,
                isBeautified: htmlService.isBeautifyEnabled,
                isSearchEnabled: htmlService.isSearchEnabled,
                backgroundColor: Theme.of(context).canvasColor,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return snapshot.data!;
                }
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
