import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';

import 'builders.dart';

const fullPageUrl = 'https://example.com/';
const fullPageServerHtml =
    '<html><head><title>Server</title></head><body>SERVER-BODY</body></html>';
const fullPageDomHtml =
    '<!DOCTYPE html><html><head><title>Rendered</title></head><body><div id="app">RENDERED-DOM</div></body></html>';

/// A URL inspection where everything worked: server (3 hops, headers, body,
/// robots) and browser (DOM, resources with sizes, cookies with flags).
PageInspection fullPage() {
  final hops = [
    hop('http://example.com/', 301, headers: {
      'location': ['https://example.com/']
    }),
    hop('https://example.com/', 302, headers: {
      'location': ['https://example.com/']
    }),
    hop(fullPageUrl, 200, headers: {
      'content-type': ['text/html; charset=utf-8'],
      'server': ['nginx'],
    }),
  ];
  return urlInspection(
    url: 'http://example.com/',
    serverResult: server(serverSnapshot(
        url: 'http://example.com/', hops: hops, body: fullPageServerHtml)),
    browserResult: browser(browserSnapshot(
      url: fullPageUrl,
      dom: fullPageDomHtml,
      resources: [
        resource('https://example.com/app.js', 'script',
            transfer: browser(4096), decoded: browser(12000)),
        resource('https://example.com/app.css', 'css',
            transfer: browser(1024), decoded: browser(3000)),
      ],
      cookies: [
        BrowserCookie(
          name: 'sid',
          value: 'abc',
          domain: browser('example.com'),
          path: browser('/'),
          expires: const Unavailable(UnavailableReason.notReportedByPlatform),
          isSecure: browser(true),
          isHttpOnly: browser(true),
          sameSite: browser('Lax'),
        ),
      ],
    )),
    robots: server(RobotsInfo(
      robotsStatus: server(200),
      robotsText: server('User-agent: *\nDisallow: /private'),
      disallowCount: server(1),
      allowCount: server(0),
      sitemaps: server(const <String>[]),
      sitemapStatus: server(404),
    )),
  );
}
