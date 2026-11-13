import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:view_source_vibe/models/settings.dart';

/// Android renderer priority policy for low-resource mode: keep the page's
/// renderer at normal priority while the WebView is visible, but let the
/// system treat it as waived (a prime target for memory reclaim) while the
/// tab is hidden. Null when low-resource mode is off or not on Android.
RendererPriorityPolicy? lowResourceRendererPriorityPolicy(AppSettings s) {
  if (!s.lowResourceMode || !Platform.isAndroid) return null;
  return RendererPriorityPolicy(
    rendererRequestedPriority: RendererPriority.RENDERER_PRIORITY_IMPORTANT,
    waivedWhenNotVisible: true,
  );
}
