import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/monaco_source_viewer_editor.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';

/// A tab widget that preserves the editor state when switching tabs.
/// This uses AutomaticKeepAliveClientMixin to prevent the editor from being
/// disposed and recreated when the tab is not visible.
class EditorTab extends StatefulWidget {
  final HtmlFile file;
  final AppSettings settings;
  final HtmlService htmlService;

  const EditorTab({
    super.key,
    required this.file,
    required this.settings,
    required this.htmlService,
  });

  @override
  State<EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<EditorTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Cache the editor widget to prevent rebuilding
  Widget? _cachedEditor;
  String? _cachedContentHash;

  @override
  void didUpdateWidget(EditorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear cache when settings change to force rebuild with new settings
    if (oldWidget.settings.fontSize != widget.settings.fontSize ||
        oldWidget.settings.themeName != widget.settings.themeName ||
        oldWidget.settings.wrapText != widget.settings.wrapText ||
        oldWidget.settings.showLineNumbers != widget.settings.showLineNumbers ||
        oldWidget.htmlService.isBeautifyEnabled !=
            widget.htmlService.isBeautifyEnabled) {
      _cachedEditor = null;
      _cachedContentHash = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // This is required for AutomaticKeepAliveClientMixin

    // Calculate current content hash to detect changes
    final currentContent = widget.htmlService.isBeautifyEnabled
        ? (widget.htmlService.getBeautifiedContentSync(
                widget.file.content, widget.file.extension) ??
            widget.file.content)
        : widget.file.content;

    final currentContentHash =
        '${currentContent.hashCode}_${widget.file.extension}_${widget.settings.fontSize}_'
        '${widget.settings.themeName}_${widget.settings.wrapText}_${widget.settings.showLineNumbers}_'
        '${widget.htmlService.isBeautifyEnabled}_${widget.htmlService.isSearchEnabled}';

    // If we have a cached editor and content hasn't changed, use the cached version
    if (_cachedEditor != null && _cachedContentHash == currentContentHash) {
      return _cachedEditor!;
    }

    // Otherwise, build a new editor
    return FutureBuilder<Widget>(
      future: MonacoSourceViewerEditor.buildEditor(
        content: currentContent,
        extension: widget.file.extension,
        context: context,
        fontSize: widget.settings.fontSize,
        fontFamily: 'Courier', // Default font family
        themeName: widget.settings.themeName,
        wrapText: widget.settings.wrapText,
        showLineNumbers: widget.settings.showLineNumbers,
        isBeautified: widget.htmlService.isBeautifyEnabled,
        isSearchEnabled: widget.htmlService.isSearchEnabled,
        activeFindController: widget.htmlService.activeFindController,
        onFindControllerChanged: (controller) =>
            widget.htmlService.updateActiveFindController(controller),
        onSearchClosed: widget.htmlService.toggleSearch,
        backgroundColor: Theme.of(context).canvasColor,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          // Cache the editor widget to prevent future flashes
          _cachedEditor = snapshot.data!;
          _cachedContentHash = currentContentHash;
          return snapshot.data!;
        }

        // Show loading indicator only while actually loading
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading editor...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}
