import 'package:view_source_vibe/models/inspection/page_inspection.dart';

import 'builders.dart';

const botUrl = 'https://shop.example.net/';
const botChallengeHtml =
    '<html><body>Just a moment... CHALLENGE-PAGE</body></html>';
const botDomHtml = '<html><body>REAL-PAGE-AS-RENDERED</body></html>';

/// The server (our curl-like request) got a 403 challenge page; the browser
/// rendered the real page.
PageInspection botBlocked() {
  final h = hop(botUrl, 403, headers: {
    'content-type': ['text/html; charset=utf-8']
  });
  return urlInspection(
    url: botUrl,
    serverResult:
        server(serverSnapshot(url: botUrl, hops: [h], body: botChallengeHtml)),
    browserResult: browser(browserSnapshot(url: botUrl, dom: botDomHtml)),
  );
}
