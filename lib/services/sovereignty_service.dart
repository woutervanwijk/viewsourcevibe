import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:view_source_vibe/services/probe_service.dart';

enum Jurisdiction { eu, us, other, unknown }

const _euCountries = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR',
  'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
  'SI', 'ES', 'SE', 'IS', 'LI', 'NO', // EU + EEA
};

// Non-EU but adequate / European-ish jurisdictions, shown as "other" but
// kept apart from US in the UI via the country code.
Jurisdiction jurisdictionFor(String? country) {
  if (country == null || country.isEmpty || country == '?') {
    return Jurisdiction.unknown;
  }
  if (country == 'US') return Jurisdiction.us;
  if (_euCountries.contains(country)) return Jurisdiction.eu;
  return Jurisdiction.other;
}

class HostingProvider {
  final String name;
  final String country; // HQ / controlling jurisdiction
  final RegExp pattern; // matched against host, ASN holder, NS or MX name
  const HostingProvider(this.name, this.country, this.pattern);
}

final List<HostingProvider> providers = [
  HostingProvider(
    'Cloudflare',
    'US',
    RegExp(r'cloudflare|cdnjs|jsdelivr|unpkg|cf-ns\.', caseSensitive: false),
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
  ),
  HostingProvider(
    'Akamai',
    'US',
    RegExp(r'akamai|edgekey|edgesuite', caseSensitive: false),
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
  HostingProvider('Gcore', 'LU', RegExp(r'gcore', caseSensitive: false)),
  HostingProvider('Bunny.net', 'SI', RegExp(r'bunny', caseSensitive: false)),
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

class HostInfo {
  final String host;
  final Set<String> roles = {};
  int requests = 0;
  int bytes = 0;
  String? ip;
  int? asn;
  String? asnHolder;
  String? ipCountry;
  HostingProvider? provider; // company controlling the host (HQ jurisdiction)

  HostInfo(this.host);

  /// Controlling jurisdiction: the company's HQ if known, else the IP country.
  Jurisdiction get jurisdiction =>
      jurisdictionFor(provider?.country ?? ipCountry);

  /// Hosted in the EU, but by a US company: still subject to the CLOUD Act.
  bool get cloudActRisk =>
      provider?.country == 'US' &&
      jurisdictionFor(ipCountry) == Jurisdiction.eu;

  Map<String, dynamic> toJson() => {
        'host': host,
        'roles': roles.toList(),
        'requests': requests,
        'bytes': bytes,
        'ip': ip,
        'asn': asn,
        'asnHolder': asnHolder,
        'ipCountry': ipCountry,
        'provider': provider?.name,
        'providerCountry': provider?.country,
        'jurisdiction': jurisdiction.name,
      };
}

class DnsDependency {
  final String record; // ns-1582.awsdns-05.co.uk
  final HostingProvider? provider;
  const DnsDependency(this.record, this.provider);
}

class SovereigntyReport {
  final String mainHost;
  final List<HostInfo> hosts; // main host first, then by requests desc
  final HostingProvider? cdn;
  final List<DnsDependency> nameServers;
  final List<DnsDependency> mailServers;
  final String? tlsIssuer;
  final HostingProvider? tlsProvider;
  final List<String> notes;

  const SovereigntyReport({
    required this.mainHost,
    required this.hosts,
    required this.cdn,
    required this.nameServers,
    required this.mailServers,
    required this.tlsIssuer,
    required this.tlsProvider,
    required this.notes,
  });

  /// Share (0..1) per jurisdiction for the given weight.
  Map<Jurisdiction, double> share(num Function(HostInfo) weight) {
    final totals = {for (final j in Jurisdiction.values) j: 0.0};
    for (final h in hosts) {
      totals[h.jurisdiction] = totals[h.jurisdiction]! + weight(h);
    }
    final sum = totals.values.fold<double>(0, (a, b) => a + b);
    if (sum == 0) return totals;
    return totals.map((k, v) => MapEntry(k, v / sum));
  }

  Map<String, dynamic> toJson() => {
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
        'notes': notes,
        'hosts': hosts.map((h) => h.toJson()).toList(),
      };
}

class SovereigntyService {
  static const _maxHosts = 40;
  static const _timeout = Duration(seconds: 5);

  // Session caches so re-analysis and shared CDNs don't re-query.
  static final Map<String, ({int? asn, String? holder})> _asnCache = {};
  static final Map<String, String?> _countryCache = {};

  static Future<SovereigntyReport> analyze({
    required String pageUrl,
    required Map<String, dynamic>? probeResult,
    required List<Map<String, dynamic>> resources,
    Map<String, dynamic>? metadata,
  }) async {
    final mainUri = Uri.tryParse(pageUrl);
    final mainHost = mainUri?.host ?? '';
    final hosts = <String, HostInfo>{};

    void add(String url, int bytes, String role) {
      final host = Uri.tryParse(url)?.host ?? '';
      if (host.isEmpty) return;
      final info = hosts.putIfAbsent(host, () => HostInfo(host));
      info.requests++;
      info.bytes += bytes;
      info.roles.add(role);
    }

    if (mainHost.isNotEmpty) add(pageUrl, 0, 'document');
    for (final r in resources) {
      final name = r['name']?.toString() ?? '';
      if (!name.startsWith('http')) continue;
      add(
        name,
        (r['transfer'] as num? ?? 0).toInt(),
        ProbeService.categorizeResource(name, pageUrl),
      );
    }
    // Static links as fallback when no runtime resource data exists.
    if (resources.isEmpty && metadata != null) {
      for (final key in ['externalJsLinks', 'jsLinks']) {
        for (final u in (metadata[key] as List? ?? const [])) {
          add(u.toString(), 0, 'script');
        }
      }
      for (final key in ['externalCssLinks', 'cssLinks']) {
        for (final u in (metadata[key] as List? ?? const [])) {
          add(u.toString(), 0, 'style');
        }
      }
    }

    final ordered = hosts.values.toList()
      ..sort((a, b) {
        if (a.host == mainHost) return -1;
        if (b.host == mainHost) return 1;
        return b.requests.compareTo(a.requests);
      });
    final analyzed = ordered.take(_maxHosts).toList();

    await Future.wait(analyzed.map(_enrichHost));

    final headers = <String, String>{
      for (final e in (probeResult?['headers'] as Map? ?? const {}).entries)
        e.key.toString(): e.value.toString(),
    };
    final cdn = detectCdnFromHeaders(headers);

    final domain = registrableDomain(mainHost);
    final dns = domain.isEmpty
        ? [const <String>[], const <String>[]]
        : await Future.wait([_dnsQuery(domain, 2), _dnsQuery(domain, 15)]);

    final issuer =
        (probeResult?['certificate']?['issuerParsed'] as Map?)?['Organization']
            ?.toString();
    final tlsProvider = matchProvider([issuer]);

    final notes = <String>[];
    final risky = analyzed.where((h) => h.cloudActRisk).toList();
    if (risky.isNotEmpty) {
      notes.add(
        '${risky.length} host(s) are located in the EU but operated by a US company (${risky.map((h) => h.provider!.name).toSet().join(', ')}): still subject to the US CLOUD Act.',
      );
    }
    if (analyzed.any(
      (h) =>
          h.host.endsWith('fonts.googleapis.com') ||
          h.host.endsWith('fonts.gstatic.com'),
    )) {
      notes.add(
        'Fonts are loaded from Google servers, which sends visitor IPs to the US. A German court (LG München, 2022) ruled this violates the GDPR; self-host fonts instead.',
      );
    }

    return SovereigntyReport(
      mainHost: mainHost,
      hosts: analyzed,
      cdn: cdn,
      nameServers: [
        for (final r in dns[0]) DnsDependency(r, matchProvider([r])),
      ],
      mailServers: [
        for (final r in dns[1]) DnsDependency(r, matchProvider([r])),
      ],
      tlsIssuer: issuer,
      tlsProvider: tlsProvider,
      notes: notes,
    );
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
    } catch (e) {
      debugPrint('Sovereignty lookup failed for ${info.host}: $e');
    }
    info.provider = matchProvider([info.host, info.asnHolder]);
  }

  static Future<Map<String, dynamic>?> _getJson(String url) async {
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

  /// Naive registrable domain: last two labels, three for common
  /// second-level suffixes (co.uk, com.au, ...).
  static String registrableDomain(String host) {
    final parts = host.split('.');
    if (parts.length <= 2) return host;
    const sld = {'co', 'com', 'org', 'net', 'gov', 'ac'};
    final take =
        (sld.contains(parts[parts.length - 2]) && parts.last.length == 2)
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
  /// Returns record targets for NS (2) / MX (15), empty on failure.
  static Future<List<String>> _dnsQuery(String domain, int type) async {
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
        return parseDnsNames(bytes.takeBytes(), type);
      } catch (e) {
        debugPrint('DNS query via $resolver failed for $domain: $e');
      } finally {
        client.close(force: true);
      }
    }
    return const [];
  }

  @visibleForTesting
  static Uint8List buildDnsQuery(String domain, int type) {
    final b = BytesBuilder()..add([0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
    for (final label in domain.split('.')) {
      final l = utf8.encode(label);
      b.addByte(l.length);
      b.add(l);
    }
    b.add([0, 0, type, 0, 1]);
    return b.toBytes();
  }

  /// Extracts the target names of NS (type 2) / MX (type 15) answers.
  @visibleForTesting
  static List<String> parseDnsNames(Uint8List d, int type) {
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
      if (rtype == type) {
        out.add(type == 15 ? readName(rdata + 2).$1 : readName(rdata).$1);
      }
      pos = rdata + rdlen;
    }
    return out;
  }
}
