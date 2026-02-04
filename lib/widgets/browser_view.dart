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
              if (mounted) {
                Provider.of<HtmlService>(context, listen: false)
                    .updateWebViewLoadingProgress(progress / 100.0);
              }
            },
            onPageStarted: (String url) {
              if (mounted) {
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                htmlService.updateWebViewUrl(url);
                htmlService.updateWebViewLoadingProgress(0.0);
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
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                htmlService.syncWebViewState(url);
                htmlService.updateWebViewLoadingProgress(1.0);
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
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          htmlService.activeWebViewController = _controller;

          // Only load if we are on the browser tab (index 1)
          if (htmlService.activeTabIndex == 1) {
            _loadContent();
          }
        }
      });
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

  @override
  void didUpdateWidget(BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the file changed (e.g. from local to URL or different content), reload.
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.file.content != widget.file.content) {
      _loadContentIfVisible();
    }
  }

  void _loadContentIfVisible() {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    if (htmlService.activeTabIndex == 1) {
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    if (_controller == null) return;

    final htmlService = Provider.of<HtmlService>(context, listen: false);
    String targetUrl = widget.file.path;

    // If there's a specialized loading URL (e.g. forceWebView path), use it.
    if (htmlService.webViewLoadingUrl != null) {
      targetUrl = htmlService.webViewLoadingUrl!;
    } else if (_currentRssUrl != null && targetUrl == _currentRssUrl) {
      // Already handled RSS
      return;
    }

    if (kIsWeb) {
      platform_impl.registerMediaIframe(viewID, _getEffectiveUrl());
      return;
    }

    final currentUrl = await _controller.currentUrl();

    // Check if it's an RSS/Atom/XML feed
    // We use the file content if available, otherwise just load the URL
    final isRssOrXml = await RssTemplateService.isRssFeed(
        widget.file.name, widget.file.content);

    if (isRssOrXml && widget.file.content.isNotEmpty) {
      // Use temporary internal RSS rendering if needed
      final html = await RssTemplateService.convertRssToHtml(
          widget.file.content, targetUrl);
      _controller.loadHtmlString(html, baseUrl: targetUrl);
      _currentRssUrl = targetUrl;
    } else {
      // If not RSS, or RSS but content is empty, proceed with normal loading
      _currentRssUrl = null;
      if (currentUrl == targetUrl && targetUrl.isNotEmpty) return;

      if (targetUrl.startsWith('http')) {
        await _controller.loadRequest(Uri.parse(targetUrl));
      } else {
        await _controller.loadHtmlString(widget.file.content,
            baseUrl: widget.file.path);
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
