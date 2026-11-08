import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/legacy_browser_adapter.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

Present<T> _b<T>(T v) => Present(v, source: DataSource.browser);
Present<T> _s<T>(T v) => Present(v, source: DataSource.server);

const _na = Unavailable<int>(UnavailableReason.blockedByPlatform, 'no TAO');
const _naD = Unavailable<double>(UnavailableReason.notReportedByPlatform);

ResourceEntry res(
  String url, {
  String type = 'script',
  Observed<int> tx = const Unavailable(UnavailableReason.blockedByPlatform),
  Observed<int> dec = const Unavailable(UnavailableReason.blockedByPlatform),
  Observed<double>? start,
  Observed<double>? dur,
  ResourceSource source = ResourceSource.observer,
}) =>
    ResourceEntry(
      url: url,
      type: type,
      source: source,
      startTime: start ?? _naD,
      duration: dur ?? _naD,
      transfer: tx,
      decoded: dec,
    );

BrowserSnapshot snap({
  List<ResourceEntry>? resources,
  Observed<List<ResourceEntry>>? resourcesObserved,
  BrowserPlatform platform = BrowserPlatform.android,
  Observed<BrowserStorage>? storage,
  Observed<List<BrowserCookie>>? cookies,
  bool truncated = false,
}) {
  const un = Unavailable<Never>(UnavailableReason.notApplicable);
  return BrowserSnapshot(
    url: Uri.parse('https://a.test/page'),
    platform: platform,
    contentType: _b('text/html'),
    renderedDom: _b(const RenderedDom(text: '<html>é</html>')),
    resources: resourcesObserved ?? _b(resources ?? const []),
    cookies: cookies ?? un,
    storage: storage ?? un,
    navigation: un,
    snapshotTimeMs: _b(1000.0),
    resourcesTruncated: truncated,
  );
}

ServerSnapshot serverSnap({Observed<ServerBody>? body, int? status}) {
  final hop = HttpHop(
    url: Uri.parse('https://a.test/page'),
    statusCode: status ?? 200,
    reasonPhrase: 'OK',
    headers: const {},
    setCookies: const ['sid=1; Path=/; Secure'],
    remoteAddress: const Unavailable(UnavailableReason.notReportedByPlatform),
    certificate: const Unavailable(UnavailableReason.notApplicable),
  );
  return ServerSnapshot(
    requestedUrl: hop.url,
    userAgent: 'ua',
    hops: [hop],
    finalUrl: _s(hop.url),
    body: body ??
        const Unavailable(UnavailableReason.notReportedByServer, 'none'),
    timingMs: _s(5),
    certificate: const Unavailable(UnavailableReason.notApplicable),
  );
}

ServerBody serverBody(int bytes, int wire) => ServerBody(
      decoded: DecodedText(
          text: 'x' * bytes,
          charset: 'utf-8',
          charsetSource: CharsetSource.header,
          byteLength: bytes),
      transferLength: wire,
      truncated: false,
      contentLength: const Unavailable(UnavailableReason.notReportedByServer),
    );

PageInspection inspection(BrowserSnapshot? b, {ServerSnapshot? server}) =>
    PageInspection(
      generation: 1,
      target: UrlTarget(Uri.parse('https://a.test/page')),
      server: server == null ? const Pending() : _s(server),
      browser: b == null ? const Pending() : _b(b),
      file: const Unavailable(UnavailableReason.notApplicable),
    );

BrowserCookie cookie(String name,
        {Observed<bool> secure =
            const Unavailable(UnavailableReason.notExposedToPage),
        Observed<bool> httpOnly =
            const Unavailable(UnavailableReason.notExposedToPage),
        Observed<String> domain =
            const Unavailable(UnavailableReason.notExposedToPage)}) =>
    BrowserCookie(
      name: name,
      value: 'v',
      domain: domain,
      path: const Unavailable(UnavailableReason.notExposedToPage),
      expires: const Unavailable(UnavailableReason.notExposedToPage),
      isSecure: secure,
      isHttpOnly: httpOnly,
      sameSite: const Unavailable(UnavailableReason.notExposedToPage),
    );

void main() {
  group('legacyResourceTimeline', () {
    test('Present values come through, non-Present are null, never 0', () {
      final p = inspection(snap(resources: [
        res('https://a.test/a.js',
            tx: _b(100),
            dec: _b(400),
            start: _b(5.0),
            dur: _b(20.0),
            type: 'script'),
        res('https://cdn.test/b.js', tx: _na, dec: _na),
      ]));
      final t = legacyResourceTimeline(p);
      expect(t, hasLength(2));
      expect(t[0], containsPair('name', 'https://a.test/a.js'));
      expect(t[0]['transfer'], 100);
      expect(t[0]['decoded'], 400);
      expect(t[0]['startTime'], 5.0);
      expect(t[0]['duration'], 20.0);
      expect(t[0]['initiatorType'], 'script');
      expect(t[1].containsKey('transfer'), isTrue);
      expect(t[1]['transfer'], isNull);
      expect(t[1]['decoded'], isNull);
      expect(t[1]['startTime'], isNull);
      expect(t[1]['duration'], isNull);
    });

    test('empty when the browser has no Present resources', () {
      expect(legacyResourceTimeline(inspection(null)), isEmpty);
      expect(
          legacyResourceTimeline(inspection(snap(
              resourcesObserved:
                  const Unavailable(UnavailableReason.unsupportedPlatform)))),
          isEmpty);
    });

    test('an unavailable size carries the reason as text', () {
      final t = legacyResourceTimeline(
          inspection(snap(resources: [res('https://c.test/x.js')])));
      expect(t.single['transferNote'], contains('Not visible'));
    });
  });

  group('legacyPageWeight', () {
    test('totals sum Present values only and flag the lower bounds', () {
      final w = legacyPageWeight(inspection(snap(resources: [
        res('https://a.test/a.js', tx: _b(100), dec: _b(400)),
        res('https://cdn.test/b.js', tx: _na, dec: _na),
        res('https://a.test/c.css', type: 'css', tx: _b(50), dec: _b(60)),
      ])))!;
      expect(w['transfer'], 150);
      expect(w['decoded'], 460);
      expect(w['transferLowerBound'], isTrue);
      expect(w['decodedLowerBound'], isTrue);
      expect(w.containsKey('isPartial'), isFalse);
      final bd = w['breakdown'] as Map;
      expect(bd['scripts'], containsPair('count', 2));
      expect(bd['scripts']['transfer'], 100);
      expect(bd['css']['count'], 1);
      expect(bd['css']['transfer'], 50);
    });

    test('no lower bound when every size is Present', () {
      final w = legacyPageWeight(inspection(snap(resources: [
        res('https://a.test/a.js', tx: _b(1), dec: _b(2)),
      ])))!;
      expect(w['transferLowerBound'], isFalse);
      expect(w['decodedLowerBound'], isFalse);
    });

    test('truncated resources make the total partial', () {
      final w = legacyPageWeight(inspection(snap(truncated: true, resources: [
        res('https://a.test/a.js', tx: _b(1), dec: _b(2)),
      ])))!;
      expect(w['transferLowerBound'] == true || w['decodedLowerBound'] == true, isTrue);
    });

    test('no Present size at all gives null totals, not 0', () {
      final w = legacyPageWeight(
          inspection(snap(resources: [res('https://c.test/x.js')])))!;
      expect(w.containsKey('transfer'), isFalse);
      expect(w.containsKey('decoded'), isFalse);
      expect(w['transferLowerBound'] == true || w['decodedLowerBound'] == true, isTrue);
      expect(w['breakdown']['scripts']['count'], 1);
      expect(
          (w['breakdown']['scripts'] as Map).containsKey('transfer'), isFalse);
    });

    test(
        'B10: image weight uses transfer; WebKit pixel-buffer decoded is not '
        'added', () {
      // The parser reports the WebKit image decoded size as Unavailable.
      final w = legacyPageWeight(
          inspection(snap(platform: BrowserPlatform.ios, resources: [
        res('https://a.test/hero.jpg',
            type: 'img',
            tx: _b(30000),
            dec: const Unavailable(UnavailableReason.notReportedByPlatform)),
        res('https://a.test/a.js', tx: _b(10), dec: _b(20)),
      ])))!;
      final images = w['breakdown']['images'] as Map;
      expect(images['count'], 1);
      expect(images['transfer'], 30000);
      expect(images.containsKey('decoded'), isFalse);
      expect(w['transfer'], 30010);
      expect(w['decoded'], 20);
      // An image without a decoded size is by design, not a gap.
      expect(w['transferLowerBound'], isFalse);
      expect(w['decodedLowerBound'], isFalse);
    });

    test('B10: a Present decoded size of a WebKit image is ignored', () {
      final w = legacyPageWeight(
          inspection(snap(platform: BrowserPlatform.macos, resources: [
        res('https://a.test/hero.png',
            type: 'img', tx: _b(30000), dec: _b(4000000)),
      ])))!;
      expect(w['breakdown']['images'].containsKey('decoded'), isFalse);
      expect(w.containsKey('decoded'), isFalse);
    });

    test('the main document comes from the server body (labelled)', () {
      final w = legacyPageWeight(inspection(
          snap(resources: [
            res('https://a.test/a.js', tx: _b(10), dec: _b(20)),
          ]),
          server: serverSnap(body: _s(serverBody(1000, 400)))))!;
      expect(w['transfer'], 410);
      expect(w['decoded'], 1020);
      expect(w['documentSource'], 'server');
      expect(w['breakdown']['html']['count'], 1);
    });

    test('null without a Present browser snapshot', () {
      expect(legacyPageWeight(inspection(null)), isNull);
    });
  });

  group('legacyDomFile', () {
    test('size is the UTF-8 byte length of the serialized DOM (B9)', () {
      final b = snap();
      final f = legacyDomFile(b, name: 'page.html')!;
      expect(f.content, '<html>é</html>');
      expect(f.size, 15); // 14 chars, é is two bytes
      expect(f.isUrl, isTrue);
      expect(f.path, 'https://a.test/page');
    });

    test('null when the DOM is not Present', () {
      final b = BrowserSnapshot.unavailable(Uri.parse('https://a.test/'),
          BrowserPlatform.windows, UnavailableReason.unsupportedPlatform, 'x');
      expect(legacyDomFile(b, name: 'p.html'), isNull);
    });
  });
}
