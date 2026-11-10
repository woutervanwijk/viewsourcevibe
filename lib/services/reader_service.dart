import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:view_source_vibe/services/collectors/readability_js.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// What the Reader tab is doing.
enum ReaderStatus {
  /// Nothing extracted yet (or invalidated by a new page load).
  idle,

  /// Readability is running against the live page.
  extracting,

  /// An article was extracted and can be rendered.
  ready,

  /// The page has no readable article (Readability returned null).
  noArticle,

  /// Extraction threw.
  error,

  /// No live WebView matches the current file, so the Reader tab's own
  /// WebView loads the raw document and parses it there.
  inView,
}

/// The article Readability extracted from a page.
class ReaderArticle {
  final String title;
  final String byline;
  final String excerpt;
  final String content;
  final int length;
  final String siteName;
  final String publishedTime;
  final String dir;
  final String lang;

  const ReaderArticle({
    required this.title,
    required this.byline,
    required this.excerpt,
    required this.content,
    required this.length,
    required this.siteName,
    required this.publishedTime,
    required this.dir,
    required this.lang,
  });

  factory ReaderArticle.fromJson(Map<String, dynamic> json) => ReaderArticle(
        title: '${json['title'] ?? ''}',
        byline: '${json['byline'] ?? ''}',
        excerpt: '${json['excerpt'] ?? ''}',
        content: '${json['content'] ?? ''}',
        length: (json['length'] as num?)?.toInt() ?? 0,
        siteName: '${json['siteName'] ?? ''}',
        publishedTime: '${json['publishedTime'] ?? ''}',
        dir: '${json['dir'] ?? ''}',
        lang: '${json['lang'] ?? ''}',
      );

  /// Rough reading time at 200 words per minute (word ~= 5 characters).
  int get readingTimeMinutes {
    if (length <= 0) return 0;
    return (length / 5 / 200).ceil().clamp(1, 999);
  }
}

/// State and extraction logic for the Reader tab. Extraction runs
/// Readability.js inside a WebView that already shows the page (preferred:
/// the Browser tab's live DOM) and hands the article HTML to the Reader
/// tab's own WebView for rendering.
class ReaderService extends ChangeNotifier {
  final HtmlService _html;

  ReaderService(this._html) {
    // A new navigation bumps the store's generation; when that happens the
    // extracted article is outdated. Reset to idle so the view re-extracts.
    _html.addListener(_onHtmlChanged);
  }

  @override
  void dispose() {
    _html.removeListener(_onHtmlChanged);
    super.dispose();
  }

  void _onHtmlChanged() {
    if (!isStale) return;
    if (_status == ReaderStatus.extracting) return;
    if (_status != ReaderStatus.idle || _article != null) {
      _status = ReaderStatus.idle;
      _article = null;
    }
    // Re-notify even when already idle: the load may have just finished,
    // which is the moment the Reader view can extract successfully.
    notifyListeners();
  }

  ReaderStatus _status = ReaderStatus.idle;
  ReaderArticle? _article;
  String? _errorMessage;
  int? _extractedGeneration;
  bool _extracting = false;

  /// The Reader tab's own WebView, for scroll-to-top.
  InAppWebViewController? _viewController;

  ReaderStatus get status => _status;
  ReaderArticle? get article => _article;
  String? get errorMessage => _errorMessage;

  /// True when the extracted article belongs to an older page generation.
  bool get isStale => _extractedGeneration != _generation;

  int get _generation => _html.store.current.generation;

  /// Base URL for resolving the article's relative resources: the loaded
  /// page's own URL (or file path).
  String? get baseUrl {
    final path = _html.currentFile?.path ?? '';
    return path.isEmpty ? null : path;
  }

  void setViewController(InAppWebViewController? controller) {
    _viewController = controller;
  }

  /// The Reader tab's WebView controller, for handing it keyboard focus.
  InAppWebViewController? get viewController => _viewController;

  Future<void> scrollToTop() async {
    try {
      await _viewController?.scrollTo(x: 0, y: 0);
    } catch (_) {}
  }

  /// Extracts only when the current article is missing or outdated.
  Future<void> extractIfStale() async {
    if (_extracting) return;
    if (!isStale &&
        _status != ReaderStatus.idle &&
        _status != ReaderStatus.error) {
      return;
    }
    await extract();
  }

  /// Runs Readability against the live page when the Browser tab's WebView
  /// shows the current file; otherwise switches to [ReaderStatus.inView] so
  /// the Reader tab's WebView loads the raw document and parses it there.
  Future<void> extract() async {
    if (_extracting) return;
    _extracting = true;
    _status = ReaderStatus.extracting;
    _errorMessage = null;
    notifyListeners();
    final gen = _generation;
    try {
      final controller = _html.activeWebViewController;
      WebUri? liveUrl;
      if (controller != null) {
        try {
          liveUrl = await controller.getUrl();
        } catch (_) {}
      }
      final file = _html.currentFile;
      final liveMatches = liveUrl != null &&
          file != null &&
          _html.areUrlsEqual(liveUrl.toString(), file.path);
      debugPrint(
          '[Reader] extract: liveUrl=$liveUrl file=${file?.path} liveMatch=$liveMatches');
      if (controller != null && liveMatches) {
        final result =
            await controller.evaluateJavascript(source: vsvReadabilityEvalJs);
        if (gen != _generation) return; // navigated away meanwhile
        debugPrint(
            '[Reader] live eval returned ${result == null ? 'null' : '${result.toString().length} chars'}');
        if (result == null) {
          // The live evaluation came back empty (blocked or failed
          // silently): parse the app's own copy of the page instead.
          _status = ReaderStatus.inView;
        } else {
          applyResult(result);
        }
        _extractedGeneration = gen;
      } else {
        _status = ReaderStatus.inView;
        _extractedGeneration = gen;
      }
    } catch (e) {
      if (gen == _generation) {
        _status = ReaderStatus.error;
        _errorMessage = '$e';
      }
    } finally {
      _extracting = false;
      notifyListeners();
    }
  }

  /// Parses what the in-page parse script returned. Called by [extract]
  /// (live WebView) and by the Reader tab after parsing inside its own
  /// WebView. Does not notify; callers do.
  ReaderArticle? applyResult(Object? result) {
    _article = null;
    if (result == null) {
      _status = ReaderStatus.noArticle;
      return null;
    }
    // Some platforms hand back an already-decoded object.
    if (result is Map) {
      return _applyDecoded(result.cast<String, dynamic>());
    }
    var text = result.toString();
    if (text.isEmpty || text == 'null') {
      _status = ReaderStatus.noArticle;
      return null;
    }
    // Some platforms wrap a returned JS string in quotes (a JSON string
    // literal); unwrap that before parsing.
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      try {
        final unwrapped = jsonDecode(text);
        if (unwrapped is String) text = unwrapped;
      } catch (_) {}
    }
    try {
      return _applyDecoded(jsonDecode(text));
    } catch (e) {
      _status = ReaderStatus.error;
      _errorMessage = '$e';
      return null;
    }
  }

  ReaderArticle? _applyDecoded(Object? decoded) {
    if (decoded is Map && decoded['error'] != null) {
      _status = ReaderStatus.error;
      _errorMessage = '${decoded['error']}';
      debugPrint('[Reader] parse error: $_errorMessage');
      return null;
    }
    if (decoded is Map<String, dynamic>) {
      _article = ReaderArticle.fromJson(decoded);
      _status = ReaderStatus.ready;
      debugPrint(
          '[Reader] article ready: title="${_article!.title}" length=${_article!.length}');
      return _article;
    }
    _status = ReaderStatus.noArticle;
    debugPrint('[Reader] no article on this page');
    return null;
  }

  /// Same as [applyResult], but called when parsing happened inside the
  /// Reader tab's own WebView; notifies listeners.
  void applyInViewResult(Object? result) {
    applyResult(result);
    notifyListeners();
  }

  /// The in-WebView parse threw; record it as an error.
  void applyInViewError(String message) {
    _status = ReaderStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// A new page load invalidated the extracted article.
  void markStale() {
    _extractedGeneration = null;
    if (_status == ReaderStatus.extracting) return;
    if (_status == ReaderStatus.idle && _article == null) return;
    _status = ReaderStatus.idle;
    _article = null;
    notifyListeners();
  }

  /// Wraps the extracted article in the reader template, or null when there
  /// is no article.
  String? buildRenderHtml({required bool dark}) {
    final a = _article;
    if (a == null) return null;
    return wrapInReaderTemplate(a, dark: dark, baseUrl: baseUrl);
  }
}

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Wraps Readability's article HTML in a minimal reader page: a centered
/// column, serif text, and colors matching the app's light/dark theme.
/// [baseUrl] resolves the article's relative images and links.
String wrapInReaderTemplate(
  ReaderArticle article, {
  required bool dark,
  String? baseUrl,
}) {
  final bg = dark ? '#1e1e1e' : '#ffffff';
  final fg = dark ? '#e6e6e6' : '#1a1a1a';
  final muted = dark ? '#9e9e9e' : '#666666';
  final link = dark ? '#8ab4f8' : '#1a56db';
  final border = dark ? '#3c3c3c' : '#e0e0e0';
  final base = (baseUrl == null || baseUrl.isEmpty)
      ? ''
      : '<base href="${_escapeHtml(baseUrl)}">';
  final lang = article.lang.isNotEmpty ? ' lang="${_escapeHtml(article.lang)}"' : '';
  final dir =
      article.dir.isNotEmpty ? ' dir="${_escapeHtml(article.dir)}"' : '';
  final title = _escapeHtml(article.title.isNotEmpty
      ? article.title
      : (article.siteName.isNotEmpty ? article.siteName : 'Reader'));
  final byline = [article.byline, article.siteName]
      .where((s) => s.isNotEmpty)
      .map(_escapeHtml)
      .join(' · ');
  final reading = article.readingTimeMinutes > 0
      ? ' · ${article.readingTimeMinutes} min read'
      : '';
  final header = byline.isEmpty
      ? ''
      : '<p class="byline">$byline$reading</p>';

  return '''<!DOCTYPE html>
<html$dir$lang>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
$base
<title>$title</title>
<style>
  html { background: $bg; }
  body {
    margin: 0;
    background: $bg;
    color: $fg;
    font-family: Georgia, 'Times New Roman', serif;
    font-size: 19px;
    line-height: 1.7;
  }
  article {
    max-width: 42em;
    margin: 0 auto;
    padding: 24px 20px 64px;
  }
  h1 {
    font-size: 1.6em;
    line-height: 1.3;
    margin: 0 0 8px;
  }
  .byline {
    color: $muted;
    font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
    font-size: 0.75em;
    margin: 0 0 24px;
    padding-bottom: 16px;
    border-bottom: 1px solid $border;
  }
  img, video, svg { max-width: 100%; height: auto; }
  a { color: $link; }
  pre, code {
    font-family: 'SF Mono', Menlo, Consolas, monospace;
    font-size: 0.85em;
    background: ${dark ? '#2a2a2a' : '#f4f4f4'};
    border-radius: 4px;
  }
  pre { padding: 12px; overflow-x: auto; }
  blockquote {
    margin: 1.2em 0;
    padding-left: 16px;
    border-left: 3px solid $border;
    color: $muted;
  }
  table { border-collapse: collapse; max-width: 100%; }
  th, td { border: 1px solid $border; padding: 6px 10px; }
</style>
</head>
<body>
<article>
  <header>
    <h1>$title</h1>
    $header
  </header>
  ${article.content}
</article>
</body>
</html>''';
}
