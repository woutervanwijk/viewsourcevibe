import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:view_source_vibe/models/html_file.dart';

import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/rss_template_service.dart';
import 'dart:io';

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
  InAppWebViewController? _controller;
  String? _currentRssUrl;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file?.path != widget.file?.path ||
        oldWidget.file?.content != widget.file?.content) {
      if (_controller != null && widget.file?.path != null) {
        _controller!.getUrl().then((currentUrlUri) async {
          final url = currentUrlUri.toString();

          final isRss = await RssTemplateService.isRssFeed(
              widget.file?.name ?? '', widget.file?.content ?? '');

          if (url == widget.file!.path && !isRss) {
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

    if (htmlService.webViewLoadingUrl != null) {
      targetUrl = htmlService.webViewLoadingUrl!;
    } else if (_currentRssUrl != null &&
        targetUrl == _currentRssUrl &&
        targetUrl.isNotEmpty) {
      return;
    }

    final currentUrlUri = await _controller!.getUrl();
    final currentUrl = currentUrlUri.toString();

    var isRssOrXml = await RssTemplateService.isRssFeed(
        widget.file?.name ?? '', widget.file?.content ?? '');

    // Robust check: if content inspection failed, check headers from probe
    if (!isRssOrXml && widget.file?.probeResult != null) {
      final headers = widget.file!.probeResult!['headers'];
      if (headers is Map) {
        final contentType =
            headers['content-type']?.toString().toLowerCase() ?? '';
        if (contentType.contains('application/rss+xml') ||
            contentType.contains('application/atom+xml')) {
          debugPrint(
              'BrowserView: Detected RSS/Atom via Content-Type header: $contentType');
          isRssOrXml = true;
        }
      }
    }

    if (isRssOrXml && (widget.file?.content.isNotEmpty ?? false)) {
      final html = await RssTemplateService.convertRssToHtml(
          widget.file!.content, targetUrl);
      if (html.isNotEmpty) {
        _controller!.loadData(data: html, baseUrl: WebUri(targetUrl));
      }
      _currentRssUrl = targetUrl;
    } else {
      _currentRssUrl = null;
      if (currentUrl == targetUrl && targetUrl.isNotEmpty) return;

      if (targetUrl.startsWith('http') && !targetUrl.contains('about:blank')) {
        await _controller!
            .loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
      } else if (widget.file?.content.isNotEmpty ?? false) {
        await _controller!.loadData(
            data: widget.file!.content,
            baseUrl: widget.file!.path.isNotEmpty
                ? WebUri(widget.file!.path)
                : null);
      } else {
        await _controller!.loadData(
            data: '<html><body></body></html>', baseUrl: WebUri(targetUrl));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      gestureRecognizers: widget.gestureRecognizers,
      onWebContentProcessDidTerminate: (controller) {
        controller.reload();
        setState(() {});
      },
      initialSettings: InAppWebViewSettings(
        isInspectable: kDebugMode,
        preferredContentMode: UserPreferredContentMode.RECOMMENDED,
        mediaPlaybackRequiresUserGesture: false,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowContentAccess: false,
        allowsInlineMediaPlayback: true,
        iframeAllowFullscreen: false,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        final htmlService = Provider.of<HtmlService>(context, listen: false);
        htmlService.activeWebViewController = controller;

        // Fix macOS background color crash
        if (!Platform.isMacOS) {
          // setBackgroundColor is not available/needed in the same way, usually handled by CSS or initial settings
          // InAppWebViewSettings has transparentBackground option if needed.
        }

        if (htmlService.activeTabIndex == htmlService.browserTabIndex ||
            htmlService.isWebViewLoading) {
          _loadContent();
        }
      },
      onLoadStart: (controller, url) {
        // Handle load start
      },
      onLoadStop: (controller, url) async {
        if (mounted && url != null) {
          final urlString = url.toString();
          if (urlString == 'about:blank' || urlString.startsWith('data:')) {
            return;
          }

          final htmlService = Provider.of<HtmlService>(context, listen: false);
          if ((await controller.getUrl()).toString() != urlString) return;

          if (_currentRssUrl != null && urlString == _currentRssUrl) {
            if (htmlService.currentFile?.path != urlString) {
              htmlService.loadFromUrl(urlString);
            }
            return;
          }

          htmlService.syncWebViewState(urlString, isPartial: false);
          htmlService.updateWebViewLoadingProgress(1.0);
        }
      },
      onProgressChanged: (controller, progress) {
        // Handle progress
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url!;
        final url = uri.toString();

        if (url == 'about:blank' || url.startsWith('data:')) {
          return NavigationActionPolicy.ALLOW;
        }

        if (navigationAction.isForMainFrame) {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          if (url == htmlService.webViewLoadingUrl) {
            return NavigationActionPolicy.ALLOW;
          }
        }

        return NavigationActionPolicy.ALLOW;
      },
    );
  }
}
