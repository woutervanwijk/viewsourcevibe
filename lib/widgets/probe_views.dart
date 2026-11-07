import 'package:view_source_vibe/widgets/service_logo.dart';
import 'package:view_source_vibe/widgets/evidence_view.dart';
import 'package:view_source_vibe/models/detection_evidence.dart';
import 'package:view_source_vibe/services/logo_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/cookies_view.dart';
import 'package:view_source_vibe/services/derive/divergences.dart';
import 'package:view_source_vibe/services/derive/header_insights.dart';
import 'package:view_source_vibe/services/derive/probe_general.dart';
import 'package:view_source_vibe/services/derive/security_audit.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/utils/format_utils.dart';

// ---------------------------------------------------------------------------
// Shared pieces of the migrated probe tabs
// ---------------------------------------------------------------------------

Widget _detailRow(String label, String value) {
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

Widget _chip(IconData icon, String label, Color color) {
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
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Widget _cardTitle(BuildContext context, IconData icon, String title,
    {Color? color}) {
  return Row(
    children: [
      Icon(icon,
          size: 20, color: color ?? Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );
}

Widget _card(BuildContext context, List<Widget> children,
    {Color? border, bool filled = false}) {
  final scheme = Theme.of(context).colorScheme;
  return Card(
    elevation: 0,
    color:
        filled ? scheme.surfaceContainerHighest.withValues(alpha: 0.3) : null,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: border ?? scheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
}

/// The body of a card whose value is not there: loading, failed or
/// unavailable, each with its own text.
Widget _notThere<T>(Observed<T> state, String pendingText) {
  switch (state) {
    case Pending<T>():
      return Row(
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(pendingText,
                  style: const TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      );
    case Failed<T>(:final error):
      return SelectableText(error,
          style: const TextStyle(color: Colors.red, fontSize: 12));
    case Unavailable<T>(:final reason, :final detail):
      return Text(unavailableMessage(reason, detail),
          style: const TextStyle(color: Colors.grey, fontSize: 12));
    case Present<T>():
      return const SizedBox.shrink();
  }
}

/// The message of a tab that has nothing to show for this target.
Widget _tabMessage(String text, {bool error = false}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SelectableText(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: error ? Colors.red : Colors.grey),
        ),
      ),
    ),
  );
}

/// Shows a tab's top-level state: the model builder runs for Present only.
Widget _tabBody<T>(Observed<T> state, Widget Function(T) present) {
  return switch (state) {
    Present<T>(:final value) => present(value),
    Pending<T>() => const Center(child: CircularProgressIndicator()),
    Failed<T>(:final error) => _tabMessage('Error: $error', error: true),
    Unavailable<T>(:final detail, :final reason) =>
      _tabMessage(detail.isEmpty ? unavailableMessage(reason, detail) : detail),
  };
}

// ---------------------------------------------------------------------------
// General
// ---------------------------------------------------------------------------

class ProbeGeneralView extends StatelessWidget {
  const ProbeGeneralView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    final state = context
        .select<HtmlService, Observed<GeneralModel>>((s) => s.generalView);
    return _tabBody(state, (m) => _content(context, m));
  }

  Widget _content(BuildContext context, GeneralModel m) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        );
    final status = m.status;
    return Scrollbar(
        child: ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
      children: [
        Text('Curl Probe (Server-Side)', style: titleStyle),
        const SizedBox(height: 8),
        _buildStatusCard(context, status),
        if (m.divergences.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDivergences(context, m.divergences),
        ],
        const SizedBox(height: 16),
        _buildContentTypeTruthCard(context, m.contentType),
        const SizedBox(height: 16),
        _buildSourceDiffCard(context, m.diff),
        if (status is Present<ServerStatus> &&
            status.value.redirects.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildRedirectChainView(context, status.value.redirects),
        ],
        const SizedBox(height: 16),
        _buildRobotsSitemapCard(context, m.robots),
        const SizedBox(height: 16),
        _buildNetworkInfoCard(context, m.network),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text('Browser Probe (Client-Side)', style: titleStyle),
        const SizedBox(height: 8),
        _buildBrowserProbeCard(context, m.browser),
        const SizedBox(height: 16),
        _buildStorageInspector(context, m.storage),
      ],
    ));
  }

  Widget _buildDivergences(BuildContext context, List<Divergence> items) {
    return _card(
      context,
      [
        _cardTitle(context, Icons.compare_arrows,
            "The app's request and the browser differ",
            color: Colors.orange),
        const SizedBox(height: 10),
        for (final d in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                    d.lowSeverity
                        ? Icons.info_outline
                        : Icons.warning_amber_rounded,
                    size: 15,
                    color: d.lowSeverity ? Colors.grey : Colors.orange),
                const SizedBox(width: 7),
                Expanded(
                    child:
                        Text(d.message, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
      ],
      border: Colors.orange.withValues(alpha: 0.4),
    );
  }

  Widget _buildStatusCard(BuildContext context, Observed<ServerStatus> state) {
    if (state is! Present<ServerStatus>) {
      return _card(
          context,
          [
            _cardTitle(context, Icons.dns_outlined, 'Server response'),
            const SizedBox(height: 12),
            _notThere(state, 'Fetching…'),
          ],
          filled: true);
    }
    final s = state.value;
    final code = s.last.status;
    var statusColor = Colors.green;
    if (code >= 300 && code < 400) statusColor = Colors.orange;
    if (code >= 400) statusColor = Colors.red;
    final htmlService = context.read<HtmlService>();

    return _card(
      context,
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                s.finalStatusText,
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            if (s.isRedirect)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text('Redirect',
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Answer to the app\'s own request, not the browser\'s',
            style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 12),
        _detailRow('Content-Type', s.contentType ?? 'not sent by the server'),
        _detailRow('Final URL', s.finalUrlLabel),
        if (s.redirectTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 128,
                  child: Text('Redirect to:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => htmlService.loadFromUrl(s.redirectTo!),
                    child: Text(
                      s.redirectTo!,
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
        _detailRow('Content Length', s.contentLengthLabel),
        _detailRow('Body received', s.bodyLabel),
        _detailRow('User-Agent', s.userAgent),
      ],
      filled: true,
    );
  }

  Widget _buildContentTypeTruthCard(
      BuildContext context, Observed<ContentTypeTruth> state) {
    if (state is! Present<ContentTypeTruth>) {
      return _card(context, [
        _cardTitle(context, Icons.help_outline, 'Content-Type Truth Check'),
        const SizedBox(height: 12),
        _notThere(state, 'Waiting for the server response…'),
      ]);
    }
    final c = state.value;
    final (color, icon) = switch (c.verdict) {
      ContentTypeVerdict.aligned => (Colors.green, Icons.check_circle_outline),
      ContentTypeVerdict.mismatch => (Colors.red, Icons.warning_amber_rounded),
      ContentTypeVerdict.noHeader => (Colors.orange, Icons.help_outline),
    };
    return _card(
      context,
      [
        _cardTitle(context, icon, 'Content-Type Truth Check', color: color),
        const SizedBox(height: 12),
        _detailRow('Declared', c.declared ?? 'not sent by the server'),
        _detailRow('Sniffed', '${c.sniffed} (server response)'),
        _detailRow('Verdict', c.verdictText),
      ],
      border: color.withValues(alpha: 0.36),
    );
  }

  Widget _buildRobotsSitemapCard(
      BuildContext context, Observed<RobotsCard> state) {
    if (state is! Present<RobotsCard>) {
      return _card(context, [
        _cardTitle(context, Icons.travel_explore, 'Robots / Sitemap Discovery'),
        const SizedBox(height: 12),
        _notThere(state, 'Checking robots.txt and sitemap.xml…'),
      ]);
    }
    final r = state.value;
    final htmlService = context.read<HtmlService>();
    return _card(context, [
      _cardTitle(context, Icons.travel_explore, 'Robots / Sitemap Discovery'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip(
            r.robotsFound == true
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            r.robotsLabel,
            r.robotsFound == true ? Colors.green : Colors.orange,
          ),
          _chip(Icons.map_outlined, r.sitemapsLabel, Colors.blue),
          _chip(Icons.block, r.disallowLabel, Colors.red),
          _chip(Icons.done_outline, r.allowLabel, Colors.green),
        ],
      ),
      const SizedBox(height: 12),
      _detailRow('Robots URL', r.robotsUrl),
      if (r.truncatedNote != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(r.truncatedNote!,
              style: const TextStyle(color: Colors.orange, fontSize: 12)),
        ),
      if (r.sitemaps.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...r.sitemaps.map((url) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.account_tree_outlined, size: 18),
              title: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              onTap: () => htmlService.loadFromUrl(url),
            )),
      ],
      if (r.sampleDisallow.isNotEmpty) ...[
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
        ...r.sampleDisallow.map(
          (rule) => Text(rule,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ),
      ],
    ]);
  }

  Widget _buildStorageInspector(
      BuildContext context, Observed<StorageCard> state) {
    if (state is! Present<StorageCard>) {
      return _card(context, [
        _cardTitle(context, Icons.inventory_2_outlined, 'Storage Inspector'),
        const SizedBox(height: 12),
        _notThere(state, 'Waiting for the browser…'),
      ]);
    }
    final s = state.value;
    return _card(context, [
      _cardTitle(context, Icons.inventory_2_outlined, 'Storage Inspector'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (s.local != null) ...[
            _chip(Icons.storage, s.local!.countLabel, Colors.blue),
            _chip(Icons.memory, s.local!.sizeLabel, Colors.blue),
          ] else
            _chip(
                Icons.storage, 'localStorage: ${s.localUnknown}', Colors.grey),
          if (s.session != null) ...[
            _chip(Icons.tab, s.session!.countLabel, Colors.purple),
            _chip(Icons.memory, s.session!.sizeLabel, Colors.purple),
          ] else
            _chip(
                Icons.tab, 'sessionStorage: ${s.sessionUnknown}', Colors.grey),
        ],
      ),
      const SizedBox(height: 12),
      if (s.local != null)
        _buildStorageKeyList(context, 'localStorage', s.local!),
      if (s.session != null)
        _buildStorageKeyList(context, 'sessionStorage', s.session!),
    ]);
  }

  Widget _buildStorageKeyList(
      BuildContext context, String label, StorageAreaCard area) {
    if (area.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ...area.items.take(8).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.size,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSourceDiffCard(BuildContext context, SourceDiffCard card) {
    final diff = card.diff;
    final changed = diff?.changed ?? 0;
    final color = diff == null
        ? Theme.of(context).colorScheme.primary
        : changed == 0
            ? Colors.green
            : changed < 30
                ? Colors.orange
                : Colors.red;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68);

    return _card(
      context,
      [
        _cardTitle(context, Icons.difference_outlined, 'Diff Two Sources',
            color: color),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final side in card.sides)
              _chip(
                side.ready ? Icons.check_circle_outline : Icons.hourglass_empty,
                '${side.name}: ${side.status}',
                side.ready ? Colors.green : Colors.orange,
              ),
          ],
        ),
        if (diff == null) ...[
          const SizedBox(height: 10),
          Text(
            'Both the server HTML and the rendered DOM are needed to compare them.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.dns, '${diff.serverLines} server lines', Colors.blue),
              _chip(Icons.web, '${diff.browserLines} DOM lines', Colors.purple),
              _chip(Icons.add, '+${diff.addedLines}', Colors.green),
              _chip(Icons.remove, '-${diff.removedLines}', Colors.red),
              _chip(Icons.percent, '${diff.similarity}% similar', color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            changed == 0
                ? 'Server HTML and rendered DOM look identical.'
                : 'Compact line-level diff between the server HTML (-) and the rendered DOM (+).',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          if (diff.samples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                diff.samples.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ],
      ],
      border: color.withValues(alpha: 0.34),
    );
  }

  Widget _buildRedirectChainView(
      BuildContext context, List<RedirectStep> redirects) {
    final htmlService = context.read<HtmlService>();
    return _card(context, [
      _cardTitle(context, Icons.alt_route, 'Redirect Chain View'),
      const SizedBox(height: 12),
      ...redirects.asMap().entries.map((entry) {
        final step = entry.value;
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
                    Text(step.statusText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 3),
                    SelectableText(step.from,
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 3),
                    if (step.to == null)
                      const Text('no Location header',
                          style: TextStyle(color: Colors.grey, fontSize: 11))
                    else
                      InkWell(
                        onTap: () => htmlService.loadFromUrl(step.to!),
                        child: Text(
                          step.to!,
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
    ]);
  }

  Widget _buildBrowserProbeCard(
      BuildContext context, Observed<BrowserCard> state) {
    if (state is! Present<BrowserCard>) {
      return _card(context, [_notThere(state, 'Waiting for the browser…')],
          filled: true);
    }
    final b = state.value;
    return _card(
      context,
      [
        _detailRow('Effective URL', b.url),
        _detailRow('Environment', b.environment),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        _detailRow('Document Size', b.documentSizeLabel),
        const Divider(),
        _detailRow('Total Resources', b.resourcesLabel),
        _detailRow('Total Size', b.totalSizeLabel),
      ],
      filled: true,
    );
  }

  Widget _buildNetworkInfoCard(
      BuildContext context, Observed<NetworkCard> state) {
    final title = Text(
      'Network & Performance',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
    if (state is! Present<NetworkCard>) {
      return _card(context, [
        title,
        const SizedBox(height: 12),
        _notThere(state, 'Fetching…'),
      ]);
    }
    final n = state.value;
    return _card(context, [
      title,
      const SizedBox(height: 12),
      _detailRow('Remote address', n.remoteAddress),
      _detailRow('Response Time', n.responseTime),
      if (n.serverSoftware != null)
        _detailRow('Server Software', n.serverSoftware!),
      if (n.via != null) _detailRow('Proxy/Via', n.via!),
      for (final (label, value) in n.browserTiming)
        _detailRow(label, '$value (measured by the browser)'),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Headers
// ---------------------------------------------------------------------------

Color _toneColor(InsightTone tone) => switch (tone) {
      InsightTone.good => Colors.green,
      InsightTone.warn => Colors.orange,
      InsightTone.bad => Colors.red,
      InsightTone.neutral => Colors.grey,
      InsightTone.info => Colors.blue,
      InsightTone.brand => Colors.purple,
    };

class ProbeHeadersView extends StatelessWidget {
  const ProbeHeadersView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    final state = context
        .select<HtmlService, Observed<HeadersModel>>((s) => s.headersView);
    return _tabBody(state, (m) => _content(context, m));
  }

  Widget _content(BuildContext context, HeadersModel m) {
    return Scrollbar(
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          if (!m.known) ...[
            _card(context, [
              if (m.loading)
                _notThere<Object>(const Pending(), m.stateNote ?? 'Fetching…')
              else
                _notThere<Object>(Failed(m.stateNote ?? 'No response'), ''),
            ]),
            const SizedBox(height: 16),
          ],
          _buildHeaderIntelligence(context, m),
          if (m.groups.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildHeaderCategorySection(context, m.groups),
          ],
          if (m.hops.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'All Response Headers',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final hop in m.hops.reversed) ...[
              _buildHopHeaders(context, hop, isFinal: hop == m.hops.last),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHopHeaders(BuildContext context, HopHeaders hop,
      {required bool isFinal}) {
    final rows = Column(
      children: hop.lines.asMap().entries.map((entry) {
        final line = entry.value;
        final value = line.values.join('\n');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.key > 0) const Divider(height: 1),
            ListTile(
              title: Text(
                line.name,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              dense: true,
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text:
                        line.values.map((v) => '${line.name}: $v').join('\n')));
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
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: isFinal
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(hop.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                if (hop.lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text('The server sent no headers.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  rows,
              ],
            )
          : ExpansionTile(
              title: Text(hop.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              subtitle: Text(hop.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11)),
              children: [rows],
            ),
    );
  }

  Widget _buildHeaderIntelligence(BuildContext context, HeadersModel m) {
    return _card(
      context,
      [
        _cardTitle(context, Icons.rule_folder_outlined, 'Header Intelligence'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: m.insights.map((insight) {
            final evidence = [
              for (final (name, value) in insight.evidence)
                DetectionEvidence(EvidenceKind.header, 'Response header $name',
                    detail: '$name: $value'),
            ];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showEvidenceSheet(context, insight.label, evidence,
                  description: insight.detail),
              child: _buildHeaderInsightChip(insight),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ...m.notes.map(
          (note) => Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(note.icon, size: 15, color: _toneColor(note.tone)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(note.text, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ],
      filled: true,
    );
  }

  Widget _buildHeaderCategorySection(
      BuildContext context, List<HeaderGroup> groups) {
    return _card(context, [
      Text(
        'Header Groups',
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      ...groups.map((group) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: group.headers.map((h) {
                    return Tooltip(
                      message: h.$2,
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(h.$1),
                        avatar: const Icon(Icons.label_outline, size: 15),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          )),
    ]);
  }

  Widget _buildHeaderInsightChip(HeaderInsight insight) {
    final color = _toneColor(insight.tone);
    return Tooltip(
      message: insight.detail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(insight.icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              insight.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Security
// ---------------------------------------------------------------------------

Color _certColor(CertTone tone) => switch (tone) {
      CertTone.good => Colors.green,
      CertTone.warn => Colors.orange,
      CertTone.bad => Colors.red,
      CertTone.neutral => Colors.grey,
    };

class ProbeSecurityView extends StatelessWidget {
  const ProbeSecurityView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    final state = context
        .select<HtmlService, Observed<SecurityModel>>((s) => s.securityView);
    return _tabBody(state, (m) => _content(context, m));
  }

  Widget _content(BuildContext context, SecurityModel m) {
    final audit = m.audit;
    return Scrollbar(
        child: ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
      children: [
        _buildSecurityScorecard(context, audit),
        const SizedBox(height: 16),
        _buildCspSimulator(context, m.csp),
        const SizedBox(height: 16),
        Text(
          'Security Header Audit',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (m.tlsWarning != null) ...[
          _buildTlsWarningCard(context, m.tlsWarning!),
          const SizedBox(height: 12),
        ],
        if (audit is Present<SecurityAudit>)
          ...audit.value.rows.map((row) {
            final isPresent = row.value != null;
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
                title: Text(row.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  isPresent
                      ? FormatUtils.formatHumanData(row.value!)
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
          })
        else
          _notThere(audit, 'Fetching the response headers…'),
        const SizedBox(height: 24),
        Text(
          'SSL Certificate',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCertificateCard(context, m.certificate),
      ],
    ));
  }

  Widget _buildSecurityScorecard(
      BuildContext context, Observed<SecurityAudit> state) {
    if (state is! Present<SecurityAudit> || state.value.percentage == null) {
      return _card(
          context,
          [
            _cardTitle(context, Icons.security, 'Security Headers Score'),
            const SizedBox(height: 12),
            _notThere(state, 'Fetching the response headers…'),
          ],
          filled: true);
    }
    final audit = state.value;
    final percentage = audit.percentage!;
    final score = percentage / 100;
    final Color scoreColor;
    if (percentage >= 80) {
      scoreColor = Colors.green;
    } else if (percentage >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return _card(
      context,
      [
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    '${audit.passed} of ${audit.total} controls present',
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
          children: audit.checks.map((check) {
            final color = !check.applicable
                ? Colors.grey
                : check.passing
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
                      !check.applicable
                          ? Icons.remove_circle_outline
                          : check.passing
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
      filled: true,
      border: scoreColor.withValues(alpha: 0.45),
    );
  }

  Widget _buildCspSimulator(BuildContext context, Observed<CspModel> state) {
    if (state is! Present<CspModel>) {
      return _card(context, [
        _cardTitle(context, Icons.policy_outlined, 'CSP Simulator'),
        const SizedBox(height: 12),
        _notThere(state, 'Fetching the response headers…'),
      ]);
    }
    final csp = state.value;
    final score = csp.score;
    final color = score == null
        ? Colors.grey
        : score >= 80
            ? Colors.green
            : score >= 50
                ? Colors.orange
                : Colors.red;

    return _card(
      context,
      [
        Row(
          children: [
            Icon(Icons.policy_outlined, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CSP Simulator',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (score != null)
              Text('$score',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        if (csp.policies.isEmpty)
          const Text(
            'No Content-Security-Policy header found.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          )
        else
          for (final (i, policy) in csp.policies.indexed) ...[
            if (csp.policies.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Text('Policy ${i + 1} (score ${policy.score})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: policy.directives
                  .map((d) => _chip(Icons.rule, '${d.$1} ${d.$2}', Colors.blue))
                  .toList(),
            ),
            const SizedBox(height: 12),
            ...policy.findings.map((finding) {
              final findingColor = switch (finding.severity) {
                CspSeverity.low => Colors.green,
                CspSeverity.medium => Colors.orange,
                CspSeverity.high => Colors.red,
              };
              final icon = switch (finding.severity) {
                CspSeverity.low => Icons.check_circle_outline,
                CspSeverity.medium => Icons.warning_amber_rounded,
                CspSeverity.high => Icons.dangerous_outlined,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: findingColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(finding.text,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          ],
      ],
      border: color.withValues(alpha: 0.34),
    );
  }

  Widget _buildTlsWarningCard(BuildContext context, String warning) {
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
      BuildContext context, Observed<CertificateModel> state) {
    if (state is! Present<CertificateModel>) {
      return _card(context, [
        Row(
          children: [
            const Icon(Icons.no_encryption_gmailerrorred, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: _notThere(state, 'Fetching the certificate…')),
          ],
        ),
      ]);
    }
    final cert = state.value;
    final validityColor = _certColor(cert.validityTone);
    final hostColor = cert.hostMatches ? Colors.green : Colors.orange;

    return _card(context, [
      Row(
        children: [
          Expanded(
            child: _buildCertSignal(
                context,
                validityColor,
                cert.validityExpired
                    ? Icons.dangerous_outlined
                    : cert.validityTone == CertTone.neutral
                        ? Icons.help_outline
                        : cert.validityTone == CertTone.good
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                cert.validityLabel),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCertSignal(
              context,
              hostColor,
              cert.hostMatches
                  ? Icons.verified_user_outlined
                  : Icons.help_outline,
              cert.hostLabel,
            ),
          ),
        ],
      ),
      const Divider(height: 24),
      _certSectionTitle(context, 'Subject (Owner)'),
      const SizedBox(height: 8),
      _buildParsedInfo(context, cert.subject, cert.subjectRaw),
      const Divider(height: 24),
      _certSectionTitle(context, 'Issuer'),
      const SizedBox(height: 8),
      _buildParsedInfo(context, cert.issuer, cert.issuerRaw),
      const Divider(height: 24),
      Row(
        children: [
          Expanded(
              child: _buildCertDetail(context, 'Valid From', cert.validFrom)),
          Expanded(
              child: _buildCertDetail(context, 'Valid Until', cert.validUntil)),
        ],
      ),
      if (cert.derHint != null) ...[
        const Divider(height: 24),
        _buildCertDetail(context, 'DER Fingerprint Hint', cert.derHint!),
      ],
      if (cert.pem != null) ...[
        const Divider(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy PEM Certificate'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: cert.pem!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Certificate copied')),
              );
            },
          ),
        ),
      ],
    ]);
  }

  Widget _certSectionTitle(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      );

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

  Widget _buildParsedInfo(
      BuildContext context, Map<String, String> parsed, String raw) {
    if (parsed.isEmpty) {
      return SelectableText(
        raw,
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
                  e.value,
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
        _certSectionTitle(context, label),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cookies
// ---------------------------------------------------------------------------

class ProbeCookiesView extends StatelessWidget {
  const ProbeCookiesView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    final state = context
        .select<HtmlService, Observed<CookiesModel>>((s) => s.cookiesView);
    return _tabBody(state, (m) => _content(context, m));
  }

  Widget _content(BuildContext context, CookiesModel m) {
    return Scrollbar(
        child: ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
      children: [
        _buildCookiePrivacyLens(context, m),
        const SizedBox(height: 12),
        if (m.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(Icons.cookie_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(m.complete
                    ? 'No cookies detected.'
                    : 'No cookies seen in the sources read so far.'),
              ],
            ),
          ),
        ...m.rows.map((cookie) => _buildCookieCard(context, cookie)),
      ],
    ));
  }

  Widget _buildCookieCard(BuildContext context, CookieRow cookie) {
    final badgeColor = switch (cookie.category) {
      'essential' => Colors.green,
      'analytics' => Colors.blue,
      'advertising' => Colors.orange,
      'social' => Colors.purple,
      _ => Colors.grey,
    };
    final provider = cookie.provider;
    final muted = TextStyle(fontSize: 11, color: Colors.grey[600]);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                cookie.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace'),
              ),
            ),
            if (provider != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (logoDomainFor(provider) != null) ...[
                      ServiceLogo(
                          label: provider,
                          fallback: Icons.cookie_outlined,
                          size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      provider,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
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
              cookie.value,
              style: const TextStyle(
                  fontSize: 12, fontFamily: 'monospace', color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(cookie.flagsLine, style: muted),
            const SizedBox(height: 2),
            Text(cookie.scopeLine, style: muted),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.category, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(cookie.category.toUpperCase(), style: muted),
                const SizedBox(width: 12),
                Icon(
                    cookie.source == 'Browser'
                        ? Icons.web
                        : cookie.source == 'Server'
                            ? Icons.dns
                            : Icons.merge_type,
                    size: 12,
                    color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(cookie.source, style: muted),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(
                ClipboardData(text: '${cookie.name}=${cookie.value}'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Cookie copied'),
                  duration: Duration(milliseconds: 500)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCookiePrivacyLens(BuildContext context, CookiesModel m) {
    final score = m.score;
    final color = score == null
        ? Colors.grey
        : score >= 75
            ? Colors.green
            : score >= 45
                ? Colors.orange
                : Colors.red;

    return _card(
      context,
      [
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
                child: score == null
                    ? Icon(Icons.help_outline, color: color)
                    : Text(
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
                    m.verdict,
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
            for (final chip in m.chips)
              _chip(chip.icon, chip.label, _toneColor(chip.tone)),
          ],
        ),
        if (m.notes.isNotEmpty) const SizedBox(height: 12),
        ...m.notes.map(
          (note) => Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(note.icon, size: 15, color: _toneColor(note.tone)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(note.text, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        if (m.sourcesNote != null) ...[
          const SizedBox(height: 10),
          Text(m.sourcesNote!,
              style: const TextStyle(color: Colors.orange, fontSize: 12)),
        ],
      ],
      filled: true,
    );
  }
}
