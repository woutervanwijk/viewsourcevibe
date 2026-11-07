import '../models/inspection/observed.dart';
import '../models/inspection/page_inspection.dart';
import '../models/inspection/server_snapshot.dart';
import 'derive/cookies.dart';

/// The old `probeResult` map, built from the store's server data (and
/// robots), so widgets that still read the map keep working. The analyzed
/// cookies also include the cookies the browser reported, with their real
/// flags.
///
/// Returns null unless the server fetch is Present. Any value that is not
/// Present is left out of the map: unknown is never 0, '' or a placeholder.
Map<String, dynamic>? legacyProbeMap(PageInspection p) {
  final server = p.server;
  if (server is! Present<ServerSnapshot>) return null;
  final s = server.value;
  if (s.hops.isEmpty) return null;
  final last = s.hops.last;

  final headers = <String, String>{};
  last.headers.forEach((name, values) {
    if (name == 'set-cookie') return;
    headers[name] = values.join(', ');
  });

  final finalUrl = s.finalUrl;
  final isRedirect = s.hops.length > 1;
  final cookies = [for (final h in s.hops) ...h.setCookies];
  final body = s.body;
  final contentLength = body is Present<ServerBody>
      ? body.value.contentLength
      : const Pending<int>();
  final ip = last.remoteAddress;
  final timing = s.timingMs;
  final cert = s.certificate;

  final map = <String, dynamic>{
    'statusCode': last.statusCode,
    if (last.reasonPhrase.isNotEmpty) 'reasonPhrase': last.reasonPhrase,
    'headers': headers,
    'isRedirect': isRedirect,
    'url': s.requestedUrl.toString(),
    if (finalUrl is Present<Uri>) 'finalUrl': finalUrl.value.toString(),
    if (contentLength is Present<int>) 'contentLength': contentLength.value,
    if (ip is Present<String>) ...{'ip': ip.value, 'ipAddress': ip.value},
    if (timing is Present<int>) ...{
      'responseTime': timing.value,
      'timing': {'total': timing.value},
    },
    'security': {
      'Strict-Transport-Security': headers['strict-transport-security'],
      'Content-Security-Policy': headers['content-security-policy'],
      'X-Frame-Options': headers['x-frame-options'],
      'X-Content-Type-Options': headers['x-content-type-options'],
      'Referrer-Policy': headers['referrer-policy'],
      'Permissions-Policy': headers['permissions-policy'],
    },
    'cookies': cookies,
    'certificate': cert is Present<Map<String, dynamic>> ? cert.value : null,
    if (last.url.scheme == 'https') ...{
      'tlsInvalidCertificate': s.acceptedInvalidCertificate,
      'tlsWarning': s.acceptedInvalidCertificate
          ? 'TLS certificate validation failed. Content was loaded anyway for inspection.'
          : null,
    },
  };

  if (isRedirect) {
    map['redirectChain'] = [
      for (var i = 0; i < s.hops.length - 1; i++)
        {
          'from': s.hops[i].url.toString(),
          'to': s.hops[i + 1].url.toString(),
          'statusCode': s.hops[i].statusCode,
          'reasonPhrase': s.hops[i].reasonPhrase,
        },
    ];
    if (finalUrl is Present<Uri>) {
      map['redirectLocation'] = finalUrl.value.toString();
    }
  }

  final robots = p.robots;
  if (robots is Present<RobotsInfo>) {
    map['robotsSitemap'] = _robotsMap(s.requestedUrl, robots.value);
  }

  map['analyzedCookies'] = [
    for (final c in deriveCookies(p)) cookieInfoToMap(c),
  ];
  return map;
}

bool _ok(int status) => status >= 200 && status < 400;

Map<String, dynamic> _robotsMap(Uri page, RobotsInfo r) {
  final origin = Uri(scheme: page.scheme, host: page.host, port: page.port);
  final robotsUrl = origin.resolve('/robots.txt').toString();
  final sitemapUrl = origin.resolve('/sitemap.xml').toString();
  final status = r.robotsStatus;
  final sitemapStatus = r.sitemapStatus;
  final text = r.robotsText;
  final listed = r.sitemaps;
  final disallow = r.disallowCount;
  final allow = r.allowCount;

  final found = <String>{
    if (listed is Present<List<String>>) ...listed.value,
    if (sitemapStatus is Present<int> && _ok(sitemapStatus.value)) sitemapUrl,
  };

  final userAgents = <String>{};
  final sampleDisallow = <String>[];
  final sampleAllow = <String>[];
  if (text is Present<String>) {
    for (final raw in text.value.split(RegExp(r'\r?\n|\r'))) {
      final line = raw.split('#').first.trim();
      final i = line.indexOf(':');
      if (i <= 0) continue;
      final key = line.substring(0, i).trim().toLowerCase();
      final value = line.substring(i + 1).trim();
      if (value.isEmpty) continue;
      if (key == 'user-agent') userAgents.add(value);
      if (key == 'disallow') sampleDisallow.add(value);
      if (key == 'allow') sampleAllow.add(value);
    }
  }

  return {
    'robotsUrl': robotsUrl,
    'sitemapUrl': sitemapUrl,
    if (status is Present<int>) ...{
      'robotsStatus': status.value,
      'robotsPresent': _ok(status.value),
    },
    if (sitemapStatus is Present<int>) 'sitemapStatus': sitemapStatus.value,
    if (listed is Present<List<String>> || found.isNotEmpty)
      'sitemaps': found.toList()..sort(),
    if (disallow is Present<int>) 'disallowCount': disallow.value,
    if (allow is Present<int>) 'allowCount': allow.value,
    if (text is Present<String>) ...{
      'userAgents': userAgents.toList()..sort(),
      'sampleDisallow': sampleDisallow.take(8).toList(),
      'sampleAllow': sampleAllow.take(8).toList(),
    },
  };
}
