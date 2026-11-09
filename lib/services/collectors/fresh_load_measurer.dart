import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../derive/network_quiet.dart';
import 'vsv_collect_js.dart';

/// Loads a page once more, apart from the live browser, the way Lighthouse
/// does: empty cache, phone-sized screen, waiting until the network is
/// quiet. Returns the collector's raw payload (see `parseBrowserPayload`)
/// and a small screenshot of what it showed.
abstract interface class FreshLoadMeasurer {
  Future<FreshLoadRaw> measure(Uri url, NetworkQuietPolicy policy);
}

class FreshLoadRaw {
  final Object? payload;

  /// Small JPEG; null when the platform gave none.
  final Uint8List? screenshot;
  const FreshLoadRaw(this.payload, {this.screenshot});
}

/// Thumbnail settings for screenshots of a load (small JPEG).
final kThumbnailScreenshot = ScreenshotConfiguration(
    compressFormat: CompressFormat.JPEG, quality: 60, snapshotWidth: 240);

/// Where no off-screen browser exists (Windows, Linux).
class NoFreshLoad implements FreshLoadMeasurer {
  const NoFreshLoad();
  @override
  Future<FreshLoadRaw> measure(Uri url, NetworkQuietPolicy policy) =>
      Future.error(UnsupportedError('not available on this platform'));
}

/// Resource count and transferred bytes so far: changes while the page is
/// still loading. The dropped count is part of it: once the collector buffer
/// is full, resources still arrive but only the drop count moves, and the
/// network is not quiet yet.
const _signatureJs = '''
(function() {
  var n = 0, t = 0, o = window.__vsv_obs || {};
  for (var k in o) { if (o.hasOwnProperty(k)) { n++; t += o[k].tx || 0; } }
  return n + ':' + t + ':' + (window.__vsv_obsDropped || 0);
})()''';

/// Extra time after the scroll-through for the lazy requests to finish.
const Duration _scrollSettleBudget = Duration(seconds: 20);

/// A recent iPhone Safari, for the desktop app: Lighthouse measures a phone.
const _phoneUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 '
    'Safari/604.1';

/// [FreshLoadMeasurer] with an off-screen WebView (Android, iOS, macOS).
///
/// iOS/macOS use a private (non-persistent) session: no cookies, no cache.
/// Android has no private session per WebView (incognito would delete the
/// live browser's cookies), so there the cache is bypassed but the user's
/// cookies are sent.
class HeadlessFreshLoadMeasurer implements FreshLoadMeasurer {
  const HeadlessFreshLoadMeasurer();

  static bool get supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  Future<FreshLoadRaw> measure(Uri url, NetworkQuietPolicy policy) async {
    final loaded = Completer<void>();
    final clock = Stopwatch()..start();
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(url)),
      // Lighthouse's mobile viewport.
      initialSize: const Size(412, 823),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        incognito: !Platform.isAndroid,
        cacheEnabled: false,
        cacheMode: CacheMode.LOAD_NO_CACHE,
        mediaPlaybackRequiresUserGesture: true,
        userAgent: Platform.isMacOS ? _phoneUserAgent : null,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: '$vsvResourceBootstrapJs\n$vsvCollectJs\n$vsvScrollThroughJs',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]),
      onLoadStop: (_, __) {
        if (!loaded.isCompleted) loaded.complete();
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true && !loaded.isCompleted) {
          loaded.completeError(StateError(error.description));
        }
      },
    );
    await view.run();
    try {
      await loaded.future.timeout(policy.max);
      final controller = view.webViewController!;

      /// Waits until the resource signature is quiet (or [budget] is spent).
      Future<void> waitQuiet(Duration budget) async {
        var signature =
            await controller.evaluateJavascript(source: _signatureJs);
        var lastChange = clock.elapsed;
        while (clock.elapsed < budget &&
            clock.elapsed - lastChange < policy.quiet) {
          await Future<void>.delayed(policy.interval);
          final s = await controller.evaluateJavascript(source: _signatureJs);
          if (s != signature) {
            signature = s;
            lastChange = clock.elapsed;
          }
        }
      }

      await waitQuiet(policy.max);
      // Use the browser's own lazy loading: scroll through the page so
      // loading=lazy / IntersectionObserver content is actually fetched,
      // then wait for those requests, so the collect below measures them
      // for real instead of leaving them to estimates.
      try {
        await controller.evaluateJavascript(
            source:
                'window.__vsv_scrollThrough && window.__vsv_scrollThrough(false)');
      } catch (_) {}
      await waitQuiet(clock.elapsed + _scrollSettleBudget);

      final payload = await controller.evaluateJavascript(
          source: 'window.__vsv_collect()');
      Uint8List? shot;
      try {
        shot = await controller.takeScreenshot(
            screenshotConfiguration: kThumbnailScreenshot);
      } catch (_) {
        // No screenshot is fine: the sizes are what was measured.
      }
      return FreshLoadRaw(payload, screenshot: shot);
    } finally {
      await view.dispose();
    }
  }
}
