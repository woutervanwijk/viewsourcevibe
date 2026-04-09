import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/widgets/media_browser.dart';

class SourceViewer extends StatefulWidget {
  final HtmlFile file;

  const SourceViewer({super.key, required this.file});

  @override
  State<SourceViewer> createState() => _SourceViewerState();
}

class _SourceViewerState extends State<SourceViewer> {
  late ScrollController _verticalController;
  late ScrollController _horizontalController;
  final ValueNotifier<bool> _showScrollToTopFab = ValueNotifier<bool>(false);
  bool _wasSearchEnabled = false;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _verticalController.addListener(_scrollListener);
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.removeListener(_scrollListener);
    _verticalController.dispose();
    _horizontalController.dispose();
    _showScrollToTopFab.dispose();

    super.dispose();
  }

  void _scrollListener() {
    if (_verticalController.hasClients) {
      final shouldShow = _verticalController.offset > 200;
      if (shouldShow != _showScrollToTopFab.value) {
        _showScrollToTopFab.value = shouldShow;
      }
    }
  }

  void _scrollToTop() {
    if (_verticalController.hasClients) {
      _verticalController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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
      case 'plaintext':
        return 'Plain Text';
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
      default:
        return contentType.replaceAll('_', ' ').replaceAll('\\', ' ');
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    // Add null safety and path cleanup
    final fileName = widget.file.name.split('/').last.split('\\').last;
    final fileContent = widget.file.content;
    final lines = fileContent.split('\n');
    final fileExtension = fileName.isNotEmpty
        ? fileName.split('.').last.toLowerCase()
        : '';
    final isHtmlFile = fileExtension == 'html' || fileExtension == 'htm';

    return Stack(children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Selector<HtmlService, _SourceViewerHeaderData>(
            selector: (context, service) => _SourceViewerHeaderData(
              isSearchActive: service.isSearchActive,
              isSearchEnabled: service.isSearchEnabled,
              isMedia: service.isMedia,
              selectedContentType: service.selectedContentType,
              activeFindController: service.activeFindController,
              wrapText: settings.wrapText,
            ),
            builder: (context, data, child) {
              // Activate the find controller only on the false→true transition,
              // not on every rebuild while search is active.
              if (data.isSearchEnabled && !_wasSearchEnabled) {
                _wasSearchEnabled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (data.activeFindController != null &&
                      data.activeFindController!.value == null) {
                    data.activeFindController!.findMode();
                    data.activeFindController!.findInputFocusNode
                        .requestFocus();
                  }
                });
              } else if (!data.isSearchEnabled) {
                _wasSearchEnabled = false;
              }

              final isTapEnabled = !data.isMedia && widget.file.isTextBased;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: isTapEnabled
                        ? () => _showContentTypeMenu(context)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
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
                                  _getDisplayNameForContentType(
                                      data.selectedContentType ??
                                          widget.file.extension),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isTapEnabled ? null : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_formatNumber(lines.length)} lines • ${_formatNumber(widget.file.size)} bytes',
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
                          if (!data.isMedia) ...[
                            // Find button
                            IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final htmlService = Provider.of<HtmlService>(
                                    context,
                                    listen: false);
                                htmlService.toggleSearch();
                              },
                              tooltip: 'Find',
                            ),
                            const SizedBox(width: 2),
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
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  settings.wrapText = !settings.wrapText;
                                },
                                tooltip: 'Word Wrap',
                              ),
                            ),
                            const SizedBox(width: 2),
                            // Beautify Toggle button
                            Consumer<HtmlService>(
                                builder: (context, htmlService, child) {
                              return Row(
                                children: [
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
                                            : Icons
                                                .format_indent_increase_outlined,
                                        size: 20,
                                        color: htmlService.isBeautifyEnabled
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
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
                              );
                            }),
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
                    notification.metrics.axis == Axis.vertical &&
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
              child: Selector<HtmlService, _SourceViewerBodyData>(
                selector: (context, service) => _SourceViewerBodyData(
                  isMedia: service.isMedia,
                  isBeautifyEnabled: service.isBeautifyEnabled,
                  isSearchEnabled: service.isSearchEnabled,
                  selectedContentType: service.selectedContentType,
                  fontSize: settings.fontSize,
                  wrapText: settings.wrapText,
                  showLineNumbers: settings.showLineNumbers,
                  themeName: settings.themeName,
                ),
                builder: (context, data, child) {
                  final htmlService =
                      Provider.of<HtmlService>(context, listen: false);
                  if (data.isMedia) {
                    return MediaBrowser(file: widget.file);
                  }

                  return _buildEditor(
                    context,
                    htmlService,
                    widget.file.content,
                    data,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      ValueListenableBuilder<bool>(
        valueListenable: _showScrollToTopFab,
        builder: (context, showFab, child) {
          if (showFab) {
            return Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'scroll-to-top-source',
                mini: true,
                onPressed: _scrollToTop,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: const Icon(Icons.arrow_upward),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ]);
  }

  Widget _buildEditor(
      BuildContext context,
      HtmlService htmlService,
      String content,
      _SourceViewerBodyData data) {
    return htmlService.buildEditor(
      content,
      data.selectedContentType ?? widget.file.extension,
      context,
      fontSize: data.fontSize,
      fontFamily: 'Courier',
      themeName: data.themeName,
      wrapText: data.wrapText,
      showLineNumbers: data.showLineNumbers,
      isBeautified: htmlService.isBeautifyEnabled,
      isSearchEnabled: data.isSearchEnabled,
      onSearchClosed: () {
        if (htmlService.isSearchEnabled) {
          htmlService.toggleSearch();
        }
      },
      verticalController: _verticalController,
      horizontalController: _horizontalController,
    ) as Widget;
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

/// Helper classes for SourceViewer Selector
@immutable
class _SourceViewerHeaderData {
  final bool isSearchActive;
  final bool isSearchEnabled;
  final bool isMedia;
  final String? selectedContentType;
  final CodeFindController? activeFindController;
  final bool wrapText;

  const _SourceViewerHeaderData({
    required this.isSearchActive,
    required this.isSearchEnabled,
    required this.isMedia,
    required this.wrapText,
    this.selectedContentType,
    this.activeFindController,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SourceViewerHeaderData &&
          runtimeType == other.runtimeType &&
          isSearchActive == other.isSearchActive &&
          isSearchEnabled == other.isSearchEnabled &&
          isMedia == other.isMedia &&
          wrapText == other.wrapText &&
          selectedContentType == other.selectedContentType &&
          activeFindController == other.activeFindController;

  @override
  int get hashCode =>
      isSearchActive.hashCode ^
      isSearchEnabled.hashCode ^
      isMedia.hashCode ^
      wrapText.hashCode ^
      selectedContentType.hashCode ^
      activeFindController.hashCode;
}

@immutable
class _SourceViewerBodyData {
  final bool isMedia;
  final bool isBeautifyEnabled;
  final bool isSearchEnabled;
  final String? selectedContentType;
  final double fontSize;
  final bool wrapText;
  final bool showLineNumbers;
  final String themeName;

  const _SourceViewerBodyData({
    required this.isMedia,
    required this.isBeautifyEnabled,
    required this.isSearchEnabled,
    required this.fontSize,
    required this.wrapText,
    required this.showLineNumbers,
    required this.themeName,
    this.selectedContentType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SourceViewerBodyData &&
          runtimeType == other.runtimeType &&
          isMedia == other.isMedia &&
          isBeautifyEnabled == other.isBeautifyEnabled &&
          isSearchEnabled == other.isSearchEnabled &&
          fontSize == other.fontSize &&
          wrapText == other.wrapText &&
          showLineNumbers == other.showLineNumbers &&
          themeName == other.themeName &&
          selectedContentType == other.selectedContentType;

  @override
  int get hashCode =>
      isMedia.hashCode ^
      isBeautifyEnabled.hashCode ^
      isSearchEnabled.hashCode ^
      fontSize.hashCode ^
      wrapText.hashCode ^
      showLineNumbers.hashCode ^
      themeName.hashCode ^
      selectedContentType.hashCode;
}
