import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/settings.dart';
import '../utils/format_utils.dart';

abstract class ProbeViewBase extends StatelessWidget {
  const ProbeViewBase({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<HtmlService, AppSettings>(
        builder: (context, htmlService, settings, child) {
      final result = htmlService.probeResult;

      // Show spinner only if we don't have results yet
      if ((htmlService.isProbing || htmlService.isLoading) && result == null) {
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
          Positioned.fill(
              child: buildContent(context, htmlService, result, settings)),
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
      Map<String, dynamic> result, AppSettings settings);

  Widget _buildDetailRow(String label, String value, AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 12, fontFamily: settings.fontFamily),
            ),
          ),
        ],
      ),
    );
  }
}

class ProbeGeneralView extends ProbeViewBase {
  const ProbeGeneralView({super.key});

  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result, AppSettings settings) {
    // Check if we have browser probe results
    final browserResult = htmlService.browserProbeResult;
    final hasBrowserProbe = browserResult != null && browserResult.isNotEmpty;

    return ListView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        if (hasBrowserProbe) ...[
          _buildSectionHeader('Browser Analysis (Client-side)'),
          _buildBrowserInfoCard(browserResult, settings),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader('Basic Network Info (Server-side)'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                    'URL', result['url']?.toString() ?? 'N/A', settings),
                _buildDetailRow('Final URL',
                    result['finalUrl']?.toString() ?? 'N/A', settings),
                _buildDetailRow('Status',
                    result['statusCode']?.toString() ?? 'N/A', settings),
                _buildDetailRow(
                    'IP Address', result['ip']?.toString() ?? 'N/A', settings),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (result['timing'] != null) ...[
          _buildSectionHeader('Timing'),
          _buildTimingCard(result['timing'] as Map<String, dynamic>, settings),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildBrowserInfoCard(
      Map<String, dynamic> info, AppSettings settings) {
    return Card(
      elevation: 0,
      color: Colors.blue.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow(
                'Browser', info['browser']?.toString() ?? 'N/A', settings),
            _buildDetailRow('OS', info['os']?.toString() ?? 'N/A', settings),
            _buildDetailRow(
                'Device', info['device']?.toString() ?? 'N/A', settings),
            if (info['engine'] != null)
              _buildDetailRow('Engine', info['engine'].toString(), settings),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingCard(Map<String, dynamic> timing, AppSettings settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: timing.entries.map((e) {
            String label = e.key[0].toUpperCase() + e.key.substring(1);
            String value = e.value.toString();
            if (e.value is int || e.value is double) {
              value = '${e.value} ms';
            }
            return _buildDetailRow(label, value, settings);
          }).toList(),
        ),
      ),
    );
  }
}

class ProbeHeadersView extends ProbeViewBase {
  const ProbeHeadersView({super.key});

  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result, AppSettings settings) {
    final Map<String, dynamic> headers = result['headers'] ?? {};
    final sortedKeys = headers.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView.separated(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      itemCount: sortedKeys.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final value = headers[key];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  key,
                  style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                subtitle: SelectableText(
                  FormatUtils.formatHumanData(value),
                  style:
                      TextStyle(fontFamily: settings.fontFamily, fontSize: 13),
                ),
                dense: true,
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: '$key: ${value.toString()}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Header copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProbeSecurityView extends ProbeViewBase {
  const ProbeSecurityView({super.key});

  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result, AppSettings settings) {
    final Map<String, dynamic> security = result['security'] ?? {};

    return ListView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader('Security Headers'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: security.entries.map((e) {
              final isLast = security.entries.last.key == e.key;
              final isPresent = e.value != null;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isPresent ? Icons.check_circle : Icons.warning,
                      color: isPresent ? Colors.green : Colors.orange,
                    ),
                    title: Text(e.key,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: settings.fontFamily)),
                    subtitle: Text(
                      isPresent
                          ? FormatUtils.formatHumanData(e.value!)
                          : 'Not implementation / Missing',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: settings.fontFamily,
                        color: isPresent ? null : Colors.orange[700],
                      ),
                    ),
                    dense: true,
                  ),
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'SSL Certificate'.toUpperCase(),
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCertificateCard(context, result['certificate'], settings),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildCertificateCard(
      BuildContext context, Map<String, dynamic>? cert, AppSettings settings) {
    if (cert == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No SSL certificate information available.'),
        ),
      );
    }

    final subjectParsed = cert['subjectParsed'] as Map<String, dynamic>?;
    final issuerParsed = cert['issuerParsed'] as Map<String, dynamic>?;

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
            Text(
              'Subject',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            _buildParsedInfo(context, subjectParsed, cert['subject'], settings),
            const Divider(height: 24),
            Text(
              'Issuer',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            _buildParsedInfo(context, issuerParsed, cert['issuer'], settings),
            const Divider(height: 24),
            _buildDetailRow(
                'Valid From', cert['validFrom']?.toString() ?? 'N/A', settings),
            _buildDetailRow(
                'Valid To', cert['validTo']?.toString() ?? 'N/A', settings),
            _buildDetailRow(
                'Protocol', cert['protocol']?.toString() ?? 'N/A', settings),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedInfo(BuildContext context, Map<String, dynamic>? parsed,
      dynamic raw, AppSettings settings) {
    if (parsed == null || parsed.isEmpty) {
      return SelectableText(
        raw?.toString() ?? 'N/A',
        style: TextStyle(fontSize: 12, fontFamily: settings.fontFamily),
      );
    }

    return Column(
      children: parsed.entries.map((e) {
        return _buildDetailRow(e.key, e.value.toString(), settings);
      }).toList(),
    );
  }
}

class ProbeCookiesView extends ProbeViewBase {
  const ProbeCookiesView({super.key});

  @override
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result, AppSettings settings) {
    var cookies = result['analyzedCookies'] as List<dynamic>? ?? [];

    // Fallback if analyzedCookies is empty but raw cookies exist (e.g. during a transition)
    if (cookies.isEmpty && result['cookies'] != null) {
      final raw = result['cookies'] as List;
      if (raw.isNotEmpty && raw[0] is Map) {
        cookies = raw;
      }
    }

    if (cookies.isEmpty) {
      return const Center(child: Text('No cookies detected.'));
    }

    return ListView.builder(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      itemCount: cookies.length,
      itemBuilder: (context, index) {
        final cookie = cookies[index] as Map<String, dynamic>;
        return _buildCookieCard(context, cookie, settings);
      },
    );
  }

  Widget _buildCookieCard(
      BuildContext context, Map<String, dynamic> cookie, AppSettings settings) {
    final name = cookie['name']?.toString() ?? 'N/A';
    final value = cookie['value']?.toString() ?? 'N/A';
    final domain = cookie['domain']?.toString() ?? 'N/A';
    final expires = cookie['expires']?.toString() ?? 'Session';
    final isSecure = cookie['secure'] == true;
    final isHttpOnly = cookie['httpOnly'] == true;

    // Enhanced look for identified cookies
    final category = cookie['category']?.toString();
    final description = cookie['description']?.toString();
    final provider = cookie['provider']?.toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: category != null
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: settings.fontFamily),
                  ),
                ),
                if (provider != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      provider,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (category != null) ...[
              const SizedBox(height: 4),
              Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(height: 24),
            _buildCookieRow('Value', value, settings),
            _buildCookieRow('Domain', domain, settings),
            _buildCookieRow('Expires', expires, settings),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (isSecure) _buildBadge('Secure', Colors.green),
                if (isHttpOnly) _buildBadge('HttpOnly', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCookieRow(String label, String value, AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(fontSize: 13, fontFamily: settings.fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
