import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

class MetadataView extends StatelessWidget {
  const MetadataView({super.key});

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final metadata = htmlService.pageMetadata;

    if (metadata == null) {
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

    return ListView(
      primary: false,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      children: [
        _buildHeaderSection(context, metadata),
        const SizedBox(height: 24),
        if (metadata['detectedTech']?.isNotEmpty == true) ...[
          _buildSectionTitle(context, 'Technology Stack'),
          _buildTechSection(context, metadata['detectedTech']),
          const SizedBox(height: 24),
        ],
        if (metadata['pageConfig']?.isNotEmpty == true) ...[
          _buildSectionTitle(context, 'Page Configuration'),
          _buildMapSection(context, metadata['pageConfig']),
          const SizedBox(height: 24),
        ],
        if (metadata['resourceHints']?.isNotEmpty == true) ...[
          _buildSectionTitle(context, 'Optimization (Resource Hints)'),
          _buildHintSection(context, metadata['resourceHints']),
          const SizedBox(height: 24),
        ],
        if (metadata['openGraph']?.isNotEmpty == true) ...[
          _buildSectionTitle(context, 'OpenGraph Tags'),
          _buildMapSection(context, metadata['openGraph']),
          const SizedBox(height: 24),
        ],
        if (metadata['twitter']?.isNotEmpty == true) ...[
          _buildSectionTitle(context, 'Twitter Card Info'),
          _buildMapSection(context, metadata['twitter']),
          const SizedBox(height: 24),
        ],
        _buildSectionTitle(context, 'Linked Resources'),
        _buildLinkSection(
            context, 'Stylesheets (CSS)', metadata['cssLinks'], Icons.css),
        _buildLinkSection(
            context, 'Scripts (JS)', metadata['jsLinks'], Icons.javascript),
        _buildLinkSection(context, 'Iframes (HTML)', metadata['iframeLinks'],
            Icons.web_asset),
        _buildLinkSection(
            context, 'RSS/Atom Feeds', metadata['rssLinks'], Icons.rss_feed),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Other Meta Tags'),
        _buildMapSection(context, metadata['otherMeta']),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHeaderSection(
      BuildContext context, Map<String, dynamic> metadata) {
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
        _buildSectionTitle(context, 'Basic Information'),
        _buildMapSection(context, {
          'Title': title,
          if (metadata['language'] != null) 'Language': metadata['language'],
          if (metadata['charset'] != null) 'Charset': metadata['charset'],
          if (favicon != null) 'Icon URL': favicon,
          'Description': description,
        }),
      ],
    );
  }

  Widget _buildHintSection(BuildContext context, Map<String, dynamic> hints) {
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
              ...urls.map((url) => ListTile(
                    title: Text(
                      url.toString(),
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildTechSection(BuildContext context, Map<String, dynamic> tech) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tech.entries.map((e) {
        return Chip(
          avatar: Icon(Icons.code,
              size: 16, color: Theme.of(context).colorScheme.primary),
          label: Text('${e.key}: ${e.value}'),
          backgroundColor: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        );
      }).toList(),
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

  Widget _buildMapSection(BuildContext context, Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Text('None detected.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }

    final unescape = HtmlUnescape();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: data.entries.map((e) {
          final isLast = data.entries.last.key == e.key;
          final value = unescape.convert(e.value.toString());
          final isUrl =
              value.startsWith('http://') || value.startsWith('https://');

          return Column(
            children: [
              ListTile(
                title: Text(
                  e.key,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace'),
                ),
                subtitle: SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
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

  Widget _buildLinkSection(
      BuildContext context, String title, List<dynamic> links, IconData icon) {
    if (links.isEmpty) return const SizedBox.shrink();

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
        ...links.map((url) => Card(
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
                  url.toString(),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                dense: true,
                onTap: () {
                  final htmlService =
                      Provider.of<HtmlService>(context, listen: false);
                  htmlService.loadFromUrl(url.toString(), switchToTab: 0);
                },
              ),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}
