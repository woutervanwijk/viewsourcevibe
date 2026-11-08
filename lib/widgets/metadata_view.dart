import 'dart:convert';
import 'package:view_source_vibe/widgets/service_logo.dart';
import 'package:view_source_vibe/widgets/evidence_view.dart';
import 'package:view_source_vibe/services/detection/engine.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/detections_view.dart';
import 'package:view_source_vibe/services/derive/metadata_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/settings.dart';

class MetadataView extends StatelessWidget {
  const MetadataView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  static bool _isWebUrl(String? s) =>
      s != null && (s.startsWith('http://') || s.startsWith('https://'));

  Widget _status(BuildContext context, Widget lead, String title,
      {String? text, bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            lead,
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: error ? scheme.error : Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    final settings = Provider.of<AppSettings>(context);
    final state = context
        .select<HtmlService, Observed<MetadataModel>>((s) => s.metadataState);
    final detectionsView =
        context.select<HtmlService, DetectionsView>((s) => s.detectionsView);

    switch (state) {
      case Pending<MetadataModel>():
        return _status(context, const CircularProgressIndicator(),
            'Reading the page metadata…');
      case Failed<MetadataModel>(:final error):
        return _status(
            context,
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            'Metadata could not be extracted',
            text: error,
            error: true);
      case Unavailable<MetadataModel>():
        return _status(
            context,
            Icon(Icons.info_outline,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            'No Metadata',
            text: 'Load a URL to view page metadata.');
      case Present<MetadataModel>(value: final model):
        return _buildModel(context, model, detectionsView, settings);
    }
  }

  Widget _buildModel(BuildContext context, MetadataModel model,
      DetectionsView detectionsView, AppSettings settings) {
    final metadata = model.data;
    final tech =
        detectionsView.detections.where((d) => d.category.tech).toList();
    // Collect dynamic sections to sort them alphabetically
    final List<({String title, Widget content})> dynamicSections = [];

    if (tech.isNotEmpty) {
      dynamicSections.add((
        title: 'Technology Stack',
        content: _buildTechSection(context, tech),
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
        content: _buildHintSection(context, model, metadata['resourceHints']),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(model.sourceLine,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 12),
            _buildHeaderSection(context, model, settings),
            const SizedBox(height: 24),
            _buildAccessibilitySnapshot(context, model.checks),
            const SizedBox(height: 24),
            _buildSeoHealthPanel(context, model),
            const SizedBox(height: 24),
            if (_hasSocialPreview(metadata)) ...[
              _buildSectionTitle(context, 'Open Graph / Social Preview'),
              _buildSocialPreviewSection(context, model),
              const SizedBox(height: 24),
            ],
            if ((metadata['structuredData'] as List?)?.isNotEmpty == true) ...[
              _buildSectionTitle(context, 'Structured Data Viewer'),
              _buildStructuredDataSection(context, metadata['structuredData']),
              const SizedBox(height: 24),
            ],
            if (tech.isEmpty &&
                (detectionsView.scanning || detectionsView.failure != null))
              _detectionStatus(context, detectionsView),
            if (tech.isNotEmpty) ...[
              _buildSectionTitle(context, 'Tech Stack Confidence'),
              _buildTechConfidenceSection(context, tech),
              const SizedBox(height: 24),
            ],
            ...dynamicSections.expand((section) => [
                  _buildSectionTitle(context, section.title),
                  section.content,
                  const SizedBox(height: 24),
                ]),
            _buildSectionTitle(context, 'Linked Resources'),
            _buildLinkSection(context, model, 'Stylesheets (CSS)',
                (metadata['cssLinks'] as List?) ?? const [], Icons.css),
            _buildLinkSection(context, model, 'Scripts (JS)',
                (metadata['jsLinks'] as List?) ?? const [], Icons.javascript),
            _buildLinkSection(
                context,
                model,
                'Iframes (HTML)',
                (metadata['iframeLinks'] as List?) ?? const [],
                Icons.web_asset),
            _buildLinkSection(context, model, 'RSS/Atom Feeds',
                (metadata['rssLinks'] as List?) ?? const [], Icons.rss_feed),
            const SizedBox(height: 80),
          ],
        ),
      ),
    ));
  }

  /// Technologies are not listed yet (scanning) or could not be scanned: said
  /// so, rather than showing nothing.
  Widget _detectionStatus(BuildContext context, DetectionsView view) {
    final failed = view.failure != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          if (!failed)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(Icons.error_outline,
                size: 16, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                failed
                    ? 'Technology scan failed: ${view.failure}'
                    : 'Scanning for technologies…',
                style: TextStyle(
                    fontSize: 12,
                    color: failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
      BuildContext context, MetadataModel model, AppSettings settings) {
    final metadata = model.data;
    final unescape = HtmlUnescape();
    final title = model.hasTitle
        ? (model.title.isEmpty
            ? 'This page has an empty <title>'
            : unescape.convert(model.title))
        : 'This page has no <title>';
    final description = model.hasDescription
        ? unescape.convert('${metadata['description']}')
        : 'This page has no meta description';
    final String? image = metadata['image'] as String?;
    final String? favicon = metadata['favicon'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isWebUrl(favicon)) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    final htmlService =
                        Provider.of<HtmlService>(context, listen: false);
                    htmlService.loadFromUrl(favicon,
                        switchToTab: HtmlService.viewerTab);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      favicon!,
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
        if (_isWebUrl(image)) ...[
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                htmlService.loadFromUrl(image,
                    switchToTab: HtmlService.viewerTab);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  image!,
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

  Widget _buildAccessibilitySnapshot(BuildContext context, DocumentChecks c) {
    final checks = [
      _SnapshotCheck('H1', c.h1Count == 1, '${c.h1Count} found'),
      _SnapshotCheck('Headings', c.headingCount > 0, '${c.headingCount} found'),
      _SnapshotCheck('Image alt', c.imagesMissingAlt == 0,
          c.imageCount == 0 ? 'No images' : '${c.imagesMissingAlt} missing'),
      _SnapshotCheck(
          'Form labels',
          c.unlabeledControls == 0,
          c.controlCount == 0
              ? 'No controls'
              : '${c.unlabeledControls} missing'),
      _SnapshotCheck(
          'Landmarks', c.landmarkCount > 0, '${c.landmarkCount} found'),
    ];
    return _buildSnapshotCard(
      context,
      title: 'Accessibility Snapshot',
      icon: Icons.accessibility_new_outlined,
      checks: checks,
    );
  }

  Widget _buildSeoHealthPanel(BuildContext context, MetadataModel model) {
    final metadata = model.data;
    final title = model.title;
    final description = metadata['description']?.toString() ?? '';
    final canonical = metadata['pageConfig'] is Map
        ? (metadata['pageConfig']['canonical']?.toString() ?? '')
        : '';
    final robotsMeta = model.checks.robotsMeta ?? '';
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

  bool _hasSocialPreview(Map<String, dynamic> metadata) {
    final openGraph = metadata['openGraph'] as Map<String, dynamic>? ?? {};
    final twitter = metadata['twitter'] as Map<String, dynamic>? ?? {};
    return openGraph.isNotEmpty ||
        twitter.isNotEmpty ||
        metadata['title'] != null ||
        metadata['description'] != null ||
        metadata['image'] != null;
  }

  Widget _buildSocialPreviewSection(BuildContext context, MetadataModel model) {
    final metadata = model.data;
    final openGraph = metadata['openGraph'] as Map<String, dynamic>? ?? {};
    final twitter = metadata['twitter'] as Map<String, dynamic>? ?? {};
    final title = _socialValue(
      metadata,
      openGraph,
      twitter,
      'title',
      'og:title',
      'twitter:title',
      fallback: model.hasTitle ? null : 'This page has no <title>',
    );
    final description = _socialValue(
      metadata,
      openGraph,
      twitter,
      'description',
      'og:description',
      'twitter:description',
      fallback:
          'No social description (og:description, twitter:description or meta description) found',
    );
    final rawImage = _socialValue(
      metadata,
      openGraph,
      twitter,
      'image',
      'og:image',
      'twitter:image',
    );
    // A relative image cannot be loaded without a base URL.
    final image = _isWebUrl(rawImage) ? rawImage : null;
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
          htmlService.loadFromUrl(image, switchToTab: HtmlService.viewerTab);
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
      BuildContext context, MetadataModel model, Map<String, dynamic> hints) {
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
                    subtitle: model.unresolvedNote('$url') == null
                        ? null
                        : Text(model.unresolvedNote('$url')!,
                            style: const TextStyle(fontSize: 10)),
                    trailing: model.unresolvedNote('$url') == null
                        ? const Icon(Icons.arrow_forward_ios, size: 12)
                        : null,
                    dense: true,
                    onTap: model.unresolvedNote('$url') != null
                        ? null
                        : () {
                            final htmlService = Provider.of<HtmlService>(
                                context,
                                listen: false);
                            htmlService.loadFromUrl(url.toString(),
                                switchToTab: HtmlService.viewerTab);
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

  String _techLabel(Detection d) =>
      '${d.category.label}: ${d.name}${d.version != null ? ' ${d.version}' : ''}';

  Widget _buildTechSection(BuildContext context, List<Detection> tech) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tech.map((d) {
        return ActionChip(
          onPressed: () =>
              showEvidenceSheet(context, _techLabel(d), d.evidence),
          avatar: ServiceLogo(
              domain: d.entity.logoDomain,
              label: d.name,
              fallback: Icons.code,
              color: Theme.of(context).colorScheme.primary,
              size: 18),
          label: Text(
            _techLabel(d),
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
    if (item is! Map) return 'JSON-LD';
    final rawType = item['@type'];
    if (rawType is List) return rawType.map((t) => '$t').join(', ');
    if (rawType is String && rawType.trim().isNotEmpty) {
      return rawType.trim();
    }
    // No @type on the node: still recognize the vocabulary from @context
    // (e.g. schema.org) instead of reporting an unknown schema.
    final context = item['@context'];
    final vocab = context is List
        ? context.whereType<String>().join(', ')
        : context is String
            ? context
            : '';
    if (vocab.contains('schema.org')) return 'schema.org';
    return vocab.isNotEmpty ? vocab : 'JSON-LD';
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
      BuildContext context, List<Detection> tech) {
    final items = tech.map((d) {
      final (score, reason) = d.confidence;
      return (
        label: _techLabel(d),
        score: score,
        reason: reason,
        sources: d.evidence,
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
            final sources = item.sources;
            return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showEvidenceSheet(context, item.label, sources),
                child: Padding(
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
                              item.label,
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
                            if (sources.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              EvidenceList(
                                  evidence: sources, max: 1, compact: true),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ));
          }).toList(),
        ),
      ),
    );
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
                          htmlService.loadFromUrl(value,
                              switchToTab: HtmlService.viewerTab);
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
                    htmlService.loadFromUrl(value,
                        switchToTab: HtmlService.viewerTab);
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

  Widget _buildLinkSection(BuildContext context, MetadataModel model,
      String title, List<dynamic> links, IconData icon) {
    if (links.isEmpty) return const SizedBox.shrink();

    // Largest first; items without a known size last.
    int sizeOf(dynamic l) => l is Map && l['size'] is Map
        ? (l['size']['decoded'] as int? ?? -1)
        : -1;
    final sortedLinks = List<dynamic>.from(links);
    sortedLinks.sort((a, b) {
      final sizeA = sizeOf(a);
      final sizeB = sizeOf(b);
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
          final unresolved = model.unresolvedNote(url);
          final sizeText = linkSizeLabel(link is Map ? link['size'] : null,
              unknownReason: model.sizeUnknownReason);

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
              subtitle: Text(
                unresolved == null ? sizeText : '$unresolved; $sizeText',
                style: TextStyle(
                  fontSize: 10,
                  color: sizeText.startsWith('size unknown')
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: unresolved == null
                  ? const Icon(Icons.arrow_forward_ios, size: 12)
                  : null,
              dense: true,
              onTap: unresolved != null
                  ? null
                  : () {
                      final htmlService =
                          Provider.of<HtmlService>(context, listen: false);
                      htmlService.loadFromUrl(url,
                          switchToTab: HtmlService.viewerTab);
                    },
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SnapshotCheck {
  final String label;
  final bool ok;
  final String detail;

  const _SnapshotCheck(this.label, this.ok, this.detail);
}
