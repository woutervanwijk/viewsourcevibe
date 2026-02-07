import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import '../utils/format_utils.dart';

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final metadata = htmlService.pageMetadata;
    final services =
        metadata?['detectedServices'] as Map<String, List<String>>?;

    if (services == null || services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_clear_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            const Text('No Services Detected'),
            const SizedBox(height: 8),
            const Text('No common third-party services found on this page.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          _buildSectionTitle(context, 'Detected Services'),
          const Text(
            'Common third-party services, trackers, and infrastructure used by this page.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ...services.entries.map((entry) {
            return _buildServiceCategory(context, entry.key, entry.value);
          }),
          if (metadata?['analyzedCookies'] != null &&
              (metadata!['analyzedCookies'] as List).isNotEmpty)
            ..._buildCookieSection(
                context, metadata['analyzedCookies'] as List),
          const Divider(height: 48),
          _buildSectionTitle(context, 'External Resources'),
          const Text(
            'JavaScript and CSS files loaded by this page.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildResourceSection(
              context,
              'Scripts (JS)',
              [
                ...(metadata?['jsLinks'] ?? []),
                ...(metadata?['externalJsLinks'] ?? [])
              ],
              Icons.javascript),
          const SizedBox(height: 16),
          _buildResourceSection(
              context,
              'Stylesheets (CSS)',
              [
                ...(metadata?['cssLinks'] ?? []),
                ...(metadata?['externalCssLinks'] ?? [])
              ],
              Icons.css),
          const SizedBox(height: 16),
          _buildResourceSection(
              context,
              'Iframes (HTML)',
              [
                ...(metadata?['iframeLinks'] ?? []),
                ...(metadata?['externalIframeLinks'] ?? [])
              ],
              Icons.web_asset),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildResourceSection(
      BuildContext context, String title, List<dynamic>? links, IconData icon) {
    if (links == null || links.isEmpty) return const SizedBox.shrink();

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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  links.length.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...links.map((link) {
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
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: size != null
                  ? Text(
                      FormatUtils.formatBytes(size['decoded'] as int? ?? 0),
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
                htmlService.loadFromUrl(url,
                    switchToTab: htmlService.sourceTabIndex);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildServiceCategory(
      BuildContext context, String category, List<String> items) {
    IconData icon;
    Color color;

    switch (category) {
      case 'Analytics & Trackers':
        icon = Icons.analytics_outlined;
        color = Colors.orange;
        break;
      case 'Fonts & Icons':
        icon = Icons.font_download_outlined;
        color = Colors.blue;
        break;
      case 'Advertising':
        icon = Icons.ad_units_outlined;
        color = Colors.red;
        break;
      case 'Cloud & Infrastructure':
        icon = Icons.cloud_outlined;
        color = Colors.purple;
        break;
      case 'Social & Widgets':
        icon = Icons.share_outlined;
        color = Colors.green;
        break;
      case 'Uncategorized':
        icon = Icons.help_outline;
        color = Colors.grey;
        break;
      default:
        icon = Icons.category_outlined;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  items.length.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Chip(
                label: Text(item),
                backgroundColor: color.withValues(alpha: 0.05),
                side: BorderSide(color: color.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                labelStyle: const TextStyle(fontSize: 13),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCookieSection(
      BuildContext context, List<dynamic> cookies) {
    // Group providers by display category
    final Map<String, Set<String>> grouped = {};

    for (var c in cookies) {
      if (c is! Map) continue;

      final String? provider = c['provider'];
      final String category = c['category'] ?? 'unknown';

      // If provider is missing, group under Uncategorized
      if (provider == null || provider.isEmpty) {
        grouped
            .putIfAbsent('Uncategorized', () => {})
            .add(c['name'] ?? 'Unknown Cookie');
        continue;
      }

      String displayCat = 'Cloud & Infrastructure';
      switch (category) {
        case 'analytics':
          displayCat = 'Analytics & Trackers';
          break;
        case 'advertising':
          displayCat = 'Advertising';
          break;
        case 'social':
          displayCat = 'Social & Widgets';
          break;
        case 'functional':
        case 'essential':
          displayCat = 'Cloud & Infrastructure';
          break;
      }

      grouped.putIfAbsent(displayCat, () => {}).add(provider);
    }

    if (grouped.isEmpty) return [];

    return [
      const Divider(height: 48),
      _buildSectionTitle(context, 'Detected from Cookies'),
      const Text(
        'Technologies identified by analyzing the cookies set by this page.',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      ),
      const SizedBox(height: 24),
      ...grouped.entries.map((entry) {
        return _buildServiceCategory(context, entry.key, entry.value.toList());
      }),
    ];
  }
}
