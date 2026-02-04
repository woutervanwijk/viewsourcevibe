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
        _treeController.expand(roots.first);
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
      return const Center(child: Text('No content to parse'));
    }

    if (_treeController.roots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return TreeView<DomTreeNode>(
      primary:
          false, // Prevent conflict with FileViewer's PrimaryScrollController
      treeController: _treeController,
      nodeBuilder: (BuildContext context, TreeEntry<DomTreeNode> entry) {
        return DomTreeTile(
          entry: entry,
          onTap: () => _treeController.toggleExpansion(entry.node),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final node = entry.node;
    final isElement = node.isElement;
    final attributes = node.attributes;
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
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (entry.hasChildren)
                Icon(
                  entry.isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 20,
                )
              else
                const SizedBox(width: 20),
              const SizedBox(width: 4),
              if (isElement) ...[
                Text(
                  '<${node.label}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (attrString.isNotEmpty)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        attrString,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                Text(
                  '>',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Text(
                    node.label,
                    style: const TextStyle(fontSize: 12),
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
