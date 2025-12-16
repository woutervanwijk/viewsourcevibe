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

    final lines = file.content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File info header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    file.isHtml ? Icons.html : Icons.text_snippet,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${lines.length} lines • ${file.fileSize}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
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
