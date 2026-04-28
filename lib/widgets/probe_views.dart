import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/utils/format_utils.dart';

abstract class ProbeViewBase extends StatelessWidget {
  const ProbeViewBase({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(builder: (context, htmlService, child) {
      final result = htmlService.probeResult;

      // Show spinner if we are in any loading/parsing phase and don't have results yet
      if ((htmlService.isProbing ||
              htmlService.isLoading ||
              htmlService.isWebViewLoading ||
              htmlService.isExtractingMetadata) &&
          result == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (htmlService.probeError != null && result == null) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: SelectableText(
              'Error: ${htmlService.probeError}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      }

      if (result == null) {
        return const Center(
            child: Text('Probe a URL to see details',
                style: TextStyle(color: Colors.grey)));
      }

      return Stack(
        children: [
          Positioned.fill(child: buildContent(context, htmlService, result)),
          if (htmlService.isProbing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      );
    });
  }

  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result);

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(FormatUtils.formatHumanData(value)),
          ),
        ],
      ),
    );
  }
}

class ProbeGeneralView extends ProbeViewBase {
  const ProbeGeneralView({super.key});

  @override
  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    // Check if we have browser probe results
    final browserResult = htmlService.browserProbeResult;
    final hasBrowserProbe = browserResult != null && browserResult.isNotEmpty;

    return Scrollbar(
        child: ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
      children: [
        if (hasBrowserProbe) ...[
          // Section Header for CURL Probe
          Text(
            'Curl Probe (Server-Side)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
        ],
        _buildStatusCard(context, htmlService, result),
        const SizedBox(height: 16),
        _buildContentTypeTruthCard(context, htmlService, result),
        const SizedBox(height: 16),
        if (_redirectChainFrom(result).isNotEmpty) ...[
          _buildRedirectChainView(
              context, htmlService, _redirectChainFrom(result)),
          const SizedBox(height: 16),
        ],
        _buildRobotsSitemapCard(context, htmlService, result),
        const SizedBox(height: 16),
        _buildNetworkInfoCard(context, result),
        if (hasBrowserProbe || htmlService.isWebViewLoading) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Browser Probe (Client-Side)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (hasBrowserProbe)
            _buildBrowserProbeCard(context, browserResult)
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ],
    ));
  }

  Widget _buildContentTypeTruthCard(BuildContext context,
      HtmlService htmlService, Map<String, dynamic> result) {
    final headers = result['headers'] as Map?;
    final rawContentType = headers?['content-type']?.toString() ??
        headers?['Content-Type']?.toString() ??
        '';
    final declaredMime = rawContentType.split(';').first.trim().toLowerCase();
    final content = htmlService.currentFile?.content ?? '';
    final filename =
        htmlService.currentFile?.name ?? result['finalUrl']?.toString();
    final sniffed = _sniffContentType(content, filename);
    final status = _contentTypeTruthStatus(declaredMime, sniffed);
    final color = status.$1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(status.$2, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Content-Type Truth Check',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
                'Declared', declaredMime.isEmpty ? 'N/A' : rawContentType),
            _buildDetailRow('Sniffed', sniffed),
            _buildDetailRow('Verdict', status.$3),
          ],
        ),
      ),
    );
  }

  (Color, IconData, String) _contentTypeTruthStatus(
      String declaredMime, String sniffed) {
    if (declaredMime.isEmpty) {
      return (
        Colors.orange,
        Icons.help_outline,
        'No Content-Type header to compare.'
      );
    }
    if (_mimeMatchesSniff(declaredMime, sniffed)) {
      return (
        Colors.green,
        Icons.check_circle_outline,
        'Header and content look aligned.'
      );
    }
    return (
      Colors.red,
      Icons.warning_amber_rounded,
      'Header does not match the loaded content shape.'
    );
  }

  bool _mimeMatchesSniff(String mime, String sniffed) {
    if (sniffed == 'empty') return true;
    if (mime.contains('html')) return sniffed == 'html';
    if (mime.contains('xml') || mime.contains('svg')) return sniffed == 'xml';
    if (mime.contains('json')) return sniffed == 'json';
    if (mime.contains('javascript') || mime.contains('ecmascript')) {
      return sniffed == 'javascript' || sniffed == 'text';
    }
    if (mime == 'text/css') return sniffed == 'css' || sniffed == 'text';
    if (mime.startsWith('text/')) {
      return ['text', 'html', 'css', 'javascript'].contains(sniffed);
    }
    return true;
  }

  String _sniffContentType(String content, String? filename) {
    final trimmed = content.trimLeft();
    final lowerName = filename?.toLowerCase() ?? '';
    if (trimmed.isEmpty) return 'empty';
    if (trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html')) {
      return 'html';
    }
    if (trimmed.startsWith('<?xml') ||
        trimmed.startsWith('<rss') ||
        trimmed.startsWith('<feed')) {
      return 'xml';
    }
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return 'json';
    if (lowerName.endsWith('.css') ||
        trimmed.contains('{') && trimmed.contains(':')) {
      return 'css';
    }
    if (lowerName.endsWith('.js') ||
        trimmed.startsWith('import ') ||
        trimmed.startsWith('const ') ||
        trimmed.startsWith('function ')) {
      return 'javascript';
    }
    return 'text';
  }

  Widget _buildRobotsSitemapCard(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    final discovery = result['robotsSitemap'] as Map<String, dynamic>?;

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
                Icon(Icons.travel_explore,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Robots / Sitemap Discovery',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (discovery == null)
              const Text('Discovery is running or unavailable for this URL.',
                  style: TextStyle(color: Colors.grey, fontSize: 12))
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDiscoveryChip(
                    discovery['robotsPresent'] == true
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    'robots ${discovery['robotsStatus'] ?? 'N/A'}',
                    discovery['robotsPresent'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                  _buildDiscoveryChip(
                    Icons.map_outlined,
                    '${(discovery['sitemaps'] as List? ?? []).length} sitemap${(discovery['sitemaps'] as List? ?? []).length == 1 ? '' : 's'}',
                    Colors.blue,
                  ),
                  _buildDiscoveryChip(
                    Icons.block,
                    '${discovery['disallowCount'] ?? 0} disallow',
                    Colors.red,
                  ),
                  _buildDiscoveryChip(
                    Icons.done_outline,
                    '${discovery['allowCount'] ?? 0} allow',
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                  'Robots URL', discovery['robotsUrl']?.toString() ?? 'N/A'),
              if ((discovery['sitemaps'] as List? ?? []).isNotEmpty) ...[
                const SizedBox(height: 8),
                ...(discovery['sitemaps'] as List).map((url) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading:
                          const Icon(Icons.account_tree_outlined, size: 18),
                      title: Text(
                        url.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace'),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () => htmlService.loadFromUrl(url.toString()),
                    )),
              ],
              if ((discovery['sampleDisallow'] as List? ?? []).isNotEmpty) ...[
                const Divider(height: 20),
                Text(
                  'Sample disallow rules',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                ...(discovery['sampleDisallow'] as List).map(
                  (rule) => Text(rule.toString(),
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace')),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRedirectChainView(BuildContext context, HtmlService htmlService,
      List<Map<String, dynamic>> redirects) {
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
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Redirect Chain View',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...redirects.asMap().entries.map((entry) {
              final redirect = entry.value;
              final status = redirect['statusCode']?.toString() ?? '3xx';
              final from = redirect['from']?.toString() ?? '';
              final to = redirect['to']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.orange.withValues(alpha: 0.15),
                      child: Text(
                        '${entry.key + 1}',
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
                          Text(status,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 3),
                          SelectableText(from,
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 3),
                          InkWell(
                            onTap: () => htmlService.loadFromUrl(to),
                            child: Text(
                              to,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
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

  List<Map<String, dynamic>> _redirectChainFrom(Map<String, dynamic> result) {
    final raw = result['redirectChain'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    final redirectLocation = result['redirectLocation']?.toString();
    if (redirectLocation == null || redirectLocation.isEmpty) return [];
    return [
      {
        'from': result['url'],
        'to': redirectLocation,
        'statusCode': result['statusCode'],
        'reasonPhrase': result['reasonPhrase'],
      }
    ];
  }

  Widget _buildBrowserProbeCard(
      BuildContext context, Map<String, dynamic> result) {
    final pageWeight = result['pageWeight'] as Map<String, dynamic>? ?? {};
    final totalTx = pageWeight['totalTransfer'] as int? ?? 0;
    final totalDec = pageWeight['totalDecoded'] as int? ?? 0;
    final mainDocTx = pageWeight['mainDocumentTransfer'] as int? ?? 0;
    final mainDocDec = pageWeight['mainDocumentDecoded'] as int? ?? 0;
    final resourceCount = result['resourceCount'] as int? ?? 0;
    final url = result['url'] as String? ?? 'N/A';
    final statusCode = result['serverStatusCode'];

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Effective URL', url),
            if (statusCode != null)
              _buildDetailRow('HTTP Status', statusCode.toString()),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow(
                'Document Size',
                mainDocDec > 0
                    ? FormatUtils.formatBytesWithTransfer(
                        {'decoded': mainDocDec, 'transfer': mainDocTx})
                    : 'N/A'),
            const Divider(),
            _buildDetailRow('Total Resources', '$resourceCount requests'),
            _buildDetailRow(
                'Total Size',
                totalDec > 0
                    ? FormatUtils.formatBytesWithTransfer(
                        {'decoded': totalDec, 'transfer': totalTx})
                    : 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    final status = result['statusCode'];
    final reason = result['reasonPhrase'];
    final isRedirect = result['isRedirect'] == true;

    Color statusColor = Colors.green;
    if (status != null) {
      if (status >= 300 && status < 400) statusColor = Colors.orange;
      if (status >= 400) statusColor = Colors.red;
    }

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    '$status $reason'.trim(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isRedirect)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: const Text(
                      'Redirect',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (result['headers']?['content-type'] != null)
              _buildDetailRow(
                  'Content-Type', result['headers']['content-type']),
            _buildDetailRow('Final URL', result['finalUrl'] ?? 'N/A'),
            if (isRedirect && result['redirectLocation'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 128,
                      child: Text(
                        'Redirect to:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          // Load the redirect URL
                          final redirectUrl = result['redirectLocation'];
                          Provider.of<HtmlService>(context, listen: false)
                              .loadFromUrl(redirectUrl);
                          Provider.of<HtmlService>(context, listen: false)
                              .probeUrl(redirectUrl)
                              .ignore();
                        },
                        child: Text(
                          result['redirectLocation'],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (result['contentLength'] != null ||
                (htmlService.currentFile?.content.isNotEmpty ?? false))
              _buildDetailRow(
                'Content Length',
                () {
                  final probeLength = result['contentLength'] ?? 0;
                  final fileLength =
                      htmlService.currentFile?.content.length ?? 0;
                  if (fileLength > 0) {
                    return '$probeLength ($fileLength bytes loaded)';
                  }
                  return '$probeLength bytes';
                }(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkInfoCard(
      BuildContext context, Map<String, dynamic> result) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network & Performance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            if (result['ipAddress'] != null)
              _buildDetailRow('Server IP', result['ipAddress']),
            if (result['responseTime'] != null)
              _buildDetailRow('Response Time', '${result['responseTime']} ms'),
            if (result['headers']?['server'] != null)
              _buildDetailRow('Server Software', result['headers']['server']),
            if (result['headers']?['via'] != null)
              _buildDetailRow('Proxy/Via', result['headers']['via']),
          ],
        ),
      ),
    );
  }
}

class ProbeHeadersView extends ProbeViewBase {
  const ProbeHeadersView({super.key});

  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    final Map<String, dynamic> headers = result['headers'] ?? {};
    final sortedKeys = headers.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scrollbar(
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          Text(
            'All Response Headers',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: sortedKeys.asMap().entries.map((entry) {
                final index = entry.key;
                final key = entry.value;
                final value = headers[key]!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(
                        key,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        FormatUtils.formatHumanData(value),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                      ),
                      dense: true,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: '$key: $value'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Header copied to clipboard'),
                              duration: Duration(milliseconds: 500)),
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ProbeSecurityView extends ProbeViewBase {
  const ProbeSecurityView({super.key});

  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    final Map<String, dynamic> security = result['security'] ?? {};

    return Scrollbar(
        child: ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
      children: [
        _buildSecurityScorecard(context, result, security),
        const SizedBox(height: 16),
        Text(
          'Security Header Audit',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (result['tlsInvalidCertificate'] == true) ...[
          _buildTlsWarningCard(context, result),
          const SizedBox(height: 12),
        ],
        ...(() {
          final sortedSecurity = security.entries.toList()
            ..sort(
                (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
          return sortedSecurity.map((e) {
            final isPresent = e.value != null;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isPresent
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(
                  isPresent
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: isPresent ? Colors.green : Colors.orange,
                ),
                title: Text(e.key,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  isPresent
                      ? FormatUtils.formatHumanData(e.value!)
                      : 'Missing Header',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isPresent ? null : Colors.orange[700],
                  ),
                ),
                dense: true,
              ),
            );
          }).toList();
        }()),
        const SizedBox(height: 24),
        Text(
          'SSL Certificate',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCertificateCard(context, result),
      ],
    ));
  }

  Widget _buildSecurityScorecard(BuildContext context,
      Map<String, dynamic> result, Map<String, dynamic> security) {
    final checks = _buildSecurityHeaderChecks(result, security);
    final applicableChecks =
        checks.where((check) => check.isApplicable).toList();
    final passed = applicableChecks.where((check) => check.isPassing).length;
    final total = applicableChecks.length;
    final score = total == 0 ? 0.0 : passed / total;
    final percentage = (score * 100).round();

    final Color scoreColor;
    if (percentage >= 80) {
      scoreColor = Colors.green;
    } else if (percentage >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.32),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scoreColor.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: score,
                        strokeWidth: 6,
                        color: scoreColor,
                        backgroundColor: scoreColor.withValues(alpha: 0.14),
                      ),
                      Center(
                        child: Text(
                          '$percentage',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: scoreColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Headers Score',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$passed of $total controls present',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: checks.map((check) {
                final color = !check.isApplicable
                    ? Colors.grey
                    : check.isPassing
                        ? Colors.green
                        : Colors.orange;
                return Tooltip(
                  message: check.detail,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !check.isApplicable
                              ? Icons.remove_circle_outline
                              : check.isPassing
                                  ? Icons.check_circle_outline
                                  : Icons.warning_amber_rounded,
                          color: color,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          check.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<_SecurityHeaderCheck> _buildSecurityHeaderChecks(
      Map<String, dynamic> result, Map<String, dynamic> security) {
    final csp = _headerValue(security, 'Content-Security-Policy');
    final frameOptions = _headerValue(security, 'X-Frame-Options');
    final contentTypeOptions = _headerValue(security, 'X-Content-Type-Options');
    final hsts = _headerValue(security, 'Strict-Transport-Security');
    final referrerPolicy = _headerValue(security, 'Referrer-Policy');
    final permissionsPolicy = _headerValue(security, 'Permissions-Policy');
    final finalUrl =
        result['finalUrl']?.toString() ?? result['url']?.toString();
    final isHttps = finalUrl?.startsWith('https://') ?? false;

    final hasFrameProtection =
        _isPresent(frameOptions) || (csp?.contains('frame-ancestors') ?? false);
    final hasNoSniff =
        contentTypeOptions?.toLowerCase().contains('nosniff') ?? false;

    return [
      _SecurityHeaderCheck(
        label: 'HSTS',
        isApplicable: isHttps,
        isPassing: _isPresent(hsts),
        detail: isHttps
            ? (_isPresent(hsts)
                ? 'Strict-Transport-Security is present.'
                : 'Missing Strict-Transport-Security on HTTPS.')
            : 'HSTS is only meaningful on HTTPS responses.',
      ),
      _SecurityHeaderCheck(
        label: 'CSP',
        isPassing: _isPresent(csp),
        detail: _isPresent(csp)
            ? 'Content-Security-Policy is present.'
            : 'Missing Content-Security-Policy.',
      ),
      _SecurityHeaderCheck(
        label: 'Frames',
        isPassing: hasFrameProtection,
        detail: hasFrameProtection
            ? 'Frame protection is present.'
            : 'Missing X-Frame-Options or CSP frame-ancestors.',
      ),
      _SecurityHeaderCheck(
        label: 'No Sniff',
        isPassing: hasNoSniff,
        detail: hasNoSniff
            ? 'X-Content-Type-Options includes nosniff.'
            : 'Missing X-Content-Type-Options: nosniff.',
      ),
      _SecurityHeaderCheck(
        label: 'Referrer',
        isPassing: _isPresent(referrerPolicy),
        detail: _isPresent(referrerPolicy)
            ? 'Referrer-Policy is present.'
            : 'Missing Referrer-Policy.',
      ),
      _SecurityHeaderCheck(
        label: 'Permissions',
        isPassing: _isPresent(permissionsPolicy),
        detail: _isPresent(permissionsPolicy)
            ? 'Permissions-Policy is present.'
            : 'Missing Permissions-Policy.',
      ),
    ];
  }

  String? _headerValue(Map<String, dynamic> security, String key) {
    final value = security[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text.toLowerCase();
  }

  bool _isPresent(String? value) => value != null && value.isNotEmpty;

  Widget _buildTlsWarningCard(
      BuildContext context, Map<String, dynamic> result) {
    final warning = result['tlsWarning']?.toString() ??
        'TLS certificate validation failed. Content was loaded anyway for inspection.';
    return Card(
      elevation: 0,
      color: Colors.orange.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text(
          'TLS Certificate Warning',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(warning),
        dense: true,
      ),
    );
  }

  Widget _buildCertificateCard(
      BuildContext context, Map<String, dynamic> result) {
    final cert = result['certificate'] as Map<String, dynamic>?;
    if (cert == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.no_encryption_gmailerrorred, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(child: Text('No certificate information available')),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic>? subjectParsed = cert['subjectParsed'];
    final Map<String, dynamic>? issuerParsed = cert['issuerParsed'];
    final String start = cert['startValidity'] ?? '';
    final String end = cert['endValidity'] ?? '';
    final finalUrl =
        result['finalUrl']?.toString() ?? result['url']?.toString();
    final host = Uri.tryParse(finalUrl ?? '')?.host ?? '';
    final commonName = subjectParsed?['Common Name']?.toString() ?? '';
    final validity = _certificateValidity(end);
    final hostMatch = _certificateHostMatches(host, commonName);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildCertSignal(
                    context,
                    validity.$2,
                    validity.$1,
                    validity.$3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCertSignal(
                    context,
                    hostMatch ? Colors.green : Colors.orange,
                    hostMatch
                        ? Icons.verified_user_outlined
                        : Icons.help_outline,
                    host.isEmpty
                        ? 'Host unknown'
                        : hostMatch
                            ? 'CN matches host'
                            : 'CN differs from host',
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Subject (Owner)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildParsedInfo(context, subjectParsed, cert['subject']),
            const Divider(height: 24),
            Text(
              'Issuer',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildParsedInfo(context, issuerParsed, cert['issuer']),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                    child: _buildCertDetail(
                        context, 'Valid From', _formatDate(start))),
                Expanded(
                    child: _buildCertDetail(
                        context, 'Valid Until', _formatDate(end))),
              ],
            ),
            if (cert['der'] != null) ...[
              const Divider(height: 24),
              _buildCertDetail(
                context,
                'DER Fingerprint Hint',
                cert['der'].toString().substring(
                      0,
                      cert['der'].toString().length.clamp(0, 32),
                    ),
              ),
            ],
            if (cert['pem'] != null) ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy PEM Certificate'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: cert['pem']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Certificate copied')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCertSignal(
      BuildContext context, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _certificateValidity(String end) {
    try {
      final endDate = DateTime.parse(end);
      final days = endDate.difference(DateTime.now()).inDays;
      if (days < 0) {
        return (
          Icons.dangerous_outlined,
          Colors.red,
          'Expired ${days.abs()}d ago'
        );
      }
      if (days < 14) {
        return (Icons.warning_amber_rounded, Colors.red, 'Expires in ${days}d');
      }
      if (days < 45) {
        return (
          Icons.warning_amber_rounded,
          Colors.orange,
          'Expires in ${days}d'
        );
      }
      return (Icons.check_circle_outline, Colors.green, 'Valid for ${days}d');
    } catch (_) {
      return (Icons.help_outline, Colors.grey, 'Validity unknown');
    }
  }

  bool _certificateHostMatches(String host, String commonName) {
    if (host.isEmpty || commonName.isEmpty) return false;
    final normalizedHost = host.toLowerCase();
    final normalizedCn = commonName.toLowerCase();
    if (normalizedCn == normalizedHost) return true;
    if (normalizedCn.startsWith('*.')) {
      final suffix = normalizedCn.substring(1);
      return normalizedHost.endsWith(suffix) &&
          normalizedHost.split('.').length == normalizedCn.split('.').length;
    }
    return false;
  }

  Widget _buildParsedInfo(
      BuildContext context, Map<String, dynamic>? parsed, String? raw) {
    if (parsed == null || parsed.isEmpty) {
      return SelectableText(
        raw ?? 'Unknown',
        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parsed.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '${e.key}:',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Expanded(
                child: SelectableText(
                  e.value.toString(),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCertDetail(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  String _formatDate(String isoString) {
    try {
      if (isoString.isEmpty) return 'Unknown';
      final date = DateTime.parse(isoString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}

class ProbeCookiesView extends ProbeViewBase {
  const ProbeCookiesView({super.key});

  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    // Prefer analyzed cookies if available (merged Server + Browser + Categories)
    final List<dynamic>? analyzedCookies = result['analyzedCookies'];

    if (analyzedCookies != null && analyzedCookies.isNotEmpty) {
      final sortedCookies = List<Map<String, dynamic>>.from(analyzedCookies);
      sortedCookies.sort((a, b) {
        final categoryA = a['category'] as String? ?? 'unknown';
        final categoryB = b['category'] as String? ?? 'unknown';

        // Known cookies first (essential, analytics, advertising, social)
        bool isKnown(String cat) => cat != 'unknown';
        final aKnown = isKnown(categoryA);
        final bKnown = isKnown(categoryB);

        if (aKnown != bKnown) {
          return aKnown ? -1 : 1;
        }

        // If known, sort by provider name first, then cookie name
        if (aKnown) {
          final providerA = (a['provider'] as String? ?? '').toLowerCase();
          final providerB = (b['provider'] as String? ?? '').toLowerCase();
          if (providerA != providerB) {
            return providerA.compareTo(providerB);
          }
        }

        // Default: sort by name
        final nameA = (a['name'] as String? ?? '').toLowerCase();
        final nameB = (b['name'] as String? ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

      return Scrollbar(
          child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          _buildCookiePrivacyLens(context, sortedCookies),
          const SizedBox(height: 12),
          ...sortedCookies.map((cookie) {
            final name = cookie['name'] as String? ?? 'Unknown';
            final value = cookie['value'] as String? ?? '';
            final category = cookie['category'] as String? ?? 'unknown';
            final provider = cookie['provider'] as String?;
            final source = cookie['source'] as String? ?? 'Unknown';

            Color badgeColor;
            switch (category) {
              case 'essential':
                badgeColor = Colors.green;
                break;
              case 'analytics':
                badgeColor = Colors.blue;
                break;
              case 'advertising':
                badgeColor = Colors.orange;
                break;
              case 'social':
                badgeColor = Colors.purple;
                break;
              default:
                badgeColor = Colors.grey;
            }

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                    ),
                    if (provider != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          provider,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.category, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          category.toUpperCase(),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                            source == 'Browser'
                                ? Icons.web
                                : source == 'Server'
                                    ? Icons.dns
                                    : Icons.merge_type,
                            size: 12,
                            color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          source,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '$name=$value'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Cookie copied'),
                          duration: Duration(milliseconds: 500)),
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ));
    }

    // Fallback to basic list if no analysis available
    final List<String> cookies =
        (result['cookies'] as List?)?.map((e) => e.toString()).toList() ?? [];
    cookies.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (cookies.isEmpty) {
      if (htmlService.isLoading ||
          htmlService.isProbing ||
          htmlService.isWebViewLoading ||
          htmlService.isExtractingMetadata) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cookie_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No cookies detected.'),
            Text('(Try reloading the browser)',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return Scrollbar(
        child: ListView.builder(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
      itemCount: cookies.length,
      itemBuilder: (context, index) {
        final cookie = cookies[index];
        final parts = cookie.split(';');
        final nameValue = parts[0];
        final attributes = parts.length > 1 ? parts.sublist(1).join(';') : '';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(nameValue,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(FormatUtils.formatHumanData(attributes.trim()),
                style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cookie));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Cookie copied'),
                      duration: Duration(milliseconds: 500)),
                );
              },
            ),
          ),
        );
      },
    ));
  }

  Widget _buildCookiePrivacyLens(
      BuildContext context, List<Map<String, dynamic>> cookies) {
    final analytics = _countCategory(cookies, 'analytics');
    final advertising = _countCategory(cookies, 'advertising');
    final social = _countCategory(cookies, 'social');
    final unknown = _countCategory(cookies, 'unknown');
    final secure = cookies.where((cookie) => cookie['secure'] == true).length;
    final httpOnly =
        cookies.where((cookie) => cookie['httpOnly'] == true).length;
    final thirdPartyish = cookies.where(_isThirdPartyishCookie).length;
    final weakSameSite = cookies.where(_hasWeakSameSite).length;
    final score = _cookiePrivacyScore(cookies);
    final color = score >= 75
        ? Colors.green
        : score >= 45
            ? Colors.orange
            : Colors.red;

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
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.36)),
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cookie Privacy Lens',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _cookiePrivacyVerdict(score),
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.68),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCookieLensChip(
                    context,
                    Icons.cookie_outlined,
                    '${cookies.length} total',
                    Theme.of(context).colorScheme.primary),
                if (analytics > 0)
                  _buildCookieLensChip(context, Icons.analytics_outlined,
                      '$analytics analytics', Colors.blue),
                if (advertising > 0)
                  _buildCookieLensChip(context, Icons.ad_units_outlined,
                      '$advertising ads', Colors.orange),
                if (social > 0)
                  _buildCookieLensChip(context, Icons.share_outlined,
                      '$social social', Colors.purple),
                if (unknown > 0)
                  _buildCookieLensChip(context, Icons.help_outline,
                      '$unknown unknown', Colors.grey),
                _buildCookieLensChip(context, Icons.lock_outline,
                    '$secure secure', Colors.green),
                _buildCookieLensChip(context, Icons.shield_outlined,
                    '$httpOnly HttpOnly', Colors.teal),
                if (thirdPartyish > 0)
                  _buildCookieLensChip(context, Icons.public,
                      '$thirdPartyish cross-site-ish', Colors.red),
                if (weakSameSite > 0)
                  _buildCookieLensChip(context, Icons.open_in_new,
                      '$weakSameSite weak SameSite', Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            ..._cookiePrivacyNotes(cookies).map(
              (note) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(note.icon, size: 15, color: note.color),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        note.text,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCookieLensChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  int _cookiePrivacyScore(List<Map<String, dynamic>> cookies) {
    if (cookies.isEmpty) return 100;
    var score = 100;
    score -= _countCategory(cookies, 'advertising') * 12;
    score -= _countCategory(cookies, 'analytics') * 7;
    score -= _countCategory(cookies, 'social') * 6;
    score -= _countCategory(cookies, 'unknown') * 3;
    score -= cookies.where(_isThirdPartyishCookie).length * 6;
    score -= cookies.where(_hasWeakSameSite).length * 5;
    score -= cookies.where(_isMissingSecure).length * 2;
    return score.clamp(0, 100);
  }

  int _countCategory(List<Map<String, dynamic>> cookies, String category) {
    return cookies.where((cookie) => cookie['category'] == category).length;
  }

  bool _isThirdPartyishCookie(Map<String, dynamic> cookie) {
    final category = cookie['category']?.toString();
    final domain = cookie['domain']?.toString() ?? '';
    final provider = cookie['provider']?.toString() ?? '';
    return category == 'advertising' ||
        category == 'social' ||
        domain.startsWith('.') ||
        provider.contains('Google') ||
        provider.contains('Meta') ||
        provider.contains('Facebook') ||
        provider.contains('DoubleClick');
  }

  bool _hasWeakSameSite(Map<String, dynamic> cookie) {
    final source = cookie['source']?.toString() ?? '';
    if (!source.contains('Server')) return false;
    final sameSite = cookie['sameSite']?.toString().toLowerCase();
    if (sameSite == null || sameSite.isEmpty) return true;
    return sameSite == 'none' && cookie['secure'] != true;
  }

  bool _isMissingSecure(Map<String, dynamic> cookie) {
    final source = cookie['source']?.toString() ?? '';
    return source.contains('Server') && cookie['secure'] != true;
  }

  String _cookiePrivacyVerdict(int score) {
    if (score >= 75) return 'Low visible tracking pressure from cookies.';
    if (score >= 45) return 'Moderate cookie tracking signals detected.';
    return 'Heavy tracking or weak cookie boundaries detected.';
  }

  List<_CookiePrivacyNote> _cookiePrivacyNotes(
      List<Map<String, dynamic>> cookies) {
    final notes = <_CookiePrivacyNote>[];
    final advertising = _countCategory(cookies, 'advertising');
    final analytics = _countCategory(cookies, 'analytics');
    final weakSameSite = cookies.where(_hasWeakSameSite).length;
    final notSecure = cookies.where(_isMissingSecure).length;
    final httpOnly =
        cookies.where((cookie) => cookie['httpOnly'] == true).length;

    if (advertising > 0) {
      notes.add(_CookiePrivacyNote(
        Icons.ad_units_outlined,
        Colors.orange,
        '$advertising advertising cookie${advertising == 1 ? '' : 's'} can support cross-site profiling.',
      ));
    }
    if (analytics > 0) {
      notes.add(_CookiePrivacyNote(
        Icons.analytics_outlined,
        Colors.blue,
        '$analytics analytics cookie${analytics == 1 ? '' : 's'} can measure repeat visits.',
      ));
    }
    if (weakSameSite > 0) {
      notes.add(_CookiePrivacyNote(
        Icons.open_in_new,
        Colors.red,
        '$weakSameSite cookie${weakSameSite == 1 ? '' : 's'} missing strict SameSite protection.',
      ));
    }
    if (notSecure > 0) {
      notes.add(_CookiePrivacyNote(
        Icons.lock_open,
        Colors.red,
        '$notSecure cookie${notSecure == 1 ? '' : 's'} not marked Secure.',
      ));
    }
    if (httpOnly > 0) {
      notes.add(_CookiePrivacyNote(
        Icons.shield_outlined,
        Colors.green,
        '$httpOnly cookie${httpOnly == 1 ? '' : 's'} protected from JavaScript access.',
      ));
    }
    if (notes.isEmpty) {
      notes.add(const _CookiePrivacyNote(
        Icons.check_circle_outline,
        Colors.green,
        'No obvious cookie privacy issues detected.',
      ));
    }
    return notes.take(4).toList();
  }
}

class _CookiePrivacyNote {
  final IconData icon;
  final Color color;
  final String text;

  const _CookiePrivacyNote(this.icon, this.color, this.text);
}

class _SecurityHeaderCheck {
  final String label;
  final bool isApplicable;
  final bool isPassing;
  final String detail;

  const _SecurityHeaderCheck({
    required this.label,
    this.isApplicable = true,
    required this.isPassing,
    required this.detail,
  });
}
