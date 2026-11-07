import 'package:view_source_vibe/models/inspection/page_inspection.dart';

import 'builders.dart';

const trackerUrl = 'https://news.example.com/';
const trackerServerHtml = '<html><head><title>News</title>'
    '<script src="https://www.googletagmanager.com/gtag/js?id=G-TEST1"></script>'
    '</head><body>SERVER</body></html>';
const trackerDomHtml = '<html><head><title>News</title>'
    '<script src="https://www.googletagmanager.com/gtag/js?id=G-TEST1"></script>'
    '<script src="https://example.com/own.js"></script>'
    '</head><body>DOM</body></html>';

/// A page with Google Tag Manager in the source and trackers loaded at run
/// time (Facebook pixel, Google Analytics), seen by server and browser.
PageInspection trackerPage() {
  final h = hop(trackerUrl, 200, headers: {
    'content-type': ['text/html; charset=utf-8']
  });
  return urlInspection(
    url: trackerUrl,
    serverResult: server(
        serverSnapshot(url: trackerUrl, hops: [h], body: trackerServerHtml)),
    browserResult: browser(browserSnapshot(
      url: trackerUrl,
      dom: trackerDomHtml,
      resources: [
        resource('https://connect.facebook.net/en_US/fbevents.js', 'script',
            transfer: browser(1000), decoded: browser(2000)),
        resource('https://www.google-analytics.com/analytics.js', 'script',
            transfer: browser(1000), decoded: browser(2000)),
      ],
      cookies: const [],
    )),
  );
}
