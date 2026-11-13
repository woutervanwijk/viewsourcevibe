import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/collectors/readability_js.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/reader_service.dart';
import 'package:view_source_vibe/utils/low_resource_webview.dart';

/// The Reader tab: the current page rendered as a clean article, extracted
/// with Readability.js (see [ReaderService]). All parsing happens in the
/// service; this widget shows the result in a read-only WebView that is
/// created with its content (`initialData`), so no racy loadData is needed.
class ReaderView extends StatefulWidget {
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  const ReaderView({super.key, this.gestureRecognizers});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  ReaderService? _reader;
  AppSettings? _appSettings;
  bool _inViewParsed = false;

  @override
  void initState() {
    super.initState();
    _reader = context.read<ReaderService>();
    _reader!.addListener(_onReader);
    _appSettings = context.read<AppSettings>();
    _appSettings!.addListener(_onAppSettings);
    // Sync after the first frame so notifyListeners never fires mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWithService());
  }

  @override
  void dispose() {
    _reader?.removeListener(_onReader);
    _appSettings?.removeListener(_onAppSettings);
    _reader?.setViewController(null);
    super.dispose();
  }

  /// Applies live-adjustable settings (low-resource renderer policy) to the
  /// running reader WebView when the setting changes.
  void _onAppSettings() {
    final s = _appSettings;
    if (s == null) return;
    _reader?.viewController?.setSettings(settings: _buildSettings(s)).ignore();
  }

  void _onReader() => _syncWithService();

  /// Kicks off extraction when the article is missing or outdated. Rendering
  /// itself is driven by [build] (the WebView is created with initialData).
  void _syncWithService() {
    final r = _reader;
    if (r == null || !mounted) return;
    if (r.status == ReaderStatus.idle && r.isStale) {
      // A new page loaded while this tab was kept alive: re-extract once the
      // load has finished (parsing a half-loaded page would fail).
      if (!context.read<HtmlService>().isLoading) {
        debugPrint('[Reader] view: stale article, extracting');
        r.extractIfStale();
      }
    }
  }

  Future<void> _parseInView(InAppWebViewController controller) async {
    _inViewParsed = true;
    debugPrint('[Reader] view: parsing raw document inside the reader WebView');
    try {
      final result = await controller.evaluateJavascript(
          source: vsvReadabilityEvalJs);
      if (!mounted) return;
      debugPrint(
          '[Reader] view: in-view parse returned ${result == null ? 'null' : '${result.toString().length} chars'}');
      // Records the article; the next build shows it via initialData.
      _reader?.applyInViewResult(result);
    } catch (e) {
      debugPrint('[Reader] view: in-view parse threw: $e');
      if (!mounted) return;
      _reader?.applyInViewError('$e');
    }
  }

  InAppWebViewSettings _buildSettings(AppSettings s) => InAppWebViewSettings(
        isInspectable: kDebugMode,
        mediaPlaybackRequiresUserGesture: true,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowContentAccess: false,
        allowsInlineMediaPlayback: true,
        rendererPriorityPolicy: lowResourceRendererPriorityPolicy(s),
      );

  void _onWebViewCreated(InAppWebViewController controller) {
    debugPrint('[Reader] view: WebView created');
    _reader?.setViewController(controller);
  }

  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    final r = _reader;
    if (r != null && r.status == ReaderStatus.inView && !_inViewParsed) {
      await _parseInView(controller);
    }
  }

  Future<NavigationActionPolicy> _shouldOverrideUrlLoading(
      InAppWebViewController controller, NavigationAction navigationAction) async {
    final url = navigationAction.request.url?.toString() ?? '';
    final html = context.read<HtmlService>();
    final file = html.currentFile;
    // The tab's own programmatic load of the current page must be allowed.
    final isCurrentPage = file != null && html.areUrlsEqual(url, file.path);
    if (isCurrentPage) return NavigationActionPolicy.ALLOW;
    // Links tapped in the article open in the Browser tab.
    if (navigationAction.isForMainFrame &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      if (mounted) {
        debugPrint('[Reader] view: link tap → browser tab: $url');
        html.beginBrowserNavigation(url);
      }
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderService>();
    final appSettings = context.watch<AppSettings>();
    // Watch the effective dark mode so a theme change re-renders the article.
    return Selector<AppSettings, bool>(
      selector: (context, s) => s.themeMode == ThemeModeOption.system
          ? s.darkMode
          : s.themeMode == ThemeModeOption.dark,
      builder: (context, dark, _) {
        switch (reader.status) {
          case ReaderStatus.idle:
          case ReaderStatus.extracting:
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Extracting article…'),
                ],
              ),
            );
          case ReaderStatus.noArticle:
            return _message(
              context,
              Icons.article_outlined,
              'No readable article found on this page',
            );
          case ReaderStatus.error:
            final detail = reader.errorMessage;
            return _message(
              context,
              Icons.error_outline,
              'Reader mode failed${detail == null || detail.isEmpty ? '' : ': $detail'}',
            );
          case ReaderStatus.ready:
            final html = reader.buildRenderHtml(dark: dark);
            if (html == null) {
              return _message(context, Icons.article_outlined,
                  'No readable article found on this page');
            }
            final base = reader.baseUrl;
            return InAppWebView(
              key: ValueKey('reader-article-${html.hashCode}'),
              gestureRecognizers: widget.gestureRecognizers,
              initialSettings: _buildSettings(appSettings),
              initialData: InAppWebViewInitialData(
                data: html,
                baseUrl: base != null && base.isNotEmpty ? WebUri(base) : null,
              ),
              onWebViewCreated: _onWebViewCreated,
              onLoadStart: (controller, url) => _inViewParsed = false,
              onLoadStop: _onLoadStop,
              shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
            );
          case ReaderStatus.inView:
            // No live WebView matches this file: load the raw document into
            // this WebView (from the app's own copy, no second network load)
            // and parse it here on load stop.
            final file = context.read<HtmlService>().currentFile;
            final path = file?.path ?? '';
            final content = file?.content ?? '';
            final base = path.isNotEmpty ? WebUri(path) : null;
            return InAppWebView(
              key: ValueKey('reader-raw-$path'),
              gestureRecognizers: widget.gestureRecognizers,
              initialSettings: _buildSettings(appSettings),
              initialData: content.isNotEmpty
                  ? InAppWebViewInitialData(data: content, baseUrl: base)
                  : null,
              initialUrlRequest: content.isEmpty &&
                      (file?.isUrl ?? false) &&
                      path.startsWith('http')
                  ? URLRequest(url: WebUri(path))
                  : null,
              onWebViewCreated: _onWebViewCreated,
              onLoadStart: (controller, url) => _inViewParsed = false,
              onLoadStop: _onLoadStop,
              shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
            );
        }
      },
    );
  }

  Widget _message(BuildContext context, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _reader?.extract(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
