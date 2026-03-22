import 'package:flutter/material.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/source_viewer_editor.dart';

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
            child: SourceViewerEditor.buildEditor(
              content: htmlService.isBeautifyEnabled
                  ? (htmlService.getBeautifiedContentSync(file.content, file.extension) ?? file.content)
                  : file.content,
              extension: file.extension,
              context: context,
              verticalController: ScrollController(),
              horizontalController: htmlService.isBeautifyEnabled
                  ? htmlService.horizontalScrollController
                  : null,
              fontSize: settings.fontSize,
              fontFamily: 'Courier',
              themeName: settings.themeName,
              wrapText: settings.wrapText,
              showLineNumbers: settings.showLineNumbers,
              isBeautified: htmlService.isBeautifyEnabled,
              forceCodeForge: true, // Always use CodeForge in fullscreen mode
            ),
          ),
        ],
      ),
    );
  }
}
