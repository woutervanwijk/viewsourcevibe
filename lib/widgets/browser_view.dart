import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'dart:convert';
import 'package:view_source_vibe/widgets/media_browser_platform_proxy.dart'
    if (dart.library.js_util) 'package:view_source_vibe/widgets/media_browser_web_impl.dart'
    as platform_impl;

class BrowserView extends StatefulWidget {
  final HtmlFile file;

  const BrowserView({super.key, required this.file});

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  late final WebViewController? _controller;
  final String viewID = 'browser-preview-view';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading bar.
            },
            onPageStarted: (String url) {},
            onPageFinished: (String url) {},
            onWebResourceError: (WebResourceError error) {},
          ),
        );

      _loadContent();
    } else {
      _controller = null;
      platform_impl.registerMediaIframe(viewID, _getEffectiveUrl());
    }
  }

  String _getEffectiveUrl() {
    if (widget.file.isUrl) {
      return widget.file.path;
    }
    // For local files, we might need to data-uri them if they are HTML
    return Uri.dataFromString(
      widget.file.content,
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
  }

  void _loadContent() {
    if (_controller == null) return;

    if (widget.file.isUrl) {
      _controller!.loadRequest(Uri.parse(widget.file.path));
    } else {
      _controller!.loadHtmlString(widget.file.content);
    }
  }

  @override
  void didUpdateWidget(BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.file.content != widget.file.content) {
      if (kIsWeb) {
        platform_impl.registerMediaIframe(viewID, _getEffectiveUrl());
      } else {
        _loadContent();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return HtmlElementView(
        viewType: viewID,
        key: ValueKey(_getEffectiveUrl()),
      );
    }

    return WebViewWidget(controller: _controller!);
  }
}
