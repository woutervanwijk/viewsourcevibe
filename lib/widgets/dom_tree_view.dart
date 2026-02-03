import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

class DomTreeView extends StatefulWidget {
  const DomTreeView({super.key});

  @override
  State<DomTreeView> createState() => _DomTreeViewState();
}

class _DomTreeViewState extends State<DomTreeView> {
  dom.Document? _document;
  String? _lastContent;

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final content = htmlService.currentFile?.content ?? '';

    if (content != _lastContent) {
      if (content.isNotEmpty) {
        _document = html_parser.parse(content);
      } else {
        _document = null;
      }
      _lastContent = content;
    }

    if (_document == null) {
      return const Center(child: Text('No content to parse'));
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildNode(_document!.documentElement!),
      ],
    );
  }

  Widget _buildNode(dom.Node node) {
    if (node is dom.Element) {
      final children = node.nodes.where((n) {
        if (n is dom.Text) {
          return n.text.trim().isNotEmpty;
        }
        return n is dom.Element;
      }).toList();

      final attributes = node.attributes;
      final attrString =
          attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ');

      final label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '<${node.localName}',
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
        ],
      );

      if (children.isEmpty) {
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 16),
          title: label,
        );
      }

      return ExpansionTile(
        title: label,
        dense: true,
        childrenPadding: const EdgeInsets.only(left: 16),
        expandedAlignment: Alignment.topLeft,
        children: children.map((n) => _buildNode(n)).toList(),
      );
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return const SizedBox.shrink();

      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.only(left: 16),
        title: Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
