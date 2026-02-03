import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/widgets/code_find_panel.dart';
import 'package:view_source_vibe/widgets/media_browser.dart';
import 'package:view_source_vibe/widgets/browser_view.dart';
import 'package:view_source_vibe/utils/code_beautifier.dart';

class FileViewer extends StatelessWidget {
  final HtmlFile file;

  const FileViewer({super.key, required this.file});

  void _showContentTypeMenu(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    final availableContentTypes = htmlService.getAvailableContentTypes();
    final selectedContentType = htmlService.selectedContentType;
    final fileExtension =
        htmlService.currentFile?.extension.toLowerCase() ?? 'plaintext';

    showModalBottomSheet(
      context: context,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Content Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableContentTypes.length,
                  itemBuilder: (context, index) {
                    final contentType = availableContentTypes[index];

                    // Determine if this content type is selected
                    final isSelected = selectedContentType != null
                        ? contentType == selectedContentType
                        : contentType == fileExtension ||
                            (contentType == 'automatic' &&
                                selectedContentType == null);

                    return ListTile(
                      leading: _getIconForContentType(contentType),
                      title: Text(_getDisplayNameForContentType(contentType)),
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        htmlService.updateFileContentType(contentType);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Icon _getIconForContentType(String contentType) {
    switch (contentType) {
      case 'automatic':
        return const Icon(Icons.auto_awesome, color: Colors.blue);
      case 'html':
      case 'xml':
      case 'xhtml':
        return const Icon(Icons.html, color: Colors.blue);
      case 'css':
        return const Icon(Icons.css, color: Colors.purple);
      case 'javascript':
      case 'typescript':
      case 'jsx':
      case 'tsx':
        return const Icon(Icons.javascript, color: Colors.amber);
      case 'json':
        return const Icon(Icons.data_object, color: Colors.amber);
      case 'yaml':
      case 'yml':
        return const Icon(Icons.data_array, color: Colors.green);
      case 'markdown':
      case 'md':
        return const Icon(Icons.text_snippet, color: Colors.blue);
      case 'python':
      case 'py':
        return const Icon(Icons.terminal, color: Colors.blue);
      case 'java':
        return const Icon(Icons.coffee, color: Colors.orange);
      case 'dart':
        return const Icon(Icons.code, color: Colors.blue);
      case 'c':
      case 'cpp':
      case 'csharp':
        return const Icon(Icons.developer_mode, color: Colors.blue);
      case 'php':
        return const Icon(Icons.code,
            color: Colors.purple); // Using code icon for PHP
      case 'ruby':
      case 'rb':
        return const Icon(Icons.diamond,
            color: Colors.red); // Using diamond instead of gem
      case 'swift':
        return const Icon(Icons.bolt,
            color: Colors.orange); // Using bolt instead of swift
      case 'go':
        return const Icon(Icons.code, color: Colors.blue);
      case 'rust':
      case 'rs':
        return const Icon(Icons.construction, color: Colors.orange);
      case 'sql':
        return const Icon(Icons.storage, color: Colors.blue);
      case 'plaintext':
      case 'txt':
      case 'text':
      default:
        return const Icon(Icons.text_snippet, color: Colors.grey);
    }
  }

  String _getDisplayNameForContentType(String contentType) {
    switch (contentType) {
      case 'automatic':
        return 'Automatic (Detected)';
      case 'html':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'javascript':
        return 'JavaScript';
      case 'typescript':
        return 'TypeScript';
      case 'json':
        return 'JSON';
      case 'xml':
        return 'HTML/XML';
      case 'yaml':
        return 'YAML';
      case 'markdown':
        return 'Markdown';
      case 'python':
        return 'Python';
      case 'java':
        return 'Java';
      case 'dart':
        return 'Dart';
      case 'c':
        return 'C';
      case 'cpp':
        return 'C++';
      case 'csharp':
        return 'C#';
      case 'php':
        return 'PHP';
      case 'ruby':
        return 'Ruby';
      case 'swift':
        return 'Swift';
      case 'go':
        return 'Go';
      case 'rust':
        return 'Rust';
      case 'sql':
        return 'SQL';
      case 'plaintext':
        return 'Plain Text';
      default:
        return contentType.replaceAll('_', ' ').replaceAll('\\', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    // Add null safety checks
    final fileName = file.name;
    final fileContent = file.content;
    final lines = fileContent.split('\n');
    final fileExtension =
        fileName.isNotEmpty ? file.name.split('.').last.toLowerCase() : '';
    final isHtmlFile = fileExtension == 'html' || fileExtension == 'htm';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File info header or Search Panel
        Consumer<HtmlService>(
          builder: (context, htmlService, child) {
            if (htmlService.isSearchActive &&
                htmlService.activeFindController != null) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: Container(
                  color: Theme.of(context).cardColor,
                  child: CodeFindPanelView(
                    controller: htmlService.activeFindController!,
                    readOnly: false,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 6.0), // Match UrlInput margin
                  ),
                ),
              );
            }

            final isTapEnabled = !htmlService.isWebViewMode &&
                !htmlService.isMedia &&
                file.isTextBased;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap:
                      isTapEnabled ? () => _showContentTypeMenu(context) : null,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          isHtmlFile ? Icons.html : Icons.text_snippet,
                          size: 16,
                          color: isTapEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                fileName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isTapEnabled ? null : Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${lines.length} lines • ${file.fileSize}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(153),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Find, Font Size and Word Wrap buttons - only show for text content and if not in WebView mode
                        if (!htmlService.isMedia) ...[
                          if (!htmlService.isWebViewMode) ...[
                            // Find button
                            IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => htmlService.toggleSearch(),
                              tooltip: 'Find',
                            ),
                            const SizedBox(width: 2),
                            // Font Size picker
                            PopupMenuButton<double>(
                              icon: const Icon(Icons.format_size, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Font Size',
                              onSelected: (double size) {
                                settings.fontSize = size;
                              },
                              itemBuilder: (BuildContext context) {
                                return AppSettings.availableFontSizes
                                    .map((size) {
                                  return PopupMenuItem<double>(
                                    value: size,
                                    child: Row(
                                      children: [
                                        Text('${size.toInt()} px'),
                                        if (settings.fontSize == size) ...[
                                          const Spacer(),
                                          Icon(Icons.check,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            const SizedBox(width: 2),
                            // Word Wrap button
                            Container(
                              decoration: BoxDecoration(
                                color: settings.wrapText
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(40)
                                    : null,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  settings.wrapText
                                      ? Icons.wrap_text
                                      : Icons.wrap_text_outlined,
                                  size: 20,
                                  color: settings.wrapText
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  settings.wrapText = !settings.wrapText;
                                },
                                tooltip: 'Word Wrap',
                              ),
                            ),
                            const SizedBox(width: 2),
                            // Beautify Toggle button
                            Container(
                              decoration: BoxDecoration(
                                color: htmlService.isBeautifyEnabled
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(40)
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
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    htmlService.toggleIsBeautifyEnabled(),
                                tooltip: htmlService.isBeautifyEnabled
                                    ? 'Show Raw'
                                    : 'Beautify Code',
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                          // View Source button - only show in WebView mode
                          if (htmlService.isWebViewMode) ...[
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 20),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  htmlService.extractCurrentWebViewContent(),
                              tooltip: 'Load HTML from Current Page',
                            ),
                            const SizedBox(width: 2),
                          ],
                          // WebView Toggle button - Always show for text files
                          Container(
                            decoration: BoxDecoration(
                              color: htmlService.isWebViewMode
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(40)
                                  : null,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: IconButton(
                              icon: Icon(
                                htmlService.isWebViewMode
                                    ? Icons.code
                                    : Icons.language,
                                size: 20,
                                color: htmlService.isWebViewMode
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  htmlService.toggleIsWebViewMode(),
                              tooltip: htmlService.isWebViewMode
                                  ? 'Show Editor'
                                  : 'Show Browser Preview',
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const Divider(height: 1),

        // File content with built-in syntax highlighting and line numbers
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // On iOS, tapping the status bar triggers a scroll to top.
              // We detect this by checking for a scroll update with no drag details
              // that reaches the top boundary.
              if (Theme.of(context).platform == TargetPlatform.iOS &&
                  notification is ScrollUpdateNotification &&
                  notification.dragDetails == null &&
                  notification.metrics.pixels >= -50 &&
                  notification.metrics.pixels <= 10) {
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);

                // Target the PrimaryScrollController (associated with editor)
                final vController = PrimaryScrollController.of(context);

                if (vController.hasClients && vController.offset > 10) {
                  vController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );

                  // Also scroll horizontal to start for better UX
                  final hController = htmlService.horizontalScrollController;
                  if (hController != null &&
                      hController.hasClients &&
                      hController.offset > 0) {
                    hController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                }
              }
              return false;
            },
            child: Consumer<HtmlService>(
              builder: (context, htmlService, child) {
                if (htmlService.isMedia) {
                  return MediaBrowser(file: file);
                }

                if (htmlService.isWebViewMode) {
                  return BrowserView(
                    file: file,
                    gestureRecognizers: {
                      Factory<VerticalDragGestureRecognizer>(
                        () =>
                            VerticalDragGestureRecognizer()..onUpdate = (_) {},
                      ),
                    },
                  );
                }

                String displayContent = file.content;
                if (htmlService.isBeautifyEnabled) {
                  displayContent = CodeBeautifier.beautify(
                    file.content,
                    htmlService.selectedContentType ?? file.extension,
                  );
                }

                // Build the editor, handling both cached (sync) and new (async) states
                // explicitly to prevent flickering and crashes.
                final result = htmlService.buildEditor(
                  displayContent,
                  htmlService.selectedContentType ?? file.extension,
                  context,
                  fontSize: settings.fontSize,
                  themeName: settings.themeName,
                  wrapText: settings.wrapText,
                  showLineNumbers: settings.showLineNumbers,
                );

                // If cached, return immediately (no flicker)
                if (result is Widget) {
                  return result;
                }

                // If async, show loading indicator
                return FutureBuilder<Widget>(
                  // Use key to force rebuild when content changes
                  key: ValueKey(
                      '${htmlService.currentFile?.path}_${htmlService.selectedContentType}'),
                  future: result,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      return snapshot.data!;
                    }

                    // Show loading indicator
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing syntax highlighting...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class SearchHighlightPainter extends CustomPainter {
  final List<int> searchResults;
  final int currentIndex;
  final String searchQuery;
  final String content;

  SearchHighlightPainter({
    required this.searchResults,
    required this.currentIndex,
    required this.searchQuery,
    required this.content,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (searchResults.isEmpty || searchQuery.isEmpty) return;

    // Simplified search highlight - draws placeholder rectangles
    // In a real app, you'd calculate exact text positions
    for (int i = 0; i < searchResults.length; i++) {
      // For demo purposes, we'll just highlight the current search result
      if (i == currentIndex) {
        // For demo purposes, we'll just highlight the current search result
        if (i == currentIndex) {
          // This would need proper text measurement in a real implementation
          // For now, we'll just draw a rectangle as a placeholder
          final rect = Rect.fromLTWH(0, i * 20.0, size.width, 20);

          final paint = Paint()
            ..color = Colors.yellow
                .withAlpha(77) // Use withAlpha instead of withOpacity
            ..style = PaintingStyle.fill;

          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
