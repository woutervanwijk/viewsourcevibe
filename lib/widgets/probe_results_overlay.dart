import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

class ProbeResultsOverlay extends StatelessWidget {
  const ProbeResultsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(
      builder: (context, htmlService, child) {
        if (!htmlService.isProbeOverlayVisible) {
          return const SizedBox.shrink();
        }

        // Use a colored container to overlay
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: _buildContent(context, htmlService),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, HtmlService htmlService) {
    if (htmlService.isProbing) {
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
    if (result != null) {
      return ListView(
        primary:
            false, // Prevent conflict with editor's primary scroll controller
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(context, htmlService, result),
          const SizedBox(height: 16),
          _buildHeadersList(context, result),
        ],
      );
    }

    return const Center(child: Text('Enter a URL and press Enter to probe.'));
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
            Row(
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
                if (isRedirect) ...[
                  const SizedBox(width: 8),
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
              ],
            ),
            const SizedBox(height: 12),
            if (result['headers']?['server'] != null)
              _buildDetailRow('Server', result['headers']['server']),
            if (result['headers']?['content-type'] != null)
              _buildDetailRow(
                  'Content-Type', result['headers']['content-type']),
            const SizedBox(height: 8),
            _buildDetailRow('Final URL', result['finalUrl']),
            if (isRedirect && result['redirectLocation'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 100,
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
                  if ((probeLength == 0 || probeLength == null) &&
                      fileLength > 0) {
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersList(BuildContext context, Map<String, dynamic> result) {
    final headers = result['headers'] as Map<String, String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Response Headers',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: headers.entries.map((e) {
              return ListTile(
                title: Text(
                  e.key,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  e.value,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
                dense: true,
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: '${e.key}: ${e.value}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Header copied to clipboard'),
                        duration: Duration(milliseconds: 500)),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
