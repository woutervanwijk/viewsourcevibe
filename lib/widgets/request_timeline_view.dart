import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/utils/format_utils.dart';

class RequestTimelineView extends StatelessWidget {
  const RequestTimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(
      builder: (context, htmlService, child) {
        final resources = htmlService.resourceTimelineData;
        final probe = htmlService.probeResult ?? const <String, dynamic>{};
        final browserProbe =
            htmlService.browserProbeResult ?? const <String, dynamic>{};
        final pageWeight =
            browserProbe['pageWeight'] as Map<String, dynamic>? ??
                const <String, dynamic>{};
        final redirectChain = _redirectChainFrom(probe);

        if (resources.isEmpty &&
            redirectChain.isEmpty &&
            (htmlService.isLoading ||
                htmlService.isWebViewLoading ||
                htmlService.isExtractingMetadata)) {
          return const Center(child: CircularProgressIndicator());
        }

        if (resources.isEmpty && redirectChain.isEmpty && probe.isEmpty) {
          return const Center(
            child: Text(
              'Load a URL to view the request timeline.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final sortedResources = [...resources]..sort((a, b) {
            final aSize = _resourceSize(a);
            final bSize = _resourceSize(b);
            return bSize.compareTo(aSize);
          });
        final maxSize = sortedResources.fold<int>(
          0,
          (max, resource) =>
              _resourceSize(resource) > max ? _resourceSize(resource) : max,
        );

        return Scrollbar(
          child: ListView(
            primary: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
            children: [
              _buildOverviewCard(context, probe, pageWeight, resources.length),
              if (redirectChain.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildRedirectChainCard(context, redirectChain),
              ],
              const SizedBox(height: 16),
              Text(
                'Resource Timeline',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (sortedResources.isEmpty)
                _buildEmptyResourcesCard(context)
              else
                ...sortedResources.map(
                  (resource) => _buildResourceCard(context, resource, maxSize),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    Map<String, dynamic> probe,
    Map<String, dynamic> pageWeight,
    int resourceCount,
  ) {
    final url = probe['finalUrl']?.toString() ?? probe['url']?.toString();
    final statusCode = probe['statusCode'];
    final transfer = (pageWeight['totalTransfer'] as num? ?? 0).toInt();
    final decoded = (pageWeight['totalDecoded'] as num? ?? 0).toInt();

    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Timeline',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (url != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip(
                  context,
                  Icons.http,
                  statusCode == null ? 'Status N/A' : 'HTTP $statusCode',
                ),
                _buildMetricChip(
                  context,
                  Icons.account_tree_outlined,
                  '$resourceCount resources',
                ),
                _buildMetricChip(
                  context,
                  Icons.download_outlined,
                  transfer > 0 ? FormatUtils.formatBytes(transfer) : 'Size N/A',
                ),
                if (decoded > 0 && decoded != transfer)
                  _buildMetricChip(
                    context,
                    Icons.data_object,
                    '${FormatUtils.formatBytes(decoded)} decoded',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedirectChainCard(
    BuildContext context,
    List<Map<String, dynamic>> redirects,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Redirect Chain',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...redirects.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final redirect = entry.value;
              final status = redirect['statusCode']?.toString() ?? '3xx';
              final reason = redirect['reasonPhrase']?.toString();
              final from = redirect['from']?.toString() ?? '';
              final to = redirect['to']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.orange.withValues(alpha: 0.16),
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reason == null ? status : '$status $reason',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            from,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward, size: 13),
                              const SizedBox(width: 4),
                              Expanded(
                                child: SelectableText(
                                  to,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard(
    BuildContext context,
    Map<String, dynamic> resource,
    int maxSize,
  ) {
    final name = resource['name']?.toString() ?? '';
    final transfer = (resource['transfer'] as num? ?? 0).toInt();
    final decoded = (resource['decoded'] as num? ?? 0).toInt();
    final size = _resourceSize(resource);
    final fraction = maxSize <= 0 ? 0.0 : (size / maxSize).clamp(0.0, 1.0);
    final type = _resourceType(name);
    final color = _typeColor(type);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(type), color: color, size: 18),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  FormatUtils.formatBytesWithTransfer({
                    'decoded': decoded,
                    'transfer': transfer,
                  }),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              name,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyResourcesCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No browser resource timing entries yet. Open the Browser tab or reload the page to collect them.',
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _redirectChainFrom(Map<String, dynamic> probe) {
    final raw = probe['redirectChain'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final redirectLocation = probe['redirectLocation']?.toString();
    if (redirectLocation == null || redirectLocation.isEmpty) return [];

    return [
      {
        'from': probe['url'],
        'to': redirectLocation,
        'statusCode': probe['statusCode'],
        'reasonPhrase': probe['reasonPhrase'],
      }
    ];
  }

  int _resourceSize(Map<String, dynamic> resource) {
    final transfer = (resource['transfer'] as num? ?? 0).toInt();
    final decoded = (resource['decoded'] as num? ?? 0).toInt();
    return decoded > transfer ? decoded : transfer;
  }

  String _resourceType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.js') || lower.contains('.js?')) return 'script';
    if (lower.endsWith('.css') || lower.contains('.css?')) return 'style';
    if (lower.contains('/font') ||
        lower.endsWith('.woff') ||
        lower.endsWith('.woff2') ||
        lower.endsWith('.ttf')) {
      return 'font';
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.avif') ||
        lower.contains('/image')) {
      return 'image';
    }
    if (lower.contains('/api/') ||
        lower.contains('graphql') ||
        lower.contains('xhr')) {
      return 'fetch';
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'document';
    return 'other';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'script':
        return Icons.javascript;
      case 'style':
        return Icons.css;
      case 'image':
        return Icons.image_outlined;
      case 'font':
        return Icons.title;
      case 'fetch':
        return Icons.sync_alt;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'script':
        return Colors.amber;
      case 'style':
        return Colors.purple;
      case 'image':
        return Colors.teal;
      case 'font':
        return Colors.indigo;
      case 'fetch':
        return Colors.blue;
      case 'document':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
