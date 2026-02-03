import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

class ContextMenuItemWidget extends PopupMenuItem<void>
    implements PreferredSizeWidget {
  ContextMenuItemWidget({
    super.key,
    required String text,
    required VoidCallback super.onTap,
  }) : super(child: Text(text));

  @override
  Size get preferredSize => const Size(150, 25);
}

class ContextMenuControllerImpl implements SelectionToolbarController {
  const ContextMenuControllerImpl();

  // Regex to detect URLs (http/https/ftp) or protocol-relative URLs (//)
  static final RegExp _urlRegex = RegExp(
    r'((?:https?:)?\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|(?:https?:)?\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|ftp:\/\/[a-zA-Z0-9]+\.[^\s]{2,})',
    caseSensitive: false,
  );

  bool _isDelimiter(int codeUnit) {
    // Whitespace: Space(32), Tab(9), LF(10), CR(13)
    // Quotes: "(34), '(39)
    // HTML/XML brackets: <(60), >(62)
    // Assignment: =(61)
    return codeUnit == 32 ||
        codeUnit == 9 ||
        codeUnit == 10 ||
        codeUnit == 13 ||
        codeUnit == 34 ||
        codeUnit == 39 ||
        codeUnit == 60 ||
        codeUnit == 62 ||
        codeUnit == 61;
  }

  String _cleanUrl(String url) {
    // Remove trailing punctuation often caught
    while (url.endsWith(')') ||
        url.endsWith(',') ||
        url.endsWith('.') ||
        url.endsWith(';')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String? _detectUrl(String text, int index) {
    if (text.isEmpty) return null;

    // Safety clamp
    final int safeIndex = index.clamp(0, text.length - 1);

    int start = safeIndex;
    int end = safeIndex;

    // Walk backwards
    while (start > 0 && !_isDelimiter(text.codeUnitAt(start - 1))) {
      start--;
    }

    // Walk forwards
    while (end < text.length && !_isDelimiter(text.codeUnitAt(end))) {
      end++;
    }

    String token = text.substring(start, end).trim();

    // 1. Check for absolute or protocol-relative URL
    if (_urlRegex.hasMatch(token)) {
      final match = _urlRegex.firstMatch(token);
      if (match != null) {
        final found = _cleanUrl(match.group(0)!);
        return found;
      }
    }

    // 2. Check for Relative URL (basic pattern)
    // Must contain / or have a known extension
    if (token.contains('/') ||
        token.endsWith('.html') ||
        token.endsWith('.css') ||
        token.endsWith('.js') ||
        token.endsWith('.php')) {
      return token;
    }

    return null;
  }

  @override
  void hide(BuildContext context) {}

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // The anchors and renderRect from re_editor are relative to the CodeEditor widget
    final Rect localRect = renderRect ??
        Rect.fromPoints(
          anchors.primaryAnchor,
          anchors.secondaryAnchor ?? anchors.primaryAnchor,
        );

    final Offset globalTopLeft = renderBox.localToGlobal(localRect.topLeft);
    final Offset globalBottomRight =
        renderBox.localToGlobal(localRect.bottomRight);
    final Rect globalRect = Rect.fromPoints(globalTopLeft, globalBottomRight);

    // Get the horizontal center of the selection
    final double centerX = globalRect.center.dx;
    // ContextMenuItemWidget has preferredSize of 150 width
    const double menuWidth = 150.0;

    // Get the overlay's render box to determine the container size
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Calculate the left position to center the menu horizontally
    // Offset by half the width, and clamp to screen boundaries
    final double left =
        (centerX - (menuWidth / 2)).clamp(0.0, overlay.size.width - menuWidth);

    // Link detection
    String? detectedUrl;
    final selection = controller.selection;

    // 1. Handle Selection Range
    if (!selection.isCollapsed) {
      if (selection.startIndex == selection.endIndex) {
        // Same line range
        final int lineIndex = selection.startIndex;
        if (lineIndex >= 0 && lineIndex < controller.codeLines.length) {
          final lineText = controller.codeLines[lineIndex].text;
          final int start = selection.startOffset;
          final int end = selection.endOffset;
          if (start >= 0 && end > start && end <= lineText.length) {
            final selectedText = lineText.substring(start, end).trim();
            if (_urlRegex.hasMatch(selectedText)) {
              detectedUrl =
                  _cleanUrl(_urlRegex.firstMatch(selectedText)!.group(0)!);
            } else if (selectedText.contains('/') ||
                selectedText.endsWith('.html')) {
              detectedUrl = selectedText;
            }
          }
        }
      }
    }

    // 2. Handle Cursor (single tap/longpress)
    if (detectedUrl == null &&
        selection.baseIndex >= 0 &&
        selection.baseIndex < controller.codeLines.length) {
      final lineIndex = selection.baseIndex;
      final charOffset = selection.baseOffset;
      final lineText = controller.codeLines[lineIndex].text;

      detectedUrl = _detectUrl(lineText, charOffset);
    }

    final htmlService = Provider.of<HtmlService>(context, listen: false);

    showMenu(
        requestFocus: false,
        context: context,
        position: RelativeRect.fromLTRB(
          left,
          globalRect.top,
          overlay.size.width - left - menuWidth,
          overlay.size.height - globalRect.bottom,
        ),
        items: [
          if (detectedUrl != null)
            ContextMenuItemWidget(
              text: 'Open Link',
              onTap: () {
                String targetUrl = detectedUrl!;
                // Handle protocol-relative URLs
                if (targetUrl.startsWith('//')) {
                  targetUrl = 'https:$targetUrl';
                } else if (!targetUrl.contains('://') &&
                    !targetUrl.startsWith('data:')) {
                  // Resolve relative URL
                  final currentFile = htmlService.currentFile;
                  if (currentFile != null && currentFile.isUrl) {
                    try {
                      final uri = Uri.parse(currentFile.path);
                      final resolvedUri = uri.resolve(targetUrl);
                      targetUrl = resolvedUri.toString();
                    } catch (e) {
                      debugPrint('Error resolving relative URL: $e');
                    }
                  }
                }
                htmlService.loadFromUrl(targetUrl);
              },
            ),
          ContextMenuItemWidget(
            text: 'Copy',
            onTap: () {
              controller.copy();
            },
          ),
          ContextMenuItemWidget(
            text: 'Select All',
            onTap: () {
              controller.selectAll();
            },
          ),
        ]);
  }
}
