import 'package:flutter/material.dart' show IconData, Icons;

import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../sovereignty_service.dart' show detectCdnFromHeaders;
import 'observed_text.dart';
import 'probe_general.dart' show probeGate;
import 'security_audit.dart' show isNosniff;

/// How an insight should look: the widget maps a tone to a colour.
enum InsightTone { good, warn, bad, neutral, info, brand }

enum InsightId { cache, compression, cdn, cors, negotiation, validators }

/// One chip of the Header Intelligence card.
class HeaderInsight {
  final InsightId id;
  final String label;
  final IconData icon;
  final InsightTone tone;
  final String detail;

  /// The (header name, value) pairs the insight is based on.
  final List<(String, String)> evidence;

  const HeaderInsight(this.id, this.label, this.icon, this.tone, this.detail,
      [this.evidence = const []]);
}

class HeaderNote {
  final IconData icon;
  final InsightTone tone;
  final String text;
  const HeaderNote(this.icon, this.tone, this.text);
}

class HeaderGroup {
  final String name;
  final List<(String, String)> headers;
  const HeaderGroup(this.name, this.headers);
}

/// A header as received: repeated headers keep every value on its own.
class HeaderLine {
  final String name;
  final List<String> values;
  const HeaderLine(this.name, this.values);
}

class HopHeaders {
  final String title;
  final String url;
  final List<HeaderLine> lines;
  const HopHeaders(this.title, this.url, this.lines);
}

/// The Headers tab. [known] is false until the server response is Present;
/// then every insight is "unknown — no server response" and [stateNote]
/// says why (still loading, failed, ...).
class HeadersModel {
  final bool known;

  /// True while the response is still being fetched.
  final bool loading;
  final String? stateNote;
  final List<HeaderInsight> insights;
  final List<HeaderNote> notes;
  final List<HeaderGroup> groups;
  final List<HopHeaders> hops;

  const HeadersModel({
    required this.known,
    required this.loading,
    required this.stateNote,
    required this.insights,
    required this.notes,
    required this.groups,
    required this.hops,
  });
}

const _unknownDetail = 'unknown — no server response';

const _unknownInsights = [
  HeaderInsight(InsightId.cache, 'Cache: unknown', Icons.help_outline,
      InsightTone.neutral, _unknownDetail),
  HeaderInsight(InsightId.compression, 'Compression: unknown', Icons.compress,
      InsightTone.neutral, _unknownDetail),
  HeaderInsight(InsightId.cdn, 'CDN/proxy: unknown', Icons.hub_outlined,
      InsightTone.neutral, _unknownDetail),
  HeaderInsight(InsightId.cors, 'CORS: unknown', Icons.public_off,
      InsightTone.neutral, _unknownDetail),
  HeaderInsight(InsightId.negotiation, 'Vary: unknown', Icons.swap_vert,
      InsightTone.neutral, _unknownDetail),
  HeaderInsight(InsightId.validators, 'Validators: unknown',
      Icons.remove_circle_outline, InsightTone.neutral, _unknownDetail),
];

const _categories = <String, List<String>>{
  'Caching': ['cache-control', 'etag', 'last-modified', 'expires', 'age'],
  'Delivery': [
    'server',
    'via',
    'x-cache',
    'cf-cache-status',
    'x-served-by',
    'content-encoding',
  ],
  'Negotiation': ['vary', 'content-type', 'content-language', 'accept-ranges'],
  'CORS': [
    'access-control-allow-origin',
    'access-control-allow-methods',
    'access-control-allow-headers',
    'access-control-allow-credentials',
  ],
};

List<(String, String)> _evidence(Map<String, String> h, List<String> names) => [
      for (final n in names)
        if (h[n] != null) (n, h[n]!),
    ];

HeaderInsight _cache(Map<String, String> h) {
  final age = h['age'];
  final ev = _evidence(h, ['cache-control', 'age', 'expires']);
  // RFC 9111 directives: name -> value ('' when it has none).
  final cc = <String, String>{};
  for (final part in (h['cache-control'] ?? '').toLowerCase().split(',')) {
    final kv = part.trim().split('=');
    if (kv.first.isNotEmpty) {
      cc[kv.first] = kv.skip(1).join('=').replaceAll('"', '');
    }
  }
  HeaderInsight make(String label, InsightTone tone, String detail) =>
      HeaderInsight(InsightId.cache, label, Icons.cached, tone, detail, ev);
  final ageText = age == null ? '' : ', Age is $age';
  final private =
      cc.containsKey('private') ? ' (private: browser cache only)' : '';
  if (cc.containsKey('no-store')) {
    return HeaderInsight(InsightId.cache, 'No-store', Icons.lock_outline,
        InsightTone.warn, 'Response should not be stored by caches.', ev);
  }
  final sMaxAge = int.tryParse(cc['s-maxage'] ?? '');
  final maxAge = int.tryParse(cc['max-age'] ?? '');
  final seconds = sMaxAge ?? maxAge;
  final source = sMaxAge != null ? 's-maxage' : 'max-age';
  if (cc.containsKey('no-cache') || seconds == 0) {
    return make('Always revalidate', InsightTone.info,
        'Caches must revalidate before reuse (${cc.containsKey('no-cache') ? 'no-cache' : '$source=0'})$private$ageText.');
  }
  if (seconds != null) {
    final long = seconds >= 86400;
    return make(
        long ? 'Cacheable' : 'Short cache',
        long ? InsightTone.good : InsightTone.info,
        'Cache-Control $source is ${seconds}s'
        '${sMaxAge != null ? ' for shared caches' : ''}$private$ageText.');
  }
  if (cc.containsKey('private')) {
    return make('Private cache', InsightTone.info,
        'Cache-Control private: only the browser may cache this.');
  }
  return HeaderInsight(
      InsightId.cache,
      'No cache policy',
      Icons.help_outline,
      InsightTone.neutral,
      'No explicit Cache-Control max-age/no-store directive found.',
      ev);
}

HeaderInsight _compression(Map<String, String> h) {
  final encoding = h['content-encoding']?.toLowerCase();
  final ev = _evidence(h, ['content-encoding']);
  if (encoding == null || encoding.isEmpty) {
    return HeaderInsight(
        InsightId.compression,
        'No gzip/deflate compression',
        Icons.compress,
        InsightTone.warn,
        'The server did not compress the response for gzip/deflate (the app does not request br/zstd).',
        ev);
  }
  return HeaderInsight(
      InsightId.compression,
      encoding.toUpperCase(),
      Icons.compress,
      InsightTone.good,
      'Response uses Content-Encoding: $encoding.',
      ev);
}

HeaderInsight _cdn(Map<String, String> h) {
  final ev =
      _evidence(h, ['server', 'via', 'cf-cache-status', 'cf-ray', 'x-cache']);
  final provider = detectCdnFromHeaders(h);
  if (provider != null) {
    return HeaderInsight(InsightId.cdn, provider.name, Icons.cloud_outlined,
        InsightTone.brand, '${provider.name} headers detected.', ev);
  }
  final hit = RegExp(r'\bHIT\b', caseSensitive: false);
  if (hit.hasMatch(h['x-cache'] ?? '') ||
      hit.hasMatch(h['cf-cache-status'] ?? '')) {
    return HeaderInsight(InsightId.cdn, 'Cache hit', Icons.speed,
        InsightTone.good, 'Proxy/cache header suggests a cache hit.', ev);
  }
  if (h.containsKey('via') || h.containsKey('x-cache')) {
    return HeaderInsight(InsightId.cdn, 'Proxy/CDN', Icons.hub_outlined,
        InsightTone.info, 'Proxy or cache headers detected.', ev);
  }
  return HeaderInsight(InsightId.cdn, 'Origin-ish', Icons.dns_outlined,
      InsightTone.neutral, 'No obvious CDN/proxy headers detected.', ev);
}

HeaderInsight _cors(Map<String, String> h) {
  final origin = h['access-control-allow-origin'];
  final credentials =
      h['access-control-allow-credentials']?.toLowerCase() == 'true';
  final ev = _evidence(
      h, ['access-control-allow-origin', 'access-control-allow-credentials']);
  if (origin == null || origin.isEmpty) {
    return HeaderInsight(
        InsightId.cors,
        'No CORS',
        Icons.public_off,
        InsightTone.neutral,
        'No Access-Control-Allow-Origin header found.',
        ev);
  }
  if (origin == '*' && credentials) {
    return HeaderInsight(
        InsightId.cors,
        'Risky CORS',
        Icons.warning_amber_rounded,
        InsightTone.bad,
        'Wildcard origin with credentials is unsafe and usually rejected.',
        ev);
  }
  return HeaderInsight(
      InsightId.cors,
      origin == '*' ? 'Open CORS' : 'CORS set',
      Icons.public,
      origin == '*' ? InsightTone.warn : InsightTone.good,
      'Access-Control-Allow-Origin: $origin.',
      ev);
}

HeaderInsight _negotiation(Map<String, String> h) {
  final vary = h['vary'];
  final ev = _evidence(h, ['vary']);
  if (vary == null || vary.isEmpty) {
    return HeaderInsight(InsightId.negotiation, 'No Vary', Icons.swap_vert,
        InsightTone.neutral, 'No Vary header found.', ev);
  }
  return HeaderInsight(
      InsightId.negotiation,
      'Vary: ${vary.split(',').length}',
      Icons.swap_vert,
      InsightTone.info,
      'Vary controls cache variants: $vary.',
      ev);
}

HeaderInsight _validators(Map<String, String> h) {
  final hasEtag = (h['etag'] ?? '').isNotEmpty;
  final hasLastModified = (h['last-modified'] ?? '').isNotEmpty;
  final ev = _evidence(h, ['etag', 'last-modified']);
  if (hasEtag || hasLastModified) {
    return HeaderInsight(
        InsightId.validators,
        hasEtag && hasLastModified ? '2 validators' : 'Validator',
        Icons.verified_outlined,
        InsightTone.good,
        'Conditional request validator is present.',
        ev);
  }
  return HeaderInsight(
      InsightId.validators,
      'No validator',
      Icons.remove_circle_outline,
      InsightTone.warn,
      'No ETag or Last-Modified header found.',
      ev);
}

List<HeaderNote> _notes(Map<String, String> h) {
  final notes = <HeaderNote>[];
  if ((h['content-type'] ?? '').isEmpty) {
    notes.add(const HeaderNote(Icons.warning_amber_rounded, InsightTone.warn,
        'Missing Content-Type makes content sniffing more likely.'));
  }
  if (!isNosniff(h['x-content-type-options'])) {
    notes.add(const HeaderNote(Icons.security, InsightTone.warn,
        'X-Content-Type-Options: nosniff is not present.'));
  }
  if ((h['server'] ?? '').isNotEmpty || (h['x-powered-by'] ?? '').isNotEmpty) {
    notes.add(const HeaderNote(Icons.badge_outlined, InsightTone.neutral,
        'Server technology is disclosed in response headers.'));
  }
  if ((h['content-length'] ?? '').isEmpty &&
      (h['transfer-encoding'] ?? '').isNotEmpty) {
    notes.add(const HeaderNote(Icons.alt_route, InsightTone.info,
        'Transfer-Encoding is used instead of a fixed Content-Length.'));
  }
  if (notes.isEmpty) {
    notes.add(const HeaderNote(Icons.check_circle_outline, InsightTone.good,
        'No obvious header hygiene notes.'));
  }
  return notes.take(4).toList();
}

String _hopTitle(int i, int count, HttpHop hop) {
  final status = hop.reasonPhrase.isEmpty
      ? '${hop.statusCode}'
      : '${hop.statusCode} ${hop.reasonPhrase}';
  return i == count - 1
      ? 'Final response · $status'
      : 'Redirect ${i + 1} · $status';
}

/// The Headers tab: insights from the final response's headers, the headers
/// of every hop as received. When the server response is not Present the
/// insights say "unknown" and nothing is judged.
Observed<HeadersModel> deriveHeaders(PageInspection p) {
  final gate = probeGate<HeadersModel>(p);
  if (gate != null) return gate;
  final server = p.server;
  if (server is! Present<ServerSnapshot> || server.value.hops.isEmpty) {
    final why = server is Present<ServerSnapshot>
        ? 'The server did not answer.'
        : server is Pending<ServerSnapshot>
            ? 'Fetching the response headers…'
            : notPresentText(server);
    return Present(
        HeadersModel(
          known: false,
          loading: server is Pending<ServerSnapshot>,
          stateNote: why,
          insights: _unknownInsights,
          notes: const [
            HeaderNote(Icons.help_outline, InsightTone.neutral,
                'Header hygiene cannot be judged: unknown — no server response.'),
          ],
          groups: const [],
          hops: const [],
        ),
        source: DataSource.server,
        provenance: Provenance.derived);
  }
  final hops = server.value.hops;
  final last = hops.last;
  final lookup = <String, String>{
    for (final e in last.headers.entries)
      if (e.value.isNotEmpty) e.key: e.value.join(', '),
  };
  return Present(
      HeadersModel(
        known: true,
        loading: false,
        stateNote: null,
        insights: [
          _cache(lookup),
          _compression(lookup),
          _cdn(lookup),
          _cors(lookup),
          _negotiation(lookup),
          _validators(lookup),
        ],
        notes: _notes(lookup),
        groups: [
          for (final c in _categories.entries)
            if (c.value.any((k) => (lookup[k] ?? '').isNotEmpty))
              HeaderGroup(c.key, [
                for (final k in c.value)
                  if ((lookup[k] ?? '').isNotEmpty) (k, lookup[k]!),
              ]),
        ],
        hops: [
          for (var i = 0; i < hops.length; i++)
            HopHeaders(
              _hopTitle(i, hops.length, hops[i]),
              hops[i].url.toString(),
              [
                for (final name in (hops[i].headers.keys.toList()..sort()))
                  HeaderLine(name, hops[i].headers[name]!),
              ],
            ),
        ],
      ),
      source: DataSource.server,
      provenance: Provenance.derived);
}
