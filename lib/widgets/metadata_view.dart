import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html_unescape/html_unescape.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/settings.dart';
import '../utils/format_utils.dart';

class MetadataView extends StatelessWidget {
  const MetadataView({super.key});

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final settings = Provider.of<AppSettings>(context);
    final metadata = htmlService.pageMetadata;

    // Show loading indicator only if we're extracting metadata
    // (not for general loading states which might be WebView loading)
    if (htmlService.isExtractingMetadata) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show message if no metadata available
    if (metadata == null) {
      // Only show "no metadata" if we're not still loading the page
      if (htmlService.isLoading || htmlService.isWebViewLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            const Text('No Metadata'),
            const SizedBox(height: 8),
            const Text('Load a URL to view page metadata.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Collect dynamic sections to sort them alphabetically
    final List<({String title, Widget content})> dynamicSections = [];

    if (metadata['detectedTech']?.isNotEmpty == true) {
      dynamicSections.add((
        title: 'Technology Stack',
        content: _buildTechSection(context, metadata['detectedTech'], settings),
      ));
    }
    if (metadata['article']?.isNotEmpty == true) {
      dynamicSections.add((
        title: 'Article Information',
        content: _buildMapSection(context, metadata['article'], settings),
      ));
    }
    if (metadata['pageConfig']?.isNotEmpty == true) {
      dynamicSections.add((
        title: 'Page Configuration',
        content: _buildMapSection(context, metadata['pageConfig'], settings),
      ));
    }
    if (metadata['resourceHints']?.isNotEmpty == true) {
      dynamicSections.add((
        title: 'Optimization (Resource Hints)',
        content:
            _buildHintSection(context, metadata['resourceHints'], settings),
      ));
    }
    if (metadata['openGraph']?.isNotEmpty == true) {
      dynamicSections.add((
        title: 'OpenGraph Tags',
        content: _buildMapSection(context, metadata['openGraph'], settings),
      ));
    }
    if (metadata['twitter']?.isNotEmpty == true) {
      dynamicSections.add((
        title: 'Twitter Card Information',
        content: _buildMapSection(context, metadata['twitter'], settings),
      ));
    }
    if (metadata['otherMeta']?.isNotEmpty == true) {
      dynamicSections.add((
        title: 'Other Meta Tags',
        content: _buildMapSection(context, metadata['otherMeta'], settings),
      ));
    }

    // Sort sections by title
    dynamicSections.sort((a, b) => a.title.compareTo(b.title));

    return Scrollbar(
        child: SingleChildScrollView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            _buildHeaderSection(context, metadata, settings),
            const SizedBox(height: 24),
            _buildAccessibilitySnapshot(context, htmlService),
            const SizedBox(height: 24),
            _buildSeoHealthPanel(context, htmlService, metadata),
            const SizedBox(height: 24),
            if (_hasSocialPreview(metadata)) ...[
              _buildSectionTitle(context, 'Open Graph / Social Preview'),
              _buildSocialPreviewSection(context, metadata),
              const SizedBox(height: 24),
            ],
            if ((metadata['structuredData'] as List?)?.isNotEmpty == true) ...[
              _buildSectionTitle(context, 'Structured Data Viewer'),
              _buildStructuredDataSection(context, metadata['structuredData']),
              const SizedBox(height: 24),
            ],
            if (metadata['detectedTech']?.isNotEmpty == true) ...[
              _buildSectionTitle(context, 'Tech Stack Confidence'),
              _buildTechConfidenceSection(context, metadata['detectedTech']),
              const SizedBox(height: 24),
            ],
            ...dynamicSections.expand((section) => [
                  _buildSectionTitle(context, section.title),
                  section.content,
                  const SizedBox(height: 24),
                ]),
            _buildSectionTitle(context, 'Linked Resources'),
            _buildLinkSection(context, 'Stylesheets (CSS)',
                metadata['cssLinks'], Icons.css, settings),
            _buildLinkSection(context, 'Scripts (JS)', metadata['jsLinks'],
                Icons.javascript, settings),
            _buildLinkSection(context, 'Iframes (HTML)',
                metadata['iframeLinks'], Icons.web_asset, settings),
            _buildLinkSection(context, 'RSS/Atom Feeds', metadata['rssLinks'],
                Icons.rss_feed, settings),
            const SizedBox(height: 80),
          ],
        ),
      ),
    ));
  }

  Widget _buildHeaderSection(BuildContext context,
      Map<String, dynamic> metadata, AppSettings settings) {
    final unescape = HtmlUnescape();
    final title = unescape.convert(metadata['title'] ?? 'No Title');
    final description = unescape
        .convert(metadata['description'] ?? 'No description available.');
    final image = metadata['image'];
    final favicon = metadata['favicon'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (favicon != null) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    final htmlService =
                        Provider.of<HtmlService>(context, listen: false);
                    htmlService.loadFromUrl(favicon, switchToTab: 0);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      favicon,
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.public,
                          size: 48,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (image != null) ...[
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                htmlService.loadFromUrl(image, switchToTab: 0);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  image,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Page Weight'),
        _buildPageWeightSection(context, metadata['pageWeight'], settings),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Basic Information'),
        _buildMapSection(
            context,
            {
              'Title': title,
              if (metadata['language'] != null)
                'Language': metadata['language'],
              if (metadata['charset'] != null) 'Charset': metadata['charset'],
              if (favicon != null) 'Icon URL': favicon,
              'Description': description,
            },
            settings),
      ],
    );
  }

  Widget _buildAccessibilitySnapshot(
      BuildContext context, HtmlService htmlService) {
    final doc = _parseCurrentDocument(htmlService);
    final images = doc.querySelectorAll('img');
    final imagesMissingAlt = images
        .where((img) =>
            !(img.attributes.containsKey('alt')) ||
            img.attributes['alt']!.trim().isEmpty)
        .length;
    final headings = doc.querySelectorAll('h1,h2,h3,h4,h5,h6');
    final h1Count = doc.querySelectorAll('h1').length;
    final forms = doc.querySelectorAll('input,select,textarea');
    final unlabeledControls =
        forms.where((element) => _isUnlabeledControl(doc, element)).length;
    final landmarks = doc
        .querySelectorAll(
          'main,nav,header,footer,aside,[role="main"],[role="navigation"],[role="banner"],[role="contentinfo"]',
        )
        .length;

    final checks = [
      _SnapshotCheck('H1', h1Count == 1, '$h1Count found'),
      _SnapshotCheck(
          'Headings', headings.isNotEmpty, '${headings.length} found'),
      _SnapshotCheck('Image alt', imagesMissingAlt == 0,
          images.isEmpty ? 'No images' : '$imagesMissingAlt missing'),
      _SnapshotCheck('Form labels', unlabeledControls == 0,
          forms.isEmpty ? 'No controls' : '$unlabeledControls missing'),
      _SnapshotCheck('Landmarks', landmarks > 0, '$landmarks found'),
    ];
    return _buildSnapshotCard(
      context,
      title: 'Accessibility Snapshot',
      icon: Icons.accessibility_new_outlined,
      checks: checks,
    );
  }

  Widget _buildSeoHealthPanel(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> metadata) {
    final doc = _parseCurrentDocument(htmlService);
    final title = metadata['title']?.toString() ?? '';
    final description = metadata['description']?.toString() ?? '';
    final canonical = metadata['pageConfig'] is Map
        ? (metadata['pageConfig']['canonical']?.toString() ?? '')
        : '';
    final robotsMeta = doc
            .querySelector('meta[name="robots"],meta[name="googlebot"]')
            ?.attributes['content']
            ?.toString() ??
        '';
    final ogTitle =
        (metadata['openGraph'] as Map?)?['og:title']?.toString() ?? '';

    final checks = [
      _SnapshotCheck('Title', title.length >= 10 && title.length <= 70,
          title.isEmpty ? 'Missing' : '${title.length} chars'),
      _SnapshotCheck(
          'Description',
          description.length >= 50 && description.length <= 170,
          description.isEmpty ? 'Missing' : '${description.length} chars'),
      _SnapshotCheck('Canonical', canonical.isNotEmpty,
          canonical.isEmpty ? 'Missing' : 'Present'),
      _SnapshotCheck(
          'Robots meta',
          !robotsMeta.toLowerCase().contains('noindex'),
          robotsMeta.isEmpty ? 'Indexable by default' : robotsMeta),
      _SnapshotCheck('OG title', ogTitle.isNotEmpty,
          ogTitle.isEmpty ? 'Missing' : 'Present'),
    ];
    return _buildSnapshotCard(
      context,
      title: 'SEO Health Panel',
      icon: Icons.manage_search_outlined,
      checks: checks,
    );
  }

  Widget _buildSnapshotCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_SnapshotCheck> checks,
  }) {
    final passed = checks.where((check) => check.ok).length;
    final score = checks.isEmpty ? 0 : ((passed / checks.length) * 100).round();
    final color = score >= 80
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : Colors.red;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: checks.map((check) {
                final checkColor = check.ok ? Colors.green : Colors.orange;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: checkColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: checkColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        check.ok
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: checkColor,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${check.label}: ${check.detail}',
                        style: TextStyle(
                          color: checkColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  dom.Document _parseCurrentDocument(HtmlService htmlService) {
    return html_parser.parse(htmlService.currentFile?.content ?? '');
  }

  bool _isUnlabeledControl(dom.Document doc, dom.Element element) {
    final type = element.attributes['type']?.toLowerCase();
    if (type == 'hidden' || type == 'submit' || type == 'button') return false;
    if ((element.attributes['aria-label'] ?? '').trim().isNotEmpty) {
      return false;
    }
    if ((element.attributes['aria-labelledby'] ?? '').trim().isNotEmpty) {
      return false;
    }
    final id = element.attributes['id'];
    if (id != null && id.isNotEmpty) {
      final escaped = id.replaceAll('"', r'\"');
      if (doc.querySelector('label[for="$escaped"]') != null) {
        return false;
      }
    }
    return element.parent?.localName != 'label';
  }

  bool _hasSocialPreview(Map<String, dynamic> metadata) {
    final openGraph = metadata['openGraph'] as Map<String, dynamic>? ?? {};
    final twitter = metadata['twitter'] as Map<String, dynamic>? ?? {};
    return openGraph.isNotEmpty ||
        twitter.isNotEmpty ||
        metadata['title'] != null ||
        metadata['description'] != null ||
        metadata['image'] != null;
  }

  Widget _buildSocialPreviewSection(
      BuildContext context, Map<String, dynamic> metadata) {
    final openGraph = metadata['openGraph'] as Map<String, dynamic>? ?? {};
    final twitter = metadata['twitter'] as Map<String, dynamic>? ?? {};
    final title = _socialValue(
      metadata,
      openGraph,
      twitter,
      'title',
      'og:title',
      'twitter:title',
      fallback: 'Untitled page',
    );
    final description = _socialValue(
      metadata,
      openGraph,
      twitter,
      'description',
      'og:description',
      'twitter:description',
      fallback: 'No social description found.',
    );
    final image = _socialValue(
      metadata,
      openGraph,
      twitter,
      'image',
      'og:image',
      'twitter:image',
    );
    final site = openGraph['og:site_name']?.toString() ??
        twitter['twitter:site']?.toString() ??
        '';
    final type = openGraph['og:type']?.toString() ??
        twitter['twitter:card']?.toString() ??
        'summary';
    final url = openGraph['og:url']?.toString() ?? metadata['canonical'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 680;
          final imageWidget = _buildSocialImage(context, image);
          final textWidget = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSocialBadge(context, type, Icons.style_outlined),
                    if (site.isNotEmpty)
                      _buildSocialBadge(context, site, Icons.public),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  HtmlUnescape().convert(title ?? ''),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  HtmlUnescape().convert(description ?? ''),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.72),
                      ),
                ),
                if (url != null && url.toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    url.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 260, height: 160, child: imageWidget),
                Expanded(child: textWidget),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 190, child: imageWidget),
              textWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSocialImage(BuildContext context, String? image) {
    if (image == null || image.isEmpty) {
      return Container(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.outline,
          size: 42,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          htmlService.loadFromUrl(image, switchToTab: 0);
        },
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
          child: Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildSocialImage(context, null),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialBadge(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  String? _socialValue(
    Map<String, dynamic> metadata,
    Map<String, dynamic> openGraph,
    Map<String, dynamic> twitter,
    String metadataKey,
    String ogKey,
    String twitterKey, {
    String? fallback,
  }) {
    return openGraph[ogKey]?.toString() ??
        twitter[twitterKey]?.toString() ??
        metadata[metadataKey]?.toString() ??
        fallback;
  }

  Widget _buildHintSection(
      BuildContext context, Map<String, dynamic> hints, AppSettings settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: hints.entries.map((e) {
          final isLast = hints.entries.last.key == e.key;
          final List<dynamic> urls = e.value;

          final sortedUrls = List<dynamic>.from(urls)
            ..sort((a, b) => a
                .toString()
                .toLowerCase()
                .compareTo(b.toString().toLowerCase()));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                child: Text(
                  e.key.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              ...sortedUrls.map((url) => ListTile(
                    title: Text(
                      url.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier',
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                    dense: true,
                    onTap: () {
                      final htmlService =
                          Provider.of<HtmlService>(context, listen: false);
                      htmlService.loadFromUrl(url.toString(), switchToTab: 0);
                    },
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: url.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  )),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTechSection(
      BuildContext context, Map<String, dynamic> tech, AppSettings settings) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tech.entries.map((e) {
        return Chip(
          avatar: Icon(Icons.code,
              size: 16, color: Theme.of(context).colorScheme.primary),
          label: Text(
            '${e.key}: ${e.value}',
            style: TextStyle(
              fontFamily: 'Courier',
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStructuredDataSection(
      BuildContext context, List<dynamic> structuredData) {
    final encoder = const JsonEncoder.withIndent('  ');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: structuredData.asMap().entries.map((entry) {
          final item = entry.value;
          final type = _structuredDataType(item);
          final title = _structuredDataTitle(item);
          final json = encoder.convert(item);
          final isLast = entry.key == structuredData.length - 1;

          return Column(
            children: [
              ExpansionTile(
                initiallyExpanded: entry.key == 0,
                leading: const Icon(Icons.schema_outlined),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  tooltip: 'Copy JSON-LD',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Structured data copied')),
                    );
                  },
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SelectableText(
                      json,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _structuredDataType(dynamic item) {
    if (item is! Map) return 'Unknown schema';
    final rawType = item['@type'];
    if (rawType is List) return rawType.join(', ');
    return rawType?.toString() ?? 'Unknown schema';
  }

  String _structuredDataTitle(dynamic item) {
    if (item is! Map) return 'JSON-LD Item';
    for (final key in ['name', 'headline', 'title', '@id']) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return _structuredDataType(item);
  }

  Widget _buildTechConfidenceSection(
      BuildContext context, Map<String, dynamic> tech) {
    final items = tech.entries.map((entry) {
      final confidence = _techConfidence(entry.key, entry.value.toString());
      return (
        label: entry.key,
        value: entry.value.toString(),
        score: confidence.$1,
        reason: confidence.$2,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items.map((item) {
            final color = item.score >= 80
                ? Colors.green
                : item.score >= 60
                    ? Colors.orange
                    : Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: item.score / 100,
                          strokeWidth: 5,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.12),
                        ),
                        Center(
                          child: Text(
                            '${item.score}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.label}: ${item.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.reason,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.64),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  (int, String) _techConfidence(String label, String value) {
    final combined = '$label $value'.toLowerCase();
    if (combined.contains('version')) {
      return (92, 'Version-specific signal from generator/header pattern.');
    }
    if (['cdn', 'web server', 'backend', 'platform', 'cache', 'storage']
        .any(combined.contains)) {
      return (88, 'Server header or infrastructure marker.');
    }
    if (['cms', 'framework', 'static site', 'e-commerce']
        .any(combined.contains)) {
      return (78, 'HTML path, script, or generator marker.');
    }
    if (combined.contains('css')) {
      return (64, 'CSS class or stylesheet heuristic.');
    }
    return (58, 'Weak heuristic match; inspect source to confirm.');
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildMapSection(
      BuildContext context, Map<String, dynamic> data, AppSettings settings) {
    if (data.isEmpty) {
      return const Text('None detected.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }

    final unescape = HtmlUnescape();

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: sortedEntries.map((e) {
          final isLast = sortedEntries.last.key == e.key;
          final value = unescape.convert(e.value.toString());
          final isUrl =
              value.startsWith('http://') || value.startsWith('https://');

          return Column(
            children: [
              ListTile(
                title: Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                subtitle: SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier',
                    color: isUrl ? Theme.of(context).colorScheme.primary : null,
                    decoration: isUrl ? TextDecoration.underline : null,
                  ),
                  onTap: isUrl
                      ? () {
                          final htmlService =
                              Provider.of<HtmlService>(context, listen: false);
                          htmlService.loadFromUrl(value, switchToTab: 0);
                        }
                      : null,
                ),
                trailing: isUrl
                    ? const Icon(Icons.arrow_forward_ios, size: 12)
                    : null,
                dense: true,
                onTap: () {
                  if (isUrl) {
                    final htmlService =
                        Provider.of<HtmlService>(context, listen: false);
                    htmlService.loadFromUrl(value, switchToTab: 0);
                  } else {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  }
                },
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLinkSection(BuildContext context, String title,
      List<dynamic> links, IconData icon, AppSettings settings) {
    if (links.isEmpty) return const SizedBox.shrink();

    final sortedLinks = List<dynamic>.from(links);
    sortedLinks.sort((a, b) {
      final sizeA = a is Map ? (a['size']?['decoded'] as num? ?? 0) : 0;
      final sizeB = b is Map ? (b['size']?['decoded'] as num? ?? 0) : 0;

      if (sizeB != sizeA) {
        return sizeB.compareTo(sizeA);
      }

      final urlA = (a is Map ? (a['src'] ?? a['href'] ?? '') : a.toString())
          .toLowerCase();
      final urlB = (b is Map ? (b['src'] ?? b['href'] ?? '') : b.toString())
          .toLowerCase();
      return urlA.compareTo(urlB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
            ],
          ),
        ),
        ...sortedLinks.map((link) {
          final String url = link is Map
              ? (link['src'] ?? link['href'] ?? '')
              : link.toString();
          final Map<String, dynamic>? size = link is Map ? link['size'] : null;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 4),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                url,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Courier',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: size != null && (size['decoded'] as int? ?? 0) > 0
                  ? Text(
                      FormatUtils.formatBytesWithTransfer(size),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              dense: true,
              onTap: () {
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                htmlService.loadFromUrl(url, switchToTab: 0);
              },
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPageWeightSection(BuildContext context,
      Map<String, dynamic>? weight, AppSettings settings) {
    if (weight == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info_outline,
                  size: 24, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 8),
              Text(
                'Page size not available because the browser is not loaded.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final breakdown = weight['breakdown'] as Map<String, dynamic>?;
    final isPartial = weight['isPartial'] as bool? ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 50),
                  child: Text(
                    'Total Page Size',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${isPartial ? '≥ ' : ''}${FormatUtils.formatBytesWithTransfer({
                          'decoded': weight['decoded'] as int? ?? 0,
                          'transfer': weight['transfer'] as int? ?? 0,
                        })}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          if (isPartial)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Some resources are hosted on third-party CDNs that restrict size reporting. Actual size may be larger.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (breakdown != null) ...[
            const Divider(height: 1),
            _buildWeightRow(
                context, 'External JS', breakdown['scripts'], settings),
            _buildWeightRow(context, 'CSS Files', breakdown['css'], settings),
            _buildWeightRow(
                context, 'Images/Media', breakdown['images'], settings),
            _buildWeightRow(
                context, 'HTML/Content', breakdown['html'], settings),
            _buildWeightRow(
                context, 'Misc. Resources', breakdown['other'], settings),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightRow(BuildContext context, String label,
      Map<String, dynamic>? data, AppSettings settings) {
    if (data == null || (data['count'] as int? ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label (${data['count']})',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            FormatUtils.formatBytesWithTransfer({
              'decoded': data['decoded'] as int? ?? 0,
              'transfer': data['transfer'] as int? ?? 0,
            }),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCheck {
  final String label;
  final bool ok;
  final String detail;

  const _SnapshotCheck(this.label, this.ok, this.detail);
}
