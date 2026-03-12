import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:view_source_vibe/models/html_file.dart';

import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/rss_template_service.dart';
import 'dart:io';
import 'dart:collection';

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
  HtmlService? _htmlService; // cached to use safely in dispose()
  String? _lastSyncedUrl; // track last early-synced URL to avoid duplicates

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the reference now while the element is still active.
    _htmlService = Provider.of<HtmlService>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Use the cached reference — Provider.of is NOT safe here
    // because the widget's element is already deactivated.
    _htmlService?.clearWebViewController();
    super.dispose();
  }

  @override
  void didUpdateWidget(BrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file?.path != widget.file?.path ||
        oldWidget.file?.content != widget.file?.content) {
      if (_controller != null && widget.file?.path != null) {
        _controller!.getUrl().then((currentUrlUri) async {
          if (!mounted) return;
          final url = currentUrlUri.toString();

          final isRss = await RssTemplateService.isRssFeed(
              widget.file?.name ?? '', widget.file?.content ?? '');

          if (!mounted) return;

          if (url == widget.file!.path && !isRss) {
            debugPrint(
                'didUpdateWidget: Skipping reload, WebView already on $url');
            return;
          }

          debugPrint(
              'didUpdateWidget: Reloading from $url to ${widget.file!.path}');
          _loadContentIfVisible();
        }).catchError((e) {
          debugPrint('didUpdateWidget: controller error (likely disposed): $e');
        });
      } else {
        _loadContentIfVisible();
      }
    }
  }

  void _loadContentIfVisible() {
    if (!mounted) return;
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    if (htmlService.activeTabIndex == htmlService.browserTabIndex) {
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    if (_controller == null || !mounted) return;

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
        final htmlService = Provider.of<HtmlService>(context, listen: false);
        htmlService.reloadCurrentFile();
        setState(() {});
      },
      initialSettings: InAppWebViewSettings(
        isInspectable: true,
        preferredContentMode: UserPreferredContentMode.RECOMMENDED,
        mediaPlaybackRequiresUserGesture: false,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowContentAccess: false,
        allowsInlineMediaPlayback: true,
        iframeAllowFullscreen: false,
        useHybridComposition: _shouldUseHybridComposition(),
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: '''
              if (window.performance && performance.setResourceTimingBufferSize) {
                performance.setResourceTimingBufferSize(10000);
              }
            ''',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
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
        _lastSyncedUrl = null;
      },
      onLoadStop: (controller, url) async {
        if (mounted && url != null) {
          final urlString = url.toString();
          // Block data: and blob: URLs
          if (urlString.startsWith('data:') || urlString.startsWith('blob:')) {
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
          _lastSyncedUrl = urlString;
          htmlService.updateWebViewLoadingProgress(1.0);
        }
      },
      onProgressChanged: (controller, progress) async {
        final htmlService = Provider.of<HtmlService>(context, listen: false);
        htmlService.updateWebViewLoadingProgress(progress / 100.0);

        // Early sync: trigger state update at 98% done to fill tabs faster
        // while the last bits of slow resources (analytics trackers etc) might still be loading.
        if (progress >= 98 && progress < 100 && _lastSyncedUrl == null) {
          final url = await controller.getUrl();
          final urlString = url?.toString();
          if (urlString != null && _lastSyncedUrl != urlString) {
            _lastSyncedUrl = urlString;
            htmlService.syncWebViewState(urlString, isPartial: true);
          }
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? true) {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          htmlService.handleWebViewError(error.description);
        }
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        if (request.isForMainFrame ?? true) {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          // Http errors mean we got a response like 404, we don't necessarily want to kill the view completely
          // but we should mark loading as done.
          htmlService.updateWebViewLoadingProgress(1.0);
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url!;
        final url = uri.toString();

        // Block data: and blob: URLs from loading
        if (url.startsWith('data:') || url.startsWith('blob:')) {
          return NavigationActionPolicy.CANCEL;
        }

        if (url == 'about:blank') {
          return NavigationActionPolicy.ALLOW;
        }

        if (navigationAction.isForMainFrame) {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          // If this is the load we just triggered internally, allow it
          // We use null check because webViewLoadingUrl is cleared once load starts/completes
          final isPendingLoad = htmlService.webViewLoadingUrl != null &&
              htmlService.areUrlsEqual(url, htmlService.webViewLoadingUrl!);

          // Also allow if it's the current file path (e.g. RSS template load with baseUrl)
          final isCurrentFile = htmlService.currentFile != null &&
              htmlService.areUrlsEqual(url, htmlService.currentFile!.path);

          if (isPendingLoad || isCurrentFile) {
            return NavigationActionPolicy.ALLOW;
          }

          // Otherwise, intercept and redirect through standard loadUrl flow
          // This ensures that clicking links or redirects are handled by the app's unified loading logic
          debugPrint('Intercepting main-frame navigation to: $url');
          htmlService.loadUrl(url);
          return NavigationActionPolicy.CANCEL;
        }

        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  bool _shouldUseHybridComposition() {
    if (!Platform.isAndroid) return true;

    try {
      final osVersion = Platform.operatingSystemVersion.toLowerCase();

      // Prioritize API level check if present (e.g., "API 29")
      // Android 10 is API level 29
      final apiMatch = RegExp(r'api\s+(\d+)').firstMatch(osVersion);
      if (apiMatch != null) {
        final apiLevel = int.parse(apiMatch.group(1)!);
        return apiLevel >= 29;
      }

      // Fallback to version number (e.g., "Android 10", "11 (REL)")
      final versionMatch =
          RegExp(r'(?:android\s+)?(\d+)').firstMatch(osVersion);
      if (versionMatch != null) {
        final version = int.parse(versionMatch.group(1)!);
        // If the number is clearly a version (1-15), check it.
        // If it's larger and we haven't hit the API check yet, it's ambiguous,
        // but most modern Android strings include "Android X" or "API Y".
        return version >= 10;
      }
    } catch (e) {
      debugPrint('BrowserView: Error parsing Android version: $e');
    }

    return true; // Default to true if parsing fails
  }
}
