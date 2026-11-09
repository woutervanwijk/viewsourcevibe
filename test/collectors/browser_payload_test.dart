import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/collectors/browser_payload.dart';
import 'package:view_source_vibe/services/collectors/vsv_collect_js.dart';

String fixture(String name) =>
    File('test/fixtures/browser/$name').readAsStringSync();

T present<T>(Observed<T> o) {
  expect(o, isA<Present<T>>(), reason: '$o');
  return (o as Present<T>).value;
}

UnavailableReason unavailable<T>(Observed<T> o) {
  expect(o, isA<Unavailable<T>>(), reason: '$o');
  return (o as Unavailable<T>).reason;
}

ResourceEntry byUrl(BrowserSnapshot s, String url) =>
    present(s.resources).firstWhere((e) => e.url == url);

BrowserSnapshot parse(String name, BrowserPlatform p, String page) =>
    parseBrowserPayload(fixture(name), p, pageUrl: Uri.parse(page));

void main() {
  test('every fixture is marked synthetic with a note', () {
    final dir = Directory('test/fixtures/browser');
    final files = dir.listSync().whereType<File>().toList();
    expect(files.length, 8);
    for (final f in files) {
      final j = jsonDecode(f.readAsStringSync()) as Map;
      expect(j['_synthetic'], true, reason: f.path);
      expect(j['_note'], isA<String>(), reason: f.path);
    }
  });

  group('iOS cross-origin', () {
    final s = parse('ios_cross_origin_rtvutrecht.json', BrowserPlatform.ios,
        'https://www.rtvutrecht.nl/');

    test('cross-origin 0/0 is blockedByPlatform, not 0', () {
      final e = byUrl(s, 'https://cdn.example.net/lib.js');
      expect(unavailable(e.transfer), UnavailableReason.blockedByPlatform);
      expect(unavailable(e.decoded), UnavailableReason.blockedByPlatform);
      // timing is still known
      expect(present(e.startTime), 60.0);
      expect(present(e.duration), 200.0);
    });

    test('same-origin sizes are measured', () {
      final e = byUrl(s, 'https://www.rtvutrecht.nl/static/app.css');
      expect(present(e.transfer), 12000);
      expect(present(e.decoded), 50000);
    });

    test('WebKit image decoded is notReportedByPlatform, transfer kept', () {
      final e = byUrl(s, 'https://www.rtvutrecht.nl/img/logo.png');
      expect(unavailable(e.decoded), UnavailableReason.notReportedByPlatform);
      expect(present(e.transfer), 5000);
    });

    test('other sections', () {
      expect(present(s.contentType), 'text/html');
      final dom = present(s.renderedDom);
      expect(dom.domCharCount, dom.text.length);
      expect(dom.limitations, ['iframes not included (1)']);
      expect(present(s.snapshotTimeMs), 15234.5);
      expect(present(s.navigation).protocol, isA<Present<String>>());
      final storage = present(s.storage);
      final local = present(storage.local);
      expect(local.count, 2);
      // UTF-8: "consent"(7) + "é€"(2+3) = 12, "theme"+"dark" = 9
      expect(present(local.bytes), 21);
      expect(local.topItems.first.key, 'consent');
      expect(s.rawPayload, isNotNull);
    });

    test('document.cookie flags are notExposedToPage', () {
      final c = present(s.cookies);
      expect(c.map((x) => x.name), ['a', 'b']);
      expect(c.first.value, '1');
      expect(
          unavailable(c.first.isHttpOnly), UnavailableReason.notExposedToPage);
      expect(unavailable(c.first.isSecure), UnavailableReason.notExposedToPage);
    });
  });

  test('Android cache hit: counted at its encoded size, decoded kept', () {
    final s = parse('android_cache_hit.json', BrowserPlatform.android,
        'https://example.com/');
    final e = byUrl(s, 'https://example.com/app.js');
    // transferSize 0 (cache) -> the encoded body a fresh load downloads.
    expect(present(e.transfer), 30000);
    expect((e.transfer as Present<int>).provenance, Provenance.derived);
    expect(e.fromCache, isTrue);
    expect(byUrl(s, 'https://example.com/photo.jpg').fromCache, isFalse);
    expect(present(e.decoded), 90000);
    // Android image decoded is real
    final img = byUrl(s, 'https://example.com/photo.jpg');
    expect(present(img.decoded), 39800);
    expect(present(s.cookies), isEmpty);
  });

  test('iframe entries keep the frame origin; the page\'s own do not', () {
    final s = parse('iframe_resources.json', BrowserPlatform.android,
        'https://example.com/');
    final own = byUrl(s, 'https://example.com/app.js');
    expect(own.inFrame, isFalse);
    // The iframe document itself is loaded by the page.
    expect(byUrl(s, 'https://ads.example.net/frame.html').inFrame, isFalse);
    final ad = byUrl(s, 'https://ads.example.net/ad.js');
    expect(ad.frameOrigin, 'https://ads.example.net');
    expect(present(ad.transfer), 5000);
    final img = byUrl(s, 'https://ads.example.net/creative.jpg');
    expect(img.inFrame, isTrue);
    // Zeros from a cross-origin creative stay unknown, never 0.
    expect(img.transfer, isA<Unavailable<int>>());
    // A later report keeps where it was first seen.
    final merged = mergeResources([ad], [
      ResourceEntry(
          url: ad.url,
          type: 'script',
          source: ResourceSource.observer,
          startTime: ad.startTime,
          duration: ad.duration,
          transfer: ad.transfer,
          decoded: ad.decoded)
    ]).single;
    expect(merged.frameOrigin, 'https://ads.example.net');
  });

  test('the bootstrap runs in iframes and posts to the top frame', () {
    expect(vsvResourceBootstrapJs, contains('__vsv_frame'));
    expect(vsvResourceBootstrapJs, contains('ev.source === window'));
    expect(vsvCollectJs, contains('item.fr = 1'));
  });

  test('macOS: patch-only entry carries content-length as transfer', () {
    final s = parse('macos_basic.json', BrowserPlatform.macos,
        'https://example.com/index.html');
    final api = byUrl(s, 'https://example.com/api/items');
    expect(api.source, ResourceSource.patch);
    expect(present(api.transfer), 812);
    expect(unavailable(api.decoded), UnavailableReason.notReportedByPlatform);
    expect(unavailable(api.duration), UnavailableReason.notReportedByPlatform);
    expect(present(api.startTime), 1500.0);
    expect(byUrl(s, 'https://example.com/main.js').source,
        ResourceSource.observer);
    // load event not yet fired
    expect(present(s.navigation).loadEvent, isA<Pending<double>>());
    expect(present(s.renderedDom).shadowRootCount, 2);
  });

  test('relative and absolute fetch URL become one entry, observer wins', () {
    final s = parse('fetch_relative_dupes.json', BrowserPlatform.android,
        'https://example.com/app/');
    final list = present(s.resources);
    expect(list.length, 2);
    final e = byUrl(s, 'https://example.com/api/data.json');
    expect(e.source, ResourceSource.observer);
    expect(present(e.transfer), 700);
    final x = byUrl(s, 'https://example.com/other.json');
    expect(x.source, ResourceSource.patch);
    expect(x.type, 'xhr');
  });

  test('storage SecurityError fails only that area', () {
    final s = parse('storage_security_error.json', BrowserPlatform.ios,
        'https://example.com/');
    final storage = present(s.storage);
    expect(storage.local, isA<Failed<StorageArea>>());
    expect((storage.local as Failed).error, contains('SecurityError'));
    expect(present(present(storage.session).bytes), 2);
    expect(present(s.resources).length, 1);
    expect(present(s.cookies).single.name, 'k');
  });

  test('a section error fails only that section (B22)', () {
    final j = jsonDecode(fixture('macos_basic.json')) as Map<String, dynamic>;
    j['dom'] = {'ok': false, 'error': 'boom'};
    final s = parseBrowserPayload(jsonEncode(j), BrowserPlatform.macos,
        pageUrl: Uri.parse('https://example.com/index.html'));
    expect((s.renderedDom as Failed).error, 'boom');
    expect(present(s.resources).length, 2);
    expect(present(s.cookies).length, 1);
  });

  group('unusable payloads', () {
    test('non-String result is unsupportedPlatform in every section', () {
      final obj =
          (jsonDecode(fixture('windows_nonstring.json')) as Map)['payload'];
      for (final raw in [obj, null, 42]) {
        final s = parseBrowserPayload(raw, BrowserPlatform.windows,
            pageUrl: Uri.parse('https://example.com/'));
        expect(unavailable(s.resources), UnavailableReason.unsupportedPlatform);
        expect(unavailable(s.cookies), UnavailableReason.unsupportedPlatform);
        expect(unavailable(s.storage), UnavailableReason.unsupportedPlatform);
        expect(
            unavailable(s.renderedDom), UnavailableReason.unsupportedPlatform);
      }
    });

    test('unparsable string is Failed', () {
      final s = parseBrowserPayload('<not json', BrowserPlatform.android,
          pageUrl: Uri.parse('https://example.com/'));
      expect(s.resources, isA<Failed<List<ResourceEntry>>>());
      expect(s.rawPayload, '<not json');
    });

    test('double-encoded JSON string is accepted', () {
      final s = parseBrowserPayload(
          jsonEncode(fixture('android_cache_hit.json')),
          BrowserPlatform.android,
          pageUrl: Uri.parse('https://example.com/'));
      expect(present(s.resources).length, 2);
    });
  });

  group('DOM <pre> unwrap', () {
    test('HTML page with <pre> and no DOCTYPE keeps its DOM', () {
      final s = parse('page_with_pre.json', BrowserPlatform.ios,
          'https://example.com/readme');
      final dom = present(s.renderedDom);
      expect(dom.unwrappedRawDocument, false);
      expect(dom.text, startsWith('<html><head></head><body><h1>Readme'));
      expect(dom.text, contains('<pre>a &lt; b &amp;&amp; c</pre>'));
    });

    test('even when raw is present, HTML is never unwrapped', () {
      final j =
          jsonDecode(fixture('page_with_pre.json')) as Map<String, dynamic>;
      (j['dom'] as Map)['raw'] = 'a < b';
      final s = parseBrowserPayload(jsonEncode(j), BrowserPlatform.ios,
          pageUrl: Uri.parse('https://example.com/readme'));
      expect(present(s.renderedDom).unwrappedRawDocument, false);
    });

    for (final ct in [
      'text/plain',
      'application/json',
      'application/javascript',
      'text/css; charset=utf-8',
    ]) {
      test('$ct is unwrapped to raw text', () {
        final j =
            jsonDecode(fixture('page_with_pre.json')) as Map<String, dynamic>;
        j['contentType'] = ct;
        j['dom'] = {
          'ok': true,
          'value': '<html><body><pre>{&quot;a&quot;:1}</pre></body></html>',
          'raw': '{"a":1}',
        };
        final s = parseBrowserPayload(jsonEncode(j), BrowserPlatform.ios,
            pageUrl: Uri.parse('https://example.com/x'));
        final dom = present(s.renderedDom);
        expect(dom.unwrappedRawDocument, true);
        expect(dom.text, '{"a":1}');
        expect(dom.domCharCount, 7);
      });
    }
  });

  group('mergeResources', () {
    ResourceEntry entry(String url,
            {Observed<double>? start,
            Observed<double>? dur,
            Observed<int>? tx,
            Observed<int>? dec,
            ResourceSource src = ResourceSource.observer}) =>
        ResourceEntry(
          url: url,
          type: 'script',
          source: src,
          startTime: start ??
              const Unavailable(UnavailableReason.notReportedByPlatform),
          duration:
              dur ?? const Unavailable(UnavailableReason.notReportedByPlatform),
          transfer:
              tx ?? const Unavailable(UnavailableReason.blockedByPlatform),
          decoded:
              dec ?? const Unavailable(UnavailableReason.blockedByPlatform),
        );
    Present<T> p<T>(T v) => Present(v, source: DataSource.browser);

    test('keeps startTime/duration and measured sizes; adds new entries', () {
      final old = [
        entry('https://a/x',
            start: p(10.0), dur: p(5.0), tx: p(100), dec: p(300)),
      ];
      final fresh = [
        entry('https://a/x'), // all Unavailable
        entry('https://a/y', start: p(20.0)),
      ];
      final m = mergeResources(old, fresh);
      expect(m.length, 2);
      final x = m.firstWhere((e) => e.url == 'https://a/x');
      expect(present(x.startTime), 10.0);
      expect(present(x.duration), 5.0);
      expect(present(x.transfer), 100);
      expect(present(x.decoded), 300);
    });

    test('fresh Present values win', () {
      final m = mergeResources(
        [entry('https://a/x', start: p(10.0), tx: p(100))],
        [entry('https://a/x', start: p(11.0), tx: p(120))],
      );
      expect(present(m.single.startTime), 11.0);
      expect(present(m.single.transfer), 120);
    });

    test(
        'Unavailable fills in when old had nothing; patch never beats observer',
        () {
      final m = mergeResources(
        [entry('https://a/x', tx: p(100))],
        [entry('https://a/x', tx: p(999), src: ResourceSource.patch)],
      );
      expect(m.single.source, ResourceSource.observer);
      expect(present(m.single.transfer), 100);
    });
  });

  group('parseNativeCookies', () {
    test('iOS keeps flags', () {
      final c = parseNativeCookies([
        {
          'name': 'sid',
          'value': 'x',
          'domain': '.example.com',
          'path': '/',
          'expiresDate': 1893456000000,
          'isSecure': true,
          'isHttpOnly': false,
          'sameSite': 'LAX',
        },
        {'name': 'tmp', 'value': 'y', 'expiresDate': null, 'isSecure': false},
      ], BrowserPlatform.ios);
      expect(present(c[0].isSecure), true);
      expect(present(c[0].isHttpOnly), false);
      expect(present(c[0].domain), '.example.com');
      expect(present(c[0].sameSite), 'LAX');
      expect(present(c[0].expires).toUtc().year, 2030);
      expect(unavailable(c[1].expires), UnavailableReason.notApplicable);
      expect(present(c[1].isSecure), false);
      expect(unavailable(c[1].isHttpOnly), UnavailableReason.notExposedToPage);
    });

    test('Android without flags is Unavailable, never false', () {
      final c = parseNativeCookies([
        {'name': 'sid', 'value': 'x', 'expiresDate': null},
        {
          'name': 'n',
          'value': 'v',
          'expiresDate': null,
          'isSecure': null,
          'isHttpOnly': null
        },
      ], BrowserPlatform.android);
      for (final x in c) {
        expect(unavailable(x.isSecure), UnavailableReason.notExposedToPage);
        expect(unavailable(x.isHttpOnly), UnavailableReason.notExposedToPage);
        expect(unavailable(x.domain), UnavailableReason.notExposedToPage);
        expect(unavailable(x.expires), UnavailableReason.notExposedToPage);
        expect(unavailable(x.sameSite), UnavailableReason.notExposedToPage);
      }
      expect(c.first.value, 'x');
    });
  });

  group('fix round 1', () {
    BrowserSnapshot build(
      List<Map<String, dynamic>> observer, {
      String payloadUrl = 'https://example.com/',
      String pageUrl = 'https://example.com/',
      BrowserPlatform platform = BrowserPlatform.ios,
      Map<String, dynamic> resources = const {},
      List<Map<String, dynamic>> patch = const [],
      Object? domValue = '<html></html>',
    }) {
      final j = {
        'v': 1,
        'url': payloadUrl,
        'contentType': 'text/html',
        'timing': {'ok': true, 'now': 1000.0},
        'dom': {'ok': true, 'value': domValue, 'iframes': 0, 'shadowRoots': 0},
        'resources': {
          'ok': true,
          'bootstrap': true,
          'dropped': 0,
          'observer': observer,
          'patch': patch,
          ...resources,
        },
        'navigation': {'ok': false, 'error': 'x'},
        'storage': {
          'local': {'ok': false, 'error': 'x'},
          'session': {'ok': false, 'error': 'x'},
        },
        'cookies': {'ok': true, 'raw': ''},
      };
      return parseBrowserPayload(jsonEncode(j), platform,
          pageUrl: Uri.parse(pageUrl));
    }

    Map<String, dynamic> res(String n,
            {Object? tx = 0, Object? enc = 0, Object? dec = 0}) =>
        {
          'n': n,
          'it': 'script',
          'st': 1.0,
          'du': 2.0,
          'tx': tx,
          'enc': enc,
          'dec': dec
        };

    test('1: origin comes from the payload url, not the caller pageUrl', () {
      final s = build(
        [res('https://a.com/y.js'), res('https://b.com/x.js')],
        payloadUrl: 'https://b.com/landing',
        pageUrl: 'https://a.com/',
      );
      final cross = byUrl(s, 'https://a.com/y.js');
      expect(unavailable(cross.transfer), UnavailableReason.blockedByPlatform);
      expect(unavailable(cross.decoded), UnavailableReason.blockedByPlatform);
    });

    test('1: missing payload url falls back to pageUrl', () {
      final j = jsonDecode(fixture('ios_cross_origin_rtvutrecht.json'))
          as Map<String, dynamic>;
      j.remove('url');
      final s = parseBrowserPayload(jsonEncode(j), BrowserPlatform.ios,
          pageUrl: Uri.parse('https://www.rtvutrecht.nl/'));
      expect(unavailable(byUrl(s, 'https://cdn.example.net/lib.js').transfer),
          UnavailableReason.blockedByPlatform);
    });

    for (final local in [
      'file:///tmp/a.html',
      'about:blank',
      'data:text/html,x'
    ]) {
      test('1: local page $local has no measurable resource sizes', () {
        final s = build(
          [res('https://cdn.example.net/a.js', tx: 10, enc: 9, dec: 30)],
          payloadUrl: local,
          pageUrl: local,
          patch: [
            {
              'n': 'https://cdn.example.net/api',
              'it': 'fetch',
              'cl': 5,
              'st': 1.0
            }
          ],
        );
        for (final e in present(s.resources)) {
          expect(
              unavailable(e.transfer), UnavailableReason.notReportedByPlatform);
          expect(
              unavailable(e.decoded), UnavailableReason.notReportedByPlatform);
          expect((e.transfer as Unavailable).detail,
              'resource sizes not measurable for local pages');
        }
      });
    }

    test('2: undefined size fields are Unavailable, never 0', () {
      final s = build([
        res('https://example.com/a.js', tx: null, enc: null, dec: null),
        res('https://example.com/b.js', tx: null, enc: 10, dec: 20),
      ]);
      final a = byUrl(s, 'https://example.com/a.js');
      expect(unavailable(a.transfer), UnavailableReason.notReportedByPlatform);
      expect(unavailable(a.decoded), UnavailableReason.notReportedByPlatform);
      final b = byUrl(s, 'https://example.com/b.js');
      expect(unavailable(b.transfer), UnavailableReason.notReportedByPlatform);
      expect(present(b.decoded), 20);
    });

    test('2: null fields do not trigger the cross-origin rule', () {
      final s = build([
        res('https://cdn.example.net/a.js', tx: null, enc: null, dec: null)
      ]);
      final a = byUrl(s, 'https://cdn.example.net/a.js');
      expect(unavailable(a.transfer), UnavailableReason.notReportedByPlatform);
    });

    test('2: JS sends null, not 0, for unsupported fields', () {
      expect(vsvResourceBootstrapJs, isNot(contains('transferSize || 0')));
      expect(vsvResourceBootstrapJs, isNot(contains('encodedBodySize || 0')));
      expect(vsvResourceBootstrapJs, isNot(contains('decodedBodySize || 0')));
      expect(vsvCollectJs, isNot(contains('transferSize || 0')));
      expect(vsvCollectJs, isNot(contains('decodedBodySize || 0')));
    });

    test('3: Android cookie with null expiresDate is not a session cookie', () {
      final c = parseNativeCookies([
        {'name': 'a', 'value': 'b', 'expiresDate': null}
      ], BrowserPlatform.android);
      expect(unavailable(c.single.expires), UnavailableReason.notExposedToPage);
    });

    test('3: macOS null expiresDate is still a session cookie', () {
      final c = parseNativeCookies([
        {'name': 'a', 'value': 'b', 'expiresDate': null}
      ], BrowserPlatform.macos);
      expect(unavailable(c.single.expires), UnavailableReason.notApplicable);
    });

    test('4: observer that failed to install falls back in JS', () {
      expect(vsvResourceBootstrapJs, contains('__vsv_obsOk'));
      expect(vsvCollectJs, contains('__vsv_obsOk'));
    });

    test('4: no observer and nothing measured is Unavailable, not empty', () {
      final s = build([], resources: {'bootstrap': false});
      expect(unavailable(s.resources), UnavailableReason.notReportedByPlatform);
    });

    test('4: dropped entries surface as truncation', () {
      final s = build([res('https://example.com/a.js', tx: 1, enc: 1, dec: 1)],
          resources: {'dropped': 7, 'patchDropped': 3});
      expect(s.resourcesTruncated, true);
      expect(s.resourcesDropped, 10);
      final ok =
          build([res('https://example.com/a.js', tx: 1, enc: 1, dec: 1)]);
      expect(ok.resourcesTruncated, false);
      expect(ok.resourcesDropped, 0);
    });

    test('5: patch startTime is captured at call time', () {
      expect(vsvResourceBootstrapJs, isNot(contains('st: performance.now()')));
      expect(vsvResourceBootstrapJs,
          contains('function patchRecord(url, cl, kind, st)'));
    });

    test('6: non-String DOM value is Failed, not an empty DOM', () {
      final s = build([], domValue: 42);
      expect(s.renderedDom, isA<Failed<RenderedDom>>());
      final n = build([], domValue: null);
      expect(n.renderedDom, isA<Failed<RenderedDom>>());
    });

    test('7: same-origin 0/0/0 is Unavailable, not a measured 0', () {
      final s = build([res('https://example.com/sw.js')]);
      final e = byUrl(s, 'https://example.com/sw.js');
      expect(unavailable(e.transfer), UnavailableReason.notReportedByPlatform);
      expect(unavailable(e.decoded), UnavailableReason.notReportedByPlatform);
      expect((e.transfer as Unavailable).detail,
          'reported 0 bytes; may be unmeasured (service worker / redirect)');
    });
  });

  group('collector JS strings', () {
    int count(String s, String ch) => ch.allMatches(s).length;
    for (final entry in {
      'collector': vsvCollectJs,
      'bootstrap': vsvResourceBootstrapJs,
    }.entries) {
      test('${entry.key} has balanced braces and parens', () {
        expect(count(entry.value, '{'), count(entry.value, '}'));
        expect(count(entry.value, '('), count(entry.value, ')'));
        expect(count(entry.value, '['), count(entry.value, ']'));
      });
    }
    test('defines __vsv_collect, ES5-style', () {
      expect(vsvCollectJs, contains('window.__vsv_collect = function'));
      expect(vsvCollectJs, isNot(contains('?.')));
      expect(vsvCollectJs, isNot(contains('=>')));
      expect(vsvResourceBootstrapJs, isNot(contains('?.')));
      expect(vsvResourceBootstrapJs, isNot(contains('=>')));
    });
  });
}
