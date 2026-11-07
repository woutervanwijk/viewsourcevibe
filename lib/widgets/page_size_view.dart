import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/utils/format_utils.dart';
import 'package:view_source_vibe/utils/page_weight.dart';
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

/// Images/Media files that can't be shown as a thumbnail.
final _audioVideoPath =
    RegExp(r'\.(mp4|webm|mov|m4v|ogv|mp3|ogg|wav|m4a|aac)$');

/// Page size/weight: totals, a per-type breakdown and every loaded
/// file/asset sorted by size.
class PageSizeView extends StatefulWidget {
  const PageSizeView({super.key});

  @override
  State<PageSizeView> createState() => _PageSizeViewState();
}

class _PageSizeViewState extends State<PageSizeView>
    with SingleTickerProviderStateMixin {
  late final TabController _filterController =
      TabController(length: _typeFilters.length, vsync: this)
        ..addListener(() => setState(() {}));

  // HtmlService notifies often; only re-match services when the data changes.
  Object? _resourcesKey;
  List<ResourceSize> _resources = const [];

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<ResourceSize> _resourcesFor(HtmlService htmlService) {
    final data = htmlService.resourceTimelineData;
    final pageUrl = htmlService.currentFile?.path ?? '';
    final key = (
      pageUrl,
      data.length,
      data.fold<int>(0, (sum, r) => sum + (r['decoded'] as num? ?? 0).toInt()),
      data.fold<int>(0, (sum, r) => sum + (r['transfer'] as num? ?? 0).toInt()),
    );
    if (key != _resourcesKey) {
      _resourcesKey = key;
      _resources = resourcesBySize(data, pageUrl);
    }
    return _resources;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(
      builder: (context, htmlService, child) {
        final weight =
            htmlService.pageMetadata?['pageWeight'] as Map<String, dynamic>?;
        final resources = _resourcesFor(htmlService);

        if (weight == null && resources.isEmpty) {
          if (htmlService.isLoading ||
              htmlService.isWebViewLoading ||
              htmlService.isExtractingMetadata) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.scale_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  const Text('No Page Size'),
                  const SizedBox(height: 8),
                  const Text(
                    'Page size is measured by the browser. Load a URL in the browser to see it.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final totalSize = resources.fold<int>(0, (sum, r) => sum + r.size);
        final filterType = _typeFilters[_filterController.index].$1;
        final shown = filterType == null
            ? resources
            : resources.where((r) => r.type == filterType).toList();

        return Scrollbar(
          child: ListView(
            primary: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
            children: [
              if (weight != null) ...[
                _buildTotalsCard(context, weight),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle(
                  context, 'Loaded Files & Assets (${resources.length})'),
              if (resources.isNotEmpty) ...[
                _buildFilterTabs(context, resources),
                const SizedBox(height: 12),
              ],
              if (shown.isEmpty)
                Text(
                  resources.isEmpty
                      ? 'No individual resources were reported by the browser.'
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
      },
    );
  }

  Widget _buildFilterTabs(BuildContext context, List<ResourceSize> resources) {
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

  Widget _buildTotalsCard(BuildContext context, Map<String, dynamic> weight) {
    final breakdown = weight['breakdown'] as Map<String, dynamic>?;
    final isPartial = weight['isPartial'] as bool? ?? false;
    final totalDecoded = weight['decoded'] as int? ?? 0;

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
                    '${isPartial ? '≥ ' : ''}${FormatUtils.formatBytesWithTransfer({
                          'decoded': totalDecoded,
                          'transfer': weight['transfer'] as int? ?? 0,
                        })}',
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
            for (final (key, label) in const [
              ('scripts', 'External JS'),
              ('css', 'CSS Files'),
              ('images', 'Images/Media'),
              ('html', 'HTML/Content'),
              ('other', 'Misc. Resources'),
            ])
              _buildBreakdownRow(context, label,
                  breakdown[key] as Map<String, dynamic>?, totalDecoded),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String label,
      Map<String, dynamic>? data, int totalDecoded) {
    if (data == null || (data['count'] as int? ?? 0) == 0) {
      return const SizedBox.shrink();
    }
    final decoded = data['decoded'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
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
                  'decoded': decoded,
                  'transfer': data['transfer'] as int? ?? 0,
                }),
                style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _shareBar(context, decoded, totalDecoded),
        ],
      ),
    );
  }

  Widget _buildResourceRow(BuildContext context, HtmlService htmlService,
      ResourceSize resource, int totalSize) {
    final scheme = Theme.of(context).colorScheme;
    final share = totalSize > 0 ? resource.size / totalSize : 0.0;
    final services = resource.services.take(2).toList();
    final subtitle = [
      if (resource.host.isNotEmpty) resource.host,
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
              if (resource.type == 'image' &&
                  !_audioVideoPath.hasMatch(
                      Uri.tryParse(resource.url)?.path.toLowerCase() ??
                          '')) ...[
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
                            ? 'This page HTML (${resource.pageName})'
                            : resource.fileName,
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
                    _shareBar(context, resource.size, totalSize),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    resource.size > 0
                        ? FormatUtils.formatBytesWithTransfer({
                            'decoded': resource.size,
                            'transfer': resource.transfer,
                          })
                        : 'size n/a',
                    style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
                  ),
                  if (resource.size > 0)
                    Text(
                      '${(share * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _shareBar(BuildContext context, int value, int total) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: total > 0 ? (value / total).clamp(0.0, 1.0) : 0,
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
