import 'dart:convert';

import '../models/inspection/browser_snapshot.dart';
import '../models/inspection/observed.dart';
import '../models/inspection/page_inspection.dart';
import '../models/inspection/server_snapshot.dart';
import 'derive/cookies_view.dart';
import 'derive/observed_text.dart' show notPresentAs;
import 'derive/page_weight.dart';
import 'derive/probe_general.dart';
import 'derive/security_audit.dart';
import 'observed_json.dart';

/// The data files of an inspection package, built from the store's
/// [PageInspection] and the derived models. Every value that can be unknown
/// is written as an observed value (see [observedJson]); nothing is
/// defaulted to 0, '' or 'N/A'. Cookie values never leave the app: cookies
/// are exported with their names, flags and the byte length of the value.
class InspectionExportData {
  const InspectionExportData._();

  /// A Set-Cookie header line with the value replaced by its byte length.
  static String redactSetCookie(String line) {
    final parts = line.split(';');
    final first = parts.first;
    final eq = first.indexOf('=');
    final name = eq < 0 ? first.trim() : first.substring(0, eq).trim();
    final value = eq < 0 ? '' : first.substring(eq + 1);
    final bytes = utf8.encode(value).length;
    return [
      '$name=<redacted, $bytes bytes>',
      ...parts.skip(1).map((a) => a.trim()),
    ].join('; ');
  }

  static Map<String, Object?> _hop(HttpHop h) => {
        'url': h.url.toString(),
        'statusCode': h.statusCode,
        if (h.reasonPhrase.isNotEmpty) 'reasonPhrase': h.reasonPhrase,
        'remoteAddress':
            observedPlain(h.remoteAddress, source: DataSource.server),
        'certificate': observedPlain(h.certificate, source: DataSource.server),
        'setCookieCount': h.setCookies.length,
      };

  /// network/probe.json: what the app's own request got.
  static Map<String, Object?> server(PageInspection p) => observedJson(
        p.server,
        (s) => {
          'requestedUrl': s.requestedUrl.toString(),
          'userAgent': s.userAgent,
          'hops': [for (final h in s.hops) _hop(h)],
          'finalUrl': observedJson(s.finalUrl, (u) => u.toString(),
              source: DataSource.server),
          'timingMs': observedPlain(s.timingMs, source: DataSource.server),
          'acceptedInvalidCertificate': s.acceptedInvalidCertificate,
          'body': observedJson(
            s.body,
            (b) => {
              'byteLength': b.byteLength,
              'transferLength': b.transferLength,
              'truncated': b.truncated,
              'isBinary': b.decoded.isBinary,
              'contentLength':
                  observedPlain(b.contentLength, source: DataSource.server),
              if (b.contentEncoding != null)
                'contentEncoding': b.contentEncoding,
            },
            source: DataSource.server,
          ),
        },
        source: DataSource.server,
      );

  static Object? _storageArea(StorageArea a) => {
        'count': a.count,
        'bytes': observedPlain(a.bytes, source: DataSource.browser),
        // Keys and sizes only, never values.
        'topItems': [
          for (final i in a.topItems) {'key': i.key, 'bytes': i.bytes},
        ],
      };

  /// network/browser-probe.json: what the browser reported (no cookie or
  /// storage values).
  static Map<String, Object?> browser(PageInspection p) => observedJson(
        p.browser,
        (b) => {
          'url': b.url.toString(),
          'platform': b.platform.name,
          'contentType':
              observedPlain(b.contentType, source: DataSource.browser),
          'resourceCount': observedPlain<int>(
              switch (b.resources) {
                Present<List<ResourceEntry>>(:final value, :final source) =>
                  Present(value.length, source: source),
                Pending<List<ResourceEntry>>() => const Pending(),
                Failed<List<ResourceEntry>>(:final error) => Failed(error),
                Unavailable<List<ResourceEntry>>(
                  :final reason,
                  :final detail
                ) =>
                  Unavailable(reason, detail),
              },
              source: DataSource.browser),
          'resourcesTruncated': b.resourcesTruncated,
          'resourcesDropped': b.resourcesDropped,
          'cookieCount': observedPlain<int>(
              switch (b.cookies) {
                Present<List<BrowserCookie>>(:final value, :final source) =>
                  Present(value.length, source: source),
                Pending<List<BrowserCookie>>() => const Pending(),
                Failed<List<BrowserCookie>>(:final error) => Failed(error),
                Unavailable<List<BrowserCookie>>(
                  :final reason,
                  :final detail
                ) =>
                  Unavailable(reason, detail),
              },
              source: DataSource.browser),
          'storage': observedJson(
            b.storage,
            (s) => {
              'local': observedJson(s.local, _storageArea,
                  source: DataSource.browser),
              'session': observedJson(s.session, _storageArea,
                  source: DataSource.browser),
            },
            source: DataSource.browser,
          ),
          'navigation': observedJson(
            b.navigation,
            (n) => {
              'timeToFirstByte':
                  observedPlain(n.timeToFirstByte, source: DataSource.browser),
              'domInteractive':
                  observedPlain(n.domInteractive, source: DataSource.browser),
              'domContentLoaded':
                  observedPlain(n.domContentLoaded, source: DataSource.browser),
              'loadEvent':
                  observedPlain(n.loadEvent, source: DataSource.browser),
              'protocol': observedPlain(n.protocol, source: DataSource.browser),
            },
            source: DataSource.browser,
          ),
          'snapshotTimeMs':
              observedPlain(b.snapshotTimeMs, source: DataSource.browser),
        },
        source: DataSource.browser,
      );

  /// network/headers.json: the headers of every hop, as received. Set-Cookie
  /// values are replaced by their length.
  static Map<String, Object?> headers(PageInspection p) => observedJson(
        p.server,
        (s) => {
          'hops': [
            for (final h in s.hops)
              {
                'url': h.url.toString(),
                'statusCode': h.statusCode,
                'headers': {
                  for (final e in h.headers.entries)
                    e.key: e.key == 'set-cookie'
                        ? [for (final v in e.value) redactSetCookie(v)]
                        : e.value,
                },
              },
          ],
        },
        source: DataSource.server,
      );

  /// network/redirects.json
  static Map<String, Object?> redirects(Observed<GeneralModel> general) {
    final status = switch (general) {
      Present<GeneralModel>(:final value) => value.status,
      Pending<GeneralModel>() => const Pending<ServerStatus>(),
      Failed<GeneralModel>(:final error) => Failed<ServerStatus>(error),
      Unavailable<GeneralModel>(:final reason, :final detail) =>
        Unavailable<ServerStatus>(reason, detail),
    };
    return observedJson(
      status,
      (s) => {
        'steps': [
          for (final r in s.redirects)
            {'status': r.statusText, 'from': r.from, 'to': r.to},
        ],
      },
      source: DataSource.server,
    );
  }

  /// network/cookies.json: names and flags, never values.
  static Map<String, Object?> cookies(Observed<CookiesModel> cookies) =>
      observedJson(
        cookies,
        (m) => {
          'complete': m.complete,
          if (m.sourcesNote != null) 'sourcesNote': m.sourcesNote,
          'cookies': [
            for (final c in m.rows)
              {
                'name': c.name,
                'valueBytes': c.valueBytes,
                'domain': c.domain,
                'path': c.path,
                'expires': c.expires,
                'sameSite': c.sameSite,
                'secure': c.secure,
                'httpOnly': c.httpOnly,
                'category': c.category,
                if (c.provider != null) 'provider': c.provider,
                'source': c.source,
              },
          ],
        },
        source: DataSource.server,
        provenance: Provenance.derived,
      );

  /// network/timeline.json: every request; a time or size the browser did
  /// not report is an unavailable observed value, never 0.
  static Map<String, Object?> timeline(PageInspection p) {
    final b = p.browser;
    final resources = b is Present<BrowserSnapshot>
        ? b.value.resources
        : switch (b) {
            Pending<BrowserSnapshot>() => const Pending<List<ResourceEntry>>(),
            Failed<BrowserSnapshot>(:final error) =>
              Failed<List<ResourceEntry>>(error),
            Unavailable<BrowserSnapshot>(:final reason, :final detail) =>
              Unavailable<List<ResourceEntry>>(reason, detail),
            Present<BrowserSnapshot>() => const Pending<List<ResourceEntry>>(),
          };
    return observedJson(
      resources,
      (list) => [
        for (final r in list)
          {
            'url': r.url,
            'type': r.type,
            'collectedBy': r.source.name,
            'startTime': observedPlain(r.startTime, source: DataSource.browser),
            'duration': observedPlain(r.duration, source: DataSource.browser),
            'transfer': observedPlain(r.transfer, source: DataSource.browser),
            'decoded': observedPlain(r.decoded, source: DataSource.browser),
          },
      ],
      source: DataSource.browser,
    );
  }

  /// analysis/page-weight.json
  static Map<String, Object?> pageWeight(PageInspection p) {
    final w = derivePageWeight(p);
    final b = p.browser;
    if (w == null) {
      final why = b is Present<BrowserSnapshot> ? b.value.resources : b;
      return observedJson<Object>(
          switch (why) {
            Pending() => const Pending<Object>(),
            Failed(:final error) => Failed<Object>(error),
            Unavailable(:final reason, :final detail) =>
              Unavailable<Object>(reason, detail),
            Present() => const Pending<Object>(),
          },
          (v) => v,
          source: DataSource.browser);
    }
    return {
      'status': 'present',
      'source': 'browser',
      'provenance': w.provenance.name,
      'value': {
        'transfer': w.transfer,
        'decoded': w.decoded,
        'isPartial': w.isPartial,
        if (w.documentSource != null) 'documentSource': w.documentSource!.name,
        'breakdown': {
          for (final e in w.breakdown.entries)
            e.key: {
              'count': e.value.count,
              'transfer': e.value.transfer,
              'decoded': e.value.decoded,
            },
        },
      },
    };
  }

  /// analysis/security-scorecard.json
  static Map<String, Object?> securityScorecard(Observed<SecurityModel> s) =>
      observedJson(
        s,
        (m) => {
          'audit': observedJson(
            m.audit,
            (a) => {
              'passed': a.passed,
              'total': a.total,
              'percentage': a.percentage,
              'checks': [
                for (final c in a.checks)
                  {
                    'label': c.label,
                    'applicable': c.applicable,
                    'passing': c.passing,
                    'detail': c.detail,
                  },
              ],
              'headers': {for (final r in a.rows) r.name: r.value},
            },
            source: DataSource.server,
            provenance: Provenance.derived,
          ),
          'csp': observedJson(
            m.csp,
            (c) => {
              'score': c.score,
              'policies': [
                for (final pol in c.policies)
                  {
                    'score': pol.score,
                    'directives': [
                      for (final d in pol.directives)
                        {'name': d.$1, 'sources': d.$2},
                    ],
                    'findings': [for (final f in pol.findings) f.text],
                  },
              ],
            },
            source: DataSource.server,
            provenance: Provenance.derived,
          ),
        },
        source: DataSource.server,
        provenance: Provenance.derived,
      );

  /// analysis/certificate.json
  static Map<String, Object?> certificate(Observed<SecurityModel> s) =>
      observedJson(
        switch (s) {
          Present<SecurityModel>(:final value) => value.certificate,
          Pending<SecurityModel>() => const Pending<CertificateModel>(),
          Failed<SecurityModel>(:final error) =>
            Failed<CertificateModel>(error),
          Unavailable<SecurityModel>(:final reason, :final detail) =>
            Unavailable<CertificateModel>(reason, detail),
        },
        (c) => {
          'validity': c.validityLabel,
          'host': c.hostLabel,
          'subject': c.subject.isEmpty ? c.subjectRaw : c.subject,
          'issuer': c.issuer.isEmpty ? c.issuerRaw : c.issuer,
          'validFrom': c.validFrom,
          'validUntil': c.validUntil,
          if (c.pem != null) 'pem': c.pem,
        },
        source: DataSource.server,
      );

  /// analysis/robots-sitemap.json
  static Map<String, Object?> robots(Observed<GeneralModel> general) {
    final robots = switch (general) {
      Present<GeneralModel>(:final value) => value.robots,
      Pending<GeneralModel>() => const Pending<RobotsCard>(),
      Failed<GeneralModel>(:final error) => Failed<RobotsCard>(error),
      Unavailable<GeneralModel>(:final reason, :final detail) =>
        Unavailable<RobotsCard>(reason, detail),
    };
    return observedJson(
      robots,
      (r) => {
        'robotsUrl': r.robotsUrl,
        'robots': r.robotsLabel,
        'sitemaps': r.sitemaps,
        'sitemapsLabel': r.sitemapsLabel,
        'disallow': r.disallowLabel,
        'allow': r.allowLabel,
        if (r.truncatedNote != null) 'note': r.truncatedNote,
        'sampleDisallow': r.sampleDisallow,
      },
      source: DataSource.server,
    );
  }

  /// manifest `source`: what was inspected, its size and last-modified time
  /// as observed values. A picked or shared file has no known modification
  /// time (the platform does not tell), so it is exported as unavailable.
  static Map<String, Object?> manifestSource(
      PageInspection p, String name, String path) {
    final t = p.target;
    if (t is FileTarget) {
      final f = t.file;
      return {
        'kind': 'file',
        'name': name,
        'path': path,
        'isUrl': false,
        'size': {
          'status': 'present',
          'value': f.byteLength,
          'source': 'file',
          'provenance': 'measured',
        },
        'lastModified': observedJson<DateTime>(
            f.lastModified, (d) => d.toUtc().toIso8601String(),
            source: DataSource.file),
      };
    }
    final server = p.server;
    Observed<int> size = const Pending();
    Observed<String> lastModified = const Pending();
    if (server is Present<ServerSnapshot>) {
      final body = server.value.body;
      size = switch (body) {
        Present<ServerBody>(:final value) =>
          Present(value.byteLength, source: DataSource.server),
        Pending<ServerBody>() => const Pending(),
        Failed<ServerBody>(:final error) => Failed(error),
        Unavailable<ServerBody>(:final reason, :final detail) =>
          Unavailable(reason, detail),
      };
      final lm = server.value.hops.isEmpty
          ? null
          : server.value.hops.last.header('last-modified');
      lastModified = lm == null
          ? const Unavailable(
              UnavailableReason.notReportedByServer, 'no Last-Modified header')
          : Present(lm, source: DataSource.server);
    } else {
      size = notPresentAs<int>(server);
      lastModified = notPresentAs<String>(server);
    }
    return {
      'kind': 'url',
      'name': name,
      'path': path,
      'isUrl': true,
      'size': observedPlain(size, source: DataSource.server),
      'lastModified': observedPlain(lastModified, source: DataSource.server),
    };
  }
}
