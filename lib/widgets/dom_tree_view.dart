import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/dom_tree.dart';
import 'package:view_source_vibe/services/derive/source_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';

export 'package:view_source_vibe/services/derive/dom_tree.dart'
    show DomTreeNode;

class DomTreeView extends StatefulWidget {
  const DomTreeView({super.key});

  @override
  State<DomTreeView> createState() => _DomTreeViewState();
}

class _DomTreeViewState extends State<DomTreeView> {
  TreeController<DomTreeNode>? _treeController;
  DomTree? _controllerTree;

  /// A controller for [tree]: root expanded, plus head/body/channel.
  TreeController<DomTreeNode> _controllerFor(DomTree tree) {
    if (identical(tree, _controllerTree)) return _treeController!;
    final old = _treeController;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    final controller = TreeController<DomTreeNode>(
      roots: tree.roots,
      childrenProvider: (DomTreeNode node) => node.children,
    );
    if (tree.roots.isNotEmpty) {
      final root = tree.roots.first;
      controller.expand(root);
      for (final child in root.children) {
        if (child.label == 'head' ||
            child.label == 'body' ||
            child.label == 'channel') {
          controller.expand(child);
        }
      }
    }
    _controllerTree = tree;
    return _treeController = controller;
  }

  @override
  void dispose() {
    _treeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = context.select<HtmlService, SourceView>((s) => s.sourceView);
    final tree = context.select<HtmlService, DomTree?>((s) => s.domTree);
    final loading = context
        .select<HtmlService, bool>((s) => s.isLoading || s.isWebViewLoading);

    if (tree == null) {
      return _statusFor(context, view, loading);
    }
    if (tree.roots.isEmpty) {
      return const Center(child: Text('No content to parse'));
    }

    final bottomInset = MediaQuery.of(context).padding.bottom + 50;
    final theme = Theme.of(context);
    final muted =
        TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant);
    final controller = _controllerFor(tree);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            'Source: ${view.label}${tree.note == null ? '' : ' • ${tree.note}'}',
            style: muted,
          ),
        ),
        Expanded(
          child: Scrollbar(
            child: TreeView<DomTreeNode>(
              primary: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomInset),
              treeController: controller,
              nodeBuilder:
                  (BuildContext context, TreeEntry<DomTreeNode> entry) {
                return DomTreeTile(
                  entry: entry,
                  onTap: () => controller.toggleExpansion(entry.node),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// No text to parse: show why (the tree never shows another document).
  Widget _statusFor(BuildContext context, SourceView view, bool loading) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (view.text) {
          Pending<String>() => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(view.pendingMessage, style: muted),
              ],
            ),
          Failed<String>(:final error) => Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error)),
          Unavailable<String>(:final reason, :final detail) => loading
              ? const CircularProgressIndicator()
              : Text(unavailableMessage(reason, detail),
                  textAlign: TextAlign.center, style: muted),
          Present<String>() => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class DomTreeTile extends StatelessWidget {
  final TreeEntry<DomTreeNode> entry;
  final VoidCallback onTap;

  const DomTreeTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  /// Get color for specific tags
  Color _getTagColor(BuildContext context, String tagName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (tagName.toLowerCase()) {
      case 'div':
        return isDark ? Colors.lightBlueAccent : Colors.blue[800]!;
      case 'p':
      case 'span':
        return isDark ? Colors.greenAccent : Colors.green[800]!;
      case 'a':
        return isDark ? Colors.orangeAccent : Colors.deepOrange;
      case 'img':
      case 'video':
      case 'audio':
        return isDark ? Colors.purpleAccent : Colors.purple[700]!;
      case 'script':
      case 'style':
      case 'link':
      case 'meta':
        return Colors.grey;
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return isDark ? Colors.yellowAccent : Colors.orange[900]!;
      case 'form':
      case 'input':
      case 'button':
        return isDark ? Colors.tealAccent : Colors.teal[800]!;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  /// Get icons for specific tags
  List<IconData> _getTagIcons(DomTreeNode node) {
    final icons = <IconData>[];
    final tagName = node.label.toLowerCase();
    final attrs = node.attributes;

    // Base icon for the tag
    switch (tagName) {
      case 'div':
        icons.add(Icons.check_box_outline_blank);
        break;
      case 'p':
        icons.add(Icons.format_align_left);
        break;
      case 'a':
        icons.add(Icons.link);
        break;
      case 'img':
        icons.add(Icons.image);
        break;
      case 'video':
        icons.add(Icons.videocam);
        break;
      case 'audio':
        icons.add(Icons.audiotrack);
        break;
      case 'script':
        icons.add(Icons.code);
        break;
      case 'style':
        icons.add(Icons.brush);
        break;
      case 'link':
        icons.add(Icons.link); // Or generic link icon
        break;
      case 'meta':
        icons.add(Icons.info_outline);
        break;
      case 'form':
        icons.add(Icons.input);
        break;
      case 'input':
      case 'button':
        icons.add(Icons.smart_button);
        break;
      case 'table':
        icons.add(Icons.table_chart);
        break;
      case 'ul':
      case 'ol':
        icons.add(Icons.format_list_bulleted);
        break;
      case 'li':
        icons.add(Icons.circle);
        break;
      case 'span':
        icons.add(Icons.short_text);
        break;
    }

    // External resource indicator
    if (tagName == 'script' && attrs.containsKey('src')) {
      icons.add(Icons.open_in_new);
    } else if (tagName == 'link' && attrs.containsKey('href')) {
      icons.add(Icons.open_in_new);
    } else if (tagName == 'img' && attrs.containsKey('src')) {
      // Don't add external link icon for images, we show thumbnail instead
    }

    return icons;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final baseFontSize =
        Platform.isIOS ? settings.fontSize * 0.8 : settings.fontSize;
    // Adjust tag font size slightly smaller to compensate for bold weight
    // making it appear larger than normal text
    final tagFontSize = baseFontSize;
    final attrFontSize = baseFontSize;
    final textFontSize = baseFontSize;

    final node = entry.node;
    final isElement = node.isElement;
    final attributes = node.attributes;
    final tagName = node.label.toLowerCase();

    // Format attributes for display
    final attrString =
        attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ');

    return TreeIndentation(
      entry: entry,
      guide: const IndentGuide.connectingLines(
        indent: 16,
        color: Colors.grey,
        thickness: 1,
      ),
      child: InkWell(
        onTap: entry.hasChildren ? onTap : null,
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: node.content));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Copied ${isElement ? "<${node.label}>" : "text"} to clipboard'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment
                .center, // Center vertically for better icon alignment
            children: [
              // Expansion arrow
              if (entry.hasChildren)
                Icon(
                  entry.isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: tagFontSize * 1.2,
                  color: Colors.grey,
                )
              else
                SizedBox(width: tagFontSize * 1.2),

              const SizedBox(width: 4),

              if (isElement) ...[
                // Icon or Thumbnail (Thumbnail replaces icon for img)
                if (tagName == 'img' && attributes.containsKey('src'))
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: SizedBox(
                      width: tagFontSize,
                      height: tagFontSize,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.network(
                          attributes['src']!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.broken_image,
                              size: tagFontSize * 0.9,
                              color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  )
                else
                  // Standard Tag Icons
                  ..._getTagIcons(node).map((icon) => Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Icon(icon,
                            size: tagFontSize * 0.9, color: Colors.grey[600]),
                      )),

                // Tag Name with Color
                Text(
                  '<${node.label}',
                  style: TextStyle(
                    color: _getTagColor(context, node.label),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    fontSize: tagFontSize,
                    height: 1.2,
                  ),
                ),

                // Attributes (Restored full visibility)
                if (attrString.isNotEmpty)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        attrString,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontFamily: 'Courier',
                          fontSize: attrFontSize,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),

                // Closing Bracket
                Text(
                  '>',
                  style: TextStyle(
                    color: _getTagColor(context, node.label),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    fontSize: tagFontSize,
                    height: 1.2,
                  ),
                ),
              ] else ...[
                // Text Node
                Expanded(
                  child: Text(
                    node.label,
                    style: TextStyle(
                      fontSize: textFontSize,
                      fontFamily: 'Courier',
                      color: Colors.grey,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
