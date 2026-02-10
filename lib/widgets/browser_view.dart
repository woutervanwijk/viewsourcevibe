import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// Import Android specific packages
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
  InAppWebViewController? _controller;
  final String viewID = 'browser-preview-view';
  String? _currentRssUrl;
  int _syncStage = 0; // 0: none, 1: 30%, 2: 60%, 3: 90%

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      platform_impl.registerMediaIframe(viewID, _getEffectiveUrl());
    }
    // Note: Controller initialization happens in onWebViewCreated callback
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
    if (htmlService.activeTabIndex == htmlService.browserTabIndex) {
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

    final currentUrl = await _controller!.getUrl();

    // Check if it's an RSS/Atom/XML feed
    // We use the file content if available, otherwise just load the URL
    final isRssOrXml = await RssTemplateService.isRssFeed(
        widget.file.name, widget.file.content);

    if (isRssOrXml && widget.file.content.isNotEmpty) {
      // Use temporary internal RSS rendering if needed
      final html = await RssTemplateService.convertRssToHtml(
          widget.file.content, targetUrl);
      if (html.isNotEmpty) {
        await _controller!.loadData(
          data: html,
          baseUrl: WebUri(targetUrl),
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      }
      _currentRssUrl = targetUrl;
    } else {
      // If not RSS, or RSS but content is empty, proceed with normal loading
      _currentRssUrl = null;
      final currentUrlString = currentUrl?.toString() ?? '';
      if (currentUrlString == targetUrl && targetUrl.isNotEmpty) return;

      if (targetUrl.startsWith('http') && !targetUrl.contains('about:blank')) {
        await _controller!.loadUrl(
          urlRequest: URLRequest(url: WebUri(targetUrl)),
        );
      } else if (widget.file.content.isNotEmpty) {
        await _controller!.loadData(
          data: widget.file.content,
          baseUrl: WebUri(widget.file.path),
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      } else {
        // Safe fallback for empty content to avoid assertion crash
        await _controller!.loadData(
          data: '<html><body></body></html>',
          baseUrl: WebUri(widget.file.path),
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
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

    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useHybridComposition: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      gestureRecognizers: widget.gestureRecognizers ??
          const <Factory<OneSequenceGestureRecognizer>>{},
      onWebViewCreated: (InAppWebViewController controller) {
        _controller = controller;

        // Register controller with HtmlService
        final htmlService = Provider.of<HtmlService>(context, listen: false);
        htmlService.activeWebViewController = _controller;

        // Only load if we are on the browser tab
        if (htmlService.activeTabIndex == htmlService.browserTabIndex) {
          _loadContent();
        }
      },
      onLoadStart: (InAppWebViewController controller, WebUri? url) {
        if (!mounted) return;

        final urlString = url?.toString() ?? '';
        // Ignore internal or blank URLs for UI updates
        if (urlString == 'about:blank' || urlString.startsWith('data:')) return;

        _syncStage = 0;
        final htmlService = Provider.of<HtmlService>(context, listen: false);
        htmlService.updateWebViewUrl(urlString);
        htmlService.updateWebViewLoadingProgress(0.0);
      },
      onLoadStop: (InAppWebViewController controller, WebUri? url) async {
        if (!mounted) return;

        final urlString = url?.toString() ?? '';
        // Ignore internal or blank URLs for UI updates
        if (urlString == 'about:blank' || urlString.startsWith('data:')) return;

        // If we are viewing the RSS template, block sync to preserve XML source.
        if (_currentRssUrl != null && urlString == _currentRssUrl) {
          // If the app model has drifted (e.g. we came back from an article),
          // restore the original XML content.
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          if (htmlService.currentFile?.path != urlString) {
            htmlService.loadFromUrl(urlString);
          }
          return;
        }

        // Use syncWebViewState to update everything (content, metadata, probe)
        final htmlService = Provider.of<HtmlService>(context, listen: false);
        htmlService.syncWebViewState(urlString, isPartial: false);
        htmlService.updateWebViewLoadingProgress(1.0);
        _syncStage = 0;
      },
      onProgressChanged: (InAppWebViewController controller, int progress) {
        if (!mounted) return;

        final htmlService = Provider.of<HtmlService>(context, listen: false);
        htmlService.updateWebViewLoadingProgress(progress / 100.0);

        // Multi-Stage Early Sync:
        // We trigger partial syncs at several thresholds to populate tabs progressively.
        final url = htmlService.webViewLoadingUrl;
        if (url != null && url != 'about:blank') {
          if (progress >= 30 && progress < 60 && _syncStage < 1) {
            _syncStage = 1;
            htmlService.syncWebViewState(url, isPartial: true);
          } else if (progress >= 60 && progress < 90 && _syncStage < 2) {
            _syncStage = 2;
            htmlService.syncWebViewState(url, isPartial: true);
          } else if (progress >= 90 && progress < 100 && _syncStage < 3) {
            _syncStage = 3;
            htmlService.syncWebViewState(url, isPartial: true);
          }
        }
      },
      shouldOverrideUrlLoading: (InAppWebViewController controller,
          NavigationAction navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.ALLOW;

        final urlString = uri.toString();
        if (urlString == 'about:blank' || urlString.startsWith('data:')) {
          return NavigationActionPolicy.ALLOW;
        }

        // Only intercept navigation for the main frame.
        if (!navigationAction.isForMainFrame) {
          return NavigationActionPolicy.ALLOW;
        }

        final htmlService = Provider.of<HtmlService>(context, listen: false);

        // If it's the URL we are currently loading (set by loadUrl), allow it
        if (urlString == htmlService.webViewLoadingUrl ||
            urlString == htmlService.mainUrl) {
          return NavigationActionPolicy.ALLOW;
        }

        // Otherwise, intercept and run through our robust loadUrl flow
        // This ensures state reset, probe, and proper mode handling
        htmlService.loadUrl(urlString);
        return NavigationActionPolicy.CANCEL;
      },
      onReceivedError: (InAppWebViewController controller,
          WebResourceRequest request, WebResourceError error) {
        if (!mounted) return;

        final code = error.type.toNativeValue() ?? 0;
        final message = error.description;

        // SSL errors or other critical errors
        if (code == -1200 || message.contains('SSL')) {
          // SSL error
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          htmlService.handleWebViewError(
              'SSL Handshake Failed: $message. The system WebView enforces strict security.');
        } else if (code != -999) {
          // -999 is typically "cancelled" (e.g. valid reload)
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          htmlService.handleWebViewError(message);
        }
      },
      onUpdateVisitedHistory: (InAppWebViewController controller, WebUri? url,
          bool? androidIsReload) {
        if (!mounted) return;

        final urlString = url?.toString();
        if (urlString != null &&
            urlString != 'about:blank' &&
            !urlString.startsWith('data:')) {
          Provider.of<HtmlService>(context, listen: false)
              .updateWebViewUrl(urlString);
        }
      },
    );
  }
}
