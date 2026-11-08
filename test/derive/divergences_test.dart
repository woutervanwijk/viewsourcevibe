import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/divergences.dart';

import 'fixtures.dart';

void main() {
  test('403 to the app but a browser page: divergence names status and UA', () {
    final d = deriveDivergences(inspection(
        server: serverSnap(status: 403, ua: 'curl/8', body: 'Forbidden'),
        browser: browserSnap()));
    expect(d.single.kind, DivergenceKind.serverStatus);
    expect(d.single.message,
        "server returned 403 to the app's request (UA curl/8) but the browser loaded the page");
  });

  test('no divergence when the server agrees', () {
    expect(
        deriveDivergences(
            inspection(server: serverSnap(), browser: browserSnap())),
        isEmpty);
  });

  test('server >=400 without a browser DOM is not a divergence', () {
    expect(
        deriveDivergences(inspection(
            server: serverSnap(status: 404), browser: browserSnap(dom: null))),
        isEmpty);
  });

  test('final URL and browser URL differ by host or path', () {
    final d = deriveDivergences(inspection(
        server: serverSnap(finalUrl: 'https://a.test/page'),
        browser: browserSnap(url: 'https://a.test/other')));
    expect(d.map((x) => x.kind), [DivergenceKind.finalUrl]);
    final host = deriveDivergences(inspection(
        server: serverSnap(),
        browser: browserSnap(url: 'https://b.test/page')));
    expect(host.map((x) => x.kind), [DivergenceKind.finalUrl]);
  });

  test('a redirect only the app got is explained by the cookies it lacks', () {
    final d = deriveDivergences(inspection(
        server: serverSnap(finalUrl: 'https://consent.test/consent'),
        browser: browserSnap(url: 'https://a.test/')));
    expect(d.single.kind, DivergenceKind.finalUrl);
    expect(
        d.single.message,
        "the app's own request was redirected to https://consent.test/consent "
        'but the browser is at https://a.test/ (the browser has cookies the '
        'app does not send, such as a consent choice)');
  });

  test('scheme/trailing slash/fragment alone are not divergences', () {
    expect(
        deriveDivergences(inspection(
            server: serverSnap(url: 'http://a.test/page/'),
            browser: browserSnap(url: 'https://a.test/page#x'))),
        isEmpty);
  });

  test('www <-> non-www is a low-severity redirect-host divergence', () {
    final d = deriveDivergences(inspection(
        server: serverSnap(url: 'https://a.test/page'),
        browser: browserSnap(url: 'https://www.a.test/page')));
    expect(d.single.kind, DivergenceKind.redirectHost);
    expect(d.single.lowSeverity, isTrue);
  });

  test('non-html server content-type while the DOM is html: note', () {
    final d = deriveDivergences(inspection(
        server: serverSnap(headers: {
          'content-type': ['application/octet-stream']
        }),
        browser: browserSnap()));
    expect(d.map((x) => x.kind), [DivergenceKind.contentType]);
  });
}
