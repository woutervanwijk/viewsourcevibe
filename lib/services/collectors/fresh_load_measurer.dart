import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../derive/network_quiet.dart';
import 'vsv_collect_js.dart';

/// Loads a page once more, apart from the live browser, the way Lighthouse
/// does: empty cache, phone-sized screen, waiting until the network is
/// quiet. Returns the collector's raw payload (see `parseBrowserPayload`).
abstract interface class FreshLoadMeasurer {
  Future<Object?> measure(Uri url, NetworkQuietPolicy policy);
}

/// Where no off-screen browser exists (Windows, Linux).
class NoFreshLoad implements FreshLoadMeasurer {
  const NoFreshLoad();
  @override
  Future<Object?> measure(Uri url, NetworkQuietPolicy policy) =>
      Future.error(UnsupportedError('not available on this platform'));
}

/// Resource count and transferred bytes so far: changes while the page is
/// still loading.
const _signatureJs = '''
(function() {
  var n = 0, t = 0, o = window.__vsv_obs || {};
  for (var k in o) { if (o.hasOwnProperty(k)) { n++; t += o[k].tx || 0; } }
  return n + ':' + t;
})()''';

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
  Future<Object?> measure(Uri url, NetworkQuietPolicy policy) async {
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
          source: '$vsvResourceBootstrapJs\n$vsvCollectJs',
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
      var signature =
          await controller.evaluateJavascript(source: _signatureJs);
      var lastChange = clock.elapsed;
      while (!policy.done(
          elapsed: clock.elapsed,
          sinceLastChange: clock.elapsed - lastChange)) {
        await Future<void>.delayed(policy.interval);
        final s = await controller.evaluateJavascript(source: _signatureJs);
        if (s != signature) {
          signature = s;
          lastChange = clock.elapsed;
        }
      }
      return await controller.evaluateJavascript(
          source: 'window.__vsv_collect()');
    } finally {
      await view.dispose();
    }
  }
}
