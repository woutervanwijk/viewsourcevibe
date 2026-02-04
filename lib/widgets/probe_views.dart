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
      if (htmlService.isProbing || htmlService.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (htmlService.probeError != null) {
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
      final result = htmlService.probeResult;
      if (result == null) {
        return const Center(
            child: Text('Probe a URL to see details',
                style: TextStyle(color: Colors.grey)));
      }
      return buildContent(context, htmlService, result);
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
  Widget buildContent(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(context, htmlService, result),
        const SizedBox(height: 16),
        _buildNetworkInfoCard(context, result),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, HtmlService htmlService,
      Map<String, dynamic> result) {
    final status = result['statusCode'];
    final reason = result['reasonPhrase'];
    final isRedirect = result['isRedirect'] == true;

    Color statusColor = Colors.green;
    if (status >= 300 && status < 400) statusColor = Colors.orange;
    if (status >= 400) statusColor = Colors.red;

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
            _buildDetailRow('Final URL', result['finalUrl']),
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
    final sortedKeys = headers.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Response Headers',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                primary: false,
                itemCount: sortedKeys.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final key = sortedKeys[index];
                  final value = headers[key]!;
                  return ListTile(
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
                  );
                },
              ),
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

    return ListView(
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Security Header Audit',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...security.entries.map((e) {
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
        }),
        const SizedBox(height: 24),
        Text(
          'SSL Certificate',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCertificateCard(context, result['certificate']),
      ],
    );
  }

  Widget _buildCertificateCard(
      BuildContext context, Map<String, dynamic>? cert) {
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
              Text('No certificate information available'),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic>? subjectParsed = cert['subjectParsed'];
    final Map<String, dynamic>? issuerParsed = cert['issuerParsed'];
    final String start = cert['startValidity'] ?? '';
    final String end = cert['endValidity'] ?? '';

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
    final List<String> cookies =
        (result['cookies'] as List?)?.map((e) => e.toString()).toList() ?? [];

    if (cookies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cookie_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No cookies set by this server.'),
          ],
        ),
      );
    }

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
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
    );
  }
}
