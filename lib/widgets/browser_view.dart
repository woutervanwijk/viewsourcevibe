import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'dart:convert';
import 'package:view_source_vibe/widgets/media_browser_platform_proxy.dart'
    if (dart.library.js_util) 'package:view_source_vibe/widgets/media_browser_web_impl.dart'
    as platform_impl;
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/rss_template_service.dart';

class BrowserView extends StatefulWidget {
  final HtmlFile file;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  const BrowserView({
    super.key,
    required this.file,
    this.gestureRecognizers,
  });

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  late final WebViewController? _controller;
  final String viewID = 'browser-preview-view';
  String? _currentRssUrl;

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
            onPageStarted: (String url) {
              if (mounted) {
                Provider.of<HtmlService>(context, listen: false)
                    .updateWebViewUrl(url);
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                // If we are viewing the RSS template, block sync to preserve XML source.
                if (_currentRssUrl != null && url == _currentRssUrl) {
                  // If the app model has drifted (e.g. we came back from an article),
                  // restore the original XML content.
                  final htmlService =
                      Provider.of<HtmlService>(context, listen: false);
                  if (htmlService.currentFile?.path != url) {
                    htmlService.loadFromUrl(url);
                  }
                  return;
                }

                // Use syncWebViewState to update everything (content, metadata, probe)
                Provider.of<HtmlService>(context, listen: false)
                    .syncWebViewState(url);
              }
            },
            onUrlChange: (UrlChange change) {
              if (mounted && change.url != null) {
                Provider.of<HtmlService>(context, listen: false)
                    .updateWebViewUrl(change.url!);
              }
            },
            onWebResourceError: (WebResourceError error) {},
          ),
        );

      // Register controller with HtmlService
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<HtmlService>(context, listen: false)
              .activeWebViewController = _controller;
        }
      });

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

  Future<void> _loadContent() async {
    if (_controller == null) return;

    if (widget.file.isUrl) {
      final currentUrl = await _controller.currentUrl();

      // Check if it's an RSS/Atom/XML feed that we want to render nicely
      final isRssOrXml =
          RssTemplateService.isRssFeed(widget.file.name, widget.file.content);

      if (isRssOrXml) {
        _currentRssUrl = widget.file.path;
        final html = RssTemplateService.convertRssToHtml(
            widget.file.content, widget.file.path);
        // Load the generated HTML
        _controller.loadHtmlString(html, baseUrl: widget.file.path);
        return;
      }

      _currentRssUrl = null;

      // Prevent reloading if we are already at the target URL
      if (currentUrl == widget.file.path) return;

      _controller.loadRequest(Uri.parse(widget.file.path));
    } else {
      _currentRssUrl = null;
      _controller.loadHtmlString(widget.file.content);
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

    return WebViewWidget(
      controller: _controller!,
      gestureRecognizers: widget.gestureRecognizers ??
          const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}
