import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';

class DomTreeNode {
  final String label;
  final String content; // Outer HTML or Text
  final Map<String, String> attributes;
  final List<DomTreeNode> children;
  final bool isElement;

  DomTreeNode({
    required this.label,
    required this.content,
    required this.attributes,
    required this.children,
    required this.isElement,
  });
}

class DomTreeView extends StatefulWidget {
  const DomTreeView({super.key});

  @override
  State<DomTreeView> createState() => _DomTreeViewState();
}

class _DomTreeViewState extends State<DomTreeView> {
  late TreeController<DomTreeNode> _treeController;
  String? _lastContent;

  @override
  void initState() {
    super.initState();
    _treeController = TreeController<DomTreeNode>(
      roots: [],
      childrenProvider: (DomTreeNode node) => node.children,
    );
  }

  void _updateTree(HtmlService htmlService, String content) {
    if (content.isEmpty) {
      setState(() {
        _treeController.roots = [];
      });
      return;
    }

    List<DomTreeNode> roots = [];

    // RSS, ATOM, SVG, XML should use the XML parser for better accuracy
    final isStrictXml = htmlService.isXml || htmlService.isSvg;

    if (isStrictXml) {
      try {
        final doc = xml.XmlDocument.parse(content);
        roots = doc.children
            .map((node) => _buildFromXml(node))
            .whereType<DomTreeNode>()
            .toList();
      } catch (e) {
        // Fallback to HTML parser if XML parsing fails
        debugPrint('DomTreeView: XML parsing failed, falling back to HTML: $e');
        final doc = html_parser.parse(content);
        if (doc.documentElement != null) {
          final root = _buildFromHtml(doc.documentElement!);
          if (root != null) roots = [root];
        }
      }
    } else {
      final doc = html_parser.parse(content);
      if (doc.documentElement != null) {
        final root = _buildFromHtml(doc.documentElement!);
        if (root != null) roots = [root];
      }
    }

    setState(() {
      _treeController.roots = roots;
      // Expand root by default
      if (roots.isNotEmpty) {
        final root = roots.first;
        _treeController.expand(root);

        // Also expand head and body elements by default for better visibility
        for (var child in root.children) {
          if (child.label == 'head' || child.label == 'body') {
            _treeController.expand(child);
          }
        }
      }
    });
  }

  DomTreeNode? _buildFromXml(xml.XmlNode node) {
    if (node is xml.XmlElement) {
      final children = node.children
          .map((n) => _buildFromXml(n))
          .whereType<DomTreeNode>()
          .toList();

      return DomTreeNode(
        label: node.name.toString(),
        content: node.toXmlString(),
        attributes: node.attributes.fold<Map<String, String>>({}, (map, attr) {
          map[attr.name.toString()] = attr.value;
          return map;
        }),
        children: children,
        isElement: true,
      );
    } else if (node is xml.XmlText) {
      final text = node.value.trim();
      if (text.isEmpty) return null;

      return DomTreeNode(
        label: text,
        content: text,
        attributes: {},
        children: [],
        isElement: false,
      );
    }
    return null;
  }

  DomTreeNode? _buildFromHtml(dom.Node node) {
    if (node is dom.Element) {
      final children = node.nodes
          .map((n) => _buildFromHtml(n))
          .whereType<DomTreeNode>()
          .toList();

      return DomTreeNode(
        label: node.localName ?? 'unknown',
        content: node.outerHtml,
        attributes: node.attributes
            .map((key, value) => MapEntry(key.toString(), value)),
        children: children,
        isElement: true,
      );
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;

      return DomTreeNode(
        label: text,
        content: text,
        attributes: {},
        children: [],
        isElement: false,
      );
    }
    return null;
  }

  @override
  void dispose() {
    _treeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final content = htmlService.currentFile?.content ?? '';

    if (content != _lastContent) {
      _lastContent = content;
      Future.microtask(() {
        if (mounted) _updateTree(htmlService, content);
      });
    }

    if (content.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No content to parse')),
      );
    }

    if (_treeController.roots.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SliverFillRemaining(
      child: TreeView<DomTreeNode>(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        treeController: _treeController,
        nodeBuilder: (BuildContext context, TreeEntry<DomTreeNode> entry) {
          return DomTreeTile(
            entry: entry,
            onTap: () => _treeController.toggleExpansion(entry.node),
          );
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
        icons.add(Icons.link_off); // Or generic link icon
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
                  size: 16,
                  color: Colors.grey,
                )
              else
                const SizedBox(width: 16),

              const SizedBox(width: 4),

              if (isElement) ...[
                // Icon or Thumbnail (Thumbnail replaces icon for img)
                if (tagName == 'img' && attributes.containsKey('src'))
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.network(
                          attributes['src']!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.broken_image,
                              size: 14,
                              color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  )
                else
                  // Standard Tag Icons
                  ..._getTagIcons(node).map((icon) => Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Icon(icon, size: 14, color: Colors.grey[600]),
                      )),

                // Tag Name with Color
                Text(
                  '<${node.label}',
                  style: TextStyle(
                    color: _getTagColor(context, node.label),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 13,
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
                          fontFamily: 'monospace',
                          fontSize: 11,
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
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                // Text Node
                Expanded(
                  child: Text(
                    node.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey,
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
