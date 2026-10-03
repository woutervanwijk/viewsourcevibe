import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
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
    if (service.sovereigntyReport != null && _analyzedFor == url) return;
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
          _summaryCard(context, report),
          for (final note in report.notes) _noteCard(context, note),
          _title(context, 'Infrastructure'),
          _infraCard(context, report),
          _title(context, 'Hosts (${report.hosts.length})'),
          for (final host in report.hosts) _hostTile(context, host),
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
          const Text(
            'Jurisdiction = where the controlling company is headquartered '
            '(falls back to the IP location). Data: RIPEstat (IP/ASN), LibreDNS (DNS).',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static const _labels = {
    Jurisdiction.eu: 'EU/EEA',
    Jurisdiction.us: 'US',
    Jurisdiction.other: 'Other',
    Jurisdiction.unknown: 'Unknown',
  };

  Color _color(BuildContext context, Jurisdiction j) => switch (j) {
        Jurisdiction.eu => Colors.green,
        Jurisdiction.us => Colors.deepOrange,
        Jurisdiction.other => Colors.blueGrey,
        Jurisdiction.unknown => Theme.of(context).colorScheme.outline,
      };

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

  Widget _noteCard(BuildContext context, String note) => _card(
        context,
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(child: Text(note)),
        ]),
        tint: Colors.orange,
      );

  Widget _summaryCard(BuildContext context, SovereigntyReport report) {
    final withBytes = report.hosts.any((h) => h.bytes > 0);
    final byRequests = report.share((h) => h.requests);
    final byBytes = report.share((h) => h.bytes);
    final us = byRequests[Jurisdiction.us]! * 100;

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            us == 0
                ? 'No requests go to US-controlled companies'
                : '${us.round()}% of requests go to US-controlled companies',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _shareBar(context, 'Requests', byRequests),
          if (withBytes) ...[
            const SizedBox(height: 8),
            _shareBar(context, 'Data', byBytes),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: [
            for (final j in Jurisdiction.values)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 10, color: _color(context, j)),
                const SizedBox(width: 4),
                Text(_labels[j]!, style: const TextStyle(fontSize: 12)),
              ]),
          ]),
        ],
      ),
    );
  }

  Widget _shareBar(
      BuildContext context, String label, Map<Jurisdiction, double> share) {
    return Row(children: [
      SizedBox(
          width: 72, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              for (final j in Jurisdiction.values)
                if (share[j]! > 0)
                  Expanded(
                    flex: (share[j]! * 1000).round().clamp(1, 1000),
                    child: Tooltip(
                      message:
                          '${_labels[j]}: ${(share[j]! * 100).toStringAsFixed(0)}%',
                      child: Container(color: _color(context, j)),
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
        row('Company', main?.provider?.name ?? 'Unknown',
            main?.provider?.country),
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

  Widget _hostTile(BuildContext context, HostInfo host) {
    final j = host.jurisdiction;
    final country = host.provider?.country ?? host.ipCountry;
    final details = [
      if (host.provider != null) host.provider!.name,
      if (host.asnHolder != null) host.asnHolder!,
      if (host.ipCountry != null) 'IP in ${host.ipCountry}',
    ].join(' · ');

    return _card(
      context,
      Row(children: [
        Icon(Icons.circle, size: 12, color: _color(context, j)),
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
      tint: j == Jurisdiction.us ? Colors.deepOrange : null,
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
