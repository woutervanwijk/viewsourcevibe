import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/utils/format_utils.dart';
import 'package:view_source_vibe/utils/page_weight.dart';

/// Page size/weight: totals, a per-type breakdown and every loaded
/// file/asset sorted by size.
class PageSizeView extends StatelessWidget {
  const PageSizeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(
      builder: (context, htmlService, child) {
        final weight =
            htmlService.pageMetadata?['pageWeight'] as Map<String, dynamic>?;
        final resources = resourcesBySize(htmlService.resourceTimelineData,
            htmlService.currentFile?.path ?? '');

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
              if (resources.isEmpty)
                Text(
                  'No individual resources were reported by the browser.',
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
                      for (var i = 0; i < resources.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _buildResourceRow(
                            context, htmlService, resources[i], totalSize),
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

    return InkWell(
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
                  size: 18, color: scheme.secondary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: resource.url,
                    child: Text(
                      resource.fileName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (resource.host.isNotEmpty)
                    Text(
                      resource.host,
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
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
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
