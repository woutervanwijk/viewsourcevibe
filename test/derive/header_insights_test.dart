import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/header_insights.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';

HeadersModel headers(PageInspection p) =>
    (deriveHeaders(p) as Present<HeadersModel>).value;

PageInspection withHeaders(Map<String, List<String>> h, {int status = 200}) =>
    urlInspection(
      url: 'https://a.test/',
      serverResult: server(serverSnapshot(
          url: 'https://a.test/',
          hops: [hop('https://a.test/', status, headers: h)],
          body: 'x')),
      browserResult: const Pending(),
    );

HeaderInsight insight(HeadersModel m, InsightId id) =>
    m.insights.singleWhere((i) => i.id == id);

void main() {
  group('deriveHeaders gate', () {
    test('a local file has no response headers', () {
      final o = deriveHeaders(localFile());
      expect(o, isA<Unavailable<HeadersModel>>());
      expect((o as Unavailable).detail, contains('local file'));
    });
  });

  group('unknown headers: every insight says so', () {
    for (final entry in {
      'pending': const Pending<Object?>(),
      'failed': const Failed<Object?>('network error: boom'),
    }.entries) {
      test(entry.key, () {
        final p = fullPage().copyWith(
            server: entry.key == 'pending'
                ? const Pending()
                : const Failed('network error: boom'));
        final m = headers(p);
        expect(m.known, isFalse);
        expect(m.insights, hasLength(6));
        for (final i in m.insights) {
          expect(i.detail, 'unknown — no server response');
          expect(i.tone, InsightTone.neutral);
          expect(i.label, endsWith('unknown'));
        }
        final text = m.insights.map((i) => i.label + i.detail).join(' ');
        for (final bad in ['No cache policy', 'No compression', 'No CORS']) {
          expect(text, isNot(contains(bad)));
        }
        expect(m.notes.single.text, contains('unknown'));
        expect(m.groups, isEmpty);
        expect(m.hops, isEmpty);
        expect(m.stateNote, isNotNull);
      });
    }
  });

  group('known headers', () {
    test('cache', () {
      expect(
          insight(
                  headers(withHeaders({
                    'cache-control': ['public, max-age=31536000']
                  })),
                  InsightId.cache)
              .label,
          'Cacheable');
      expect(
          insight(
                  headers(withHeaders({
                    'cache-control': ['max-age=60'],
                    'age': ['5']
                  })),
                  InsightId.cache)
              .detail,
          contains('Age is 5'));
      expect(
          insight(
                  headers(withHeaders({
                    'cache-control': ['no-store']
                  })),
                  InsightId.cache)
              .label,
          'No-store');
      // A response that really has no policy keeps the wording.
      expect(insight(headers(withHeaders({})), InsightId.cache).label,
          'No cache policy');
    });

    test('compression, vary, validators, cors', () {
      final m = headers(withHeaders({
        'content-encoding': ['br'],
        'vary': ['Accept', 'Accept-Encoding'],
        'etag': ['"a"'],
        'last-modified': ['x'],
        'access-control-allow-origin': ['*'],
        'access-control-allow-credentials': ['true'],
      }));
      expect(insight(m, InsightId.compression).label, 'BR');
      expect(insight(m, InsightId.negotiation).label, 'Vary: 2');
      expect(insight(m, InsightId.validators).label, '2 validators');
      expect(insight(m, InsightId.cors).label, 'Risky CORS');
      expect(insight(m, InsightId.cors).tone, InsightTone.bad);
    });

    test('cdn', () {
      expect(
          insight(
                  headers(withHeaders({
                    'server': ['cloudflare']
                  })),
                  InsightId.cdn)
              .label,
          'Cloudflare');
      expect(
          insight(
                  headers(withHeaders({
                    'x-cache': ['HIT from x']
                  })),
                  InsightId.cdn)
              .label,
          'Cache hit');
      expect(
          insight(headers(withHeaders({})), InsightId.cdn).label, 'Origin-ish');
    });

    test('evidence lists the headers the chip is based on', () {
      final m = headers(withHeaders({
        'cache-control': ['max-age=60'],
        'age': ['5']
      }));
      expect(insight(m, InsightId.cache).evidence,
          [('cache-control', 'max-age=60'), ('age', '5')]);
    });

    test('notes', () {
      final m = headers(withHeaders({
        'server': ['nginx'],
        'transfer-encoding': ['chunked'],
      }));
      final texts = m.notes.map((n) => n.text).toList();
      expect(texts,
          contains('Missing Content-Type makes content sniffing more likely.'));
      expect(
          texts, contains('X-Content-Type-Options: nosniff is not present.'));
      expect(texts,
          contains('Server technology is disclosed in response headers.'));
      expect(m.notes.length, lessThanOrEqualTo(4));
    });

    test('groups list the present headers of the final response', () {
      final m = headers(fullPage());
      final delivery = m.groups.singleWhere((g) => g.name == 'Delivery');
      expect(delivery.headers.map((h) => h.$1), ['server']);
      expect(m.groups.any((g) => g.name == 'Caching'), isFalse);
    });
  });

  group('headers as received, per hop', () {
    test('every hop with its headers; repeated values stay separate', () {
      final m = headers(fullPage());
      expect(m.hops, hasLength(3));
      expect(m.hops.last.title, 'Final response · 200 OK');
      expect(m.hops.first.title, 'Redirect 1 · 301 Moved');
      expect(m.hops.first.url, 'http://example.com/');
      final multi = headers(withHeaders({
        'vary': ['Accept', 'Accept-Encoding'],
        'set-cookie': ['a=1', 'b=2'],
      }));
      final vary = multi.hops.single.lines.singleWhere((l) => l.name == 'vary');
      expect(vary.values, ['Accept', 'Accept-Encoding']);
      expect(
          multi.hops.single.lines.map((l) => l.name), ['set-cookie', 'vary']);
    });
  });

  group('cache-control (RFC 9111)', () {
    HeaderInsight cache(String v) => insight(
        headers(withHeaders({
          'cache-control': [v]
        })),
        InsightId.cache);

    test('no-cache and max-age=0 always revalidate (info)', () {
      for (final v in ['no-cache', 'no-cache, max-age=86400', 'max-age=0']) {
        final i = cache(v);
        expect(i.label, 'Always revalidate', reason: v);
        expect(i.tone, InsightTone.info, reason: v);
      }
    });

    test('no-store wins and warns', () {
      final i = cache('no-store, max-age=100');
      expect(i.label, 'No-store');
      expect(i.tone, InsightTone.warn);
    });

    test('short cache is info, long is good', () {
      expect(cache('max-age=60').label, 'Short cache');
      expect(cache('max-age=60').tone, InsightTone.info);
      expect(cache('max-age=86400').label, 'Cacheable');
      expect(cache('max-age=86400').tone, InsightTone.good);
    });

    test('s-maxage is used and mentioned; private is mentioned', () {
      final s = cache('max-age=60, s-maxage=86400');
      expect(s.label, 'Cacheable');
      expect(s.detail, contains('s-maxage'));
      final p = cache('private, max-age=86400');
      expect(p.detail, contains('private'));
      expect(cache('private').label, isNot('No cache policy'));
    });
  });

  group('compression wording', () {
    test('no encoding says gzip/deflate and that br/zstd is not requested', () {
      final i = insight(headers(withHeaders({})), InsightId.compression);
      expect(i.label, 'No gzip/deflate compression');
      expect(i.detail, contains('br/zstd'));
      expect(i.tone, InsightTone.warn);
    });
  });

  group('cdn insight', () {
    HeaderInsight cdn(Map<String, List<String>> h) =>
        insight(headers(withHeaders(h)), InsightId.cdn);

    test('names the provider like the Sovereignty page', () {
      expect(
          cdn({
            'x-vercel-id': ['fra1::a']
          }).label,
          'Vercel');
      expect(
          cdn({
            'x-vercel-id': ['fra1::a']
          }).tone,
          InsightTone.brand);
      expect(
          cdn({
            'cf-ray': ['a-AMS']
          }).label,
          'Cloudflare');
      expect(
          cdn({
            'x-amz-cf-id': ['a']
          }).label,
          'Amazon (AWS)');
    });

    test('cache hit only as a HIT token in x-cache / cf-cache-status', () {
      expect(
          cdn({
            'server': ['Whitehall']
          }).label,
          isNot('Cache hit'));
      expect(
          cdn({
            'x-cache': ['Miss from cloudfront']
          }).label,
          isNot('Cache hit'));
      expect(
          cdn({
            'x-cache': ['HIT from x']
          }).label,
          'Cache hit');
      expect(
          cdn({
            'x-cache': ['hit']
          }).label,
          'Cache hit');
    });

    test('proxy headers without a provider stay Proxy/CDN', () {
      expect(
          cdn({
            'via': ['1.1 proxy']
          }).label,
          'Proxy/CDN');
    });
  });

  group('nosniff note', () {
    test('uses the same rule as the audit', () {
      List<String> notes(String v) => headers(withHeaders({
            'x-content-type-options': [v],
            'content-type': ['text/html'],
          })).notes.map((n) => n.text).toList();
      expect(notes('nosniff, nosniff').where((t) => t.contains('nosniff')),
          isEmpty);
      expect(notes('NOSNIFF').where((t) => t.contains('nosniff')), isEmpty);
      expect(notes('nope').where((t) => t.contains('nosniff')), isNotEmpty);
    });
  });
}
