import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';

import 'builders.dart';

const iosUrl = 'https://example.org/';
const iosServerHtml =
    '<html><body>IOS-SERVER-BODY ................................................</body></html>';
const iosDomHtml = '<html><body>IOS-DOM</body></html>';

/// iOS: cross-origin resources have no sizes (blocked by the platform), the
/// image's decoded size is unavailable, one script has a transfer size.
PageInspection iosPartial() {
  const blocked = Unavailable<int>(UnavailableReason.blockedByPlatform,
      'cross-origin without Timing-Allow-Origin');
  final h = hop(iosUrl, 200, headers: {
    'content-type': ['text/html; charset=utf-8']
  });
  return urlInspection(
    url: iosUrl,
    serverResult:
        server(serverSnapshot(url: iosUrl, hops: [h], body: iosServerHtml)),
    browserResult: browser(browserSnapshot(
      url: iosUrl,
      dom: iosDomHtml,
      platform: BrowserPlatform.ios,
      resources: [
        resource('https://cdn.other.net/lib.js', 'script',
            transfer: blocked, decoded: blocked),
        resource('https://example.org/own.js', 'script',
            transfer: browser(2048), decoded: blocked),
        resource('https://example.org/pic.png', 'img',
            transfer: browser(5000),
            decoded: const Unavailable(
                UnavailableReason.notReportedByPlatform, 'image decoded size')),
      ],
    )),
  );
}

/// iOS: a cross-origin script without sizes, an own script with only a
/// transfer size, an image.
PageInspection iosPartialWithLinks() {
  const url = 'https://example.org/';
  const dom = '<html><head><title>IOS</title>'
      '<script src="https://cdn.other.net/lib.js"></script>'
      '<script src="https://example.org/own.js"></script>'
      '<script src="https://www.google-analytics.com/analytics.js"></script></head>'
      '<body><img src="https://example.org/pic.png"></body></html>';
  const blocked = Unavailable<int>(UnavailableReason.blockedByPlatform,
      'cross-origin without Timing-Allow-Origin');
  return urlInspection(
    url: url,
    serverResult: const Pending<ServerSnapshot>(),
    browserResult: browser(browserSnapshot(
      url: url,
      dom: dom,
      platform: BrowserPlatform.ios,
      resources: [
        resource('https://cdn.other.net/lib.js', 'script',
            transfer: blocked, decoded: blocked),
        resource('https://example.org/own.js', 'script',
            transfer: browser(2048), decoded: blocked),
        resource('https://www.google-analytics.com/analytics.js', 'script',
            transfer: blocked, decoded: blocked),
        resource('https://example.org/pic.png', 'img',
            transfer: browser(5000),
            decoded: const Unavailable(
                UnavailableReason.notReportedByPlatform, 'image decoded size')),
      ],
    )),
  );
}
