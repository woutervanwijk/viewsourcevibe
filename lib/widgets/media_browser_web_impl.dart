import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerMediaIframe(String viewID, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewID,
    (int viewId) {
      final iframe = web.HTMLIFrameElement();
      iframe.src = url;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      return iframe;
    },
  );
}
