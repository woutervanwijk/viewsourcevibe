import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';
import 'package:view_source_vibe/utils/format_utils.dart';

class SovereigntyView extends StatefulWidget {
  const SovereigntyView({super.key});

  @override
  State<SovereigntyView> createState() => _SovereigntyViewState();
}

class _SovereigntyViewState extends State<SovereigntyView> {
  String? _analyzedFor;

  /// Runs the (network-heavy) analysis lazily, once the page's resources are known.
  void _maybeAnalyze(HtmlService service) {
    final url = service.currentFile?.path;
    final ready = !service.isLoading &&
        !service.isWebViewLoading &&
        !service.isExtractingMetadata &&
        service.probeResult != null;
    if (!ready || url == null || service.isAnalyzingSovereignty) return;
    final report = service.sovereigntyReport;
    if (report != null &&
        _analyzedFor == url &&
        report.home == service.siteJurisdiction.jurisdiction) {
      return;
    }
    _analyzedFor = url;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => service.analyzeSovereignty());
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<HtmlService>();
    _maybeAnalyze(service);
    final report = service.sovereigntyReport;

    if (report == null) {
      return Center(
        child: service.isAnalyzingSovereignty ||
                service.isLoading ||
                service.isWebViewLoading
            ? const CircularProgressIndicator()
            : const Text('Load a URL to analyze where it is hosted.',
                style: TextStyle(color: Colors.grey)),
      );
    }

    return Scrollbar(
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          if (service.isAnalyzingSovereignty)
            const LinearProgressIndicator(minHeight: 2),
          _siteJurisdictionCard(context, service, report),
          _scoreCard(context, report),
          for (final pillar in Pillar.values)
            _pillarSection(context, report, pillar),
          _title(context, 'Where requests go'),
          _summaryCard(context, report),
          _title(context, 'Infrastructure'),
          _infraCard(context, report),
          _title(context, 'Hosts (${report.hosts.length})'),
          for (final host in report.hosts) _hostTile(context, report, host),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: service.isAnalyzingSovereignty
                  ? null
                  : service.analyzeSovereignty,
              icon: const Icon(Icons.refresh),
              label: const Text('Re-run analysis'),
            ),
          ),
          Text(
            'Judged against the jurisdiction of the organisation behind the site '
            '(${jurisdictionLabel(report.home)}). A company falls under the law of its headquarters; '
            'unlisted companies by the country where their network is '
            'registered. Server location only counts for residency. '
            'Adequate = EU adequacy decision. Checks that cannot be verified '
            '(e.g. hosting behind a CDN) are left out of the score. The score '
            'is an indication, not comparable 1:1 with other audits. '
            'Data: RIPEstat (IP/ASN), LibreDNS (DNS).',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Widget child, {Color? tint}) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: tint?.withValues(alpha: 0.1) ??
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: tint ?? Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _title(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _siteJurisdictionCard(
      BuildContext context, HtmlService service, SovereigntyReport report) {
    final site = service.siteJurisdiction;
    final manual = site.source == 'Set manually';
    final choices = {...homeJurisdictionChoices, site.jurisdiction};
    return _card(
      context,
      Row(children: [
        const Icon(Icons.gavel_outlined, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Legal home of ${service.sovereigntyDomain}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(site.source,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        DropdownButton<String>(
          value: site.jurisdiction,
          onChanged: service.isAnalyzingSovereignty
              ? null
              : (value) => service.setSiteJurisdiction(value),
          items: [
            for (final j in choices)
              DropdownMenuItem(value: j, child: Text(jurisdictionLabel(j))),
          ],
        ),
        if (manual)
          IconButton(
            tooltip: 'Back to detected / default',
            icon: const Icon(Icons.restart_alt),
            onPressed: service.isAnalyzingSovereignty
                ? null
                : () => service.setSiteJurisdiction(null),
          ),
      ]),
    );
  }

  Widget _scoreCard(BuildContext context, SovereigntyReport report) {
    final score = report.score;
    final color = score >= 80
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : Colors.red;
    final counters = {
      CheckStatus.pass: 'passed',
      CheckStatus.warn: 'warnings',
      CheckStatus.fail: 'failed',
      CheckStatus.unknown: 'not verifiable',
    };

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const Text(' / 100  '),
              Text(report.grade, style: TextStyle(color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 12, children: [
            for (final e in counters.entries)
              Row(mainAxisSize: MainAxisSize.min, children: [
                _statusIcon(e.key, size: 14),
                const SizedBox(width: 4),
                Text('${report.count(e.key)} ${e.value}',
                    style: const TextStyle(fontSize: 12)),
              ]),
          ]),
          const SizedBox(height: 12),
          for (final pillar in Pillar.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 160,
                  child: Text(pillarLabels[pillar]!,
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (report.pillarScore(pillar) ?? 0) /
                          pillarMax[pillar]!,
                      minHeight: 8,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(_pillarScoreLabel(report, pillar),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12)),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  String _pillarScoreLabel(SovereigntyReport report, Pillar pillar) {
    final score = report.pillarScore(pillar);
    return score == null ? 'n/a' : '${score.round()}/${pillarMax[pillar]}';
  }

  Widget _statusIcon(CheckStatus status, {double size = 18}) =>
      switch (status) {
        CheckStatus.pass =>
          Icon(Icons.check_circle, color: Colors.green, size: size),
        CheckStatus.warn =>
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: size),
        CheckStatus.fail => Icon(Icons.cancel, color: Colors.red, size: size),
        CheckStatus.unknown =>
          Icon(Icons.help_outline, color: Colors.grey, size: size),
      };

  Widget _pillarSection(
      BuildContext context, SovereigntyReport report, Pillar pillar) {
    final checks = report.checks.where((c) => c.pillar == pillar).toList();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(pillarLabels[pillar]!),
        trailing: Text(_pillarScoreLabel(report, pillar)),
        initiallyExpanded: checks.any((c) => c.status == CheckStatus.fail),
        children: [
          for (final check in checks)
            ListTile(
              dense: true,
              leading: _statusIcon(check.status),
              title: Text(check.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(check.evidence,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (check.alternatives.isNotEmpty &&
                      check.status != CheckStatus.pass)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                            'Alternatives in ${jurisdictionLabel(report.home)}:',
                            style: const TextStyle(fontSize: 12)),
                        for (final name in check.alternatives)
                          _alternativeLink(context, name),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _alternativeLink(BuildContext context, String name) {
    final url = alternativeUrls[name];
    if (url == null) return Text(name, style: const TextStyle(fontSize: 12));
    return InkWell(
      onTap: () async {
        final opened = await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $url')),
          );
        }
      },
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, SovereigntyReport report) {
    final relations = report.relationShare();
    final outside = ((relations[Relation.adequate] ?? 0) +
            (relations[Relation.foreign] ?? 0)) *
        100;
    final home = jurisdictionLabel(report.home);

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outside == 0
                ? 'All requests stay with companies in the site\'s jurisdiction ($home)'
                : '${outside.round()}% of requests go to companies outside the site\'s jurisdiction ($home)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _shareBar(
            context,
            'Jurisdiction',
            {
              for (final r in Relation.values)
                if ((relations[r] ?? 0) > 0)
                  _relationLabels[r]!: (
                    relations[r]!,
                    _relationColor(context, r)
                  ),
            },
          ),
          const SizedBox(height: 8),
          _shareBar(context, 'Server location',
              _regionSegments(context, report.regionShare(byControl: false))),
          const SizedBox(height: 8),
          _shareBar(context, 'Company HQ',
              _regionSegments(context, report.regionShare(byControl: true))),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (final r in Relation.values)
              _legend(context, _relationLabels[r]!, _relationColor(context, r)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (final region in regionOrder)
              if (report.hosts.any((h) =>
                  regionOf(h.ipCountry) == region ||
                  regionOf(h.controlCountry) == region))
                _legend(context, region, _regionColor(context, region)),
          ]),
        ],
      ),
    );
  }

  static const _relationLabels = {
    Relation.own: 'Site\'s jurisdiction',
    Relation.adequate: 'Adequate protection',
    Relation.foreign: 'Other jurisdiction',
    Relation.unknown: 'Unknown',
  };

  Color _relationColor(BuildContext context, Relation r) => switch (r) {
        Relation.own => Colors.green,
        Relation.adequate => Colors.teal.shade200,
        Relation.foreign => Colors.amber.shade700,
        Relation.unknown => Theme.of(context).colorScheme.outlineVariant,
      };

  static const _regionPalette = [
    Color(0xFF3B82F6), // EU/EEA
    Color(0xFF8B5CF6), // Europe (other)
    Color(0xFFF59E0B), // North America
    Color(0xFF10B981), // Latin America
    Color(0xFFEF4444), // Asia
    Color(0xFFEC4899), // Middle East
    Color(0xFF06B6D4), // Oceania
    Color(0xFF84CC16), // Africa
    Color(0xFF64748B), // Other
  ];

  Color _regionColor(BuildContext context, String region) {
    final i = regionOrder.indexOf(region);
    return i >= 0 && i < _regionPalette.length
        ? _regionPalette[i]
        : Theme.of(context).colorScheme.outlineVariant;
  }

  Map<String, (double, Color)> _regionSegments(
          BuildContext context, Map<String, double> share) =>
      {
        for (final region in regionOrder)
          if ((share[region] ?? 0) > 0)
            region: (share[region]!, _regionColor(context, region)),
      };

  Widget _legend(BuildContext context, String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);

  Widget _shareBar(BuildContext context, String label,
      Map<String, (double, Color)> segments) {
    return Row(children: [
      SizedBox(
          width: 100, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              for (final e in segments.entries)
                Expanded(
                  flex: (e.value.$1 * 1000).round().clamp(1, 1000),
                  child: Tooltip(
                    message:
                        '${e.key}: ${(e.value.$1 * 100).toStringAsFixed(0)}%',
                    child: Container(color: e.value.$2),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _infraCard(BuildContext context, SovereigntyReport report) {
    final main = report.hosts.isEmpty ? null : report.hosts.first;
    Widget row(String label, String value, [String? country]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(child: SelectableText(value)),
            if (country != null) _flag(country),
          ]),
        );

    String providers(List<DnsDependency> deps) {
      if (deps.isEmpty) return 'Unknown';
      final names = deps.map((d) => d.provider?.name ?? _shortDomain(d.record));
      return names.toSet().join(', ');
    }

    String? hq(List<DnsDependency> deps) =>
        deps.map((d) => d.provider?.country).whereType<String>().firstOrNull;

    return _card(
      context,
      Column(children: [
        row('Website', report.mainHost),
        if (main?.ip != null)
          row(
            'Hosted at',
            '${main!.ip}  ·  ${main.asn != null ? 'AS${main.asn} ' : ''}${main.asnHolder ?? ''}',
            main.ipCountry,
          ),
        if (report.cdn != null)
          row('Hosting', 'Hidden behind ${report.cdn!.name}')
        else
          row('Company', main?.provider?.name ?? main?.asnHolder ?? 'Unknown',
              main?.controlCountry),
        row('CDN / proxy', report.cdn?.name ?? 'None detected',
            report.cdn?.country),
        row('DNS', providers(report.nameServers), hq(report.nameServers)),
        row('Email (MX)', providers(report.mailServers),
            hq(report.mailServers)),
        row('TLS issuer', report.tlsIssuer ?? 'Unknown',
            report.tlsProvider?.country),
      ]),
    );
  }

  String _shortDomain(String host) {
    final domain = SovereigntyService.registrableDomain(host);
    return domain.isEmpty ? host : domain;
  }

  Widget _hostTile(
      BuildContext context, SovereigntyReport report, HostInfo host) {
    final relation = host.relation(report.home);
    final country = host.controlCountry;
    final details = [
      if (host.provider != null)
        '${host.provider!.name} (HQ ${host.provider!.country})',
      if (host.asnHolder != null)
        '${host.asnHolder!}'
            '${host.provider == null && host.asnCountry != null ? ' (registered in ${host.asnCountry})' : ''}',
      if (host.ipCountry != null)
        'server in ${host.ipCountry}, ${regionOf(host.ipCountry)}',
    ].join(' · ');

    return _card(
      context,
      Row(children: [
        Tooltip(
          message: _relationLabels[relation]!,
          child: Icon(Icons.circle,
              size: 12, color: _relationColor(context, relation)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(host.host,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (details.isNotEmpty)
              Text(details,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(
              '${host.requests} request${host.requests == 1 ? '' : 's'}'
              '${host.bytes > 0 ? ' · ${FormatUtils.formatBytes(host.bytes)}' : ''}'
              ' · ${(host.roles.toList()..sort()).join(', ')}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
        ),
        if (country != null) _flag(country),
      ]),
    );
  }

  Widget _flag(String country) {
    final code = country.toUpperCase();
    final flag = code.length == 2
        ? String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 0x41))
        : '';
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text('$flag $code', style: const TextStyle(fontSize: 13)),
    );
  }
}
