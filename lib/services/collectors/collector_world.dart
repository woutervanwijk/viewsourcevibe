import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'vsv_collect_js.dart';

/// The JavaScript world the collector runs in. iOS and macOS (WKWebView) have
/// isolated worlds: the page cannot see or alter the collector there. Android
/// has none, so it returns null (the page world, as before).
ContentWorld? collectorWorld(TargetPlatform platform) =>
    platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? ContentWorld.world(name: 'vsv')
        : null;

/// Bootstrap + collector + scroll-through as one document-start user script,
/// in every frame. In an isolated world the fetch/XHR patch is skipped
/// (`__vsv_isolated`): it would only patch the isolated copy of those objects.
UserScript collectorUserScript(TargetPlatform platform) {
  final world = collectorWorld(platform);
  return UserScript(
    source: '${world != null ? 'window.__vsv_isolated = true;\n' : ''}'
        '$vsvResourceBootstrapJs\n$vsvCollectJs\n$vsvScrollThroughJs',
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    // Also in iframes: they post their resources (ads, embeds) to the top
    // frame, so the page size counts them.
    forMainFrameOnly: false,
    contentWorld: world ?? ContentWorld.PAGE,
  );
}
