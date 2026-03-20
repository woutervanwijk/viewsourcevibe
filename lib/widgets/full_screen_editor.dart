import 'package:flutter/material.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/sourceview.dart';

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
          // Editor toolbar with same options as main tab
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                // Font Size picker
                PopupMenuButton<double>(
                  icon: const Icon(Icons.format_size, size: 20),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(),
                  tooltip: 'Font Size',
                  onSelected: (double size) {
                    settings.fontSize = size;
                  },
                  itemBuilder: (BuildContext context) {
                    return AppSettings.availableFontSizes.map((size) {
                      return PopupMenuItem<double>(
                        value: size,
                        child: Row(
                          children: [
                            Text('${size.toInt()} px'),
                            if (settings.fontSize == size) ...[
                              const Spacer(),
                              Icon(Icons.check,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary),
                            ],
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
                const SizedBox(width: 8),
                // Word Wrap button
                Container(
                  decoration: BoxDecoration(
                    color: settings.wrapText
                        ? Theme.of(context).colorScheme.primary.withAlpha(40)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(
                      settings.wrapText ? Icons.wrap_text : Icons.wrap_text_outlined,
                      size: 20,
                      color: settings.wrapText
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      settings.wrapText = !settings.wrapText;
                    },
                    tooltip: 'Word Wrap',
                  ),
                ),
                const SizedBox(width: 8),
                // Beautify Toggle button
                Container(
                  decoration: BoxDecoration(
                    color: htmlService.isBeautifyEnabled
                        ? Theme.of(context).colorScheme.primary.withAlpha(40)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(
                      htmlService.isBeautifyEnabled
                          ? Icons.format_indent_increase
                          : Icons.format_indent_increase_outlined,
                      size: 20,
                      color: htmlService.isBeautifyEnabled
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      htmlService.toggleIsBeautifyEnabled();
                    },
                    tooltip: htmlService.isBeautifyEnabled
                        ? 'Show Raw'
                        : 'Beautify Code',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Editor content
          Expanded(
            child: SourceView.buildEditor(
              content: file.content,
              extension: file.extension,
              context: context,
              verticalController: ScrollController(),
              horizontalController: ScrollController(),
              activeFindController: htmlService.activeFindController,
              onFindControllerChanged: (controller) {
                // No need to update in full screen mode as it's a separate instance
              },
              fontSize: settings.fontSize,
              fontFamily: settings.effectiveFontFamily,
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