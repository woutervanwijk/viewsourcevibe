import 'package:flutter/foundation.dart';

import '../../models/inspection/browser_snapshot.dart';

/// Starts a navigation in the in-app browser. A seam so HtmlService can be
/// tested without a WebView.
abstract class BrowserLoader {
  void loadUrl(Uri url);
}

/// Runs `window.__vsv_collect()` in the page at [url] and returns what the
/// WebView gave back (a JSON string, or something else on some platforms).
/// Throws when the browser cannot be reached.
typedef BrowserCollect = Future<Object?> Function(String url);

/// The WebView's native cookies for [url], in the shape of
/// flutter_inappwebview `Cookie.toMap()`. Throws when unavailable.
typedef NativeCookieReader = Future<List<Map>> Function(String url);

/// Looks up the size of a resource with a request of our own. Null when it
/// cannot be determined.
typedef ResourceSizeLookup = Future<int?> Function(String url);

BrowserPlatform browserPlatformFor(TargetPlatform p) => switch (p) {
      TargetPlatform.iOS => BrowserPlatform.ios,
      TargetPlatform.macOS => BrowserPlatform.macos,
      TargetPlatform.android => BrowserPlatform.android,
      TargetPlatform.windows => BrowserPlatform.windows,
      TargetPlatform.linux => BrowserPlatform.linux,
      TargetPlatform.fuchsia => BrowserPlatform.unknown,
    };
