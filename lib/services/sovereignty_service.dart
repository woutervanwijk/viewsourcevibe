import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';
import 'package:view_source_vibe/services/derive/page_weight.dart';
import 'package:view_source_vibe/services/detection/engine.dart';

class HostingProvider {
  final String name;
  final String country; // HQ / controlling jurisdiction
  final RegExp pattern; // matched against host, ASN holder, NS or MX name

  /// CDN / reverse proxy: its IP addresses hide the real (origin) host.
  final bool edge;
  const HostingProvider(this.name, this.country, this.pattern,
      {this.edge = false});
}

final List<HostingProvider> providers = [
  HostingProvider(
    'Cloudflare',
    'US',
    RegExp(r'cloudflare|cdnjs|jsdelivr|unpkg|cf-ns\.', caseSensitive: false),
    edge: true,
  ),
  HostingProvider(
    'Amazon (AWS)',
    'US',
    RegExp(r'amazon|aws|cloudfront|awsdns|route53', caseSensitive: false),
  ),
  HostingProvider(
    'Google',
    'US',
    RegExp(
      r'google|gstatic|googleapis|googlehosted|googledomains|gcp|youtube|ytimg|doubleclick',
      caseSensitive: false,
    ),
  ),
  HostingProvider(
    'Microsoft',
    'US',
    RegExp(
      r'microsoft|azure|msecnd|msft|outlook\.com|office365|bing\.',
      caseSensitive: false,
    ),
  ),
  HostingProvider(
    'Meta',
    'US',
    RegExp(r'facebook|fbcdn|instagram|meta platforms', caseSensitive: false),
  ),
  HostingProvider(
    'Fastly',
    'US',
    RegExp(r'fastly|fastlylb', caseSensitive: false),
    edge: true,
  ),
  HostingProvider(
    'Akamai',
    'US',
    RegExp(r'akamai|edgekey|edgesuite', caseSensitive: false),
    edge: true,
  ),
  HostingProvider(
    'Imperva',
    'US',
    RegExp(r'imperva|incapsula', caseSensitive: false),
    edge: true,
  ),
  HostingProvider('Vercel', 'US', RegExp(r'vercel', caseSensitive: false)),
  HostingProvider('Netlify', 'US', RegExp(r'netlify', caseSensitive: false)),
  HostingProvider('GitHub', 'US', RegExp(r'github', caseSensitive: false)),
  HostingProvider(
    'DigitalOcean',
    'US',
    RegExp(r'digitalocean', caseSensitive: false),
  ),
  HostingProvider(
    'GoDaddy',
    'US',
    RegExp(r'godaddy|domaincontrol', caseSensitive: false),
  ),
  HostingProvider(
    'Oracle',
    'US',
    RegExp(r'oracle|dyn\.com', caseSensitive: false),
  ),
  HostingProvider('Hetzner', 'DE', RegExp(r'hetzner', caseSensitive: false)),
  HostingProvider(
    'IONOS',
    'DE',
    RegExp(r'ionos|1und1|1&1|kundenserver', caseSensitive: false),
  ),
  HostingProvider('OVHcloud', 'FR', RegExp(r'ovh', caseSensitive: false)),
  HostingProvider(
    'Scaleway',
    'FR',
    RegExp(r'scaleway|online\.net', caseSensitive: false),
  ),
  HostingProvider('TransIP', 'NL', RegExp(r'transip', caseSensitive: false)),
  HostingProvider('Leaseweb', 'NL', RegExp(r'leaseweb', caseSensitive: false)),
  HostingProvider('Gcore', 'LU', RegExp(r'gcore', caseSensitive: false),
      edge: true),
  HostingProvider('Bunny.net', 'SI', RegExp(r'bunny', caseSensitive: false),
      edge: true),
  HostingProvider('Proton', 'CH', RegExp(r'proton', caseSensitive: false)),
  HostingProvider(
    'Infomaniak',
    'CH',
    RegExp(r'infomaniak', caseSensitive: false),
  ),
  HostingProvider(
    'Let\'s Encrypt',
    'US',
    RegExp(r"let's encrypt|isrg", caseSensitive: false),
  ),
  HostingProvider(
    'DigiCert',
    'US',
    RegExp(r'digicert|identrust', caseSensitive: false),
  ),
  HostingProvider(
    'Sectigo',
    'GB',
    RegExp(r'sectigo|comodo', caseSensitive: false),
  ),
  HostingProvider(
    'GlobalSign',
    'BE',
    RegExp(r'globalsign', caseSensitive: false),
  ),
  HostingProvider('Harica', 'GR', RegExp(r'harica', caseSensitive: false)),
  HostingProvider('Yandex', 'RU', RegExp(r'yandex', caseSensitive: false)),
  HostingProvider(
    'Alibaba Cloud',
    'CN',
    RegExp(r'alibaba|aliyun|alicdn', caseSensitive: false),
  ),
  HostingProvider(
    'Tencent',
    'CN',
    RegExp(r'tencent|qcloud|myqcloud', caseSensitive: false),
  ),
];

HostingProvider? matchProvider(Iterable<String?> candidates) {
  for (final text in candidates) {
    if (text == null || text.isEmpty) continue;
    for (final p in providers) {
      if (p.pattern.hasMatch(text)) return p;
    }
  }
  return null;
}

/// CDN / proxy detected from response headers.
HostingProvider? detectCdnFromHeaders(Map<String, String> headers) {
  final h = headers.map((k, v) => MapEntry(k.toLowerCase(), v.toLowerCase()));
  HostingProvider byName(String n) => providers.firstWhere((p) => p.name == n);
  if (h.containsKey('cf-ray') || (h['server'] ?? '').contains('cloudflare')) {
    return byName('Cloudflare');
  }
  if (h.containsKey('x-amz-cf-id') ||
      h.containsKey('x-amz-request-id') ||
      (h['via'] ?? '').contains('cloudfront') ||
      (h['server'] ?? '').contains('amazons3')) {
    return byName('Amazon (AWS)');
  }
  if (h.containsKey('x-azure-ref') || h.containsKey('x-msedge-ref')) {
    return byName('Microsoft');
  }
  if (h.containsKey('x-vercel-id')) return byName('Vercel');
  if (h.containsKey('x-nf-request-id')) return byName('Netlify');
  if (h.containsKey('x-served-by') && h.containsKey('x-cache') ||
      (h['via'] ?? '').contains('varnish') &&
          h.containsKey('x-fastly-request-id')) {
    return byName('Fastly');
  }
  if (h.keys.any((k) => k.startsWith('x-akamai')) ||
      (h['server'] ?? '').contains('akamai')) {
    return byName('Akamai');
  }
  if ((h['server'] ?? '').contains('gws') ||
      h.containsKey('x-goog-generation')) {
    return byName('Google');
  }
  return null;
}

enum CheckStatus { pass, warn, fail, unknown }

enum Pillar { infrastructure, residency, security, privacy }

const pillarLabels = {
  Pillar.infrastructure: 'Infrastructure',
  Pillar.residency: 'Data residency',
  Pillar.security: 'Security posture',
  Pillar.privacy: 'Privacy',
};

/// Maximum points per pillar; together 100.
const pillarMax = {
  Pillar.infrastructure: 40,
  Pillar.residency: 25,
  Pillar.security: 20,
  Pillar.privacy: 15,
};

class SovereigntyCheck {
  final Pillar pillar;
  final String title;
  final CheckStatus status;
  final String evidence;

  /// Relative weight within its pillar: 3 essential (hosting, mail, CDN),
  /// 2 important, 1 limited, 0.5 minor (fonts, CAA).
  final double weight;
  final List<String> alternatives; // shown when not passing

  const SovereigntyCheck(
    this.pillar,
    this.title,
    this.status,
    this.evidence, {
    this.weight = 1,
    this.alternatives = const [],
  });

  Map<String, dynamic> toJson() => {
        'pillar': pillar.name,
        'title': title,
        'status': status.name,
        'weight': weight,
        'evidence': evidence,
        if (alternatives.isNotEmpty) 'alternatives': alternatives,
      };
}

const euAlternatives = {
  'hosting': ['Hetzner', 'OVHcloud', 'Scaleway', 'IONOS'],
  'cdn': ['Bunny.net', 'Gcore', 'OVHcloud CDN'],
  'dns': ['deSEC', 'Hetzner DNS', 'TransIP'],
  'email': ['Proton Mail', 'Tuta', 'Infomaniak', 'mailbox.org'],
  'tls': ['HARICA', 'Certum', 'Actalis'],
  'cms': ['TYPO3', 'Drupal', 'WordPress (self-hosted)'],
  'services': ['Matomo (self-hosted)', 'Plausible', 'Simple Analytics'],
  'fonts': ['Self-host the font files'],
};

const alternativeUrls = {
  'Hetzner': 'https://www.hetzner.com',
  'OVHcloud': 'https://www.ovhcloud.com',
  'Scaleway': 'https://www.scaleway.com',
  'IONOS': 'https://www.ionos.com',
  'Bunny.net': 'https://bunny.net',
  'Gcore': 'https://gcore.com',
  'OVHcloud CDN': 'https://www.ovhcloud.com',
  'deSEC': 'https://desec.io',
  'Hetzner DNS': 'https://www.hetzner.com',
  'TransIP': 'https://www.transip.nl',
  'Proton Mail': 'https://proton.me/mail',
  'Tuta': 'https://tuta.com',
  'Infomaniak': 'https://www.infomaniak.com',
  'mailbox.org': 'https://mailbox.org',
  'HARICA': 'https://www.harica.gr',
  'Certum': 'https://www.certum.eu',
  'Actalis': 'https://www.actalis.com',
  'TYPO3': 'https://typo3.org',
  'Drupal': 'https://www.drupal.org',
  'WordPress (self-hosted)': 'https://wordpress.org',
  'Matomo (self-hosted)': 'https://matomo.org',
  'Plausible': 'https://plausible.io',
  'Simple Analytics': 'https://www.simpleanalytics.com',
  'Self-host the font files': 'https://gwfh.mranftl.com/fonts',
};

/// Classifies an SPF policy from the domain's TXT records.
(CheckStatus, String) classifySpf(List<String> txt) {
  final spf = txt.where((t) => t.toLowerCase().startsWith('v=spf1'));
  if (spf.isEmpty) return (CheckStatus.fail, 'No SPF record');
  final record = spf.first;
  final lower = record.toLowerCase();
  if (lower.contains('-all')) return (CheckStatus.pass, record);
  if (lower.contains('~all') || lower.contains('redirect=')) {
    return (CheckStatus.warn, record);
  }
  return (CheckStatus.fail, record);
}

/// Classifies a DMARC policy from the `_dmarc.` TXT records.
(CheckStatus, String) classifyDmarc(List<String> txt) {
  final dmarc = txt.where((t) => t.toLowerCase().startsWith('v=dmarc1'));
  if (dmarc.isEmpty) return (CheckStatus.fail, 'No DMARC record');
  final record = dmarc.first;
  final policy = RegExp(r'p=(\w+)', caseSensitive: false)
      .firstMatch(record)
      ?.group(1)
      ?.toLowerCase();
  return switch (policy) {
    'reject' || 'quarantine' => (CheckStatus.pass, record),
    'none' => (CheckStatus.warn, record),
    _ => (CheckStatus.fail, record),
  };
}

/// First link to a privacy or cookie statement in [html], or null.
String? findPrivacyLink(String html) {
  final link = RegExp(
    r'<a\b[^>]*href\s*=\s*["\x27]([^"\x27]*)["\x27][^>]*>([\s\S]*?)</a>',
    caseSensitive: false,
  );
  final topic = RegExp(
    r'privacy|privacyverklaring|privacybeleid|datenschutz|confidentialit|privacidad|cookie',
    caseSensitive: false,
  );
  for (final m in link.allMatches(html)) {
    final href = m.group(1)!;
    if (topic.hasMatch(href) || topic.hasMatch(m.group(2)!)) return href;
  }
  return null;
}

CheckStatus statusFor(String? country, String home) =>
    switch (relationTo(country, home)) {
      Relation.own => CheckStatus.pass,
      Relation.adequate => CheckStatus.warn,
      Relation.foreign => CheckStatus.fail,
      Relation.unknown => CheckStatus.unknown,
    };

/// Legal context for a country outside [home], appended to evidence.
String jurisdictionNote(String? country, String home) {
  final notes = <String>[
    if (relationTo(country, home) == Relation.adequate && home == eu)
      'adequate data protection (EU decision)',
    if (relationTo(country, home) != Relation.own &&
        extraterritorialLaws[country] != null)
      'subject to the ${extraterritorialLaws[country]}',
    if (home == eu && country == 'US')
      'EU–US Data Privacy Framework may apply to certified companies '
          '(not verifiable)',
  ];
  return notes.isEmpty ? '' : ' · ${notes.join(' · ')}';
}

/// Alternatives are only curated for the EU for now.
List<String> alternativesFor(String key, String home) =>
    home == eu ? euAlternatives[key]! : const [];

class HostInfo {
  final String host;
  final Set<String> roles = {};
  int requests = 0;

  /// Transfer bytes of the requests whose size is known; null when none is
  /// (never 0 for "unknown").
  int? bytes;

  /// True when some of the requests have no known size, so [bytes] is a
  /// lower bound.
  bool bytesPartial = false;
  String? ip;
  int? asn;
  String? asnHolder;
  String? ipCountry; // where the server is (geolocation)
  String? asnCountry; // where the network operator is registered
  HostingProvider? provider; // known company, with its parent's HQ

  HostInfo(this.host);

  /// Whose law applies: the known company's HQ, else the country where the
  /// network operator is registered. Never the server location.
  String? get controlCountry => provider?.country ?? asnCountry;

  Relation relation(String home) => relationTo(controlCountry, home);

  /// Located in [home], but run by a company from a foreign jurisdiction.
  bool foreignControlled(String home) =>
      provider != null &&
      relationTo(ipCountry, home) == Relation.own &&
      relationTo(provider!.country, home) == Relation.foreign;

  Map<String, dynamic> toJson() => {
        'host': host,
        'roles': roles.toList(),
        'requests': requests,
        'bytes': bytes,
        'bytesPartial': bytesPartial,
        'ip': ip,
        'asn': asn,
        'asnHolder': asnHolder,
        'ipCountry': ipCountry,
        'asnCountry': asnCountry,
        'region': regionOf(ipCountry),
        'provider': provider?.name,
        'providerCountry': provider?.country,
        'controlCountry': controlCountry,
      };
}

class DnsDependency {
  final String record; // ns-1582.awsdns-05.co.uk
  final HostingProvider? provider;
  final HostInfo? server; // IP/ASN lookup, done when the name is unknown
  const DnsDependency(this.record, this.provider, [this.server]);
}

class SovereigntyReport {
  final String home; // jurisdiction the report is judged against
  final String mainHost;
  final List<HostInfo> hosts; // main host first, then by requests desc
  final HostingProvider? cdn;
  final List<DnsDependency> nameServers;
  final List<DnsDependency> mailServers;
  final String? tlsIssuer;
  final HostingProvider? tlsProvider;
  final List<SovereigntyCheck> checks;

  const SovereigntyReport({
    this.home = eu,
    required this.mainHost,
    required this.hosts,
    required this.cdn,
    required this.nameServers,
    required this.mailServers,
    required this.tlsIssuer,
    required this.tlsProvider,
    required this.checks,
  });

  static const _points = {
    CheckStatus.pass: 1.0,
    CheckStatus.warn: 0.5,
    CheckStatus.fail: 0.0,
  };

  /// Weighted average of the pillar's verifiable checks, scaled to
  /// [pillarMax]. Unknown checks don't count; null if none is verifiable.
  double? pillarScore(Pillar pillar) {
    final list = checks
        .where((c) => c.pillar == pillar && c.status != CheckStatus.unknown);
    final totalWeight = list.fold<double>(0, (a, c) => a + c.weight);
    if (totalWeight == 0) return null;
    final earned =
        list.fold<double>(0, (a, c) => a + c.weight * _points[c.status]!);
    return pillarMax[pillar]! * earned / totalWeight;
  }

  /// 0–100 over the pillars that could be verified; null when none could be
  /// (an unverifiable report has no score, not a score of 0).
  int? get score {
    var earned = 0.0, max = 0;
    for (final p in Pillar.values) {
      final s = pillarScore(p);
      if (s == null) continue;
      earned += s;
      max += pillarMax[p]!;
    }
    return max == 0 ? null : (100 * earned / max).round();
  }

  String? get grade {
    final s = score;
    if (s == null) return null;
    return s >= 80
        ? 'Good'
        : s >= 50
            ? 'Fair'
            : 'Poor';
  }

  int count(CheckStatus status) =>
      checks.where((c) => c.status == status).length;

  /// Share (0..1) of requests per region, by server location or by the
  /// controlling company's jurisdiction.
  Map<String, double> regionShare({required bool byControl}) {
    final totals = <String, double>{};
    for (final h in hosts) {
      final region = regionOf(byControl ? h.controlCountry : h.ipCountry);
      totals[region] = (totals[region] ?? 0) + h.requests;
    }
    return _normalise(totals);
  }

  /// Share (0..1) of requests by relation to [home], by controlling company.
  Map<Relation, double> relationShare() {
    final totals = <Relation, double>{};
    for (final h in hosts) {
      final r = h.relation(home);
      totals[r] = (totals[r] ?? 0) + h.requests;
    }
    return _normalise(totals);
  }

  static Map<K, double> _normalise<K>(Map<K, double> totals) {
    final sum = totals.values.fold<double>(0, (a, b) => a + b);
    return sum == 0 ? totals : totals.map((k, v) => MapEntry(k, v / sum));
  }

  Map<String, dynamic> toJson() => {
        'home': home,
        'mainHost': mainHost,
        'cdn': cdn?.name,
        'nameServers': [
          for (final d in nameServers)
            {'record': d.record, 'provider': d.provider?.name},
        ],
        'mailServers': [
          for (final d in mailServers)
            {'record': d.record, 'provider': d.provider?.name},
        ],
        'tlsIssuer': tlsIssuer,
        'score': score,
        'grade': grade,
        'pillars': {
          for (final p in Pillar.values) p.name: pillarScore(p)?.round(),
        },
        'checks': checks.map((c) => c.toJson()).toList(),
        'hosts': hosts.map((h) => h.toJson()).toList(),
      };
}

class SovereigntyService {
  static const _maxHosts = 40;
  static const _timeout = Duration(seconds: 5);

  // Session caches so re-analysis and shared CDNs don't re-query.
  static final Map<String, ({int? asn, String? holder})> _asnCache = {};
  static final Map<String, String?> _countryCache = {};

  /// The hosts the page talks to, the main host first, then by number of
  /// requests. A resource without a known transfer size adds a request but
  /// no bytes.
  static List<HostInfo> collectHosts({
    required String pageUrl,
    required PageInspection inspection,
    Map<String, dynamic>? metadata,
  }) {
    final resources = browserResources(inspection);
    final mainHost = Uri.tryParse(pageUrl)?.host ?? '';
    final hosts = <String, HostInfo>{};
    final withUnknownSize = <String>{};

    void add(String url, int? bytes, String role) {
      final host = Uri.tryParse(url)?.host ?? '';
      if (host.isEmpty) return;
      final info = hosts.putIfAbsent(host, () => HostInfo(host));
      info.requests++;
      if (bytes == null) {
        // Only a loaded resource can have a size; the document itself and
        // static links are not measured here.
        if (role != 'document') withUnknownSize.add(host);
      } else {
        info.bytes = (info.bytes ?? 0) + bytes;
      }
      info.roles.add(role);
    }

    if (mainHost.isNotEmpty) add(pageUrl, null, 'document');
    for (final r in resources) {
      if (!r.url.startsWith('http')) continue;
      final transfer = r.transfer;
      add(
        r.url,
        transfer is Present<int> ? transfer.value : null,
        resourceCategory(r, pageUrl),
      );
    }
    // Static links as fallback when no runtime resource data exists.
    if (resources.isEmpty && metadata != null) {
      for (final key in ['externalJsLinks', 'jsLinks']) {
        for (final u in (metadata[key] as List? ?? const [])) {
          add(u.toString(), null, 'script');
        }
      }
      for (final key in ['externalCssLinks', 'cssLinks']) {
        for (final u in (metadata[key] as List? ?? const [])) {
          add(u.toString(), null, 'style');
        }
      }
    }

    for (final h in hosts.values) {
      h.bytesPartial = h.bytes != null && withUnknownSize.contains(h.host);
    }
    return hosts.values.toList()
      ..sort((a, b) {
        if (a.host == mainHost) return -1;
        if (b.host == mainHost) return 1;
        return b.requests.compareTo(a.requests);
      });
  }

  /// The resources the browser reported; empty unless they are Present.
  static List<ResourceEntry> browserResources(PageInspection inspection) {
    final b = inspection.browser;
    if (b is! Present<BrowserSnapshot>) return const [];
    final r = b.value.resources;
    return r is Present<List<ResourceEntry>> ? r.value : const [];
  }

  /// The app's own server answer; null unless it is Present with a hop.
  static ServerSnapshot? serverOf(PageInspection inspection) {
    final s = inspection.server;
    return s is Present<ServerSnapshot> && s.value.hops.isNotEmpty
        ? s.value
        : null;
  }

  static Future<SovereigntyReport> analyze({
    required String pageUrl,
    required PageInspection inspection,
    Map<String, dynamic>? metadata,
    List<Detection> detections = const [],
    String? html,
    String home = eu,
  }) async {
    final mainUri = Uri.tryParse(pageUrl);
    final mainHost = mainUri?.host ?? '';
    final server = serverOf(inspection);
    final ordered = collectHosts(
        pageUrl: pageUrl, inspection: inspection, metadata: metadata);
    final analyzed = ordered.take(_maxHosts).toList();

    await Future.wait(analyzed.map(_enrichHost));

    final headers = <String, String>{
      if (server != null)
        for (final e in server.hops.last.headers.entries)
          if (e.key != 'set-cookie') e.key: e.value.join(', '),
    };
    final mainProvider = analyzed.isEmpty ? null : analyzed.first.provider;
    final cdn = detectCdnFromHeaders(headers) ??
        (mainProvider?.edge == true ? mainProvider : null);

    final domain = registrableDomain(mainHost);
    Future<List<String>?> dnsQuery(String name, int type) =>
        domain.isEmpty ? Future.value(null) : _dnsQuery(name, type);
    final lookups = await Future.wait([
      dnsQuery(domain, 2), // NS
      dnsQuery(domain, 15), // MX
      dnsQuery(domain, 16), // TXT (SPF)
      dnsQuery('_dmarc.$domain', 16),
      dnsQuery(domain, 257), // CAA
      dnsQuery(domain, 43), // DS: present when DNSSEC is enabled
    ]);
    final securityTxt = mainHost.isEmpty
        ? null
        : classifySecurityTxt(
            await _statusOf('https://$mainHost/.well-known/security.txt'));

    final issuer = switch (server?.certificate) {
      Present<Map<String, dynamic>>(:final value) =>
        (value['issuerParsed'] as Map?)?['Organization']?.toString(),
      _ => null,
    };
    final tlsProvider = matchProvider([issuer]);

    final [nameServers, mailServers] = await Future.wait([
      _resolveDependencies(lookups[0]),
      _resolveDependencies(lookups[1]),
    ]);

    final checks = <SovereigntyCheck>[
      ..._infrastructureChecks(
        main: analyzed.isEmpty ? null : analyzed.first,
        cdn: cdn,
        headers: headers,
        nameServers: nameServers,
        mailServers: mailServers,
        issuer: issuer,
        tlsProvider: tlsProvider,
        detections: detections,
        home: home,
      ),
      ..._residencyChecks(analyzed, cdn, home),
      ...securityChecks(
        txt: lookups[2],
        dmarc: lookups[3],
        caa: lookups[4],
        ds: lookups[5],
        securityTxt: securityTxt,
        server: server,
      ),
      ..._privacyChecks(analyzed, detections, html, home),
    ];

    return SovereigntyReport(
      home: home,
      mainHost: mainHost,
      hosts: analyzed,
      cdn: cdn,
      nameServers: nameServers,
      mailServers: mailServers,
      tlsIssuer: issuer,
      tlsProvider: tlsProvider,
      checks: checks,
    );
  }

  /// Matches NS/MX names to providers. For an unrecognised name, looks up
  /// the server's network owner and location once per list.
  static Future<List<DnsDependency>> _resolveDependencies(
    List<String>? records,
  ) async {
    final deps = <DnsDependency>[];
    for (final record in records ?? const <String>[]) {
      var provider = matchProvider([record]);
      HostInfo? server;
      if (provider == null && !deps.any((d) => d.server != null)) {
        server = HostInfo(record);
        await _enrichHost(server);
        provider = server.provider;
      }
      deps.add(DnsDependency(record, provider, server));
    }
    return deps;
  }

  /// Check for a company not in [providers], judged by the country where its
  /// network (ASN) is registered. Never by IP geolocation: that only tells
  /// where a server is, not who controls it.
  static SovereigntyCheck? _registrationCheck(
    String title,
    String altKey,
    HostInfo? server,
    String evidencePrefix,
    double weight,
    String home,
  ) {
    if (server?.asnCountry == null) return null;
    final country = server!.asnCountry!;
    final status = statusFor(country, home);
    return SovereigntyCheck(
      Pillar.infrastructure,
      '$title: ${server.asnHolder ?? 'AS${server.asn}'} (registered in $country)',
      status,
      '$evidencePrefix → AS${server.asn} registered in $country '
          '(network operator; a foreign parent company is not detected)'
          '${jurisdictionNote(country, home)}',
      weight: weight,
      alternatives:
          status == CheckStatus.pass ? const [] : alternativesFor(altKey, home),
    );
  }

  static List<SovereigntyCheck> _residencyChecks(
    List<HostInfo> hosts,
    HostingProvider? cdn,
    String home,
  ) {
    const p = Pillar.residency;
    final main = hosts.isEmpty ? null : hosts.first;
    final located = hosts.where((h) => h.ipCountry != null).toList();
    final total = located.fold<int>(0, (a, h) => a + h.requests);
    int requestsWhere(Relation r) => located
        .where((h) => relationTo(h.ipCountry, home) == r)
        .fold<int>(0, (a, h) => a + h.requests);
    final own = total == 0 ? 0.0 : requestsWhere(Relation.own) / total;
    final adequate =
        total == 0 ? 0.0 : requestsWhere(Relation.adequate) / total;
    final value = own + adequate / 2;
    final foreignControlled =
        hosts.where((h) => h.foreignControlled(home)).toList();
    final homeLabel = jurisdictionLabel(home);

    return [
      if (cdn != null)
        SovereigntyCheck(
          p,
          'Website origin server in the site\'s jurisdiction ($homeLabel)',
          CheckStatus.unknown,
          'Served from an edge server of ${cdn.name}'
              '${main?.ipCountry != null ? ' in ${main!.ipCountry}' : ''}; '
              'the origin server location is hidden',
          weight: 3,
        )
      else
        SovereigntyCheck(
          p,
          'Website server in the site\'s jurisdiction ($homeLabel)',
          statusFor(main?.ipCountry, home),
          main?.ip == null
              ? 'Could not resolve the server address'
              : 'IP ${main!.ip} in ${main.ipCountry ?? 'unknown country'}'
                  '${main.asnHolder != null ? ' (${main.asnHolder})' : ''}'
                  '${jurisdictionNote(main.ipCountry, home)}',
          weight: 3,
        ),
      SovereigntyCheck(
        p,
        'Requests served from the site\'s jurisdiction',
        total == 0
            ? CheckStatus.unknown
            : value >= 0.8
                ? CheckStatus.pass
                : value >= 0.5
                    ? CheckStatus.warn
                    : CheckStatus.fail,
        total == 0
            ? 'No server locations known'
            : '${(own * 100).round()}% in $homeLabel'
                '${adequate > 0 ? ', ${(adequate * 100).round()}% in adequate countries' : ''}'
                ' (of $total located requests)',
        weight: 2,
      ),
      SovereigntyCheck(
        p,
        'Local hosting not controlled from abroad',
        foreignControlled.isEmpty ? CheckStatus.pass : CheckStatus.fail,
        foreignControlled.isEmpty
            ? 'No hosts in $homeLabel run by foreign companies'
            : foreignControlled
                .map((h) => '${h.host} (${h.provider!.name}, '
                    '${h.provider!.country}'
                    '${extraterritorialLaws[h.provider!.country] != null ? ': ${extraterritorialLaws[h.provider!.country]}' : ''})')
                .join(', '),
        weight: 2,
      ),
    ];
  }

  static SovereigntyCheck _providerCheck(
    String title,
    String altKey,
    List<DnsDependency> deps,
    String recordType,
    double weight,
    String home,
  ) {
    const p = Pillar.infrastructure;
    if (deps.isEmpty) {
      return SovereigntyCheck(
        p,
        title,
        CheckStatus.unknown,
        'No $recordType records found',
        weight: weight,
      );
    }
    final known = deps.where((d) => d.provider != null).toList();
    if (known.isEmpty) {
      final looked = deps.where((d) => d.server != null).firstOrNull;
      return _registrationCheck(
            title,
            altKey,
            looked?.server,
            '$recordType record: ${looked?.record}',
            weight,
            home,
          ) ??
          SovereigntyCheck(
            p,
            title,
            CheckStatus.unknown,
            '$recordType record: ${deps.first.record} (provider not recognised)',
            weight: weight,
          );
    }
    // Report the provider furthest from home when several are used.
    known.sort((a, b) => relationTo(b.provider!.country, home)
        .index
        .compareTo(relationTo(a.provider!.country, home).index));
    final worst = known.first;
    final country = worst.provider!.country;
    final status = statusFor(country, home);
    return SovereigntyCheck(
      p,
      '$title: ${worst.provider!.name} ($country)',
      status,
      '$recordType record: ${worst.record}${jurisdictionNote(country, home)}',
      weight: weight,
      alternatives:
          status == CheckStatus.pass ? const [] : alternativesFor(altKey, home),
    );
  }

  static const _cdnHeaders = {
    'cf-ray',
    'server',
    'via',
    'x-amz-cf-id',
    'x-azure-ref',
    'x-vercel-id',
    'x-nf-request-id',
    'x-served-by',
  };

  static List<SovereigntyCheck> _infrastructureChecks({
    required HostInfo? main,
    required HostingProvider? cdn,
    required Map<String, String> headers,
    required List<DnsDependency> nameServers,
    required List<DnsDependency> mailServers,
    required String? issuer,
    required HostingProvider? tlsProvider,
    required List<Detection> detections,
    required String home,
  }) {
    const p = Pillar.infrastructure;
    final checks = <SovereigntyCheck>[];

    final host = main?.provider;
    final hostStatus = statusFor(host?.country, home);
    final SovereigntyCheck hosting;
    if (cdn != null) {
      hosting = SovereigntyCheck(
        p,
        'Hosting company: hidden behind ${cdn.name}',
        CheckStatus.unknown,
        'The site is served through ${cdn.name}; the origin server and its '
            'hosting company are not visible from outside',
        weight: 3,
      );
    } else if (host == null) {
      hosting = _registrationCheck(
              'Hosting company', 'hosting', main, main?.host ?? '', 3, home) ??
          SovereigntyCheck(
            p,
            'Hosting company',
            CheckStatus.unknown,
            'Network owner unknown',
            weight: 3,
          );
    } else {
      hosting = SovereigntyCheck(
        p,
        'Hosting company: ${host.name} (${host.country})',
        hostStatus,
        '${main?.asn != null ? 'AS${main!.asn} ${main.asnHolder ?? ''}' : host.name}'
            '${jurisdictionNote(host.country, home)}',
        weight: 3,
        alternatives: hostStatus == CheckStatus.pass
            ? const []
            : alternativesFor('hosting', home),
      );
    }
    checks.add(hosting);

    final cdnStatus =
        cdn == null ? CheckStatus.pass : statusFor(cdn.country, home);
    checks.add(SovereigntyCheck(
      p,
      cdn == null
          ? 'CDN / proxy: none detected'
          : 'CDN / proxy: ${cdn.name} (${cdn.country})',
      cdnStatus,
      cdn == null
          ? 'No CDN headers in the response'
          : headers.keys.any((k) => _cdnHeaders.contains(k.toLowerCase())) &&
                  detectCdnFromHeaders(headers) != null
              ? 'Response headers: ${headers.keys.where((k) => _cdnHeaders.contains(k.toLowerCase())).join(', ')}'
              : 'Site IP belongs to ${main?.asnHolder ?? cdn.name}'
                  '${jurisdictionNote(cdn.country, home)}',
      weight: 3,
      alternatives: cdnStatus == CheckStatus.pass
          ? const []
          : alternativesFor('cdn', home),
    ));

    checks.add(
        _providerCheck('Email provider', 'email', mailServers, 'MX', 3, home));
    checks
        .add(_providerCheck('DNS provider', 'dns', nameServers, 'NS', 2, home));

    final tlsCountry = tlsProvider?.country;
    final tlsRelation = relationTo(tlsCountry, home);
    final tlsStatus = issuer == null
        ? CheckStatus.unknown
        : tlsRelation == Relation.own
            ? CheckStatus.pass
            : CheckStatus.warn; // few countries have their own CAs
    checks.add(SovereigntyCheck(
      p,
      'TLS certificate authority${tlsCountry != null ? ' ($tlsCountry)' : ''}',
      tlsStatus,
      issuer == null ? 'No certificate information' : 'Issuer: $issuer',
      weight: 1,
      alternatives: tlsStatus == CheckStatus.warn
          ? alternativesFor('tls', home)
          : const [],
    ));

    final cms = detections
        .where((d) => d.category == DetectionCategory.cms)
        .firstOrNull;
    if (cms != null) {
      final origin = cms.entity.origin;
      final status =
          origin == selfHosted ? CheckStatus.pass : statusFor(origin, home);
      checks.add(SovereigntyCheck(
        p,
        origin == selfHosted
            ? 'CMS: ${cms.name} (open source)'
            : 'CMS: ${cms.name}${origin != null ? ' ($origin)' : ''}',
        status,
        cms.evidence.firstOrNull?.detail ?? 'Detected in the page source',
        weight: 1,
        alternatives: status == CheckStatus.fail
            ? alternativesFor('cms', home)
            : const [],
      ));
    }
    return checks;
  }

  static List<String> _detectedServiceNames(
    List<Detection> detections,
    Set<DetectionCategory> categories,
  ) =>
      [
        for (final d in detections)
          if (categories.contains(d.category)) d.name
      ];

  /// Judges third-party services by their vendor's jurisdiction.
  static SovereigntyCheck _servicesCheck(
    String title,
    List<String> names,
    double weight,
    String home, {
    String altKey = 'services',
    String extraEvidence = '',
  }) {
    final foreign = <String>[];
    final adequate = <String>[];
    for (final name in names.toSet()) {
      final origin = vendorOriginFor(name);
      if (origin == null || origin == selfHosted) continue;
      switch (relationTo(origin, home)) {
        case Relation.foreign:
          foreign.add('$name ($origin)');
        case Relation.adequate:
          adequate.add('$name ($origin)');
        default:
      }
    }
    final status = foreign.isNotEmpty
        ? CheckStatus.fail
        : adequate.isNotEmpty
            ? CheckStatus.warn
            : CheckStatus.pass;
    return SovereigntyCheck(
      Pillar.privacy,
      title,
      status,
      names.isEmpty
          ? 'None detected'
          : foreign.isEmpty && adequate.isEmpty
              ? 'All from ${jurisdictionLabel(home)} or self-hosted: ${names.toSet().join(', ')}'
              : [...foreign, ...adequate].join(', ') + extraEvidence,
      weight: weight,
      alternatives:
          status == CheckStatus.pass ? const [] : alternativesFor(altKey, home),
    );
  }

  @visibleForTesting
  static List<SovereigntyCheck> securityChecks({
    required List<String>? txt,
    required List<String>? dmarc,
    required List<String>? caa,
    required List<String>? ds,
    required bool? securityTxt,
    required ServerSnapshot? server,
  }) {
    const p = Pillar.security;
    SovereigntyCheck dnsCheck(
      String title,
      List<String>? records,
      (CheckStatus, String) Function(List<String>) classify, {
      double weight = 1,
    }) {
      if (records == null) {
        return SovereigntyCheck(
          p,
          title,
          CheckStatus.unknown,
          'DNS lookup failed or the resolver could not answer (unknown)',
          weight: weight,
        );
      }
      final (status, evidence) = classify(records);
      return SovereigntyCheck(p, title, status, evidence, weight: weight);
    }

    final hsts = server?.hops.last.headers['strict-transport-security']
        ?.join(', ');
    return [
      dnsCheck('SPF (email sender policy)', txt, classifySpf),
      dnsCheck('DMARC (email authentication)', dmarc, classifyDmarc),
      dnsCheck(
        'DNSSEC',
        ds,
        (r) => r.isEmpty
            ? (CheckStatus.fail, 'No DS record in the parent zone')
            : (CheckStatus.pass, 'DS record present (${r.first})'),
      ),
      SovereigntyCheck(
        p,
        'HSTS enabled',
        server == null
            ? CheckStatus.unknown
            : hsts != null
                ? CheckStatus.pass
                : CheckStatus.fail,
        server == null
            ? 'No server response to read the headers from'
            : hsts != null
                ? 'Strict-Transport-Security: $hsts'
                : 'No Strict-Transport-Security header',
      ),
      dnsCheck(
        'CAA (allowed certificate authorities)',
        caa,
        (r) => r.isEmpty
            ? (CheckStatus.warn, 'No CAA record: any CA may issue')
            : (CheckStatus.pass, r.join(', ')),
        weight: 0.5,
      ),
      SovereigntyCheck(
        p,
        'security.txt published',
        switch (securityTxt) {
          null => CheckStatus.unknown,
          true => CheckStatus.pass,
          false => CheckStatus.warn,
        },
        securityTxt == true
            ? '/.well-known/security.txt found'
            : 'No /.well-known/security.txt',
        weight: 0.5,
      ),
    ];
  }

  static List<SovereigntyCheck> _privacyChecks(
    List<HostInfo> hosts,
    List<Detection> detections,
    String? html,
    String home,
  ) {
    const p = Pillar.privacy;
    final privacy = html == null ? null : findPrivacyLink(html);
    final consent =
        _detectedServiceNames(detections, {DetectionCategory.consent});
    final trackers = _detectedServiceNames(detections, {
      DetectionCategory.advertising,
      DetectionCategory.behavior,
      DetectionCategory.analytics,
      DetectionCategory.marketing,
    });
    final fonts = {
      ..._detectedServiceNames(detections, {DetectionCategory.fonts}),
      if (hosts.any((h) =>
          h.host.endsWith('fonts.googleapis.com') ||
          h.host.endsWith('fonts.gstatic.com')))
        'Google Fonts',
    }.toList();

    return [
      SovereigntyCheck(
        p,
        'Privacy statement linked',
        html == null
            ? CheckStatus.unknown
            : privacy != null
                ? CheckStatus.pass
                : CheckStatus.warn, // may be added later by JavaScript
        privacy ?? 'No link to a privacy or cookie statement in the page HTML',
      ),
      SovereigntyCheck(
        p,
        'Consent management',
        consent.isNotEmpty || trackers.isEmpty
            ? CheckStatus.pass
            : CheckStatus.warn,
        consent.isNotEmpty
            ? consent.join(', ')
            : trackers.isEmpty
                ? 'No trackers detected, so no consent tool needed'
                : 'Trackers found but no known consent tool',
      ),
      SovereigntyCheck(
        p,
        'Number of trackers',
        trackers.isEmpty
            ? CheckStatus.pass
            : trackers.length <= 2
                ? CheckStatus.warn
                : CheckStatus.fail,
        trackers.isEmpty ? 'None detected' : trackers.join(', '),
      ),
      _servicesCheck(
        'Analytics, ads & marketing in the site\'s jurisdiction',
        trackers,
        2,
        home,
      ),
      _servicesCheck(
        'Widgets, embeds & payments in the site\'s jurisdiction',
        _detectedServiceNames(detections,
            {DetectionCategory.social, DetectionCategory.ecommerce}),
        1,
        home,
      ),
      _servicesCheck(
        'Fonts & icons in the site\'s jurisdiction',
        fonts,
        0.5,
        home,
        altKey: 'fonts',
        extraEvidence: home == eu && fonts.contains('Google Fonts')
            ? ' · LG München (2022) ruled Google Fonts violates the GDPR'
            : '',
      ),
    ];
  }

  /// security.txt: 200 = published, 404 = not published, any other status
  /// (403, 429, 5xx) or no answer = unknown.
  static bool? classifySecurityTxt(int? status) => switch (status) {
        200 => true,
        404 => false,
        _ => null,
      };

  /// The HTTP status of a GET (HEAD is often refused), null when unreachable.
  static Future<int?> _statusOf(String url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      await res.drain<void>();
      return res.statusCode;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// RIPEstat is rate limited: at most this many requests in flight.
  static const ripeConcurrency = 6;
  static final _Gate _ripeGate = _Gate(ripeConcurrency);

  @visibleForTesting
  static Future<T> ripeLimitedForTest<T>(Future<T> Function() task) =>
      _ripeGate.run(task);

  /// Runs [tasks] with at most [limit] in flight; results keep the order.
  /// A task that throws gives null for that entry (unknown), not a failed
  /// batch.
  @visibleForTesting
  static Future<List<T?>> limited<T>(List<Future<T> Function()> tasks,
      {int limit = ripeConcurrency}) {
    final gate = _Gate(limit);
    return Future.wait([
      for (final task in tasks)
        gate.run<T?>(() async {
          try {
            return await task();
          } catch (_) {
            return null;
          }
        }),
    ]);
  }

  static Future<void> _enrichHost(HostInfo info) async {
    try {
      final addrs = await InternetAddress.lookup(info.host).timeout(_timeout);
      if (addrs.isEmpty) return;
      final ip = addrs.first.address;
      info.ip = ip;

      final results = await Future.wait([_asnFor(ip), _countryFor(ip)]);
      final asn = results[0] as ({int? asn, String? holder});
      info.asn = asn.asn;
      info.asnHolder = asn.holder;
      info.ipCountry = results[1] as String?;
      if (asn.asn != null) info.asnCountry = await _asnCountryFor(asn.asn!);
    } catch (e) {
      debugPrint('Sovereignty lookup failed for ${info.host}: $e');
    }
    info.provider = matchProvider([info.host, info.asnHolder]);
  }

  static Future<Map<String, dynamic>?> _getJson(String url) =>
      _ripeGate.run(() => _fetchJson(url));

  static Future<Map<String, dynamic>?> _fetchJson(String url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join().timeout(_timeout);
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<({int? asn, String? holder})> _asnFor(String ip) async {
    final cached = _asnCache[ip];
    if (cached != null) return cached;
    final json = await _getJson(
      'https://stat.ripe.net/data/prefix-overview/data.json?resource=$ip',
    );
    final asns = (json?['data']?['asns'] as List?) ?? const [];
    final first = asns.isEmpty ? null : asns.first as Map;
    final result = (
      asn: (first?['asn'] as num?)?.toInt(),
      holder: first?['holder']?.toString(),
    );
    if (first != null) _asnCache[ip] = result;
    return result;
  }

  static final Map<int, String?> _asnCountryCache = {};

  /// Country where an AS number is registered (RIR statistics).
  static Future<String?> _asnCountryFor(int asn) async {
    if (_asnCountryCache.containsKey(asn)) return _asnCountryCache[asn];
    final json = await _getJson(
      'https://stat.ripe.net/data/rir-stats-country/data.json?resource=AS$asn',
    );
    final located = (json?['data']?['located_resources'] as List?) ?? const [];
    final country =
        located.isEmpty ? null : (located.first as Map)['location']?.toString();
    if (json != null) _asnCountryCache[asn] = country;
    return country;
  }

  static Future<String?> _countryFor(String ip) async {
    if (_countryCache.containsKey(ip)) return _countryCache[ip];
    final json = await _getJson(
      'https://stat.ripe.net/data/maxmind-geo-lite/data.json?resource=$ip',
    );
    final located = (json?['data']?['located_resources'] as List?) ?? const [];
    String? country;
    if (located.isNotEmpty) {
      final locs = (located.first as Map)['locations'] as List? ?? const [];
      if (locs.isNotEmpty) country = (locs.first as Map)['country']?.toString();
    }
    if (country == '?') country = null;
    if (json != null) _countryCache[ip] = country;
    return country;
  }

  /// Multi-label public suffixes that are common enough to matter here. This
  /// is a PSL-lite, NOT the full Public Suffix List: an unlisted suffix is
  /// treated as a single label (so `x.example.co.id` gives `co.id`).
  static const _publicSuffixes = {
    'co.uk', 'ac.uk', 'gov.uk', 'org.uk',
    'com.au', 'net.au', 'org.au',
    'co.nz',
    'co.jp', 'ne.jp', 'or.jp',
    'com.br', 'com.cn', 'com.tr', 'co.za',
    // Hosting platforms where every customer gets a subdomain.
    'github.io', 'gitlab.io', 'netlify.app', 'vercel.app', 'pages.dev',
    'herokuapp.com', 'azurewebsites.net', 'cloudfront.net', 'blogspot.com',
    'appspot.com', 'web.app', 'firebaseapp.com',
  };

  /// Registrable domain: the public suffix (from [_publicSuffixes], else the
  /// generic `{co,com,org,net,gov,ac,edu}.<ccTLD>` pattern, else the last
  /// label) plus one label. `foo.github.io` stays `foo.github.io`; an IP
  /// address is returned unchanged; the result is lowercase.
  static String registrableDomain(String host) {
    final h = host.toLowerCase();
    if (h.contains(':') || RegExp(r'^\d+(\.\d+){3}$').hasMatch(h)) return h;
    final parts = h.split('.');
    if (parts.length <= 2) return h;
    final twoLabel = parts.sublist(parts.length - 2).join('.');
    const genericSld = {'co', 'com', 'org', 'net', 'gov', 'ac', 'edu'};
    final take = _publicSuffixes.contains(twoLabel) ||
            (genericSld.contains(parts[parts.length - 2]) &&
                parts.last.length == 2)
        ? 3
        : 2;
    return parts.sublist(parts.length - take).join('.');
  }

  // DoH resolvers that speak HTTP/1.1 (dart:io has no HTTP/2; Quad9 needs it).
  // European first, US fallback only when it is unreachable.
  static const _dohResolvers = [
    'https://doh.libredns.gr/dns-query',
    'https://dns.google/dns-query',
  ];

  /// DNS-over-HTTPS (RFC 8484 wire format).
  /// Returns parsed records (see [parseDnsRecords]), null on failure.
  static Future<List<String>?> _dnsQuery(String domain, int type) async {
    final dns =
        base64Url.encode(buildDnsQuery(domain, type)).replaceAll('=', '');
    for (final resolver in _dohResolvers) {
      final client = HttpClient()..connectionTimeout = _timeout;
      try {
        final req = await client
            .getUrl(Uri.parse('$resolver?dns=$dns'))
            .timeout(_timeout);
        req.headers.set('accept', 'application/dns-message');
        final res = await req.close().timeout(_timeout);
        if (res.statusCode != 200) continue;
        final bytes = await res
            .fold<BytesBuilder>(BytesBuilder(), (b, c) => b..add(c))
            .timeout(_timeout);
        final records = classifyDnsResponse(bytes.takeBytes(), type);
        if (records == null) continue; // SERVFAIL/REFUSED: try the next one
        return records;
      } catch (e) {
        debugPrint('DNS query via $resolver failed for $domain: $e');
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }

  /// The RCODE of a DNS response (0 NOERROR, 2 SERVFAIL, 3 NXDOMAIN,
  /// 5 REFUSED); null for a message too short to have one.
  @visibleForTesting
  static int? dnsRcode(Uint8List d) => d.length < 4 ? null : d[3] & 0x0F;

  /// Records of [type] in a response, with the RCODE taken into account:
  /// NOERROR and NXDOMAIN are real answers (possibly empty = "no record");
  /// SERVFAIL, REFUSED and anything else mean the resolver could not tell,
  /// so null (unknown), never an empty list.
  @visibleForTesting
  static List<String>? classifyDnsResponse(Uint8List d, int type) {
    final rcode = dnsRcode(d);
    if (rcode != 0 && rcode != 3) return null;
    return parseDnsRecords(d, type);
  }

  @visibleForTesting
  static Uint8List buildDnsQuery(String domain, int type) {
    final b = BytesBuilder()..add([0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
    for (final label in domain.split('.')) {
      final l = utf8.encode(label);
      b.addByte(l.length);
      b.add(l);
    }
    b.add([0, type >> 8, type & 0xFF, 0, 1]);
    return b.toBytes();
  }

  /// Extracts answers of [type]: names for NS (2) / MX (15), joined strings
  /// for TXT (16), `tag value` for CAA (257), the key tag for DS (43).
  @visibleForTesting
  static List<String> parseDnsRecords(Uint8List d, int type) {
    if (d.length < 12) return const [];
    int u16(int o) => (d[o] << 8) | d[o + 1];

    // Reads a (possibly compressed) name at [offset]; returns name + next offset.
    (String, int) readName(int offset) {
      final labels = <String>[];
      var pos = offset;
      int? next;
      var hops = 0;
      while (pos < d.length && hops++ < 32) {
        final len = d[pos];
        if (len == 0) {
          next ??= pos + 1;
          break;
        }
        if (len & 0xC0 == 0xC0) {
          next ??= pos + 2;
          pos = ((len & 0x3F) << 8) | d[pos + 1];
          continue;
        }
        labels.add(utf8.decode(d.sublist(pos + 1, pos + 1 + len)));
        pos += len + 1;
      }
      return (labels.join('.'), next ?? pos);
    }

    final qd = u16(4), an = u16(6);
    var pos = 12;
    for (var i = 0; i < qd; i++) {
      pos = readName(pos).$2 + 4;
    }
    final out = <String>[];
    for (var i = 0; i < an && pos + 10 <= d.length; i++) {
      pos = readName(pos).$2;
      final rtype = u16(pos);
      final rdlen = u16(pos + 8);
      final rdata = pos + 10;
      if (rtype == type && rdata + rdlen <= d.length) {
        out.add(switch (type) {
          15 => readName(rdata + 2).$1,
          16 => _txt(d.sublist(rdata, rdata + rdlen)),
          257 => _caa(d.sublist(rdata, rdata + rdlen)),
          43 => 'key tag ${u16(rdata)}',
          _ => readName(rdata).$1,
        });
      }
      pos = rdata + rdlen;
    }
    return out;
  }

  static String _txt(List<int> rdata) {
    final parts = <String>[];
    var i = 0;
    while (i < rdata.length) {
      final end = (i + 1 + rdata[i]).clamp(0, rdata.length);
      parts.add(utf8.decode(rdata.sublist(i + 1, end), allowMalformed: true));
      i = end;
    }
    return parts.join();
  }

  static String _caa(List<int> rdata) {
    if (rdata.length < 2) return '';
    final tagEnd = (2 + rdata[1]).clamp(0, rdata.length);
    final tag = utf8.decode(rdata.sublist(2, tagEnd), allowMalformed: true);
    final value = utf8.decode(rdata.sublist(tagEnd), allowMalformed: true);
    return '$tag $value';
  }
}

/// At most [limit] tasks run at once; the rest wait their turn.
class _Gate {
  final int limit;
  int _running = 0;
  final List<Completer<void>> _waiting = [];
  _Gate(this.limit);

  Future<T> run<T>(Future<T> Function() task) async {
    while (_running >= limit) {
      final c = Completer<void>();
      _waiting.add(c);
      await c.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }
}
