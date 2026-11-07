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

  test('scheme/www/trailing slash/fragment alone are not divergences', () {
    expect(
        deriveDivergences(inspection(
            server: serverSnap(url: 'http://a.test/page/'),
            browser: browserSnap(url: 'https://a.test/page#x'))),
        isEmpty);
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
