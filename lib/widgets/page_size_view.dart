import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/derive/page_weight.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/safe_network_svg.dart';
import 'package:view_source_vibe/widgets/service_logo.dart';

/// File-type filter tabs: resource type (null = all) and label, matching
/// the breakdown rows.
const _typeFilters = <(String?, String)>[
  (null, 'All'),
  ('script', 'External JS'),
  ('style', 'CSS Files'),
  ('image', 'Images/Media'),
  ('document', 'HTML/Content'),
  ('other', 'Misc. Resources'),
];

/// Page size/weight: totals, a per-type breakdown and every loaded
/// file/asset sorted by size. Everything comes from the store's browser
/// resources ([HtmlService.pageSize]); a size that was not reported is shown
/// as unknown, never as 0.
class PageSizeView extends StatefulWidget {
  const PageSizeView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  @override
  State<PageSizeView> createState() => _PageSizeViewState();
}

class _PageSizeViewState extends State<PageSizeView>
    with SingleTickerProviderStateMixin {
  late final TabController _filterController =
      TabController(length: _typeFilters.length, vsync: this)
        ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Widget _message(
      BuildContext context, IconData icon, String title, String text,
      {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(title),
            const SizedBox(height: 8),
            Text(text,
                style: TextStyle(color: error ? scheme.error : Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PageSizeView.builds++;
    final state =
        context.select<HtmlService, Observed<PageSizeModel>>((s) => s.pageSize);
    final isFile = context
        .select<HtmlService, bool>((s) => s.store.current.target is FileTarget);

    switch (state) {
      case Pending<PageSizeModel>():
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Waiting for the browser…',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        );
      case Failed<PageSizeModel>(:final error):
        return _message(context, Icons.error_outline,
            'Page size could not be measured', error,
            error: true);
      case Unavailable<PageSizeModel>(:final reason, :final detail):
        return _message(
            context,
            Icons.scale_outlined,
            'Page size not available',
            isFile
                ? 'Page size is measured by the browser and is not available for local files.'
                : 'Page size is measured by the browser. ${unavailableMessage(reason, detail)}.');
      case Present<PageSizeModel>(value: final model):
        return _buildModel(context, model);
    }
  }

  Widget _buildModel(BuildContext context, PageSizeModel model) {
    final htmlService = context.read<HtmlService>();
    final resources = model.rows;
    final totalSize = model.knownRowTotal;
    final filterType = _typeFilters[_filterController.index].$1;
    final shown = filterType == null
        ? resources
        : resources.where((r) => r.type == filterType).toList();

    return Scrollbar(
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          _buildTotalsCard(context, model),
          const SizedBox(height: 24),
          _buildSectionTitle(
              context, 'Loaded Files & Assets (${resources.length})'),
          if (resources.isNotEmpty) ...[
            _buildFilterTabs(context, resources),
            const SizedBox(height: 12),
          ],
          if (shown.isEmpty)
            Text(
              resources.isEmpty
                  ? 'The browser reported no individual resources.'
                  : 'No files of this type.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            _outlinedCard(
              context,
              Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildResourceRow(
                        context, htmlService, shown[i], totalSize),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, List<PageSizeRow> resources) {
    return TabBar(
      controller: _filterController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerHeight: 0,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      tabs: [
        for (final (type, label) in _typeFilters)
          Tab(
            height: 36,
            text:
                '$label (${type == null ? resources.length : resources.where((r) => r.type == type).length})',
          ),
      ],
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

  Widget _outlinedCard(BuildContext context, Widget child) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildTotalsCard(BuildContext context, PageSizeModel model) {
    final weight = model.weight;
    final known = formatSizePair(
        decoded: weight.decoded,
        transfer: weight.transfer,
        decodedPrefix: weight.decodedPrefix,
        transferPrefix: weight.transferPrefix);
    final note = model.missingNote;

    return _outlinedCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(
                  'Total Page Size',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    known ?? 'size unknown',
                    style: const TextStyle(
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
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                '${note[0].toUpperCase()}${note.substring(1)}. The total is a lower bound.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (model.estimateNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                '${model.estimateNote![0].toUpperCase()}${model.estimateNote!.substring(1)}.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (weight.documentSource != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'The page document is counted from the server response.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Divider(height: 1),
          for (final (key, label) in const [
            ('scripts', 'External JS'),
            ('css', 'CSS Files'),
            ('images', 'Images/Media'),
            ('html', 'HTML/Content'),
            ('other', 'Misc. Resources'),
          ])
            _buildBreakdownRow(
                context, label, weight.breakdown[key], weight.decoded),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String label,
      WeightBucket? bucket, int? totalDecoded) {
    if (bucket == null || bucket.count == 0) {
      return const SizedBox.shrink();
    }
    final text = formatSizePair(
            decoded: bucket.decoded,
            transfer: bucket.transfer,
            decodedPrefix: bucket.decodedPrefix,
            transferPrefix: bucket.transferPrefix) ??
        'size unknown';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$label (${bucket.count})',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _shareBar(context, bucket.decoded, totalDecoded),
        ],
      ),
    );
  }

  Widget _buildResourceRow(BuildContext context, HtmlService htmlService,
      PageSizeRow resource, int totalSize) {
    final scheme = Theme.of(context).colorScheme;
    final size = resource.size;
    final share = size != null && totalSize > 0 ? size / totalSize : null;
    final services = resource.services.take(2).toList();
    final host = Uri.tryParse(resource.url)?.host ?? '';
    final subtitle = [
      if (host.isNotEmpty) host,
      ...services.map((e) => e.name),
    ].join(' · ');

    return Material(
      color: resource.isPage
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: resource.url.startsWith('http')
            ? () => htmlService.loadFromUrl(resource.url,
                switchToTab: HtmlService.viewerTab)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(_iconFor(resource.type),
                    size: 18,
                    color: resource.isPage ? scheme.primary : scheme.secondary),
              ),
              const SizedBox(width: 8),
              if (resource.type == 'image' && !resource.isAudioVideo) ...[
                _buildThumbnail(context, resource.url),
                const SizedBox(width: 8),
              ],
              for (final service in services) ...[
                Tooltip(
                  message: service.name,
                  child: ServiceLogo(
                    domain: service.logoDomain,
                    label: service.name,
                    fallback: Icons.extension_outlined,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (services.isNotEmpty) const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: resource.url,
                      child: Text(
                        resource.isPage
                            ? 'This page HTML (${_pageName(resource.url)})'
                            : _fileName(resource.url),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: resource.isPage
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: resource.isPage ? scheme.primary : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    _shareBar(context, size, totalSize),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      resource.sizeLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Courier',
                          fontStyle: size == null
                              ? FontStyle.italic
                              : FontStyle.normal),
                    ),
                    if (share != null)
                      Text(
                        '${(share * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Last path segment, or the host for root URLs.
  static String _fileName(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    // pathSegments are already percent-decoded; decoding again throws on a
    // stray '%' or non-ASCII (same fix as ResourceSize.fileName on main).
    if (segments.isNotEmpty) return segments.last;
    return uri.host.isNotEmpty ? uri.host : url;
  }

  /// File name of the page document, `index` for root URLs.
  static String _pageName(String url) {
    final hasPath =
        Uri.tryParse(url)?.pathSegments.any((s) => s.isNotEmpty) ?? false;
    return hasPath ? _fileName(url) : 'index';
  }

  Widget _buildThumbnail(BuildContext context, String url) {
    const size = 28.0;
    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(Icons.broken_image_outlined,
        size: 16, color: scheme.outlineVariant);
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: path.endsWith('.svg')
            ? SafeNetworkSvg(
                url: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => fallback,
                errorWidget: fallback,
              )
            : Image.network(url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: 64,
                errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }

  /// Share of [total]; an unknown value gets an empty bar, not a measured one.
  Widget _shareBar(BuildContext context, int? value, int? total) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value != null && total != null && total > 0
            ? (value / total).clamp(0.0, 1.0)
            : 0,
        minHeight: 4,
        backgroundColor: scheme.surfaceContainerHighest,
        color: scheme.primary,
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'script' => Icons.javascript,
        'style' => Icons.style_outlined,
        'image' => Icons.image_outlined,
        'document' => Icons.description_outlined,
        _ => Icons.insert_drive_file_outlined,
      };
}
