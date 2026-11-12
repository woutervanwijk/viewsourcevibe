import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

enum DomTreeKind { html, xml, svg }

class DomTreeNode {
  final String label;
  final String content; // Outer HTML or text
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

/// The tree of one document, and which parser built it.
class DomTree {
  final List<DomTreeNode> roots;
  final bool usedXmlParser;

  /// Set when the document was not well-formed and the tree is approximate.
  final String? note;

  const DomTree(this.roots, {this.usedXmlParser = false, this.note});
}

final _feedRoot =
    RegExp(r'<(rss|feed|rdf:rdf|opml)[\s>/]', caseSensitive: false);
final _firstTag = RegExp(r'<([A-Za-z][\w:.-]*)');

/// The text without a BOM and without leading whitespace and comments.
String _afterPrologue(String text) {
  var s = text.startsWith('﻿') ? text.substring(1) : text;
  while (true) {
    s = s.trimLeft();
    if (!s.startsWith('<!--')) return s;
    final end = s.indexOf('-->');
    if (end < 0) return s;
    s = s.substring(end + 3);
  }
}

bool _shouldUseXmlParser(String text, DomTreeKind kind) {
  if (kind != DomTreeKind.html) return true;
  final rest = _afterPrologue(text);
  if (!rest.startsWith('<')) return false;
  final lower = rest.toLowerCase();
  // B25: the doctype/root checks ignore case, BOM, whitespace and comments
  // before them.
  if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
    return false;
  }
  if (lower.startsWith('<?xml')) return !lower.contains('<html');
  final first = _firstTag.firstMatch(rest)?.group(1)?.toLowerCase();
  if (first == 'svg') return true;
  return _feedRoot
      .hasMatch(rest.length > 2048 ? rest.substring(0, 2048) : rest);
}

/// Parses [text] into a tree. Pure: no widget, no service. HTML goes through
/// the forgiving HTML parser; XML/SVG/feeds through the XML parser, with an
/// approximate tag list when the XML is malformed.
DomTree deriveDomTree(String text, DomTreeKind kind) {
  if (text.isEmpty) return const DomTree([]);
  if (_shouldUseXmlParser(text, kind)) {
    try {
      final doc = xml.XmlDocument.parse(text);
      return DomTree(
        doc.children
            .map(_fromXml)
            .whereType<DomTreeNode>()
            .toList(growable: false),
        usedXmlParser: true,
      );
    } catch (e) {
      debugPrint('DomTree: strict XML parsing failed: $e');
      return DomTree(_parseCorruptXml(text),
          usedXmlParser: true, note: 'malformed XML, tree is approximate');
    }
  }
  final doc = html_parser.parse(text);
  final root =
      doc.documentElement == null ? null : _fromHtml(doc.documentElement!);
  return DomTree(root == null ? const [] : [root]);
}

/// `<label k="v" …>` for the reconstructed [content] (see [_fromHtml]).
String _openTag(String label, Map<String, String> attributes) {
  final attrs =
      attributes.entries.map((e) => '${e.key}="${e.value}"').join(' ');
  return attrs.isEmpty ? '<$label>' : '<$label $attrs>';
}

DomTreeNode? _fromXml(xml.XmlNode node) {
  if (node is xml.XmlElement) {
    final label = node.name.toString();
    final attributes = {
      for (final a in node.attributes) a.name.toString(): a.value,
    };
    final children = node.children
        .map(_fromXml)
        .whereType<DomTreeNode>()
        .toList(growable: false);
    return DomTreeNode(
      label: label,
      // Reconstructed bottom-up instead of node.toXmlString(), which
      // re-serializes every subtree: O(size x depth) on a large document.
      content:
          '${_openTag(label, attributes)}${[for (final c in children) c.content].join()}</$label>',
      attributes: attributes,
      children: children,
      isElement: true,
    );
  } else if (node is xml.XmlText) {
    final t = node.value.trim();
    if (t.isEmpty) return null;
    return DomTreeNode(
        label: t, content: t, attributes: {}, children: [], isElement: false);
  }
  return null;
}

DomTreeNode? _fromHtml(dom.Node node) {
  if (node is dom.Element) {
    final label = node.localName ?? 'unknown';
    final attributes =
        node.attributes.map((k, v) => MapEntry(k.toString(), v));
    final children = node.nodes
        .map(_fromHtml)
        .whereType<DomTreeNode>()
        .toList(growable: false);
    return DomTreeNode(
      label: label,
      // Reconstructed bottom-up instead of node.outerHtml, which
      // re-serializes every subtree: O(size x depth) time and memory when
      // building the tree of a large page (ad.nl, telegraaf.nl). Only used
      // for the long-press copy, so normalized markup is fine.
      content:
          '${_openTag(label, attributes)}${[for (final c in children) c.content].join()}</$label>',
      attributes: attributes,
      children: children,
      isElement: true,
    );
  } else if (node is dom.Text) {
    final t = node.text.trim();
    if (t.isEmpty) return null;
    return DomTreeNode(
        label: t, content: t, attributes: {}, children: [], isElement: false);
  }
  return null;
}

/// Malformed XML: list the opening tags found, flat under one node.
List<DomTreeNode> _parseCorruptXml(String content) {
  final matches =
      RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>').allMatches(content);
  if (matches.isEmpty) {
    return [
      DomTreeNode(
          label: 'corrupt-xml',
          content: content,
          attributes: {},
          children: [],
          isElement: false)
    ];
  }
  final root = DomTreeNode(
      label: 'corrupt-xml',
      content: '(malformed XML)',
      attributes: {},
      children: [],
      isElement: true);
  for (final m in matches) {
    if (m.group(1) == '/') continue;
    final attrs = m.group(3) ?? '';
    root.children.add(DomTreeNode(
      label: m.group(2) ?? 'unknown',
      content: '(corrupt)',
      attributes: attrs.isEmpty ? {} : {'attributes': attrs},
      children: [],
      isElement: true,
    ));
  }
  return [root];
}

/// Which parser family the displayed document needs: from its own content
/// type (server header / browser document.contentType) or, for files, name.
DomTreeKind domTreeKindFor({String? contentType, String? fileName}) {
  final ct = (contentType ?? '').toLowerCase();
  final name = (fileName ?? '').toLowerCase();
  if (ct.contains('svg') || name.endsWith('.svg')) return DomTreeKind.svg;
  final htmlLike = ct.contains('html');
  if (!htmlLike &&
      (ct.contains('xml') ||
          ['.xml', '.rss', '.atom', '.opml'].any(name.endsWith))) {
    return DomTreeKind.xml;
  }
  return DomTreeKind.html;
}

/// Builds a tree (isolate-friendly top-level entry for `compute`).
DomTree buildDomTreeRecord((String, DomTreeKind) args) =>
    deriveDomTree(args.$1, args.$2);

typedef DomTreeBuilder = Future<DomTree> Function(
    String text, DomTreeKind kind);
