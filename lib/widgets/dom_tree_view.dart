import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';

class DomNode {
  final dom.Node node;
  final List<DomNode> children;

  DomNode({required this.node, this.children = const []});

  String get label {
    if (node is dom.Element) {
      return (node as dom.Element).localName ?? 'unknown';
    } else if (node is dom.Text) {
      return (node as dom.Text).text.trim();
    }
    return node.toString();
  }

  Map<Object, String> get attributes {
    if (node is dom.Element) {
      return (node as dom.Element).attributes;
    }
    return {};
  }
}

class DomTreeView extends StatefulWidget {
  const DomTreeView({super.key});

  @override
  State<DomTreeView> createState() => _DomTreeViewState();
}

class _DomTreeViewState extends State<DomTreeView> {
  late TreeController<DomNode> _treeController;
  String? _lastContent;

  @override
  void initState() {
    super.initState();
    _treeController = TreeController<DomNode>(
      roots: [],
      childrenProvider: (DomNode node) => node.children,
    );
  }

  void _updateTree(String content) {
    if (content.isEmpty) {
      setState(() {
        _treeController.roots = [];
      });
      return;
    }

    final doc = html_parser.parse(content);
    final newRoot = _buildDomNode(doc.documentElement!);

    setState(() {
      _treeController.roots = [newRoot];
      // Expand root by default
      _treeController.expand(newRoot);
    });
  }

  DomNode _buildDomNode(dom.Node node) {
    final childrenNodes = node.nodes.where((n) {
      if (n is dom.Text) {
        return n.text.trim().isNotEmpty;
      }
      return n is dom.Element;
    }).toList();

    return DomNode(
      node: node,
      children: childrenNodes.map((n) => _buildDomNode(n)).toList(),
    );
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
      // Build the tree in a microtask to avoid building during the current build phase.
      Future.microtask(() {
        if (mounted) _updateTree(content);
      });
    }

    if (content.isEmpty) {
      return const Center(child: Text('No content to parse'));
    }

    if (_treeController.roots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return TreeView<DomNode>(
      treeController: _treeController,
      nodeBuilder: (BuildContext context, TreeEntry<DomNode> entry) {
        return DomTreeTile(
          entry: entry,
          onTap: () => _treeController.toggleExpansion(entry.node),
        );
      },
    );
  }
}

class DomTreeTile extends StatelessWidget {
  final TreeEntry<DomNode> entry;
  final VoidCallback onTap;

  const DomTreeTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final node = entry.node;
    final isElement = node.node is dom.Element;
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
          final domNode = node.node;
          final String copyText;
          if (domNode is dom.Element) {
            copyText = domNode.outerHtml;
          } else {
            copyText = domNode.text ?? '';
          }

          Clipboard.setData(ClipboardData(text: copyText));
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
            children: [
              if (entry.hasChildren)
                Icon(
                  entry.isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 20,
                )
              else
                const SizedBox(width: 20),
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
                    child: Text(
                      ' $attrString',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 11,
                        overflow: TextOverflow.ellipsis,
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
