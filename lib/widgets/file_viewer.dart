import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:htmlviewer/models/settings.dart';

class FileViewer extends StatelessWidget {
  final HtmlFile file;
  final ScrollController? scrollController;

  const FileViewer({super.key, required this.file, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final settings = Provider.of<AppSettings>(context);

    // Add null safety checks
    final fileName = file.name;
    final fileContent = file.content;
    final lines = fileContent.split('\n');
    final fileExtension = file.extension;
    final isHtmlFile = fileExtension == 'html' || fileExtension == 'htm';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File info header - more compact
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(
                isHtmlFile ? Icons.html : Icons.text_snippet,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${lines.length} lines • ${file.fileSize}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(153), // 60% opacity
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // File content with built-in syntax highlighting and line numbers
        Expanded(
          child: htmlService.buildHighlightedText(
            file.content,
            file.extension,
            context,
            fontSize: settings.fontSize,
            themeName: settings.themeName,
            wrapText: settings.wrapText,
            showLineNumbers: settings.showLineNumbers,
            scrollController: scrollController,
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
