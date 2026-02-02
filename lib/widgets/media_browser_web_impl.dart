import 'dart:html' as html;
import 'dart:ui' as ui;

void registerMediaIframe(String viewID, String url) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    viewID,
    (int viewId) {
      final iframe = html.IFrameElement();
      iframe.src = url;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      return iframe;
    },
  );
}
