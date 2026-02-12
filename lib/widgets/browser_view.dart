import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  final HtmlFile? file;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  const BrowserView({
    super.key,
    this.file,
    this.gestureRecognizers,
  });

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  late final WebViewController? _controller;
  final String viewID = 'browser-preview-view';
  String? _currentRssUrl;
// 0: none, 1: 30%, 2: 60%, 3: 90%

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // if (mounted) {
              //   final htmlService =
              //       Provider.of<HtmlService>(context, listen: false);
              //   htmlService.updateWebViewLoadingProgress(progress / 100.0);

              //   // Multi-Stage Early Sync:
              //   // We trigger partial syncs at several thresholds to populate tabs progressively.
              //   final url = htmlService.webViewLoadingUrl;
              //   if (url != null && url != 'about:blank') {
              //     if (progress >= 30 && progress < 60 && _syncStage < 1) {
              //       _syncStage = 1;
              //       htmlService.syncWebViewState(url, isPartial: true);
              //     } else if (progress >= 60 &&
              //         progress < 90 &&
              //         _syncStage < 2) {
              //       _syncStage = 2;
              //       htmlService.syncWebViewState(url, isPartial: true);
              //     } else if (progress >= 90 &&
              //         progress < 100 &&
              //         _syncStage < 3) {
              //       _syncStage = 3;
              //       htmlService.syncWebViewState(url, isPartial: true);
              //     }
              //   }
              // }
            },
            onPageStarted: (String url) {
              // if (mounted) {
              //   // Ignore internal or blank URLs for UI updates
              //   if (url == 'about:blank' || url.startsWith('data:')) return;

              //   _syncStage = 0;
              //   final htmlService =
              //       Provider.of<HtmlService>(context, listen: false);
              //   htmlService.updateWebViewUrl(url);
              //   htmlService.updateWebViewLoadingProgress(0.0);
              // }
            },
            onPageFinished: (String url) async {
              if (mounted) {
                // Ignore internal or blank URLs for UI updates
                if (url == 'about:blank' || url.startsWith('data:')) return;
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                if (await _controller?.currentUrl() != url) return;
                // If we are viewing the RSS template, block sync to preserve XML source.
                if (_currentRssUrl != null && url == _currentRssUrl) {
                  debugPrint('page finished rss $url');
                  // If the app model has drifted (e.g. we came back from an article),
                  // restore the original XML content.

                  if (htmlService.currentFile?.path != url) {
                    htmlService.loadFromUrl(url);
                  }
                  return;
                }
                debugPrint('page finished $url');
                // Use syncWebViewState to update everything (content, metadata, probe)
                htmlService.syncWebViewState(url, isPartial: false);
                htmlService.updateWebViewLoadingProgress(1.0);
              }
            },
            onUrlChange: (UrlChange change) async {
              if (!mounted) return;
              debugPrint('urlChange ${change.url}');
              final htmlService =
                  Provider.of<HtmlService>(context, listen: false);
              if (change.url == null ||
                  change.url == 'about:blank' ||
                  change.url!.startsWith('data:') ||
                  change.url == await _controller?.currentUrl()) {
                return;
              }

              htmlService.loadFromUrl(change.url as String,
                  switchToTab: htmlService.activeTabIndex);
            },
            onNavigationRequest: (NavigationRequest request) {
              if (!mounted) return NavigationDecision.prevent;
              if (request.url == 'about:blank' ||
                  request.url.startsWith('data:')) {
                return NavigationDecision.navigate;
              }

              // Only intercept navigation for the main frame.
              // Subframes (iframes) should generally be allowed to load their content
              // without triggering a full app navigation/URL update.
              if (!request.isMainFrame) {
                return NavigationDecision.navigate;
              }

              final htmlService =
                  Provider.of<HtmlService>(context, listen: false);

              // If it's the URL we are currently loading (set by loadFromUrl), allow it
              if (request.url == htmlService.webViewLoadingUrl) {
                return NavigationDecision.navigate;
              }
              debugPrint('onnav req ${request.url}');
              // Otherwise, intercept and run through our robust loadFromUrl flow
              // This ensures probe, reset, and proper mode (Browser/Fetch) handling
              // htmlService.loadFromUrl(request.url,
              //     switchToTab: htmlService.activeTabIndex);
              return NavigationDecision.navigate;
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                // If the main frame failed, stop loading indicator
                // We could check error.isForMainFrame if available, or just stop assuming generic error
                // On Android, SSL errors return -202 or generic codes.
                if (error.errorCode == -202 ||
                    error.description.contains('SSL')) {
                  // Specific handling for SSL
                  final htmlService =
                      Provider.of<HtmlService>(context, listen: false);
                  htmlService.handleWebViewError(
                      'SSL Handshake Failed: ${error.description}. The system WebView enforces strict security.');
                } else if (error.errorCode != -999) {
                  // -999 is typically "cancelled" (e.g. valid reload)
                  final htmlService =
                      Provider.of<HtmlService>(context, listen: false);
                  htmlService.handleWebViewError(error.description);
                }
              }
            },
          ),
        );

      // Register controller with HtmlService
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          htmlService.activeWebViewController = _controller;

          _controller?.setOnScrollPositionChange((scrollChange) {
            htmlService.webViewScrollY = scrollChange.y;
          });

          // Only load if we are on the browser tab or if we are forced to load
          if (htmlService.activeTabIndex == htmlService.browserTabIndex ||
              htmlService.isWebViewLoading) {
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
    if (widget.file?.isUrl ?? false) {
      return widget.file!.path;
    }
    // For local files, we might need to data-uri them if they are HTML
    return Uri.dataFromString(
      widget.file?.content ?? '',
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
  }

  @override
  void didUpdateWidget(BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the file changed (e.g. from local to URL or different content), reload.
    if (oldWidget.file?.path != widget.file?.path ||
        oldWidget.file?.content != widget.file?.content) {
      // CRITICAL FIX: Don't reload if WebView is already showing this URL
      // This prevents loops when syncWebViewState updates the file after navigation
      if (_controller != null && widget.file?.path != null) {
        _controller.currentUrl().then((currentUrlString) {
          final url = currentUrlString ?? '';

          // Skip reload if WebView is already on this URL
          if (url == widget.file!.path) {
            debugPrint(
                'didUpdateWidget: Skipping reload, WebView already on $url');
            return;
          }

          debugPrint(
              'didUpdateWidget: Reloading from $url to ${widget.file!.path}');
          _loadContentIfVisible();
        });
      } else {
        _loadContentIfVisible();
      }
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
    String targetUrl = widget.file?.path ??
        htmlService.webViewLoadingUrl ??
        htmlService.currentInputText ??
        '';

    // If there's a specialized loading URL (e.g. forceWebView path), use it.
    if (htmlService.webViewLoadingUrl != null) {
      targetUrl = htmlService.webViewLoadingUrl!;
    } else if (_currentRssUrl != null &&
        targetUrl == _currentRssUrl &&
        targetUrl.isNotEmpty) {
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
        widget.file?.name ?? '', widget.file?.content ?? '');

    if (isRssOrXml && (widget.file?.content.isNotEmpty ?? false)) {
      // Use temporary internal RSS rendering if needed
      final html = await RssTemplateService.convertRssToHtml(
          widget.file!.content, targetUrl);
      if (html.isNotEmpty) {
        _controller.loadHtmlString(html, baseUrl: targetUrl);
      }
      _currentRssUrl = targetUrl;
    } else {
      // If not RSS, or RSS but content is empty, proceed with normal loading
      _currentRssUrl = null;
      if (currentUrl == targetUrl && targetUrl.isNotEmpty) return;

      if (targetUrl.startsWith('http') && !targetUrl.contains('about:blank')) {
        await _controller.loadRequest(Uri.parse(targetUrl));
      } else if (widget.file?.content.isNotEmpty ?? false) {
        await _controller.loadHtmlString(widget.file!.content,
            baseUrl: widget.file!.path.isNotEmpty
                ? Uri.file(widget.file!.path).toString()
                : null);
      } else {
        // Safe fallback for empty content to avoid assertion crash
        await _controller.loadHtmlString('<html><body></body></html>',
            baseUrl: targetUrl);
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
      // gestures must bubble up for RefreshIndicator to work
      // we rely on the platform view's default behavior
    );
  }
}
