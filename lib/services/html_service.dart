import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_editor/re_editor.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:view_source_vibe/utils/code_beautifier.dart';
import 'package:view_source_vibe/utils/font_url.dart';
import 'package:view_source_vibe/services/source_viewer_editor.dart';
import 'package:view_source_vibe/services/probe_service.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';
import 'package:view_source_vibe/services/file_type_detector.dart';
import 'package:view_source_vibe/services/app_state_service.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/url_history_service.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    hide X509Certificate;
import 'package:xml/xml.dart' as xml;
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/collectors/browser_loader.dart';
import 'package:view_source_vibe/services/collectors/file_loader.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/legacy_probe_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Extracts page metadata from source (isolate in production, a fake in tests).
typedef MetadataExtractor = Future<Map<String, dynamic>>
    Function(String html, String baseUrl, {Map<String, String>? headers});

typedef SovereigntyAnalyzer = Future<SovereigntyReport> Function({
  required String pageUrl,
  required Map<String, dynamic>? probeResult,
  required List<Map<String, dynamic>> resources,
  Map<String, dynamic>? metadata,
  List<Detection> detections,
  String? html,
  String home,
});

class HtmlService extends ChangeNotifier {
  final SovereigntyAnalyzer _sovereigntyAnalyzer;

  /// Test hook: awaited right after a server file was built.
  @visibleForTesting
  Future<void> Function()? debugAfterServerFileBuilt;

  @visibleForTesting
  Map<String, dynamic>? get lastPageWeight => _lastPageWeight;

  /// The central inspection data (server, browser and file cores).
  final InspectionStore store;
  final bool _ownsStore;
  final ServerFetcher _serverFetcher;
  late final BrowserLoader _browserLoader;
  final MetadataExtractor _metadataExtractor;
  bool _disposed = false;

  /// The server fetch of the current navigation (null when none runs).
  Future<void>? _serverFetch;

  // Cached legacy probe map, rebuilt when the store or browser cookies change.
  Map<String, dynamic>? _probeCache;
  PageInspection? _probeCacheFor;

  bool _metadataRerunQueued = false;

  HtmlFile? _currentFile;
  int? _requestedTabIndex;
  int? get requestedTabIndex => _requestedTabIndex;
  HtmlFile? _originalFile; // Store original file for "Automatic" option
  String? _pendingUrl;
  String? _currentInputText;
  bool _isLoading = false;
  String?
      selectedContentType; // Track the selected content type for syntax highlighting
  AppSettings? _appSettings;
  UrlHistoryService? _urlHistoryService;
  AppStateService? _appStateService;
  GlobalKey? _codeEditorKey;

  // Editor state
  ScrollController? _verticalScrollController;
  ScrollController? _activeHorizontalScrollController;
  Timer? _disposalTimer;
  final List<dynamic> _disposalQueue = [];
  Timer? _highlightDebounceTimer;

  // Search state
  bool _isSearchEnabled = false;
  CodeFindController? _activeFindController;

  // Navigation stack for "Back" functionality
  final List<HtmlFile> _navigationStack = [];
  bool _isNavigatingBack = false;

  // Probe state: the server side lives in [store]; these are browser-derived.
  SovereigntyReport? _sovereigntyReport;
  bool _isAnalyzingSovereignty = false;
  Map<String, dynamic>?
      _browserProbeResult; // Store separate browser probe data

  // Metadata state
  Map<String, dynamic>? _pageMetadata;
  Map<String, dynamic>? get pageMetadata => _pageMetadata;
  Map<String, dynamic>? _lastPageWeight; // Store weights: transfer and decoded
  List<Map<String, dynamic>>?
      _resourcePerformanceData; // Store detailed resource data
  bool _isExtractingMetadata = false;
  String _lastBrowserCookies = '';

  double _webViewLoadingProgress = 0.0;
  double get webViewLoadingProgress => _webViewLoadingProgress;

  // WebView extraction state
  bool _isWebViewLoading = false;
  bool get isWebViewLoading => _isWebViewLoading;
  String? _webViewLoadingUrl;
  String? get webViewLoadingUrl => _webViewLoadingUrl;

  // URL added to history when a browser load started; replaced by the final
  // URL if the load redirects.
  String? _historyPendingUrl;

  // Track last file update to detect rapid redirects
  DateTime? _lastCurrentFileUpdate;

  bool _isBeautifyEnabled = false;
  bool get isBeautifyEnabled => _isBeautifyEnabled;
  final Map<String, String> _beautifiedCache = {};
  final ValueNotifier<double> webViewScrollNotifier = ValueNotifier(0.0);
  double _webViewScrollY = 0.0;
  DateTime? _lastScrollUpdate;
  double get webViewScrollY => _webViewScrollY;

  set webViewScrollY(double value) {
    if (_webViewScrollY != value) {
      _webViewScrollY = value;

      // Throttle updates to avoid excessive rebuilds (100ms)
      // Always update if it's 0 (top) or the first update to ensure "Scroll to Top" button behaves correctly
      final now = DateTime.now();
      if (value == 0 ||
          _lastScrollUpdate == null ||
          now.difference(_lastScrollUpdate!).inMilliseconds > 100) {
        _lastScrollUpdate = now;
        webViewScrollNotifier.value = value;
      }
      // Do NOT notifyListeners() here - it causes full app rebuild on every scroll frame
    }
  }

  InAppWebViewController? _activeWebViewController;
  bool _webViewControllerDisposed = false;

  InAppWebViewController? get activeWebViewController =>
      _webViewControllerDisposed ? null : _activeWebViewController;

  set activeWebViewController(InAppWebViewController? controller) {
    _activeWebViewController = controller;
    _webViewControllerDisposed = false;
  }

  void clearWebViewController() {
    _webViewControllerDisposed = true;
    _activeWebViewController = null;
  }

  Timer? _autoSaveTimer;

  // Index of the currently active tab in HomeScreen
  int _activeTabIndex = 0;
  int get activeTabIndex => _activeTabIndex;

  // Dynamic Tab Indices based on settings
  bool get _useBrowserByDefault => _appSettings?.useBrowserByDefault ?? true;

  /// Whether pages load in the Browser tab by default (browser-first mode).
  bool get useBrowserByDefault => _useBrowserByDefault;

  /// The index of the Browser tab in the current tab layout.
  int get browserTabIndex {
    if (_useBrowserByDefault) return 0;
    int idx = 1; // Source
    if (isHtmlOrXml) idx += 1; // DOM Tree
    if (showMetadataTabs) {
      idx += 5; // Metadata + Media + Size + Services + Privacy
    }
    if (showServerTabs) {
      idx += 6; // Cookies + Timeline + Probe + Headers + Security + Sovereignty
    }
    return idx;
  }

  /// Symbolic tab requests, resolved by HomeScreen once the tab layout for
  /// the newly loaded content is known.
  static const viewerTab = -1;
  static const sourceTab = -2;

  int resolveTabRequest(int index) => switch (index) {
        viewerTab => viewerTabIndex,
        sourceTab => sourceTabIndex,
        _ => index,
      };

  /// Source sits right of DOM Tree, which sits right of the metadata tabs.
  int get sourceTabIndex {
    int idx = _useBrowserByDefault ? 1 : 0; // Browser first
    if (showMetadataTabs) {
      idx += 5; // Metadata + Media + Size + Services + Privacy
      if (showServerTabs) idx += 1; // Sovereignty
    }
    if (isHtmlOrXml) idx += 1; // DOM Tree
    return idx;
  }

  /// Tab that shows the loaded file itself: Browser if first, else Source.
  int get viewerTabIndex => _useBrowserByDefault ? 0 : sourceTabIndex;

  HtmlFile? get currentFile => _currentFile;
  ScrollController? get scrollController => _verticalScrollController;
  ScrollController? get horizontalScrollController =>
      _activeHorizontalScrollController;
  GlobalKey? get codeEditorKey => _codeEditorKey;

  // Expose probe state
  /// Legacy view of the server data: null until the server answered, and for
  /// local files or failed fetches. Never a placeholder.
  Map<String, dynamic>? get probeResult => _probeResult;
  Map<String, dynamic>? get _probeResult {
    final current = store.current;
    if (!identical(current, _probeCacheFor)) {
      _probeCache = legacyProbeMap(current);
      _probeCacheFor = current;
    }
    return _probeCache;
  }

  Map<String, dynamic>? get browserProbeResult =>
      _browserProbeResult; // Expose browser probe result

  /// The HTML exactly as the server sent it; null while unknown.
  String? get serverSource {
    final server = store.current.server;
    if (server is! Present<ServerSnapshot>) return null;
    final body = server.value.body;
    if (body is! Present<ServerBody> || body.value.decoded.isBinary) {
      return null;
    }
    return body.value.decoded.text;
  }

  List<Map<String, dynamic>> get resourceTimelineData =>
      List.unmodifiable(_resourcePerformanceData ?? const []);

  List<Detection>? _detections;
  Object? _detectionsKey;

  /// Every service, tracker and technology on the page: the source scan from
  /// the metadata isolate plus the browser's requests and cookies.
  List<Detection> get detections {
    final cookies = _probeResult?['analyzedCookies'] as List?;
    final key = (
      identityHashCode(_pageMetadata),
      identityHashCode(_resourcePerformanceData),
      _resourcePerformanceData?.length,
      identityHashCode(cookies),
      cookies?.length,
    );
    if (_detections != null && key == _detectionsKey) return _detections!;
    _detectionsKey = key;
    return _detections = detect(
      pageUrl: _currentFile?.path ?? '',
      html: _currentFile?.content ?? '',
      source: Detection.listFrom(_pageMetadata?['detections']),
      requests: collectResourceUrls(_pageMetadata, resourceTimelineData),
      cookies: (cookies ?? const []).whereType<Map>(),
    );
  }

  bool get isProbing => store.current.server is Pending<ServerSnapshot>;
  SovereigntyReport? get sovereigntyReport => _sovereigntyReport;
  bool get isAnalyzingSovereignty => _isAnalyzingSovereignty;

  String get _sovereigntyHost =>
      Uri.tryParse(_currentFile?.path ?? '')?.host ?? '';

  /// Registrable domain the per-site jurisdiction choice is stored under.
  String get sovereigntyDomain =>
      SovereigntyService.registrableDomain(_sovereigntyHost);

  /// Legal home of the current site: chosen manually, else detected,
  /// else the default from settings.
  SiteJurisdiction get siteJurisdiction {
    final manual = _appSettings?.siteJurisdiction(sovereigntyDomain);
    if (manual != null) return (jurisdiction: manual, source: 'Set manually');
    final detected = detectSiteJurisdiction(
      host: _sovereigntyHost,
      certificateSubject:
          _probeResult?['certificate']?['subjectParsed'] as Map?,
      structuredData: _pageMetadata?['structuredData'] as List?,
    );
    return detected ??
        (
          jurisdiction:
              _appSettings?.homeJurisdiction ?? defaultHomeJurisdiction(),
          source: 'Not detected; default from Settings',
        );
  }

  void setSiteJurisdiction(String? jurisdiction) =>
      _appSettings?.setSiteJurisdiction(sovereigntyDomain, jurisdiction);

  /// Where is this page hosted, and by whom? Lazily run by the Sovereignty tab.

  Future<void> analyzeSovereignty() async {
    final url = _currentFile?.path;
    if (_isAnalyzingSovereignty || url == null || !url.startsWith('http')) {
      return;
    }
    _isAnalyzingSovereignty = true;
    final gen = store.current.generation;
    notifyListeners();
    try {
      final report = await _sovereigntyAnalyzer(
        pageUrl: url,
        probeResult: _probeResult,
        resources: resourceTimelineData,
        metadata: _pageMetadata,
        detections: detections,
        html: _currentFile?.content,
        home: siteJurisdiction.jurisdiction,
      );
      if (!_disposed && gen == store.current.generation) {
        _sovereigntyReport = report;
      }
    } catch (e) {
      debugPrint('Sovereignty analysis failed: $e');
    } finally {
      _isAnalyzingSovereignty = false;
      notifyListeners();
    }
  }

  bool get canGoBack => _navigationStack.isNotEmpty;
  String? get probeError {
    final server = store.current.server;
    return server is Failed<ServerSnapshot> ? server.error : null;
  }

  bool get isLoading => _isLoading;
  bool get isExtractingMetadata => _isExtractingMetadata;
  String? get pendingUrl => _pendingUrl;
  String? get currentInputText => _currentInputText;

  set currentInputText(String? value) {
    if (_currentInputText != value) {
      _currentInputText = value;
      notifyListeners();
    }
  }

  // Expose search state

  bool get isSearchActive => _isSearchEnabled;
  bool get isSearchEnabled => _isSearchEnabled;
  CodeFindController? get activeFindController => _activeFindController;

  bool get isHtml {
    final contentType =
        _probeResult?['headers']?['content-type']?.toString().toLowerCase() ??
            '';
    if (contentType.contains('text/html') ||
        contentType.contains('application/xhtml+xml')) {
      return true;
    }
    // A specific non-HTML content type (JSON, CSS, JS, XML…) is authoritative.
    if (isNonHtmlContentType(contentType)) return false;

    // Secondary check: selected content type or current file extension
    final bool looksLikeHtml = selectedContentType == 'html' ||
        (_currentFile?.name.toLowerCase().endsWith('.html') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.htm') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.xhtml') ?? false);

    if (looksLikeHtml) return true;

    final fileName = _currentFile?.name.toLowerCase() ?? '';
    if (_nonHtmlExtensions.any(fileName.endsWith)) return false;

    if (_currentFile?.content.isNotEmpty ?? false) {
      if (contentLooksLikeHtml(_currentFile!.content)) return true;
    }

    // Tertiary check: If we are midway through loading a URL and probe/file are not ready,
    // guess from the input text (URL) to keep UI stable.
    final String url = (_currentInputText ?? '').toLowerCase();

    // Check for explicit HTML extensions
    if (url.contains('.html') ||
        url.contains('.htm') ||
        url.contains('.xhtml') ||
        url.contains('.php') ||
        url.contains('.asp')) {
      return true;
    }

    return false;
  }

  /// True for a specific content type that isn't HTML. Generic types
  /// (text/plain, octet-stream) are not, so the content gets sniffed.
  static bool isNonHtmlContentType(String contentType) {
    final type = contentType.split(';').first.trim().toLowerCase();
    if (type.isEmpty ||
        type == 'text/plain' ||
        type == 'application/octet-stream') {
      return false;
    }
    return !type.contains('html');
  }

  /// Content sniff: an HTML document starts with markup and has HTML tags.
  /// JS/CSS/JSON that merely contain `<div>` in a string don't count.
  static bool contentLooksLikeHtml(String content) {
    final trimmed = content.replaceFirst('\uFEFF', '').trim();
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('<')) return false;
    if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
      return true;
    }
    final looksLikeFeed = trimmed.contains('<Channel>') ||
        lower.contains('<rss') ||
        lower.contains('<feed');
    if (looksLikeFeed) return false;
    // XHTML may start with an XML declaration.
    if (lower.startsWith('<?xml')) return lower.contains('<html');
    return RegExp(
            r'<(head|body|title|meta|script|style|div|main|section|article)\b')
        .hasMatch(lower);
  }

  static const _nonHtmlExtensions = [
    '.rss',
    '.xml',
    '.json',
    '.pdf',
    '.zip',
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.svg',
    '.webp',
    '.bmp',
    '.tiff',
    '.ico',
    '.css',
    '.js',
    '.txt',
    '.csv',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.mp3',
    '.mp4',
    '.avi',
    '.mov',
    '.wav',
    '.ogg',
    '.webm',
    '.m4a',
    '.aac',
    '.tar',
    '.gz',
    '.rar',
    '.7z',
    '.iso',
    '.dmg',
    '.exe',
    '.msi',
    '.apk',
    '.ipa',
    '.epub',
    '.mobi',
    '.azw3',
    '.md',
    '.yaml',
    '.yml',
    '.ts',
    '.mjs',
    '.map',
  ];

  bool get isSvg {
    final contentType =
        _probeResult?['headers']?['content-type']?.toString().toLowerCase() ??
            '';
    if (contentType.contains('image/svg+xml')) return true;

    return selectedContentType == 'svg' ||
        (_currentFile?.name.toLowerCase().endsWith('.svg') ?? false);
  }

  bool get isXml {
    final contentType =
        _probeResult?['headers']?['content-type']?.toString().toLowerCase() ??
            '';
    if (contentType.contains('application/xml') ||
        contentType.contains('text/xml')) {
      return true;
    }
    if (contentType.contains('application/rss+xml') ||
        contentType.contains('application/atom+xml')) {
      return true;
    }

    // Secondary check: selections or file extensions
    final bool looksLikeXml = selectedContentType == 'xml' ||
        isSvg ||
        (_currentFile?.name.toLowerCase().endsWith('.xml') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.opml') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.rss') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.atom') ?? false);

    if (looksLikeXml) return true;

    // Tertiary check: URL guessing for transition stability
    final String url = (_currentInputText ?? '').toLowerCase();
    return url.endsWith('.xml') ||
        url.endsWith('.opml') ||
        url.endsWith('.rss') ||
        url.endsWith('.atom') ||
        url.contains('.xml?') ||
        url.contains('.opml?') ||
        url.contains('.rss?') ||
        url.contains('.atom?');
  }

  /// internal helper to identify pure XML vs HTML/SVG
  bool get _isStrictXml => isXml && !isHtml && !isSvg;

  /// Metadata/Services/Media extraction is only useful for full web pages
  bool get showMetadataTabs => isHtml && !isXml;

  /// Whether to show the Browser tab. This is deliberately stable — it stays
  /// true whenever a URL is in ANY loading phase so that the tab never
  /// disappears and reappears mid-navigation (which also prevented disposed
  /// controller crashes by keeping the WebView widget mounted).
  bool get shouldShowBrowserTab {
    // Already loaded a URL
    if (_currentFile?.isUrl ?? false) return true;
    // Local files can still have a useful rendered view (HTML/SVG/media/XML).
    if (_currentFile != null && isBrowserSupported) return true;
    // WebView is actively loading
    if (_isWebViewLoading) return true;
    // A URL load was triggered but _currentFile is still null (_resetLoadState ran)
    if (_pendingUrl != null &&
        (_pendingUrl!.startsWith('http') || _pendingUrl!.contains('://'))) {
      return true;
    }
    // isWebViewLoading alias (redundant but safe)
    if (_webViewLoadingUrl != null) return true;
    return false;
  }

  /// DOM Tree and Probe tabs are useful for any structured markup
  bool get isHtmlOrXml => isHtml || isXml;

  /// Server-dependent tabs (Probe, Headers, Security, Cookies) only for URLs
  bool get showServerTabs {
    // Priority 1: Current file is a URL
    if (_currentFile?.isUrl ?? false) return true;

    // Priority 2: Not a URL file, but actively loading a URL (before _currentFile is updated)
    if (_isLoading &&
        _currentInputText != null &&
        (_currentInputText!.startsWith('http') ||
            _currentInputText!.contains('://'))) {
      // Safety check: if we already have a current local file, trust its type over the input text
      if (_currentFile == null || _currentFile!.isUrl) {
        return true;
      }
    }
    return false;
  }

  /// Browser tab is supported for URLs, HTML, SVG, and common media formats.
  /// We hide it for strict XML as it doesn't provide a useful visual render.
  bool get isBrowserSupported {
    if (isSvg) return true;
    if (isMedia) return true;
    if (_isStrictXml) return true;
    if (_currentFile?.isUrl ?? false) return true;
    if (isHtml) return true;
    // Show during loading of a URL
    if (_isLoading &&
        _currentInputText != null &&
        (_currentInputText!.startsWith('http') ||
            _currentInputText!.contains('://'))) {
      return true;
    }
    return false;
  }

  bool get isMedia {
    final contentType =
        _probeResult?['headers']?['content-type']?.toString().toLowerCase() ??
            '';
    if (contentType.contains('image/') ||
        contentType.contains('video/') ||
        contentType.contains('audio/')) {
      // SVG is technically an image but we handle it as XML/Source
      if (isSvg) return false;
      return true;
    }

    return selectedContentType == 'image' ||
        selectedContentType == 'video' ||
        selectedContentType == 'audio' ||
        (_currentFile?.isMedia ?? false);
  }

  /// Switches to the Source tab (unbeautified) and selects [line] (1-based).
  void revealSourceLine(int line) {
    SourceViewerEditor.pendingRevealLine = line;
    _isBeautifyEnabled = false;
    _requestedTabIndex = HtmlService.sourceTab;
    notifyListeners();
  }

  void consumeTabSwitchRequest() {
    _requestedTabIndex = null;
  }

  void setActiveTabIndex(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();

      // If switching to Browser tab, reload if needed (lazy loading)
      if (index == browserTabIndex) {
        triggerBrowserReload();
      }

      // Source tab without content yet: the server body may have arrived.
      if (index == sourceTabIndex) {
        _adoptServerBodyIfEmpty(store.current.generation).ignore();
      }
    }
  }

  /// Main document size as reported by the browser for [url], or 0 if unknown.
  int _browserDocSizeFor(String url) {
    final probeUrl = _browserProbeResult?['url'] as String?;
    if (probeUrl == null || !_sameUrlString(probeUrl, url)) return 0;
    return (_browserProbeResult?['pageWeight']?['mainDocumentDecoded']
                as num? ??
            0)
        .toInt();
  }

  /// Trigger a browser reload if the URL has changed and the browser tab is visible
  Future<void> triggerBrowserReload() async {
    final controller = activeWebViewController;
    final file = _currentFile;
    if (controller == null || file == null) {
      return;
    }
    try {
      final currentBrowserUrl = await controller.getUrl();
      if (file.isUrl) {
        if (currentBrowserUrl.toString() != file.path) {
          debugPrint('Triggering browser reload for: ${file.path}');
          _webViewLoadingUrl = file.path;
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri(file.path)),
          );
        }
        return;
      }

      if (isBrowserSupported && file.content.isNotEmpty) {
        debugPrint('Triggering browser reload for local file: ${file.name}');
        final baseUrl = file.path.isNotEmpty ? WebUri(file.path) : null;
        await controller.loadData(
          data: file.content,
          baseUrl: baseUrl,
        );
      } else if (currentBrowserUrl.toString() != 'about:blank') {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri('about:blank')),
        );
      }
    } catch (e) {
      debugPrint(
          'triggerBrowserReload: controller error (likely disposed): $e');
    }
  }

  void updateWebViewLoadingProgress(double progress) {
    if (_webViewLoadingProgress != progress) {
      _webViewLoadingProgress = progress;
      notifyListeners();
    }
  }

  HtmlService({
    InspectionStore? store,
    ServerFetcher? serverFetcher,
    BrowserLoader? browserLoader,
    MetadataExtractor? metadataExtractor,
    SovereigntyAnalyzer? sovereigntyAnalyzer,
  })  : _sovereigntyAnalyzer =
            sovereigntyAnalyzer ?? SovereigntyService.analyze,
        store = store ?? InspectionStore(),
        _ownsStore = store == null,
        _serverFetcher = serverFetcher ?? const IoServerFetcher(),
        _metadataExtractor = metadataExtractor ?? extractMetadataInIsolate {
    _browserLoader = browserLoader ?? _ControllerBrowserLoader(this);
    this.store.addListener(notifyListeners);
    _codeEditorKey = GlobalKey();
    _currentInputText = '';
  }

  /// Forget everything measured by the browser for the previous page.
  void _clearBrowserDerivedData() {
    _browserProbeResult = null;
    _lastPageWeight = null;
    _resourcePerformanceData = null;
    _sovereigntyReport = null;
    _lastBrowserCookies = '';
  }

  @visibleForTesting
  void seedBrowserDataForTest() {
    _browserProbeResult = {'url': 'seed'};
    _lastPageWeight = {'transfer': 1, 'decoded': 2};
    _resourcePerformanceData = [
      {'name': 'https://seed.test/a.js'}
    ];
    _lastBrowserCookies = 'seed=1';
  }

  /// Reset all loading and result state before a new URL load
  void _resetLoadState({String? newUrl, bool notify = true}) {
    _clearBrowserDerivedData();
    _pageMetadata = null;
    _webViewLoadingProgress = 0.0;
    _beautifiedCache.clear();
    _isBeautifyEnabled = false;

    // These are crucial for the "Loading" state in tabs
    _currentFile = null;
    _originalFile = null;

    if (newUrl != null) {
      _currentInputText = newUrl;
      _pendingUrl = newUrl;
    }

    _isLoading = true;
    _isWebViewLoading = false;
    _webViewLoadingUrl = null;

    if (notify) notifyListeners();
  }

  /// Unified entry point for loading a URL
  Future<void> loadUrl(
    String url, {
    int? switchToTab,
    bool forceWebView = false,
    bool skipWebViewLoad = false,
    bool forceReload = false,
  }) async {
    if (url.isEmpty) return;

    // Block data: and blob: URLs
    if (url.startsWith('data:') || url.startsWith('blob:')) {
      return;
    }

    // Sanitize
    // Auto-prepend https if no scheme is provided, excluding special schemes like about:
    // We trim the URL first to avoid issues with leading/trailing spaces
    url = url.trim();
    if (!url.contains('://') && !url.startsWith('about:')) {
      url = 'https://$url';
    }

    // Validate URL syntax before doing any work
    if (!url.startsWith('about:')) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.hasScheme ||
          !uri.hasAuthority ||
          uri.host.isEmpty) {
        throw Exception('Invalid URL format');
      }
    }

    // 0. Save current page to navigation stack before resetting state
    // We must do this BEFORE calling _resetLoadState because it clears _currentFile
    // Also check if we are navigating to a different page to avoid duplicates on reload
    // AND check for Rapid Redirects: If current file was loaded < 1s ago, assume redirect and replace it
    final bool isRedirect = _lastCurrentFileUpdate != null &&
        DateTime.now().difference(_lastCurrentFileUpdate!).inMilliseconds <
            1000;

    if ((_currentFile == null || !(areUrlsEqual(_currentFile!.path, url))) &&
        !isRedirect &&
        !_isNavigatingBack) {
      _pushToNavigationStack();
    }

    // 1. Clean state and update main URL
    // We don't notify yet because we want to set the correct loading path first
    // to avoid unmounting the WebView if it's already relevant.
    _resetLoadState(newUrl: url, notify: false);

    // 2. Clear requested tab switch if provided
    if (switchToTab != null) {
      _requestedTabIndex = switchToTab;
    }

    // 3. Force stop any previous loading and reset WebView to about:blank
    // if (activeWebViewController != null) {
    //   activeWebViewController!.loadRequest(Uri.parse('about:blank')).ignore();
    // }

    // 4. One generation and one server fetch (document + robots.txt) for this
    // navigation, in both modes. Results of an older navigation are dropped.
    final uri = Uri.parse(url);
    final bool shouldUseBrowserLogic = forceWebView || _useBrowserByDefault;
    final gen = _startInspection(uri, adoptBody: shouldUseBrowserLogic);

    // 5. Primary Load Path branching
    if (shouldUseBrowserLogic) {
      // Browser-First Flow: the browser loads immediately; the server body
      // fills the tabs until the rendered DOM replaces it.
      _webViewLoadingUrl = url;
      _isWebViewLoading = true;

      // Stay on whatever tab the user is on. Only when the WebView was never
      // shown (so it doesn't exist yet) switch to it, or nothing would load.
      if (activeWebViewController == null &&
          switchToTab == null &&
          _activeTabIndex != browserTabIndex) {
        _requestedTabIndex = browserTabIndex;
      }

      // Add to history immediately for Browser-First Flow
      final tempFile = HtmlFile(
        name: url,
        path: url,
        content: '',
        lastModified: DateTime.now(),
        size: 0,
        isUrl: true,
      );

      if (url.isNotEmpty && _shouldAddToHistory(tempFile)) {
        _urlHistoryService?.addUrl(url);
        _historyPendingUrl = url;

        // Placeholder so _currentFile is set before the HTML arrives.
        _currentFile = tempFile;
      }

      notifyListeners();

      if (!skipWebViewLoad) _browserLoader.loadUrl(uri);
    } else {
      // Source-First Flow: wait for the server body; the browser stays idle
      // until the Browser tab opens.
      notifyListeners();
      try {
        await _serverFetch;
        if (_disposed || gen != store.current.generation) return;
        _pendingUrl = null;
        final built = await _fileFromServer(uri, store.current.server);
        // Navigation may have moved on while the file was being built.
        if (_disposed || gen != store.current.generation) return;
        _applyPageWeight(built.weight);
        await loadFile(built.file);
      } catch (e) {
        if (gen == store.current.generation) _pendingUrl = null;
        rethrow;
      } finally {
        if (!_disposed && gen == store.current.generation) {
          _isLoading = false;
          notifyListeners();
        }
      }
    }
  }

  /// Starts a new inspection generation for [uri] and fetches its server side
  /// in the background. With [adoptBody] the body becomes the current file
  /// when none has content yet (browser-first).
  int _startInspection(Uri uri, {required bool adoptBody}) {
    final gen = store.beginUrl(uri);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      const na = Unavailable<Never>(
          UnavailableReason.notApplicable, 'no server fetch for this scheme');
      store.applyServer(gen, na);
      store.applyRobots(gen, na);
      _serverFetch = null;
    } else {
      _serverFetch = _fetchServer(uri, gen, adoptBody: adoptBody);
    }
    return gen;
  }

  Future<void> _fetchServer(Uri uri, int gen, {required bool adoptBody}) async {
    final origin = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null);
    _fetchRobots(origin, gen).ignore();

    Observed<ServerSnapshot> result;
    try {
      final snapshot =
          await _serverFetcher.fetch(uri, userAgent: kServerUserAgent);
      // Nothing answered: that is a failure, not a snapshot without data.
      result = snapshot.hops.isEmpty
          ? Failed(_failureMessage(snapshot))
          : Present(snapshot, source: DataSource.server);
    } catch (e) {
      result = Failed('error: $e');
    }
    if (_disposed) return;
    store.applyServer(gen, result);
    // The browser reported a URL while we were waiting; now the chain is
    // known. One that is not part of it is a navigation of its own.
    final noted = _browserUrlDuringFetch;
    if (noted != null && noted.$1 == gen && !_storeCovers(noted.$2)) {
      _startInspection(noted.$2, adoptBody: false);
      return;
    }
    if (adoptBody) await _adoptServerBodyIfEmpty(gen);
  }

  Future<void> _fetchRobots(Uri origin, int gen) async {
    Observed<RobotsInfo> result;
    try {
      result = Present(
          await _serverFetcher.fetchRobots(origin, userAgent: kServerUserAgent),
          source: DataSource.server);
    } catch (e) {
      result = Failed('error: $e');
    }
    if (_disposed) return;
    store.applyRobots(gen, result);
  }

  static String _failureMessage(ServerSnapshot s) {
    String? of<T>(Observed<T> o) => switch (o) {
          Failed<T>(error: final e) => e,
          Unavailable<T>(reason: final r, detail: final d) =>
            unavailableMessage(r, d),
          _ => null,
        };
    return of(s.finalUrl) ?? of(s.body) ?? 'no response from the server';
  }

  /// Browser-first: the server body fills the tabs while the browser DOM is
  /// still missing. The DOM (syncWebViewState) replaces it later.
  Future<void> _adoptServerBodyIfEmpty(int gen) async {
    if (_disposed || gen != store.current.generation) return;
    final target = store.current.target;
    final server = store.current.server;
    if (target is! UrlTarget || server is! Present<ServerSnapshot>) return;
    if (server.value.body is! Present<ServerBody>) return;
    final current = _currentFile;
    if (current != null && (!current.isUrl || current.content.isNotEmpty)) {
      return;
    }
    final built = await _fileFromServer(target.url, server);
    if (_disposed ||
        gen != store.current.generation ||
        (_currentFile?.content.isNotEmpty ?? false)) {
      return;
    }
    final file = built.file;
    _applyPageWeight(built.weight);
    // A redirect changes the path: do not push the empty placeholder.
    if (_currentFile != null &&
        !_sameUrlString(_currentFile!.path, file.path)) {
      _currentFile = null;
    }
    await loadFile(file);
    if (gen == store.current.generation) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Without browser numbers, the document's own wire and decoded size.
  void _applyPageWeight(Map<String, dynamic>? weight) {
    if (weight != null && _browserProbeResult == null) _lastPageWeight = weight;
  }

  static bool _sameUrlString(String a, String b) {
    final x = Uri.tryParse(a), y = Uri.tryParse(b);
    return x != null && y != null ? sameUrl(x, y) : a == b;
  }

  /// The server's answer as a file for the viewer: the body, or an error page
  /// that says why there is none. Pure: the caller applies [weight] after
  /// checking the navigation is still current.
  Future<({HtmlFile file, Map<String, dynamic>? weight})> _fileFromServer(
      Uri requested, Observed<ServerSnapshot> server) async {
    final snapshot = server is Present<ServerSnapshot> ? server.value : null;
    final body = snapshot?.body;
    if (snapshot == null || body is! Present<ServerBody>) {
      final reason = switch (server) {
        Failed<ServerSnapshot>(error: final e) => e,
        Present<ServerSnapshot>(value: final s) => _failureMessage(s),
        _ => 'no response from the server',
      };
      await debugAfterServerFileBuilt?.call();
      return (file: _urlErrorFile(requested.toString(), reason), weight: null);
    }

    final last = snapshot.hops.last;
    final finalUrl = snapshot.finalUrl;
    final finalUri = finalUrl is Present<Uri> ? finalUrl.value : requested;
    final content = body.value.decoded.isBinary ? '' : body.value.decoded.text;
    final contentType = last.header('content-type');

    String filename;
    if (last.statusCode == 200) {
      final pathFilename =
          finalUri.pathSegments.isNotEmpty ? finalUri.pathSegments.last : '';
      filename = pathFilename.isNotEmpty &&
              pathFilename.contains('.') &&
              !pathFilename.startsWith('_') &&
              pathFilename != 'index' &&
              pathFilename != 'home'
          ? pathFilename
          : generateDescriptiveFilename(finalUri, content);
      filename = await detectFileTypeAndGenerateFilename(filename, content,
          contentType: contentType);
    } else {
      filename = finalUri.pathSegments.isNotEmpty
          ? finalUri.pathSegments.last
          : 'response_${last.statusCode}';
    }

    await debugAfterServerFileBuilt?.call();
    return (
      file: HtmlFile(
        name: filename,
        path: finalUri.toString(),
        content: content,
        lastModified: DateTime.now(),
        size: body.value.byteLength,
        isUrl: true,
        isError: last.statusCode >= 400,
      ),
      weight: <String, dynamic>{
        'transfer': body.value.transferLength,
        'decoded': body.value.byteLength,
      },
    );
  }

  HtmlFile _urlErrorFile(String url, String message) {
    final errorContent = '''Web URL Could Not Be Loaded

Error: $message

URL: $url

This web URL could not be loaded. Possible reasons:

🌐 Network Issues
- Check your internet connection
- Try again later if the website is temporarily unavailable

🔒 Website Restrictions
- Some websites block automated requests
- Try opening the URL in your browser first

📱 URL Format Problems
- Make sure the URL is complete and valid
- Include "https://" at the beginning

🔄 Redirect Issues
- The URL might redirect to an unavailable location
- Try the original URL directly

If this problem persists, you can:
1. Open the URL in your browser
2. View the page source there
3. Copy and paste the HTML content here manually

Technical details: $message''';

    return HtmlFile(
      name: url,
      path: url,
      content: errorContent,
      lastModified: DateTime.now(),
      size: errorContent.length,
      isUrl: true,
      isError: true,
    );
  }

  /// Whether the current inspection already covers [uri] (R20): the same
  /// document as the requested URL, a hop of the fetched chain or its final
  /// URL. Same document = http(s), same host ignoring a leading `www.` and
  /// same path ignoring a trailing slash; the scheme may differ, so
  /// http -> https and www redirects stay one navigation, also while the
  /// fetch is still running. Any other URL is a new navigation.
  bool _storeCovers(Uri uri) {
    final current = store.current;
    final target = current.target;
    if (target is! UrlTarget) return false;
    if (sameUrl(target.url, uri) || _sameDocument(target.url, uri)) return true;
    final server = current.server;
    if (server is Present<ServerSnapshot>) {
      final finalUrl = server.value.finalUrl;
      return server.value.hops.any((h) => _sameDocument(h.url, uri)) ||
          (finalUrl is Present<Uri> && _sameDocument(finalUrl.value, uri));
    }
    return false;
  }

  static bool _sameDocument(Uri a, Uri b) {
    bool web(Uri u) => u.scheme == 'http' || u.scheme == 'https';
    String host(Uri u) {
      final h = u.host.toLowerCase();
      return h.startsWith('www.') ? h.substring(4) : h;
    }

    String path(Uri u) => u.path.length > 1 && u.path.endsWith('/')
        ? u.path.substring(0, u.path.length - 1)
        : (u.path.isEmpty ? '/' : u.path);
    return web(a) &&
        web(b) &&
        host(a) == host(b) &&
        path(a) == path(b) &&
        a.query == b.query;
  }

  /// The last URL the browser reported while the fetch of this navigation
  /// was running; checked again when the chain is known.
  (int, Uri)? _browserUrlDuringFetch;

  void _noteBrowserUrl(Uri uri) {
    if (store.current.server is Pending<ServerSnapshot>) {
      _browserUrlDuringFetch = (store.current.generation, uri);
    }
  }

  /// Strict URL identity for data decisions: scheme, host, port, path
  /// (empty equals '/') and query; the fragment is ignored.
  static bool sameUrl(Uri a, Uri b) {
    String path(Uri u) => u.path.isEmpty ? '/' : u.path;
    return a.scheme.toLowerCase() == b.scheme.toLowerCase() &&
        a.host.toLowerCase() == b.host.toLowerCase() &&
        a.port == b.port &&
        path(a) == path(b) &&
        a.query == b.query;
  }

  Future<void> reloadCurrentFile() async {
    if (_currentFile == null) return;

    if (_currentFile!.isUrl) {
      return loadUrl(_currentFile!.path, forceReload: true);
    } else {
      // Local file reload
      if (_currentFile!.path.isNotEmpty) {
        try {
          final snapshot = await FileLoader.fromPath(_currentFile!.path,
              origin: FileOrigin.restore, enforceSandbox: false);
          await loadFile(snapshot.toHtmlFile(),
              clearProbe: true, snapshot: snapshot);
        } catch (e) {
          debugPrint('Error reloading local file: $e');
        }
      }
    }
  }

  void triggerWebViewLoad(String url) {
    loadUrl(url, switchToTab: HtmlService.sourceTab, forceWebView: true);
  }

  void handleWebViewError(String errorDescription) {
    debugPrint('WebView Error: $errorDescription');
    _isWebViewLoading = false;
    _isLoading = false;
    notifyListeners();
  }

  void cancelWebViewLoad() {
    // 2. Navigate away to about:blank to kill any pending network requests
    // activeWebViewController?.loadRequest(Uri.parse('about:blank'));
    // 3. Reset internal state immediately
    _webViewLoadingUrl = null;
    _isWebViewLoading = false;
    _isLoading = false;
    _webViewLoadingProgress = 0.0; // Reset progress bar
    notifyListeners();
  }

  // Async work (loads, extraction) may finish after dispose; ignore it.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(notifyListeners);
    if (_ownsStore) store.dispose();
    _autoSaveTimer?.cancel();
    _disposalTimer?.cancel();
    // Final immediate disposal
    for (final controller in _disposalQueue) {
      if (controller != null) {
        try {
          controller.dispose();
        } catch (e) {
          debugPrint('Error disposing queued controller in dispose(): $e');
        }
      }
    }
    _disposalQueue.clear();

    // Do NOT dispose _verticalScrollController here as it might be an external controller
    // or PrimaryScrollController.of(context).
    _verticalScrollController = null;
    _activeHorizontalScrollController = null;

    _appSettings?.removeListener(notifyListeners);

    super.dispose();
  }

  /// Save current scroll position
  double? getCurrentScrollPosition() {
    if (_verticalScrollController != null &&
        _verticalScrollController!.hasClients) {
      try {
        // Handle multiple attached clients safely
        return _verticalScrollController!.positions.last.pixels;
      } catch (e) {
        debugPrint('Error getting vertical scroll position: $e');
        return null;
      }
    }
    return null;
  }

  /// Save current horizontal scroll position
  double? getCurrentHorizontalScrollPosition() {
    if (_activeHorizontalScrollController != null &&
        _activeHorizontalScrollController!.hasClients) {
      try {
        return _activeHorizontalScrollController!.positions.last.pixels;
      } catch (e) {
        debugPrint('Error getting horizontal scroll position: $e');
        return null;
      }
    }
    return null;
  }

  /// Restore scroll position
  void restoreScrollPosition(double? position) {
    if (position != null) {
      final controller = _verticalScrollController;
      if (controller != null && controller.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            controller.jumpTo(position);
          } catch (e) {
            debugPrint('Error restoring vertical scroll position: $e');
          }
        });
      }
    }
  }

  void setAppStateService(AppStateService service) {
    _appStateService = service;
  }

  void setAppSettings(AppSettings settings) {
    _appSettings = settings;
    // Listen to settings changes to update tab indices dynamically
    _appSettings?.addListener(notifyListeners);
  }

  void setUrlHistoryService(UrlHistoryService service) {
    _urlHistoryService = service;
    // Load navigation stack from persistent storage
    _loadNavigationStack();
  }

  /// Load navigation stack from SharedPreferences
  Future<void> _loadNavigationStack() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedUrls = prefs.getStringList('navigation_stack');

      if (savedUrls != null && savedUrls.isNotEmpty) {
        // Convert URLs back to HtmlFile objects
        _navigationStack.clear();
        for (final url in savedUrls) {
          // Create minimal HtmlFile objects for navigation
          // Content will be fetched when user navigates back
          final file = HtmlFile(
            name: url,
            path: url,
            content: '',
            lastModified: DateTime.now(),
            size: 0,
            isUrl: true,
          );
          _navigationStack.add(file);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading navigation stack: $e');
    }
  }

  /// Save navigation stack to SharedPreferences
  Future<void> _saveNavigationStack() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save only the URLs from the navigation stack
      final urls = _navigationStack
          .where((file) => file.isUrl && file.path.isNotEmpty)
          .map((file) => file.path)
          .toList();

      // Limit to 50 items to avoid excessive storage
      final limitedUrls = urls.length > 50 ? urls.sublist(0, 50) : urls;

      await prefs.setStringList('navigation_stack', limitedUrls);
    } catch (e) {
      debugPrint('Error saving navigation stack: $e');
    }
  }

  /// Auto-save the current state if a service is available (debounced)
  void _autoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_appStateService != null) {
        saveCurrentState(_appStateService!);
      }
    });
  }

  /// Restore horizontal scroll position
  void restoreHorizontalScrollPosition(double? position) {
    if (position != null) {
      final controller = _activeHorizontalScrollController;
      if (controller != null && controller.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            controller.jumpTo(position);
          } catch (e) {
            debugPrint('Error restoring horizontal scroll position: $e');
          }
        });
      }
    }
  }

  Future<void> saveCurrentState(AppStateService appStateService) async {
    try {
      await appStateService.saveAppState(
        currentFile: _currentFile,
        scrollPosition: getCurrentScrollPosition(),
        horizontalScrollPosition: getCurrentHorizontalScrollPosition(),
        contentType: selectedContentType,
        pendingUrl: _pendingUrl,
        inputText: _currentInputText,
      );
      // Log removed to reduce noise as AppStateService already logs success
    } catch (e) {
      debugPrint('❌ Error saving app state: $e');
    }
  }

  /// Generate a descriptive filename for URLs without clear filenames
  /// Uses domain name, path segments, and content type to create meaningful names
  String generateDescriptiveFilename(Uri uri, String content) {
    // Extract domain name (remove www. if present)
    String domain = uri.host;
    if (domain.startsWith('www.')) {
      domain = domain.substring(4);
    }

    // Clean domain name for fallback use
    String humanDomain = domain;
    final domainParts = domain.split('.');
    if (domainParts.length >= 2) {
      final commonTlds = {
        'com',
        'org',
        'net',
        'io',
        'co',
        'dev',
        'app',
        'tech',
        'info',
        'me',
        'tv',
      };
      if (!commonTlds.contains(domainParts[domainParts.length - 1])) {
        humanDomain = domainParts.sublist(0, domainParts.length - 1).join(' ');
      } else {
        humanDomain = domainParts[domainParts.length - 2];
      }
    }
    // Capitalize first letter
    humanDomain = humanDomain.isNotEmpty
        ? humanDomain[0].toUpperCase() + humanDomain.substring(1)
        : 'index';

    // Extract meaningful path segments
    final pathSegments = uri.pathSegments
        .where(
          (segment) =>
              segment.isNotEmpty &&
              !segment.startsWith('_') &&
              segment != 'index' &&
              segment != 'home',
        )
        .toList();

    String baseFilename;
    if (pathSegments.isNotEmpty) {
      baseFilename = pathSegments.last;
    } else {
      baseFilename = humanDomain;
    }

    // Clean up characters but preserve dots for extensions
    baseFilename = baseFilename
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (baseFilename.isEmpty) return humanDomain;

    // Check for "proper" extensions we want to preserve
    final baseLower = baseFilename.toLowerCase();
    final knownExtensions = {
      '.html',
      '.htm',
      '.xhtml',
      '.css',
      '.js',
      '.json',
      '.xml',
      '.yaml',
      '.yml',
      '.md',
      '.txt',
      '.py',
      '.java',
      '.dart',
      '.php',
      '.rb',
      '.swift',
      '.go',
      '.rs',
      '.sql',
      '.atom',
      '.rss',
      '.rdf',
    };

    if (knownExtensions.any((ext) => baseLower.endsWith(ext))) {
      return baseFilename;
    }

    // If it's a domain-like name without extension, return it as is
    // detectFileTypeAndGenerateFilename will handle adding extensions if needed
    return baseFilename;
  }

  /// Detect file type and generate appropriate filename using robust detection

  Future<String> detectFileTypeAndGenerateFilename(
    String filename,
    String content, {
    String? contentType,
  }) async {
    try {
      // Use the robust file type detector
      final detectedType = await fileTypeDetector.detectFileType(
        filename: filename,
        content: content,
        contentType: contentType,
      );

      // Don't add extensions for generated filenames - preserve original or use simple names
      if (filename.isEmpty ||
          filename == '/' ||
          filename == 'index' ||
          !filename.contains('.') && !filename.contains('/')) {
        // If the content-type says it's a media file, don't force .html —
        // fall through to the switch below to get the correct extension.
        final detectedLower = detectedType.toLowerCase();
        if (detectedLower != 'image' &&
            detectedLower != 'video' &&
            detectedLower != 'audio') {
          // Use simple descriptive names without extensions
          if (filename.contains('rss') || filename.contains('feed')) {
            return 'RSS Page.xml';
          }
          return 'index.html'; // Simple fallback for generated filenames
        }
      }

      // If filename already has a proper file extension, use it
      // Check for common file extensions to avoid false positives
      final filenameLower = filename.toLowerCase();
      final hasProperExtension = filenameLower.endsWith('.html') ||
          filenameLower.endsWith('.htm') ||
          filenameLower.endsWith('.xhtml') ||
          filenameLower.endsWith('.css') ||
          filenameLower.endsWith('.js') ||
          filenameLower.endsWith('.json') ||
          filenameLower.endsWith('.xml') ||
          filenameLower.endsWith('.yaml') ||
          filenameLower.endsWith('.yml') ||
          filenameLower.endsWith('.md') ||
          filenameLower.endsWith('.txt') ||
          filenameLower.endsWith('.py') ||
          filenameLower.endsWith('.java') ||
          filenameLower.endsWith('.dart') ||
          filenameLower.endsWith('.cpp') ||
          filenameLower.endsWith('.c') ||
          filenameLower.endsWith('.cs') ||
          filenameLower.endsWith('.php') ||
          filenameLower.endsWith('.rb') ||
          filenameLower.endsWith('.swift') ||
          filenameLower.endsWith('.go') ||
          filenameLower.endsWith('.rs') ||
          filenameLower.endsWith('.sql') ||
          filenameLower.endsWith('.atom') ||
          filenameLower.endsWith('.rss') ||
          filenameLower.endsWith('.rdf') ||
          filenameLower.endsWith('.png') ||
          filenameLower.endsWith('.jpg') ||
          filenameLower.endsWith('.jpeg') ||
          filenameLower.endsWith('.gif') ||
          filenameLower.endsWith('.webp') ||
          filenameLower.endsWith('.bmp') ||
          filenameLower.endsWith('.ico') ||
          filenameLower.endsWith('.avif') ||
          filenameLower.endsWith('.mp4') ||
          filenameLower.endsWith('.webm') ||
          filenameLower.endsWith('.mov') ||
          filenameLower.endsWith('.mp3') ||
          filenameLower.endsWith('.wav') ||
          filenameLower.endsWith('.flac');

      if (hasProperExtension) {
        return filename;
      }

      // Generate filename based on detected type with proper extension
      String properFilename;
      final baseName = filename.isEmpty ? 'document' : filename;

      switch (detectedType.toLowerCase()) {
        case 'html':
          properFilename = '$baseName.html';
          break;
        case 'css':
          properFilename = '$baseName.css';
          break;
        case 'javascript':
          properFilename = '$baseName.js';
          break;
        case 'typescript':
          properFilename = '$baseName.ts';
          break;
        case 'json':
          properFilename = '$baseName.json';
          break;
        case 'xml':
          // Keep atom/rss if they were in the original filename
          if (filenameLower.endsWith('.atom')) {
            properFilename = filename;
          } else if (filenameLower.endsWith('.rss')) {
            properFilename = filename;
          } else {
            properFilename = '$baseName.xml';
          }
          break;
        case 'yaml':
        case 'yml':
          properFilename = '$baseName.yaml';
          break;
        case 'markdown':
        case 'md':
          properFilename = '$baseName.md';
          break;
        case 'python':
          properFilename = '$baseName.py';
          break;
        case 'java':
          properFilename = '$baseName.java';
          break;
        case 'dart':
          properFilename = '$baseName.dart';
          break;
        case 'c':
        case 'cpp':
        case 'c++':
          properFilename = '$baseName.cpp';
          break;
        case 'csharp':
        case 'cs':
          properFilename = '$baseName.cs';
          break;
        case 'php':
          properFilename = '$baseName.php';
          break;
        case 'ruby':
          properFilename = '$baseName.rb';
          break;
        case 'swift':
          properFilename = '$baseName.swift';
          break;
        case 'go':
          properFilename = '$baseName.go';
          break;
        case 'rust':
          properFilename = '$baseName.rs';
          break;
        case 'sql':
          properFilename = '$baseName.sql';
          break;
        case 'plaintext':
        case 'txt':
        case 'text':
          properFilename = '$baseName.txt';
          break;
        case 'image':
          if (contentType != null) {
            final ct = contentType.toLowerCase();
            if (ct.contains('jpeg') || ct.contains('jpg')) {
              properFilename = '$baseName.jpg';
            } else if (ct.contains('gif')) {
              properFilename = '$baseName.gif';
            } else if (ct.contains('webp')) {
              properFilename = '$baseName.webp';
            } else if (ct.contains('svg')) {
              properFilename = '$baseName.svg';
            } else if (ct.contains('icon') || ct.contains('ico')) {
              properFilename = '$baseName.ico';
            } else if (ct.contains('avif')) {
              properFilename = '$baseName.avif';
            } else {
              properFilename = '$baseName.png';
            }
          } else {
            properFilename = '$baseName.png';
          }
          break;
        case 'video':
          if (contentType != null) {
            final ct = contentType.toLowerCase();
            if (ct.contains('webm')) {
              properFilename = '$baseName.webm';
            } else if (ct.contains('ogg')) {
              properFilename = '$baseName.ogg';
            } else if (ct.contains('quicktime') || ct.contains('mov')) {
              properFilename = '$baseName.mov';
            } else if (ct.contains('avi')) {
              properFilename = '$baseName.avi';
            } else if (ct.contains('mkv') || ct.contains('matroska')) {
              properFilename = '$baseName.mkv';
            } else {
              properFilename = '$baseName.mp4';
            }
          } else {
            properFilename = '$baseName.mp4';
          }
          break;
        case 'audio':
          if (contentType != null) {
            final ct = contentType.toLowerCase();
            if (ct.contains('wav')) {
              properFilename = '$baseName.wav';
            } else if (ct.contains('ogg')) {
              properFilename = '$baseName.ogg';
            } else if (ct.contains('aac')) {
              properFilename = '$baseName.aac';
            } else if (ct.contains('flac')) {
              properFilename = '$baseName.flac';
            } else {
              properFilename = '$baseName.mp3';
            }
          } else {
            properFilename = '$baseName.mp3';
          }
          break;
        default:
          properFilename = '$baseName.$detectedType';
          break;
      }
      return properFilename;
    } catch (e) {
      // Fallback to simple detection if robust detection fails
      return await _fallbackContentDetection(filename, content);
    }
  }

  /// Fallback content detection when robust detection fails
  Future<String> _fallbackContentDetection(
    String filename,
    String content,
  ) async {
    // Handle empty or unclear filenames
    if (filename.isEmpty ||
        filename == '/' ||
        filename == 'index' ||
        !filename.contains('.') && !filename.contains('/')) {
      filename = 'File';
    }

    // If filename already has an extension, use it
    if (filename.contains('.')) {
      return filename;
    }

    // Simple content-based detection in isolate if large
    String detectedType;
    if (content.length > 32 * 1024) {
      detectedType = await compute(_fallbackContentDetectionInternal, content);
    } else {
      detectedType = _fallbackContentDetectionInternal(content);
    }

    return '$filename${detectedType == 'Text' ? '.txt' : detectedType == 'HTML' ? '.html' : detectedType == 'XML' ? '.xml' : detectedType == 'JSON' ? '.json' : detectedType == 'YAML' ? '.yaml' : detectedType == 'Markdown' ? '.md' : detectedType == 'CSS' ? '.css' : detectedType == 'JavaScript' ? '.js' : detectedType == 'Python' ? '.py' : detectedType == 'Java' ? '.java' : detectedType == 'C++' ? '.cpp' : detectedType == 'SQL' ? '.sql' : '.txt'}';
  }

  static String _fallbackContentDetectionInternal(String content) {
    // Simple content-based detection
    final lowerContent = content.toLowerCase();

    if (lowerContent.contains('<html') ||
        lowerContent.contains('<!doctype html')) {
      return 'HTML';
    }
    if (lowerContent.contains('body {') || lowerContent.contains('@media')) {
      return 'CSS';
    }
    if (lowerContent.contains('function ') || lowerContent.contains('const ')) {
      return 'JavaScript';
    }
    if ((lowerContent.startsWith('{') && lowerContent.endsWith('}')) ||
        (lowerContent.startsWith('[') && lowerContent.endsWith(']'))) {
      return 'JSON';
    }
    if (lowerContent.startsWith('---') || lowerContent.contains(': ')) {
      return 'YAML';
    }
    if (lowerContent.startsWith('# ') || lowerContent.contains('## ')) {
      return 'Markdown';
    }
    if (_tryParseAsXmlInternal(content)) {
      return 'XML';
    }
    if (lowerContent.contains('public class ') ||
        lowerContent.contains('system.out.println')) {
      return 'Java';
    }
    if (lowerContent.contains('#include ') ||
        lowerContent.contains('int main(')) {
      return 'C++';
    }
    if (lowerContent.contains('def ') || lowerContent.contains('print(')) {
      return 'Python';
    }
    if (lowerContent.contains('select ') || lowerContent.contains('from ')) {
      return 'SQL';
    }

    return 'Text';
  }

  /// Try to parse content as XML
  /// Returns true if content appears to be valid XML
  Future<bool> tryParseAsXml(String content) async {
    if (content.trim().isEmpty) return false;
    if (content.length > 32 * 1024) {
      return await compute(_tryParseAsXmlInternal, content);
    }
    return _tryParseAsXmlInternal(content);
  }

  static bool _tryParseAsXmlInternal(String content) {
    if (content.trim().isEmpty) return false;
    try {
      // Use the robust xml package for parsing
      final doc = xml.XmlDocument.parse(content);
      // If it parsed successfully and has at least one element, it's valid XML
      return doc.children.any((node) => node is xml.XmlElement);
    } catch (e) {
      // If parsing fails, it's not valid XML
      return false;
    }
  }

  /// internal helper to check if file is valid for history
  bool _shouldAddToHistory(HtmlFile file) {
    if (!file.isUrl || file.isError) return false;

    // Strict check: Only allow http and https URLs
    if (!file.path.startsWith('http://') && !file.path.startsWith('https://')) {
      return false;
    }

    // Exclude explicit shared content (unless it's a URL in disguise which is handled by isUrl=true usually)
    // Shared URLs usually come in as isUrl=true.
    // Shared text/files come in as isUrl=false.

    // Explicit exclusions
    if (file.isShared && !file.isUrl) return false;
    if (file.path.startsWith('shared://')) return false;
    if (file.path.startsWith('content://')) return false;
    if (file.path.startsWith('sandboxed://')) return false;
    if (file.path.startsWith('about:')) return false;

    // Check for error pages
    if (file.name == 'Content File Error' ||
        file.name == 'Error' ||
        file.isError) {
      return false;
    }

    // Allow if it is a URL
    if (file.isUrl) return true;

    // Allow if it has a valid path (local file)
    if (file.path.isNotEmpty) return true;

    return false;
  }

  /// Query params that don't change the resource content (cache-busters).
  static const _cacheBusterParams = {
    'v',
    'ver',
    'version',
    't',
    'ts',
    'timestamp',
    'hash',
    '_',
    'cache',
    'cachebuster',
    'cb',
    'nocache',
    'rev',
    'revision',
  };

  /// Query string with cache-busting params removed, sorted for comparison.
  static String _queryWithoutCacheBusters(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    params.removeWhere(
        (key, _) => _cacheBusterParams.contains(key.toLowerCase()));
    final keys = params.keys.toList()..sort();
    return keys.map((k) => '$k=${params[k]}').join('&');
  }

  /// True when [url1] and [url2] point to the same resource: same host and
  /// path, and query params equal after dropping cache-busters. CDN
  /// versioning (`?v=1` vs `?v=2`) still matches, but content-changing params
  /// such as image resize options (`?width=112` vs `?width=264` or none)
  /// never do.
  static bool sameResourceModuloCacheBusters(String url1, String url2) {
    if (url1 == url2) return true;
    try {
      final uri1 = Uri.parse(url1);
      final uri2 = Uri.parse(url2);
      if (uri1.host.toLowerCase() != uri2.host.toLowerCase()) return false;
      if (uri1.path != uri2.path) return false;
      return _queryWithoutCacheBusters(uri1) == _queryWithoutCacheBusters(uri2);
    } catch (_) {
      return false;
    }
  }

  /// Helper to check if two URLs are effectively the same
  /// ignoring trailing slashes, fragments, and minor scheme differences
  bool areUrlsEqual(String url1, String url2) {
    if (url1 == url2) return true;

    try {
      final uri1 = Uri.parse(url1);
      final uri2 = Uri.parse(url2);

      // Compare hosts (case-insensitive)
      if (uri1.host.toLowerCase() != uri2.host.toLowerCase()) return false;

      // Compare paths (ignoring trailing slashes)
      String path1 = uri1.path;
      String path2 = uri2.path;
      if (path1.endsWith('/') && path1.length > 1) {
        path1 = path1.substring(0, path1.length - 1);
      }
      if (path2.endsWith('/') && path2.length > 1) {
        path2 = path2.substring(0, path2.length - 1);
      }
      if (path1 != path2) return false;

      // Compare query parameters
      // We don't compare fragments as they usually don't trigger a full reload
      // But for some SPAs they might. For now, let's treat them as equal if query/path match.
      if (uri1.query != uri2.query) return false;

      return true;
    } catch (e) {
      // If parsing fails, fall back to simple string comparison
      return url1 == url2;
    }
  }

  /// Push the current file to the navigation stack
  void _pushToNavigationStack() {
    if (!_isNavigatingBack && _currentFile != null) {
      // Only push to stack if it's a valid history item
      if (_shouldAddToHistory(_currentFile!)) {
        // Create a copy of the current file with the latest probe result
        // This ensures that when we go back, we have the probe data from when we left
        final fileToStack = HtmlFile(
          name: _currentFile!.name,
          path: _currentFile!.path,
          content: _currentFile!.content,
          lastModified: _currentFile!.lastModified,
          size: _currentFile!.size,
          isUrl: _currentFile!.isUrl,
          probeResult: _probeResult ?? _currentFile!.probeResult,
        );

        // Prevent duplicates in back stack (don't push if same as top)
        if (_navigationStack.isEmpty ||
            !areUrlsEqual(_navigationStack.last.path, fileToStack.path)) {
          _navigationStack.add(fileToStack);
          _saveNavigationStack(); // Persist navigation stack
        }
      }
    }
  }

  Future<void> loadFile(
    HtmlFile file, {
    bool clearProbe = true,
    bool isPartial = false,
    int? switchToTab,
    FileSnapshot? snapshot,
  }) async {
    _syncStoreWithFile(file, snapshot);
    if (!isPartial) {
      _isBeautifyEnabled = false; // Reset beautify mode on new file
    }

    // Save current file to navigation stack if we are not going back
    // AND if we are actually navigating to a NEW file (url/path check)
    if (_currentFile != null &&
        !_sameUrlString(_currentFile!.path, file.path)) {
      _pushToNavigationStack();
    }

    final String? previousLoadingUrl = _webViewLoadingUrl;

    // Only clear everything if it's NOT a partial update AND it's a different URL
    // This prevents "flipping" and flickering when the same page updates or finishes sync
    bool isSameUrl =
        _currentFile != null && _sameUrlString(_currentFile!.path, file.path);

    if (!isPartial && !isSameUrl) {
      await clearFile(clearProbe: clearProbe, newUrl: file.path);
    }

    // If we were in the middle of a webview load for this exact file/url
    // preserve the loading state so navigation interception doesn't reset it
    if (previousLoadingUrl != null &&
        areUrlsEqual(previousLoadingUrl, file.path)) {
      _webViewLoadingUrl = previousLoadingUrl;
      _isWebViewLoading = true;
    }

    _currentFile = file;
    _lastCurrentFileUpdate = DateTime.now();
    _originalFile = file; // Store original file for "Automatic" option

    // Try to determine content type from probe result
    if (_probeResult != null && _probeResult!['headers'] is Map) {
      final headers = _probeResult!['headers'] as Map;
      // Headers keys are often lowercase, but let's check carefully
      // The headers from http.Response are usually case-insensitive, but when serialized to Map they might not be
      final contentType = headers['content-type'] ?? headers['Content-Type'];

      if (contentType != null && contentType is String) {
        final detectedLanguage = getLanguageForMimeType(contentType);
        if (detectedLanguage != null) {
          selectedContentType = detectedLanguage;
        }
      }
    }

    // Record in history if it has a path/URL
    if (_shouldAddToHistory(file)) {
      final pending = _historyPendingUrl;
      _historyPendingUrl = null;
      if (file.isUrl && pending != null && !areUrlsEqual(pending, file.path)) {
        // The requested URL redirected here: keep only the destination.
        _urlHistoryService?.replaceUrl(pending, file.path);
      } else {
        // For local files, only add the name to history for a cleaner display
        _urlHistoryService?.addUrl(file.isUrl ? file.path : file.name);
      }
    }

    // Set requested tab switch if provided
    if (switchToTab != null) {
      _requestedTabIndex = switchToTab;
    }

    // Switch back to editor if this is a local file
    if (!file.isUrl && switchToTab == null) {
      _requestedTabIndex = HtmlService.sourceTab;
    }

    // Performance warning for large files
    final fileSizeMB = file.size / (1024 * 1024);
    if (file.size > 1 * 1024 * 1024) {
      if (file.size > 7 * 1024 * 1024) {
        // 7MB severe warning
        debugPrint(
          '⚠️  Very large file loading: ${file.name} (${fileSizeMB.toStringAsFixed(2)} MB)',
        );
      } else {
        // 1MB warning threshold
        debugPrint(
          '📄 Loading large file: ${file.name} (${fileSizeMB.toStringAsFixed(2)} MB)',
        );
      }
    }

    // Automatically detect content type for syntax highlighting
    // This ensures HTML content gets proper syntax highlighting even when loaded from URLs
    try {
      final headers = _probeResult?['headers'] as Map<String, String>?;
      final contentType = headers?['content-type'];

      final detectedType = await fileTypeDetector.detectFileType(
        filename: file.name,
        content: file.content,
        contentType: contentType,
      );

      // Map detected type to appropriate content type for syntax highlighting
      final localContentType = _mapDetectedTypeToContentType(detectedType);

      // Determine if we should override the probed content type
      // We prioritize the probed type (from headers) unless it's generic/unknown
      // or if we have a strong local detection for a specific format.
      bool preferLocalDetection = false;

      if (selectedContentType == null) {
        preferLocalDetection = true;
      } else {
        // If probed type is generic, allow local detection to override
        final isGenericProbe = selectedContentType ==
                'text' || // text/plain often maps to 'text' or similar
            contentType == 'application/octet-stream' ||
            contentType == 'application/x-www-form-urlencoded';

        if (isGenericProbe) {
          preferLocalDetection = true;
        }
      }

      if (preferLocalDetection) {
        selectedContentType = localContentType;
      } else if (localContentType != selectedContentType) {
        debugPrint(
          'Ignoring local detection ($localContentType) in favor of probe ($selectedContentType)',
        );
      }

      // Ensure filename has correct extension based on detection
      // This is crucial for URLs that don't have file extensions (e.g. API endpoints returning images)
      if (file.isUrl) {
        final correctFilename = await detectFileTypeAndGenerateFilename(
          file.name,
          file.content,
          contentType: contentType,
        );

        if (correctFilename != file.name) {
          // Create new file with corrected name
          file = file.copyWith(name: correctFilename);
          _currentFile = file;
        }
      }
    } catch (e) {
      // If detection fails, fall back to automatic (null)
      selectedContentType = null;
    }

    // For local files, show the name (filename) in the URL bar instead of the full path
    String displayName = file.name;
    if (!file.isUrl) {
      // Split by both forward and backward slashes to be safe across platforms
      displayName = displayName.split('/').last.split('\\').last;
    }
    _currentInputText = file.isUrl ? file.path : displayName;
    // Don't notify here - we'll notify once at the end after metadata extraction
    _autoSave();
    await scrollToZero();

    // Update all tab data consistently
    await _updateAllTabData(isPartial: isPartial);

    // Note: State saving is handled by the AppLifecycleObserver
    // We don't save state here to avoid excessive writes during normal usage
  }

  /// Keeps the store in line with the file being shown: a local file puts it
  /// in file mode (no server, no browser); a URL page the store knows nothing
  /// about gets a generation without a server fetch.
  void _syncStoreWithFile(HtmlFile file, FileSnapshot? snapshot) {
    if (file.isUrl) {
      final uri = Uri.tryParse(file.path);
      if (uri == null) return;
      if (_storeCovers(uri)) {
        _noteBrowserUrl(uri);
        return;
      }
      final gen = store.beginUrl(uri);
      const no = Unavailable<Never>(
          UnavailableReason.notApplicable, 'no server fetch for this document');
      store.applyServer(gen, no);
      store.applyRobots(gen, no);
      _serverFetch = null;
      return;
    }
    store.beginFile(snapshot ??
        FileLoader.fromText(file.content,
            origin: file.isShared ? FileOrigin.share : FileOrigin.picker,
            name: file.name,
            path: file.path,
            isError: file.isError));
    _clearBrowserDerivedData();
  }

  /// Map detected file type to appropriate content type for syntax highlighting
  String _mapDetectedTypeToContentType(String detectedType) {
    // Map detected types to content types that work with re_highlight
    const typeMapping = {
      'HTML': 'html',
      'CSS': 'css',
      'JavaScript': 'javascript',
      'TypeScript': 'typescript',
      'JSON': 'json',
      'XML': 'xml',
      'YAML': 'yaml',
      'Markdown': 'markdown',
      'Python': 'python',
      'Java': 'java',
      'Dart': 'dart',
      'C++': 'cpp',
      'C': 'c',
      'C#': 'csharp',
      'PHP': 'php',
      'Ruby': 'ruby',
      'Swift': 'swift',
      'Go': 'go',
      'Rust': 'rust',
      'SQL': 'sql',
      'Text': 'plaintext',
      'Image': 'image',
      'Video': 'video',
      'Audio': 'audio',
    };

    return typeMapping[detectedType] ?? 'plaintext';
  }

  bool _isBeautifyToggling = false;

  Future<void> toggleIsBeautifyEnabled() async {
    if (_isBeautifyToggling) return;
    _isBeautifyToggling = true;

    try {
      // Don't clear cache for beautify toggle - we want to preserve scroll position
      // and just update the content
      _isBeautifyEnabled = !_isBeautifyEnabled;
      notifyListeners();
    } finally {
      // Allow toggling again after a short cooling period
      await Future.delayed(const Duration(milliseconds: 200));
      _isBeautifyToggling = false;
    }
  }

  String? getBeautifiedContentSync(String content, String type) {
    final key = '${content.hashCode}_$type';
    return _beautifiedCache[key];
  }

  Future<String> getBeautifiedContent(String content, String type) async {
    final key = '${content.hashCode}_$type';
    if (_beautifiedCache.containsKey(key)) {
      return _beautifiedCache[key]!;
    }

    final result = await CodeBeautifier.beautifyAsync(content, type);
    _beautifiedCache[key] = result;
    return result;
  }

  Future<void> scrollToZero({String? newUrl}) async {
    // If we have a newUrl, we check if it's different from the current one.
    // If it's the SAME URL, we often want to preserve scroll position (e.g. on partial syncs or refreshes)
    if (newUrl != null && _currentFile != null) {
      if (areUrlsEqual(newUrl, _currentFile!.path)) {
        debugPrint('scrollToZero: Same URL, preserving scroll position');
        return;
      }
    }

    // Reset both vertical and horizontal scroll positions when loading new file
    if (_verticalScrollController?.hasClients ?? false) {
      _verticalScrollController?.jumpTo(0);
    }
    await Future.delayed(const Duration(milliseconds: 10));
    await Future.delayed(const Duration(milliseconds: 10));
    if (_activeHorizontalScrollController?.hasClients ?? false) {
      _activeHorizontalScrollController?.jumpTo(0);
    }
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> clearFile({bool clearProbe = true, String? newUrl}) async {
    await _prepareForEditorReset();
    await scrollToZero(newUrl: newUrl);
    _currentFile = null;
    // Only reset WebView loading state when loading a local file (no newUrl).
    // For URL navigations, keep the state so shouldShowBrowserTab stays true
    // throughout the transition — otherwise the browser tab briefly disappears,
    // _updateTabs clamps the index, and the wrong tab is selected after load.
    final isUrlNavigation =
        newUrl != null && (newUrl.startsWith('http') || newUrl.contains('://'));
    if (!isUrlNavigation) {
      _webViewLoadingUrl = null;
      _isWebViewLoading = false;
      _clearBrowserDerivedData();
    } else {
      // Keep the browser tab anchored to the new URL during transition.
      _webViewLoadingUrl = newUrl;
    }
    _originalFile = null; // Also clear the original file
    selectedContentType = null; // Reset content type selection
    // The user cleared the page: nothing is inspected any more. (A new
    // navigation has already started its own generation.)
    if (clearProbe && newUrl == null) store.clear();
    // Always clear page metadata when loading a new file, even if preserving probe
    // This ensures metadata tabs are cleaned when navigating back
    _pageMetadata = null;
    // clearHighlightCache() is now called within _prepareForEditorReset()
    _beautifiedCache.clear(); // Clear beautify cache
    notifyListeners();
    _autoSave();
  }

  /// Get a list of available content types for syntax highlighting
  /// Get a list of available content types for syntax highlighting
  List<String> getAvailableContentTypes() {
    // Language keys from the highlighter, plus 'html', which loadFile selects
    // for HTML pages and the editor maps to the XML highlighter.
    final availableLanguages = {
      ...SourceViewerEditor.getAvailableLanguages(),
      'html',
    };

    // Filter and sort the list to show most common types first
    final commonTypes = [
      'html',
      'xml',
      'plaintext',
      'css',
      'javascript',
      'typescript',
      'json',
      'yaml',
      'markdown',
      'python',
      'java',
      'dart',
      'c',
      'cpp',
      'csharp',
      'php',
      'ruby',
      'swift',
      'go',
      'rust',
      'sql',
    ];

    final result = <String>['automatic'];

    // Add HTML/XML first
    for (final type in ['html', 'xml']) {
      if (availableLanguages.contains(type) && !result.contains(type)) {
        result.add(type);
      }
    }

    // Add other common types
    for (final type in commonTypes) {
      if (!result.contains(type) && availableLanguages.contains(type)) {
        result.add(type);
      }
    }

    // Add remaining types
    for (final type in availableLanguages) {
      if (!result.contains(type)) {
        result.add(type);
      }
    }

    return result;
  }

  /// Update the current file's content type for syntax highlighting without changing filename
  void updateFileContentType(String newContentType) {
    if (_currentFile == null) return;

    // Handle "Automatic" option - revert to original file and clear selected content type
    if (newContentType == 'automatic') {
      if (_originalFile != null) {
        _currentFile = _originalFile!;
        selectedContentType = null; // Clear selected content type
        notifyListeners();
        _autoSave();
      }
      return;
    }

    // Update the selected content type for syntax highlighting
    selectedContentType = newContentType;

    // Create a new file with the same name but trigger UI update
    final currentFile = _currentFile!;

    // Create updated file with same name (filename doesn't change)
    final updatedFile = HtmlFile(
      name: currentFile.name, // Keep original filename
      path: currentFile.path,
      content: currentFile.content,
      lastModified: DateTime.now(),
      size: currentFile.size,
      isUrl: currentFile.isUrl,
    );

    // Update current file
    _currentFile = updatedFile;
    notifyListeners();
    _autoSave();
  }

  /// Go back to the previous file
  Future<void> goBack() async {
    if (_navigationStack.isEmpty) return;

    final previousFile = _navigationStack.removeLast();
    _saveNavigationStack(); // Persist navigation stack after removal
    _isNavigatingBack = true;
    try {
      debugPrint(
        'Back navigation: Loading previous file: ${previousFile.path}',
      );
      // Use the unified loadUrl entry point; stays on the current tab.
      await loadUrl(previousFile.path);
    } finally {
      _isNavigatingBack = false;
    }
  }

  Future<void> loadFromUrl(
    String url, {
    int? switchToTab,
    bool skipWebViewLoad = false,
    bool forceReload = false,
  }) async {
    // Redirect to the unified entry point
    return loadUrl(
      url,
      switchToTab: switchToTab,
      skipWebViewLoad: skipWebViewLoad,
      forceReload: forceReload,
    );
  }

  /// The server source is always fetched with the page, so there is nothing
  /// to load: this returns what the store has (null while unknown).
  Future<String?> loadServerSourceForDiff() async => serverSource;

  /// Makes sure the server side of [url] is being inspected and returns the
  /// legacy probe map ({} while unknown). A page the current navigation
  /// already covers (same URL, a hop of its chain, or a fetch still running)
  /// is not fetched again.
  Future<void> probeUrl(
    String url, {
    bool forceReload = false,
  }) async {
    var target = url.trim();
    if (target.startsWith('about:')) return;
    if (!target.contains('://')) target = 'https://$target';
    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return;

    if (forceReload || !_storeCovers(uri)) {
      _startInspection(uri, adoptBody: false);
    } else {
      _noteBrowserUrl(uri);
    }
    await _serverFetch;
  }

  /// Get the language name from a MIME type
  String? getLanguageForMimeType(String mimeType) {
    if (mimeType.isEmpty) return null;

    // Normalize and strip parameters (e.g., 'text/html; charset=utf-8' -> 'text/html')
    final baseMime = mimeType.split(';').first.trim().toLowerCase();

    if (baseMime.contains('html')) return 'html';
    if (baseMime.contains('javascript') ||
        baseMime == 'application/x-javascript' ||
        baseMime == 'text/ecmascript') {
      return 'javascript';
    }
    if (baseMime.contains('css')) return 'css';
    if (baseMime.contains('json')) return 'json';
    if (baseMime.contains('xml') ||
        baseMime == 'application/rss+xml' ||
        baseMime == 'application/atom+xml') {
      return 'xml';
    }
    if (baseMime.contains('markdown') || baseMime == 'text/x-markdown') {
      return 'markdown';
    }
    if (baseMime == 'text/plain') return 'plaintext';
    if (baseMime == 'text/x-dart' || baseMime == 'application/dart') {
      return 'dart';
    }
    if (baseMime == 'text/x-python' ||
        baseMime == 'application/x-python-code') {
      return 'python';
    }

    return null;
  }

  String getLanguageForExtension(String extension) {
    final ext = extension.toLowerCase();

    // Comprehensive language mapping for common file extensions
    // Prioritize HTML detection and make it more accurate
    switch (ext) {
      // Web Development - HTML first with better handling
      case 'html':
      case 'htm':
      case 'xhtml':
        return 'html'; // Use 'html' mode if available, otherwise fall back to 'xml'
      case 'css':
        return 'css';
      case 'js':
      case 'javascript':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'ts':
      case 'typescript':
        return 'typescript';
      case 'jsx':
      case 'tsx':
        return 'javascript'; // JSX/TSX use JavaScript highlighting
      case 'json':
        return 'json';
      case 'json5':
        return 'json';
      case 'xml':
      case 'xsd':
      case 'xsl':
      case 'svg':
      case 'rss':
      case 'atom':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'vue':
        return 'vue';
      case 'svelte':
        return 'html'; // Svelte files use HTML highlighting

      // Markup & Documentation
      case 'md':
      case 'markdown':
        return 'markdown';
      case 'txt':
      case 'text':
        return 'plaintext';
      case 'adoc':
      case 'asciidoc':
        return 'asciidoc';

      // Programming Languages
      case 'dart':
        return 'dart';
      case 'py':
      case 'python':
        return 'python';
      case 'java':
        return 'java';
      case 'kt':
      case 'kts':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'go':
        return 'go';
      case 'rs':
      case 'rust':
        return 'rust';
      case 'php':
        return 'php';
      case 'rb':
      case 'ruby':
        return 'ruby';
      case 'cpp':
      case 'cc':
      case 'cxx':
      case 'c++':
      case 'h':
      case 'hpp':
      case 'hxx':
        return 'cpp';
      case 'c':
        return 'c';
      case 'cs':
        return 'csharp';
      case 'scala':
        return 'scala';
      case 'hs':
      case 'haskell':
        return 'haskell';
      case 'lua':
        return 'lua';
      case 'pl':
      case 'perl':
        return 'perl';
      case 'r':
        return 'r';
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
        return 'bash';
      case 'ps1':
      case 'psm1':
        return 'powershell';

      // Configuration & Data
      case 'ini':
      case 'conf':
      case 'config':
        return 'ini';
      case 'properties':
        return 'properties';
      case 'toml':
        return 'toml';
      case 'sql':
        return 'sql';
      case 'graphql':
      case 'gql':
        return 'graphql';
      case 'dockerfile':
        return 'dockerfile';
      case 'makefile':
      case 'mk':
        return 'makefile';
      case 'cmake':
        return 'cmake';
      case 'gn':
        return 'gn';

      // Styling & Preprocessors
      case 'scss':
      case 'sass':
        return 'scss';
      case 'less':
        return 'less';
      case 'styl':
      case 'stylus':
        return 'stylus';

      // Other Common Formats
      case 'diff':
      case 'patch':
        return 'diff';
      case 'gitignore':
      case 'ignore':
        return 'gitignore';
      case 'editorconfig':
        return 'ini';

      // Additional re_highlight supported languages
      case '1c':
        return '1c';
      case 'abnf':
        return 'abnf';
      case 'accesslog':
        return 'accesslog';
      case 'actionscript':
        return 'actionscript';
      case 'ada':
        return 'ada';
      case 'angelscript':
        return 'angelscript';
      case 'apache':
        return 'apache';
      case 'applescript':
        return 'applescript';
      case 'arcade':
        return 'arcade';
      case 'arduino':
        return 'arduino';
      case 'armasm':
        return 'armasm';
      case 'aspectj':
        return 'aspectj';
      case 'autohotkey':
        return 'autohotkey';
      case 'autoit':
        return 'autoit';
      case 'avrasm':
        return 'avrasm';
      case 'awk':
        return 'awk';
      case 'axapta':
        return 'axapta';
      case 'basic':
        return 'basic';
      case 'bnf':
        return 'bnf';
      case 'brainfuck':
        return 'brainfuck';
      case 'cal':
        return 'cal';
      case 'capnproto':
        return 'capnproto';
      case 'ceylon':
        return 'ceylon';
      case 'clean':
        return 'clean';
      case 'coq':
        return 'coq';
      case 'cos':
        return 'cos';
      case 'crmsh':
        return 'crmsh';
      case 'csp':
        return 'csp';
      case 'd':
        return 'd';
      case 'delphi':
      case 'pas':
        return 'delphi';
      case 'django':
        return 'django';
      case 'dns':
        return 'dns';
      case 'dos':
        return 'dos';
      case 'dsconfig':
        return 'dsconfig';
      case 'dts':
        return 'dts';
      case 'dust':
        return 'dust';
      case 'ebnf':
        return 'ebnf';
      case 'erb':
        return 'erb';
      case 'excel':
      case 'xls':
      case 'xlsx':
        return 'excel';
      case 'fix':
        return 'fix';
      case 'flix':
        return 'flix';
      case 'fortran':
      case 'f':
      case 'f77':
      case 'f90':
      case 'f95':
        return 'fortran';
      case 'gams':
        return 'gams';
      case 'gauss':
        return 'gauss';
      case 'gcode':
        return 'gcode';
      case 'gherkin':
        return 'gherkin';
      case 'glsl':
        return 'glsl';
      case 'gml':
        return 'gml';
      case 'golo':
        return 'golo';
      case 'gradle':
        return 'gradle';
      case 'groovy':
        return 'groovy';
      case 'haml':
        return 'haml';
      case 'handlebars':
      case 'hbs':
        return 'handlebars';
      case 'hsp':
        return 'hsp';
      case 'http':
        return 'http';
      case 'hy':
        return 'hy';
      case 'inform7':
        return 'inform7';
      case 'irpf90':
        return 'irpf90';
      case 'isbl':
        return 'isbl';
      case 'jboss-cli':
        return 'jboss-cli';
      case 'julia':
      case 'jl':
        return 'julia';
      case 'lasso':
        return 'lasso';
      case 'latex':
      case 'tex':
        return 'latex';
      case 'ldif':
        return 'ldif';
      case 'leaf':
        return 'leaf';
      case 'lisp':
      case 'lsp':
        return 'lisp';
      case 'livescript':
        return 'livescript';
      case 'llvm':
        return 'llvm';
      case 'lsl':
        return 'lsl';
      case 'mathematica':
      case 'nb':
        return 'mathematica';
      case 'matlab':
      case 'm':
        return 'matlab';
      case 'maxima':
        return 'maxima';
      case 'mel':
        return 'mel';
      case 'mercury':
        return 'mercury';
      case 'mipsasm':
        return 'mipsasm';
      case 'mizar':
        return 'mizar';
      case 'mojolicious':
        return 'mojolicious';
      case 'monkey':
        return 'monkey';
      case 'moonscript':
        return 'moonscript';
      case 'n1ql':
        return 'n1ql';
      case 'nestedtext':
        return 'nestedtext';
      case 'nginx':
        return 'nginx';
      case 'nim':
        return 'nim';
      case 'nix':
        return 'nix';
      case 'nsis':
        return 'nsis';
      case 'objectivec':
      case 'mm':
        return 'objectivec';
      case 'ocaml':
      case 'ml':
      case 'mli':
        return 'ocaml';
      case 'openscad':
      case 'scad':
        return 'openscad';
      case 'oxygene':
        return 'oxygene';
      case 'parser3':
        return 'parser3';
      case 'pf':
        return 'pf';
      case 'pgsql':
        return 'pgsql';
      case 'php-template':
        return 'php-template';
      case 'pony':
        return 'pony';
      case 'processing':
        return 'processing';
      case 'profile':
        return 'profile';
      case 'prolog':
        return 'prolog';
      case 'protobuf':
      case 'proto':
        return 'protobuf';
      case 'puppet':
      case 'pp':
        return 'puppet';
      case 'purebasic':
      case 'pb':
        return 'purebasic';
      case 'python-repl':
        return 'python-repl';
      case 'q':
        return 'q';
      case 'qml':
        return 'qml';
      case 'reasonml':
      case 're':
        return 'reasonml';
      case 'rib':
        return 'rib';
      case 'roboconf':
        return 'roboconf';
      case 'routeros':
        return 'routeros';
      case 'rsl':
        return 'rsl';
      case 'ruleslanguage':
        return 'ruleslanguage';
      case 'sas':
        return 'sas';
      case 'scheme':
      case 'scm':
      case 'ss':
        return 'scheme';
      case 'scilab':
      case 'sci':
        return 'scilab';
      case 'smali':
        return 'smali';
      case 'smalltalk':
      case 'st':
        return 'smalltalk';
      case 'sml':
        return 'sml';
      case 'sqf':
        return 'sqf';
      case 'stan':
        return 'stan';
      case 'stata':
      case 'do':
      case 'ado':
        return 'stata';
      case 'step21':
      case 'stp':
        return 'step21';
      case 'subunit':
        return 'subunit';
      case 'taggerscript':
        return 'taggerscript';
      case 'tap':
        return 'tap';
      case 'tcl':
        return 'tcl';
      case 'thrift':
        return 'thrift';
      case 'tp':
        return 'tp';
      case 'twig':
        return 'twig';
      case 'vala':
      case 'vapi':
        return 'vala';
      case 'vbnet':
      case 'vb':
        return 'vbnet';
      case 'vbscript':
      case 'vbs':
        return 'vbscript';
      case 'vbscript-html':
        return 'vbscript-html';
      case 'verilog':
      case 'v':
        return 'verilog';
      case 'vhdl':
      case 'vhd':
        return 'vhdl';
      case 'vim':
      case 'vimrc':
        return 'vim';
      case 'wren':
        return 'wren';
      case 'x86asm':
      case 'asm':
        return 'x86asm';
      case 'xl':
        return 'xl';
      case 'xquery':
      case 'xq':
      case 'xql':
      case 'xqy':
        return 'xquery';
      case 'zephir':
      case 'zep':
        return 'zephir';

      // Default fallback - try to detect from content
      default:
        return 'plaintext'; // Changed from 'xml' to 'plaintext' for better fallback
    }
  }

  /// The main entry point to build an editor for this service.
  /// Delegated to SourceView for actual implementation.
  FutureOr<Widget> buildEditor(
    String content,
    String extension,
    BuildContext context, {
    double fontSize = 16.0,
    String fontFamily = 'Courier',
    String themeName = 'github',
    bool wrapText = false,
    bool showLineNumbers = true,
    bool isBeautified = false,
    bool isSearchEnabled = false,
    VoidCallback? onSearchClosed,
    ScrollController? verticalController,
    ScrollController? horizontalController,
  }) {
    try {
      // Use provided scroll controllers if available, otherwise create new ones
      final effectiveVerticalController =
          verticalController ?? ScrollController();
      final effectiveHorizontalController =
          horizontalController ?? ScrollController();

      // Dispose of old controllers to prevent memory leaks and performance issues
      if (verticalController == null) {
        _verticalScrollController?.dispose();
      }
      if (horizontalController == null) {
        _activeHorizontalScrollController?.dispose();
      }

      // Store references for external access (e.g., scroll-to-top functionality)
      _verticalScrollController = effectiveVerticalController;
      _activeHorizontalScrollController = effectiveHorizontalController;

      // Handle beautification if enabled
      if (_isBeautifyEnabled && isBeautified) {
        // Check sync cache first to avoid FutureBuilder flicker on subsequent toggles
        final cachedContent = getBeautifiedContentSync(content, extension);
        if (cachedContent != null) {
          return SourceViewerEditor.buildEditor(
            content: cachedContent,
            extension: extension,
            context: context,
            verticalController: effectiveVerticalController,
            horizontalController: effectiveHorizontalController,
            activeFindController: _activeFindController,
            onFindControllerChanged: updateActiveFindController,
            onSearchClosed: onSearchClosed,
            fontSize: fontSize,
            fontFamily: fontFamily,
            themeName: themeName,
            wrapText: wrapText,
            showLineNumbers: showLineNumbers,
            isBeautified: _isBeautifyEnabled,
            isSearchEnabled: _isSearchEnabled,
            forceCodeForge: false,
          );
        }

        debugPrint(
            'HtmlService: Beautification enabled, processing content of length ${content.length}');
        // Not cached yet — use async path with loading indicator
        return FutureBuilder<String>(
          future: getBeautifiedContent(content, extension).then((beautified) {
            debugPrint(
                'HtmlService: Beautification completed. Original: ${content.length} chars, Beautified: ${beautified.length} chars');
            return beautified;
          }).catchError((e) {
            debugPrint('HtmlService: Beautification failed: $e');
            return content;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return SourceViewerEditor.buildEditor(
                content: snapshot.data!,
                extension: extension,
                context: context,
                verticalController: effectiveVerticalController,
                horizontalController: effectiveHorizontalController,
                activeFindController: _activeFindController,
                onFindControllerChanged: updateActiveFindController,
                onSearchClosed: onSearchClosed,
                fontSize: fontSize,
                fontFamily: fontFamily,
                themeName: themeName,
                wrapText: wrapText,
                showLineNumbers: showLineNumbers,
                isBeautified: _isBeautifyEnabled,
                isSearchEnabled: _isSearchEnabled,
                forceCodeForge: false,
              );
            }

            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Beautifying code...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          },
        );
      }

      return SourceViewerEditor.buildEditor(
        content: content,
        extension: extension,
        context: context,
        verticalController: effectiveVerticalController,
        horizontalController: effectiveHorizontalController,
        activeFindController: _activeFindController,
        onFindControllerChanged: updateActiveFindController,
        onSearchClosed: onSearchClosed,
        fontSize: fontSize,
        fontFamily: fontFamily,
        themeName: themeName,
        wrapText: wrapText,
        showLineNumbers: showLineNumbers,
        isBeautified: _isBeautifyEnabled,
        isSearchEnabled: _isSearchEnabled,
        forceCodeForge: false, // Use normal behavior (fallback for large files)
      );
    } catch (e, stackTrace) {
      debugPrint('HtmlService: Error building editor: $e\n$stackTrace');
      return _buildFallbackViewer(content, fontSize, fontFamily);
    }
  }

  /// Fallback viewer for when the main editor fails
  Widget _buildFallbackViewer(
      String content, double fontSize, String fontFamily) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          content,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: fontFamily,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  /// Cancels highlighting
  void cancelPendingHighlight() {
    _highlightDebounceTimer?.cancel();
  }

  /// Reset the editor cache
  void clearHighlightCache() {
    SourceViewerEditor.clearCache();
    _verticalScrollController = null;
    _activeHorizontalScrollController = null;
    notifyListeners();
  }

  /// Proxy for tests and internal usage
  Mode? getReHighlightModeForExtension(String extension) {
    final languageName = SourceViewerEditor.getLanguageForExtension(extension);
    return SourceViewerEditor.getReHighlightMode(languageName);
  }

  /// Prepare the editor for a reset by unfocusing and clearing cache
  Future<void> _prepareForEditorReset() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    clearHighlightCache();
  }

  /// Toggle the search panel for the current editor
  void toggleSearch() {
    _isSearchEnabled = !_isSearchEnabled;

    if (_activeFindController != null) {
      if (_isSearchEnabled) {
        _activeFindController!.findMode();
        _activeFindController!.findInputFocusNode.requestFocus();
      } else {
        _activeFindController!.close();
      }
    }
    notifyListeners();
  }

  /// Update the active find controller and manage listeners
  void updateActiveFindController(CodeFindController? newController) {
    debugPrint('=== updateActiveFindController called ===');
    debugPrint('newController: ${newController != null}');
    debugPrint(
        'current _activeFindController: ${_activeFindController != null}');

    if (_activeFindController == newController) {
      debugPrint('=== Find controller unchanged, returning early ===');
      return;
    }

    // Remove listener from old controller
    if (_activeFindController != null) {
      debugPrint('=== Removing listener from old controller ===');
      _activeFindController!.removeListener(_onSearchStateChanged);
    }

    _activeFindController = newController;
    debugPrint('=== Updated _activeFindController ===');

    // Add listener to new controller
    if (_activeFindController != null) {
      debugPrint('=== Adding listener to new controller ===');
      _activeFindController!.addListener(_onSearchStateChanged);
    }

    debugPrint(
        '=== Find controller updated (not calling notifyListeners to avoid double notification) ===');
  }

  /// Callback when the search state changes
  void _onSearchStateChanged() {
    if (_activeFindController != null) {
      if (_isSearchEnabled != (_activeFindController!.value != null)) {
        _isSearchEnabled = _activeFindController!.value != null;
        notifyListeners();
      }
    }
  }

  /// Unified method to update all tab data consistently
  /// This ensures all tabs (Metadata, Services, Cookies, etc.) are updated together
  Future<void> _updateAllTabData({bool isPartial = false}) async {
    if (_currentFile == null) return;

    // Extract metadata if needed
    if ((_currentFile!.content.isNotEmpty &&
            (selectedContentType == 'html' ||
                selectedContentType == 'xml' ||
                _currentFile!.name.endsWith('.html') ||
                _currentFile!.name.endsWith('.xml') ||
                _currentFile!.name.endsWith('.xhtml'))) ||
        isPartial) {
      await _extractMetadata(isPartial: isPartial);
    }

    // Ensure probe result is properly set in current file
    if (_probeResult != null && _currentFile != null) {
      _currentFile = _currentFile!.copyWith(probeResult: _probeResult);
    }

    notifyListeners();
  }

  /// Extract metadata from the current file content.
  ///
  /// Only one extraction runs at a time; a request that arrives meanwhile is
  /// queued and runs afterwards on the latest content. A result for a
  /// navigation or content that has since changed is dropped.
  Future<void> _extractMetadata({bool isPartial = false}) async {
    if (_currentFile == null) return;
    if (_isExtractingMetadata) {
      _metadataRerunQueued = true;
      return;
    }

    _isExtractingMetadata = true;
    try {
      do {
        _metadataRerunQueued = false;
        final file = _currentFile;
        if (file == null) break;
        final gen = store.current.generation;
        final html = file.content;
        final baseUrl = file.isUrl ? file.path : '';
        final headers = _probeResult?['headers'] as Map<String, String>?;

        Map<String, dynamic>? metadata;
        try {
          metadata = Map<String, dynamic>.from(
              await _metadataExtractor(html, baseUrl, headers: headers));
        } catch (e, stack) {
          debugPrint('Error extracting metadata in isolate: $e\n$stack');
        }
        if (_disposed) return;
        if (gen != store.current.generation || _currentFile?.content != html) {
          // Stale: dropped. Rerun on what is current now.
          _metadataRerunQueued = _currentFile != null;
          continue;
        }

        _pageMetadata = metadata;
        if (metadata != null) {
          if (_lastPageWeight != null) metadata['pageWeight'] = _lastPageWeight;
          // Correlate resource sizes with metadata
          _enrichMetadataWithSizes(baseUrl);
          _fetchMissingMetadataSizesAsync().ignore();
        }
        notifyListeners();
      } while (_metadataRerunQueued);
    } finally {
      _isExtractingMetadata = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Matches extracted metadata links with performance resource data to find sizes
  void _enrichMetadataWithSizes(String baseUrl) {
    if (_pageMetadata == null) return;

    // Helper to find size using a 4-tier lookup strategy
    Map<String, int>? findSize(String? src) {
      if (src == null || src.isEmpty) return null;

      // Tier 0: Data URIs / inline SVGs — size is the content itself
      if (src.startsWith('data:') || src.startsWith('<svg')) {
        return {'transfer': src.length, 'decoded': src.length};
      }

      if (_resourcePerformanceData == null) return null;

      // Tier 1: Exact string match
      var match = _resourcePerformanceData!.firstWhere(
        (r) => r['name'] == src,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        return {
          'transfer': match['transfer'] as int,
          'decoded': match['decoded'] as int,
        };
      }

      // Tier 2: URL-normalised match (handles trailing slashes, case)
      try {
        match = _resourcePerformanceData!.firstWhere(
          (r) => areUrlsEqual(r['name'].toString(), src),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          return {
            'transfer': match['transfer'] as int,
            'decoded': match['decoded'] as int,
          };
        }
      } catch (_) {}

      // Tier 3: Same host+path, query equal modulo cache-busters (CDN
      // versioning like ?v=2 still matches). Content-changing params such as
      // image resize options (?width=112 vs ?width=264 or none) must NOT
      // match: they serve different bytes (e.g. thumbnail vs full original).
      try {
        final srcPath = Uri.parse(src).path;
        if (srcPath.length > 3) {
          match = _resourcePerformanceData!.firstWhere(
            (r) => sameResourceModuloCacheBusters(src, r['name'].toString()),
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            return {
              'transfer': match['transfer'] as int,
              'decoded': match['decoded'] as int,
            };
          }
        }
      } catch (_) {}

      // Tier 4: Strict filename suffix match, same query modulo cache-busters.
      // Requires the filename to be preceded by '/' so "chunk.js"
      // does NOT match "vendor-chunk.js"
      try {
        final srcFileName = Uri.parse(src).path.split('/').last;
        final srcQuery = _queryWithoutCacheBusters(Uri.parse(src));
        if (srcFileName.length > 4) {
          match = _resourcePerformanceData!.firstWhere((r) {
            final rName = r['name'].toString();
            if (!(rName.endsWith('/$srcFileName') || rName == srcFileName)) {
              return false;
            }
            try {
              return _queryWithoutCacheBusters(Uri.parse(rName)) == srcQuery;
            } catch (_) {
              return false;
            }
          }, orElse: () => {});
          if (match.isNotEmpty) {
            return {
              'transfer': match['transfer'] as int,
              'decoded': match['decoded'] as int,
            };
          }
        }
      } catch (_) {}

      return null;
    }

    // Merge External lists into main lists so they are unified for display
    if (_pageMetadata!['externalCssLinks'] != null &&
        (_pageMetadata!['externalCssLinks'] as List).isNotEmpty) {
      if (_pageMetadata!['cssLinks'] == null) {
        _pageMetadata!['cssLinks'] = [];
      }
      final List<dynamic> local = _pageMetadata!['cssLinks'];
      final List<dynamic> external = _pageMetadata!['externalCssLinks'];
      // merge unique
      for (var ext in external) {
        if (!local.contains(ext)) {
          local.add(ext);
        }
      }
      _pageMetadata!.remove('externalCssLinks'); // clean up
    }

    if (_pageMetadata!['externalJsLinks'] != null &&
        (_pageMetadata!['externalJsLinks'] as List).isNotEmpty) {
      if (_pageMetadata!['jsLinks'] == null) {
        _pageMetadata!['jsLinks'] = [];
      }
      final List<dynamic> local = _pageMetadata!['jsLinks'];
      final List<dynamic> external = _pageMetadata!['externalJsLinks'];
      for (var ext in external) {
        if (!local.contains(ext)) {
          local.add(ext);
        }
      }
      _pageMetadata!.remove('externalJsLinks');
    }

    if (_pageMetadata!['externalIframeLinks'] != null &&
        (_pageMetadata!['externalIframeLinks'] as List).isNotEmpty) {
      if (_pageMetadata!['iframeLinks'] == null) {
        _pageMetadata!['iframeLinks'] = [];
      }
      final List<dynamic> local = _pageMetadata!['iframeLinks'];
      final List<dynamic> external = _pageMetadata!['externalIframeLinks'];
      for (var ext in external) {
        if (!local.contains(ext)) {
          local.add(ext);
        }
      }
      _pageMetadata!.remove('externalIframeLinks');
    }

    // Enrich Images
    if (_pageMetadata!['media'] != null &&
        _pageMetadata!['media']['images'] != null) {
      final List<dynamic> images = _pageMetadata!['media']['images'];
      for (int i = 0; i < images.length; i++) {
        if (images[i] is Map) {
          // Create a mutable copy that is safely Map<String, dynamic>
          final Map<String, dynamic> safeImg = Map<String, dynamic>.from(
            images[i],
          );
          final size = findSize(safeImg['src']);
          if (size != null) {
            safeImg['size'] = size;
            images[i] = safeImg; // Update the list with the safe map
          }
        }
      }
    }

    // Enrich CSS
    if (_pageMetadata!['cssLinks'] != null) {
      // Ensure list is mutable and dynamic sized
      _pageMetadata!['cssLinks'] = List<dynamic>.from(
        _pageMetadata!['cssLinks'],
      );
      final List<dynamic> links = _pageMetadata!['cssLinks'];
      for (int i = 0; i < links.length; i++) {
        var css = links[i];
        final String href = css is Map ? (css['href'] ?? '') : css.toString();
        final size = findSize(href);
        if (size != null) {
          if (css is Map) {
            css['size'] = size;
          } else {
            // Convert String to Map to store size
            links[i] = {'href': href, 'size': size};
          }
        }
      }
    }

    // Enrich JS
    if (_pageMetadata!['jsLinks'] != null) {
      // Ensure list is mutable and dynamic sized
      _pageMetadata!['jsLinks'] = List<dynamic>.from(_pageMetadata!['jsLinks']);
      final List<dynamic> links = _pageMetadata!['jsLinks'];
      for (int i = 0; i < links.length; i++) {
        var js = links[i];
        final String src = js is Map ? (js['src'] ?? '') : js.toString();
        final size = findSize(src);
        if (size != null) {
          if (js is Map) {
            js['size'] = size;
          } else {
            // Convert String to Map to store size
            links[i] = {'src': src, 'size': size};
          }
        }
      }
    }

    // Enrich Videos
    if (_pageMetadata!['media'] != null &&
        _pageMetadata!['media']['videos'] != null) {
      final List<dynamic> videos = _pageMetadata!['media']['videos'];
      for (int i = 0; i < videos.length; i++) {
        if (videos[i] is Map) {
          final Map<String, dynamic> safeVid = Map<String, dynamic>.from(
            videos[i],
          );
          final size = findSize(safeVid['src']);
          if (size != null) {
            safeVid['size'] = size;
            videos[i] = safeVid;
          }
        }
      }
    }

    // Fonts: taken from the resources the browser actually loaded
    if (_pageMetadata!['media'] != null) {
      _pageMetadata!['media']['fonts'] = [
        for (final r in _resourcePerformanceData ?? const [])
          if (isFontUrl(r['name'] as String? ?? ''))
            {
              'src': r['name'],
              'size': {'transfer': r['transfer'], 'decoded': r['decoded']},
            }
      ];
    }

    _sortMetadataLists();
  }

  void _sortMetadataLists() {
    if (_pageMetadata == null) return;

    int getSize(dynamic item) {
      if (item is Map &&
          item.containsKey('size') &&
          item['size'] is Map &&
          item['size'].containsKey('decoded')) {
        return (item['size']['decoded'] as int?) ?? 0;
      }
      return 0;
    }

    // Sort CSS
    if (_pageMetadata!['cssLinks'] != null) {
      (_pageMetadata!['cssLinks'] as List).sort((a, b) {
        return getSize(b).compareTo(getSize(a));
      });
    }

    // Sort JS
    if (_pageMetadata!['jsLinks'] != null) {
      (_pageMetadata!['jsLinks'] as List).sort((a, b) {
        return getSize(b).compareTo(getSize(a));
      });
    }

    // Sort Images
    if (_pageMetadata!['media'] != null &&
        _pageMetadata!['media']['images'] != null) {
      (_pageMetadata!['media']['images'] as List).sort((a, b) {
        return getSize(b).compareTo(getSize(a));
      });
    }
  }

  Future<void> _fetchMissingMetadataSizesAsync() async {
    if (_pageMetadata == null) return;

    final List<Map> itemsToFetch = [];

    // JS Links
    if (_pageMetadata!['jsLinks'] != null) {
      final List list = _pageMetadata!['jsLinks'];
      for (int i = 0; i < list.length; i++) {
        var item = list[i];
        if (item is String && !item.startsWith('data:')) {
          // Create a placeholder map so we can fetch and update
          final map = {'src': item};
          list[i] = map; // Replace string with map
          itemsToFetch.add(map);
        } else if (item is Map) {
          final size = item['size'];
          if (size == null || ((size['decoded'] as int?) ?? 0) == 0) {
            final url = item['src'] as String?;
            if (url != null && !url.startsWith('data:')) {
              itemsToFetch.add(item);
            }
          }
        }
      }
    }

    // CSS Links
    if (_pageMetadata!['cssLinks'] != null) {
      final List list = _pageMetadata!['cssLinks'];
      for (int i = 0; i < list.length; i++) {
        var item = list[i];
        if (item is String && !item.startsWith('data:')) {
          final map = {'href': item};
          list[i] = map;
          itemsToFetch.add(map);
        } else if (item is Map) {
          final size = item['size'];
          if (size == null || ((size['decoded'] as int?) ?? 0) == 0) {
            final url = item['href'] as String?;
            if (url != null && !url.startsWith('data:')) {
              itemsToFetch.add(item);
            }
          }
        }
      }
    }

    // Images
    if (_pageMetadata!['media'] != null &&
        _pageMetadata!['media']['images'] != null) {
      final List list = _pageMetadata!['media']['images'];
      for (var item in list) {
        if (item is Map) {
          final size = item['size'];
          if (size == null || ((size['decoded'] as int?) ?? 0) == 0) {
            final url = item['src'] as String?;
            if (url != null && !url.startsWith('data:')) {
              itemsToFetch.add(item);
            }
          }
        }
      }
    }

    if (itemsToFetch.isEmpty) return;

    // Fetch in batches (HEAD requests should be fast, but limit concurrency)
    const int batchSize = 5;
    bool hasUpdates = false;

    for (var i = 0; i < itemsToFetch.length; i += batchSize) {
      if (_currentFile == null) break; // Stop if navigation happened

      final end = (i + batchSize < itemsToFetch.length)
          ? i + batchSize
          : itemsToFetch.length;
      final batch = itemsToFetch.sublist(i, end);

      await Future.wait(
        batch.map((item) async {
          String? url;
          if (item['src'] is String) {
            url = item['src'];
          } else if (item['href'] is String) {
            url = item['href'];
          }

          if (url != null) {
            final size = await _fetchResourceSize(url);
            if (size > 0) {
              item['size'] = {'transfer': size, 'decoded': size};
              hasUpdates = true;
            }
          }
        }),
      );

      // Update UI progressively
      if (hasUpdates) {
        _sortMetadataLists();
        notifyListeners();
      }
    }
  }

  String _unquoteHtml(String html) {
    if (html.startsWith('"') && html.endsWith('"')) {
      try {
        // Use jsonDecode to robustly handle all escape sequences (\n, \", \uXXXX, etc.)
        return jsonDecode(html) as String;
      } catch (e) {
        debugPrint('Error unquoting HTML via jsonDecode: $e');
        // Fallback to manual unquoting if jsonDecode fails
        return html
            .substring(1, html.length - 1)
            .replaceAll('\\"', '"')
            .replaceAll('\\\\', '\\')
            .replaceAll('\\n', '\n')
            .replaceAll('\\r', '\r')
            .replaceAll('\\t', '\t');
      }
    }
    return html;
  }

  Future<void> syncWebViewState(String url, {bool isPartial = false}) async {
    if (activeWebViewController == null) return;
    debugPrint('syncwv $url - $_currentInputText');
    // Update URL bar immediately
    if (_currentInputText != url) {
      _currentInputText = url;
      // which is handled by onPageStarted/onUrlChange in BrowserView
    }

    // Server side of the page the browser is on (headers, redirects, robots).
    // A page the current navigation covers is not fetched again.
    probeUrl(url).ignore();

    try {
      // 1. Critical: Get Content (HTML or Raw)
      String content = '';
      try {
        final html = await activeWebViewController!.evaluateJavascript(
          source: '''
              (function() {
                var doc = document;
                var contentType = doc.contentType;
                
                // If it's an XML/RSS/SVG file, return serialized XML
                if (contentType && (contentType.includes('xml') || contentType.includes('rss') || contentType.includes('svg'))) {
                  try {
                    return new XMLSerializer().serializeToString(doc);
                  } catch (e) {}
                }
                
                // For HTML, reconstruction to include DOCTYPE and nodes outside <html>
                var content = "";
                try {
                  var child = doc.firstChild;
                  while (child) {
                    if (child.nodeType === Node.DOCUMENT_TYPE_NODE) {
                      content += new XMLSerializer().serializeToString(child) + "\\n";
                    } else if (child.nodeType === Node.ELEMENT_NODE) {
                      content += child.outerHTML;
                    } else if (child.nodeType === Node.COMMENT_NODE) {
                      content += "<!--" + child.nodeValue + "-->";
                    } else if (child.nodeType === Node.TEXT_NODE) {
                      content += child.nodeValue;
                    }
                    child = child.nextSibling;
                  }
                } catch (e) {
                  // Fallback to current element if full serialization fails
                  content = doc.documentElement ? doc.documentElement.outerHTML : "";
                }
                
                // If still empty (shadow DOM or similar), fallback to simple string
                return content || (doc.documentElement ? doc.documentElement.outerHTML : "");
              })();
            ''',
        );

        if (html is String) {
          content = _unquoteHtml(html);

          // Workaround for raw files (JS/CSS/JSON) wrapped in <pre> by the browser
          if (content.trim().startsWith('<html') &&
              content.contains('<body') &&
              content.contains('<pre')) {
            try {
              // More robust regex for PRE tags, allowing for varied style strings or none
              final preMatch = RegExp(
                r'<pre[^>]*>(.*?)<\/pre>',
                dotAll: true,
                caseSensitive: false,
              ).firstMatch(content);

              if (preMatch != null) {
                String rawContent = preMatch.group(1) ?? '';
                rawContent = rawContent
                    .replaceAll('&lt;', '<')
                    .replaceAll('&gt;', '>')
                    .replaceAll('&amp;', '&')
                    .replaceAll('&quot;', '"')
                    .replaceAll('&#39;', "'");

                content = rawContent;
                debugPrint(
                  'HTML Service: Extracted raw content from PRE tag for $url',
                );
              }
            } catch (e) {
              debugPrint('HTML Service: Error parsing PRE tag content: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting content from WebView: $e');
        if (content.isEmpty) {
          content = '<!-- Error syncing content: $e -->';
        }
      }

      // 2. Optional: Get Page Weight & Cookies
      try {
        final storageRaw = await activeWebViewController!.evaluateJavascript(
          source: '''
              (function() {
                function collectStorage(storage) {
                  var items = [];
                  var total = 0;
                  try {
                    for (var i = 0; i < storage.length; i++) {
                      var key = storage.key(i);
                      var value = storage.getItem(key) || "";
                      total += key.length + value.length;
                      items.push({k: key, s: value.length});
                    }
                  } catch (e) {}
                  items.sort(function(a, b) { return b.s - a.s; });
                  return {count: items.length, bytes: total, items: items.slice(0, 30)};
                }
                return JSON.stringify({
                  localStorage: collectStorage(window.localStorage),
                  sessionStorage: collectStorage(window.sessionStorage)
                });
              })();
            ''',
        );

        String storageJson = '';
        if (storageRaw is String) {
          storageJson = _unquoteHtml(storageRaw);
        }

        Map<String, dynamic>? storageData;
        if (storageJson.isNotEmpty) {
          final dynamic decodedStorage = jsonDecode(storageJson);
          if (decodedStorage is Map) {
            storageData = Map<String, dynamic>.from(decodedStorage);
          }
        }

        final weightRaw = await activeWebViewController!.evaluateJavascript(
          source:
              // Use the __vsv_res accumulator set up by the injected user script.
              // It captures ALL resources via PerformanceObserver (including lazy chunks),
              // then falls back to getEntriesByType for anything missed before observer attached.
              '(function() {'
              ' var tTx=0; var tDec=0;'
              ' var acc=window.__vsv_res||{};'
              ' var list=[]; var seen=new Set();'
              ' for(var name in acc) {'
              '   var e=acc[name]; var tx=e.t||0; var dec=e.d||0; var st=e.s||0; var du=e.u||0;'
              '   if(!name.startsWith("data:")) { tTx+=tx; tDec+=dec; }'
              '   list.push({n:name,t:tx,d:dec,s:st,u:du}); seen.add(name);'
              ' }'
              ' var r=performance.getEntriesByType("resource");'
              ' for(var i=0;i<r.length;i++) {'
              '   var name=r[i].name; if(seen.has(name)) continue;'
              '   var tx=r[i].transferSize||0; var dec=r[i].decodedBodySize||0; var st=r[i].startTime||0; var du=r[i].duration||0;'
              '   if(!name.startsWith("data:")) { tTx+=tx; tDec+=dec; }'
              '   list.push({n:name,t:tx,d:dec,s:st,u:du}); seen.add(name);'
              ' }'
              ' var nav=performance.getEntriesByType("navigation")[0];'
              ' var nTx=0; var nDec=0;'
              ' if(nav && !seen.has(nav.name)) {'
              '   nTx=nav.transferSize||0; nDec=nav.decodedBodySize||0;'
              '   if(nDec===0) nDec=document.documentElement.outerHTML.length;'
              '   tTx+=nTx; tDec+=nDec;'
              '   list.push({n:nav.name,t:nTx,d:nDec,s:nav.startTime||0,u:nav.duration||0});'
              ' } else if(!nav && !seen.has(document.location.href)) {'
              '   var sz=document.documentElement.outerHTML.length;'
              '   nTx=sz; nDec=sz; tTx+=sz; tDec+=sz;'
              '   list.push({n:document.location.href,t:sz,d:sz,s:0,u:0});'
              ' }'
              ' return JSON.stringify({tx:tTx,dec:tDec,nTx:nTx,nDec:nDec,list:list,cookies:document.cookie});'
              ' })();',
        );

        String jsonStr = '';
        if (weightRaw is String) {
          jsonStr = _unquoteHtml(weightRaw);
        }

        if (jsonStr.isNotEmpty) {
          final dynamic decoded = jsonDecode(jsonStr);
          if (decoded is Map) {
            final weightMap = Map<String, dynamic>.from(decoded);

            // Extract cookies via native CookieManager (captures HttpOnly cookies unlike JS document.cookie)
            try {
              final nativeCookiesList =
                  await CookieManager.instance().getCookies(url: WebUri(url));
              String nativeCookies = nativeCookiesList
                  .where((c) => c.name.isNotEmpty)
                  .map((c) => '${c.name}=${c.value}')
                  .join('; ');

              final jsCookies = weightMap['cookies']?.toString() ?? '';

              // If native lookup returned nothing, try a broader lookup by origin as a fallback
              if (nativeCookies.isEmpty && url.startsWith('http')) {
                try {
                  final uri = Uri.parse(url);
                  final originUrl = '${uri.scheme}://${uri.host}/';
                  final originCookiesList = await CookieManager.instance()
                      .getCookies(url: WebUri(originUrl));
                  nativeCookies = originCookiesList
                      .where((c) => c.name.isNotEmpty)
                      .map((c) => '${c.name}=${c.value}')
                      .join('; ');
                } catch (_) {}
              }

              // Prefer native cookies (which include HttpOnly), but fallback to JS cookies if native is empty
              // And if both are empty, we might have had some from a previous partial sync - don't overwrite with empty
              // unless we are sure. But usually a full sync should replace.
              if (nativeCookies.isNotEmpty) {
                _lastBrowserCookies = nativeCookies;
              } else if (jsCookies.isNotEmpty) {
                _lastBrowserCookies = jsCookies;
              }
            } catch (e) {
              debugPrint('Error getting native cookies: $e');
              _lastBrowserCookies = weightMap['cookies']?.toString() ?? '';
            }
            // analyzedCookies is derived from _lastBrowserCookies on read.

            // Parse detailed resource data
            if (weightMap['list'] != null && weightMap['list'] is List) {
              _resourcePerformanceData = List<Map<String, dynamic>>.from(
                (weightMap['list'] as List).map(
                  (e) => {
                    'name': e['n'],
                    'transfer': (e['t'] as num? ?? 0).toInt(),
                    'decoded': (e['d'] as num? ?? 0).toInt(),
                    'startTime': (e['s'] as num? ?? 0).toDouble(),
                    'duration': (e['u'] as num? ?? 0).toDouble(),
                  },
                ),
              );
            }

            // Calculate totals and breakdown
            int totalTx = (weightMap['tx'] as num? ?? 0).toInt();
            int totalDec = (weightMap['dec'] as num? ?? 0).toInt();
            int mainDocTx = (weightMap['nTx'] as num? ?? 0).toInt();
            int mainDocDec = (weightMap['nDec'] as num? ?? 0).toInt();

            int scriptCount = 0, scriptTx = 0, scriptDec = 0;
            int cssCount = 0, cssTx = 0, cssDec = 0;
            int imgCount = 0, imgTx = 0, imgDec = 0;
            int htmlCount = 0, htmlTx = 0, htmlDec = 0;
            int otherCount = 0, otherTx = 0, otherDec = 0;

            if (_resourcePerformanceData != null) {
              for (var r in _resourcePerformanceData!) {
                final String name = (r['name'] as String? ?? '').toLowerCase();
                final int mTx = (r['transfer'] as num? ?? 0).toInt();
                final int mDec = (r['decoded'] as num? ?? 0).toInt();

                final type = _categorizeResource(name, url.toLowerCase());
                final bool isInline =
                    name.startsWith('data:') || name.startsWith('<svg');

                switch (type) {
                  case 'script':
                    scriptCount++;
                    if (!isInline) {
                      scriptTx += mTx;
                      scriptDec += mDec;
                    }
                    break;
                  case 'style':
                    cssCount++;
                    if (!isInline) {
                      cssTx += mTx;
                      cssDec += mDec;
                    }
                    break;
                  case 'image':
                    imgCount++;
                    if (!isInline) {
                      imgTx += mTx;
                      imgDec += mDec;
                    }
                    break;
                  case 'document':
                    htmlCount++;
                    if (!isInline) {
                      htmlTx += mTx;
                      htmlDec += mDec;
                    }
                    break;
                  default:
                    otherCount++;
                    if (!isInline) {
                      otherTx += mTx;
                      otherDec += mDec;
                    }
                    break;
                }
              }
            }

            // Populate Browser Probe Result
            _browserProbeResult = {
              'browser': 'InAppWebView',
              'os': Platform.operatingSystem,
              'device': Platform.isAndroid
                  ? 'Android'
                  : Platform.isIOS
                      ? 'iOS'
                      : 'Desktop',
              'date': DateTime.now().toIso8601String(),
              'url': url,
              'title': _pageMetadata?['title'],
              'serverStatusCode': _probeResult?['statusCode'],
              'pageWeight': {
                'totalTransfer': totalTx,
                'totalDecoded': totalDec,
                'mainDocumentTransfer': mainDocTx,
                'mainDocumentDecoded': mainDocDec,
                'breakdown': {
                  'scripts': {
                    'count': scriptCount,
                    'transfer': scriptTx,
                    'decoded': scriptDec,
                  },
                  'css': {
                    'count': cssCount,
                    'transfer': cssTx,
                    'decoded': cssDec,
                  },
                  'images': {
                    'count': imgCount,
                    'transfer': imgTx,
                    'decoded': imgDec,
                  },
                  'html': {
                    'count': htmlCount,
                    'transfer': htmlTx,
                    'decoded': htmlDec,
                  },
                  'other': {
                    'count': otherCount,
                    'transfer': otherTx,
                    'decoded': otherDec,
                  },
                },
              },
              'resourceCount': _resourcePerformanceData?.length ?? 0,
              if (storageData != null) 'storage': storageData,
            };

            // Update _lastPageWeight for Metadata tab compatibility
            _lastPageWeight = {
              'transfer': totalTx,
              'decoded': totalDec,
              'breakdown': _browserProbeResult!['pageWeight']['breakdown'],
            };

            if (_pageMetadata != null) {
              _pageMetadata!['pageWeight'] = _lastPageWeight;
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting weight/cookies: $e');
      }

      _enrichResourceSizes().ignore();

      // 3. Update the File State
      String filename = 'Page';
      try {
        filename = generateDescriptiveFilename(Uri.parse(url), content);
      } catch (_) {}

      // Use browser-reported main document size for the file size if available,
      // as it represents the official network response size.
      // Fallback to content.length (the length of the extracted DOM string).
      final int browserDocSize = _browserDocSizeFor(url);

      final file = HtmlFile(
        name: filename,
        path: url,
        content: content,
        lastModified: DateTime.now(),
        size: browserDocSize > 0 ? browserDocSize : content.length,
        isUrl: true,
        probeResult: _probeResult,
      );

      await loadFile(file, clearProbe: false, isPartial: isPartial);

      // Schedule a delayed re-query to catch deferred/lazy-loaded resources
      // (analytics scripts, lazy images, etc. that load after onLoadStop).
      debugPrint(
          'pageWeight: scheduling refresh, isPartial=$isPartial url=$url');
      if (!isPartial) {
        _refreshPageWeightAfterDelay(url).ignore();
      }
    } catch (e) {
      debugPrint('Error syncing WebView state: $e');
    } finally {
      if (!isPartial) {
        _isLoading = false;
      }
      // Update all tab data to ensure consistency
      await _updateAllTabData(isPartial: isPartial);
      // Ensure webview loading state is reset when sync completes
      _isWebViewLoading = false;
      _webViewLoadingUrl = null;
      notifyListeners();
    }
  }

  Future<void> _refreshPageWeightAfterDelay(String url) async {
    // Two passes: catch fast lazy loaders at 4s, slow PWA hydration at 14s.
    for (final delay in [
      const Duration(seconds: 4),
      const Duration(seconds: 10),
    ]) {
      await Future.delayed(delay);
      debugPrint(
          'pageWeight delayed check: controller=${activeWebViewController != null}, currentPath=${_currentFile?.path}, url=$url');
      if (activeWebViewController == null) return;
      if (_currentFile?.path != url) return; // user navigated away
      await _doPageWeightRefresh(url);
    }
  }

  static const String _weightQueryJs = '(function() {'
      ' var tTx=0; var tDec=0;'
      ' var acc=window.__vsv_res||{};'
      ' var list=[]; var seen=new Set();'
      ' for(var name in acc) {'
      '   var e=acc[name]; var tx=e.t||0; var dec=e.d||0; var st=e.s||0; var du=e.u||0;'
      '   if(!name.startsWith("data:")) { tTx+=tx; tDec+=dec; }'
      '   list.push({n:name,t:tx,d:dec,s:st,u:du}); seen.add(name);'
      ' }'
      // Fallback: pick up anything from before the observer was attached
      ' var r=performance.getEntriesByType("resource");'
      ' for(var i=0;i<r.length;i++) {'
      '   var name=r[i].name; if(seen.has(name)) continue;'
      '   var tx=r[i].transferSize||0; var dec=r[i].decodedBodySize||0; var st=r[i].startTime||0; var du=r[i].duration||0;'
      '   if(!name.startsWith("data:")) { tTx+=tx; tDec+=dec; }'
      '   list.push({n:name,t:tx,d:dec,s:st,u:du}); seen.add(name);'
      ' }'
      ' var nav=performance.getEntriesByType("navigation")[0];'
      ' if(nav && !seen.has(nav.name)) {'
      '   var nTx=nav.transferSize||0; var nDec=nav.decodedBodySize||0;'
      '   if(nDec===0) nDec=document.documentElement.outerHTML.length;'
      '   tTx+=nTx; tDec+=nDec;'
      '   list.push({n:nav.name,t:nTx,d:nDec,s:nav.startTime||0,u:nav.duration||0});'
      ' }'
      ' return JSON.stringify({tx:tTx,dec:tDec,list:list});'
      ' })();';

  Future<void> _doPageWeightRefresh(String url) async {
    try {
      final weightRaw = await activeWebViewController!
          .evaluateJavascript(source: _weightQueryJs);

      String jsonStr = '';
      if (weightRaw is String) jsonStr = _unquoteHtml(weightRaw);
      debugPrint(
          'pageWeight _doRefresh: jsonStr empty=${jsonStr.isEmpty}, rawType=${weightRaw.runtimeType}');
      if (jsonStr.isEmpty) return;

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return;

      final newTx = (decoded['tx'] as num? ?? 0).toInt();
      final newDec = (decoded['dec'] as num? ?? 0).toInt();
      final newList = decoded['list'];
      if (newList is! List) return;

      final prevTx = (_lastPageWeight?['transfer'] as num? ?? 0).toInt();
      final prevDec = (_lastPageWeight?['decoded'] as num? ?? 0).toInt();
      debugPrint(
          'pageWeight _doRefresh: newTx=$newTx newDec=$newDec prevTx=$prevTx prevDec=$prevDec');

      // SPAs (e.g. Next.js) often call performance.clearResourceTimings() which can
      // make the new snapshot look smaller than what we already captured. Always merge
      // the lists so we keep the union of all resources seen across all snapshots.
      final existing = <String, Map<String, dynamic>>{
        for (final r in (_resourcePerformanceData ?? []))
          (r['name'] as String? ?? ''): r,
      };
      bool anyNew = false;
      for (final e in newList) {
        final name = e['n'] as String? ?? '';
        if (name.isEmpty) continue;
        final tx = (e['t'] as num? ?? 0).toInt();
        final dec = (e['d'] as num? ?? 0).toInt();
        final prev = existing[name];
        if (prev == null) {
          existing[name] = {'name': name, 'transfer': tx, 'decoded': dec};
          anyNew = true;
        } else if (dec > (prev['decoded'] as num? ?? 0)) {
          existing[name] = {'name': name, 'transfer': tx, 'decoded': dec};
          anyNew = true;
        }
      }
      if (!anyNew) return;

      _resourcePerformanceData = existing.values.toList();

      // Recompute totals from the merged list (never let them go below what we had).
      int sumTx = 0, sumDec = 0;
      for (final r in _resourcePerformanceData!) {
        final name = r['name'] as String? ?? '';
        if (name.startsWith('data:')) continue;
        sumTx += (r['transfer'] as num? ?? 0).toInt();
        sumDec += (r['decoded'] as num? ?? 0).toInt();
      }
      final totalTx = sumTx > prevTx ? sumTx : prevTx;
      final totalDec = sumDec > prevDec ? sumDec : prevDec;
      if (totalTx == prevTx && totalDec == prevDec) return;

      debugPrint('pageWeight refresh: ${prevTx}B → ${totalTx}B transfer');

      if (_lastPageWeight != null) {
        _lastPageWeight!['transfer'] = totalTx;
        _lastPageWeight!['decoded'] = totalDec;
      }

      await _enrichResourceSizes();
    } catch (e) {
      debugPrint('Error in delayed page weight refresh: $e');
    }
  }

  /// Fetches content-length
  Future<void> _enrichResourceSizes() async {
    if (_resourcePerformanceData == null) return;

    final resourcesToUpdate = _resourcePerformanceData!
        .where(
          (r) =>
              (r['transfer'] as int) == 0 &&
              (r['name'] as String).startsWith('http'),
        )
        .toList();

    if (resourcesToUpdate.isEmpty) return;

    // Limit concurrency to avoid choking the network
    const int batchSize = 5;
    for (var i = 0; i < resourcesToUpdate.length; i += batchSize) {
      final end = (i + batchSize < resourcesToUpdate.length)
          ? i + batchSize
          : resourcesToUpdate.length;
      final batch = resourcesToUpdate.sublist(i, end);

      await Future.wait(
        batch.map((resource) async {
          try {
            final url = resource['name'] as String;
            final size = await _fetchResourceSize(url);
            if (size > 0) {
              resource['transfer'] = size;
              resource['decoded'] = size;
            }
          } catch (e) {
            // ignore
          }
        }),
      );
    }

    // Deduplicate resource list by URL
    final Map<String, Map<String, dynamic>> uniqueResources = {};
    for (var r in _resourcePerformanceData!) {
      final name = r['name'] as String? ?? '';
      if (name.isNotEmpty) {
        // Keep the entry with the larger decoded size (prefer non-cached data)
        final existing = uniqueResources[name];
        if (existing == null ||
            (r['decoded'] as num? ?? 0) > (existing['decoded'] as num? ?? 0)) {
          uniqueResources[name] = r;
        }
      }
    }
    _resourcePerformanceData = uniqueResources.values.toList();

    // Recalculate breakdown counts. For totals, prefer the original browser-reported
    // value since cached resources are already included there.
    int scriptCount = 0, scriptTx = 0, scriptDec = 0;
    int cssCount = 0, cssTx = 0, cssDec = 0;
    int imgCount = 0, imgTx = 0, imgDec = 0;
    int htmlCount = 0, htmlTx = 0, htmlDec = 0;
    int otherCount = 0, otherTx = 0, otherDec = 0;

    final url = _currentFile?.path.toLowerCase() ?? '';

    for (var r in _resourcePerformanceData!) {
      final String name = (r['name'] as String? ?? '').toLowerCase();
      final int mTx = (r['transfer'] as num? ?? 0).toInt();
      final int mDec = (r['decoded'] as num? ?? 0).toInt();

      final type = _categorizeResource(name, url);
      final bool isInline = name.startsWith('data:') || name.startsWith('<svg');

      switch (type) {
        case 'script':
          scriptCount++;
          if (!isInline) {
            scriptTx += mTx;
            scriptDec += mDec;
          }
          break;
        case 'style':
          cssCount++;
          if (!isInline) {
            cssTx += mTx;
            cssDec += mDec;
          }
          break;
        case 'image':
          imgCount++;
          if (!isInline) {
            imgTx += mTx;
            imgDec += mDec;
          }
          break;
        case 'document':
          htmlCount++;
          if (!isInline) {
            htmlTx += mTx;
            htmlDec += mDec;
          }
          break;
        default:
          otherCount++;
          if (!isInline) {
            otherTx += mTx;
            otherDec += mDec;
          }
          break;
      }
    }

    // For the overall total, prefer the previously stored browser-reported value
    // (which includes cached resources) over summing from the resource list.
    // Only override if we have a meaningfully larger sum (e.g., after fetching missing sizes).
    final sumTx = scriptTx + cssTx + imgTx + htmlTx + otherTx;
    final sumDec = scriptDec + cssDec + imgDec + htmlDec + otherDec;
    final prevTx = (_lastPageWeight?['transfer'] as num? ?? 0).toInt();
    final prevDec = (_lastPageWeight?['decoded'] as num? ?? 0).toInt();
    final totalTransferSize = sumTx > prevTx ? sumTx : prevTx;
    final totalDecodedSize = sumDec > prevDec ? sumDec : prevDec;

    // Detect if any resources have size=0 (cross-origin without Timing-Allow-Origin)
    final hasUnknownSizes = _resourcePerformanceData!.any((r) {
      final name = r['name'] as String? ?? '';
      return !name.startsWith('data:') &&
          (r['transfer'] as num? ?? 0) == 0 &&
          (r['decoded'] as num? ?? 0) == 0;
    });

    _lastPageWeight = {
      'transfer': totalTransferSize,
      'decoded': totalDecodedSize,
      'isPartial': hasUnknownSizes,
      'resources': _resourcePerformanceData,
      'breakdown': {
        'scripts': {
          'count': scriptCount,
          'transfer': scriptTx,
          'decoded': scriptDec,
        },
        'css': {'count': cssCount, 'transfer': cssTx, 'decoded': cssDec},
        'images': {'count': imgCount, 'transfer': imgTx, 'decoded': imgDec},
        'html': {'count': htmlCount, 'transfer': htmlTx, 'decoded': htmlDec},
        'other': {
          'count': otherCount,
          'transfer': otherTx,
          'decoded': otherDec,
        },
      },
    };

    // Update the parent metadata object if it exists
    if (_pageMetadata != null) {
      _pageMetadata!['pageWeight'] = _lastPageWeight;
    }

    // Re-enrich metadata so the Media/Services tabs update with the new sizes
    final baseUrl = _currentFile?.isUrl == true ? _currentFile!.path : '';
    _enrichMetadataWithSizes(baseUrl);
    notifyListeners();
  }

  String _categorizeResource(String name, String pageUrl) {
    return ProbeService.categorizeResource(name, pageUrl);
  }

  Future<int> _fetchResourceSize(String url) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(url);
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
      };

      // 1. Ranged GET first: this runs the same GET pipeline as the browser,
      //    so query-param transforms on image CDNs (?width=...&height=...)
      //    are applied and content-range/content-length reflect the bytes a
      //    browser actually downloads. HEAD can be answered with the
      //    untransformed origin object's size instead.
      try {
        final request = http.Request('GET', uri);
        request.headers.addAll(headers);
        request.headers['Range'] = 'bytes=0-0';

        final streamedResponse =
            await client.send(request).timeout(const Duration(seconds: 5));

        final contentLengthStr = streamedResponse.headers['content-length'];
        final contentRangeStr = streamedResponse.headers['content-range'];

        // Immediately drain the body so we don't hold the connection
        streamedResponse.stream.listen((_) {}).cancel();

        if (streamedResponse.statusCode >= 200 &&
            streamedResponse.statusCode < 400) {
          if (contentRangeStr != null) {
            final parts = contentRangeStr.split('/');
            if (parts.length == 2) {
              final size = int.tryParse(parts[1]);
              if (size != null && size > 0) return size;
            }
          }

          if (contentLengthStr != null) {
            final size = int.tryParse(contentLengthStr);
            if (size != null && size > 0) return size;
          }
        }
      } catch (e) {
        // Fallback to HEAD if the ranged GET fails or times out
      }

      // 2. Fallback to HEAD request
      try {
        final headResponse = await client
            .head(uri, headers: headers)
            .timeout(const Duration(seconds: 5));
        if (headResponse.statusCode >= 200 && headResponse.statusCode < 400) {
          final contentLength = headResponse.headers['content-length'];
          if (contentLength != null) {
            final size = int.tryParse(contentLength);
            if (size != null && size > 0) return size;
          }
        }
      } catch (e) {
        // ignore
      }
    } catch (e) {
      debugPrint('Error getting resource size for $url: $e');
    } finally {
      client.close();
    }
    return 0;
  }

  /// Clear the WebView cache (excluding cookies/localStorage if possible, but WebViewController.clearCache usually does disk cache)
  Future<void> clearBrowserCache() async {
    if (activeWebViewController != null) {
      await InAppWebViewController.clearAllCache();
      debugPrint('Browser cache cleared');
    }
  }

  /// Clear all browser data: Cache, Local Storage, and Cookies
  Future<void> clearBrowserStorage() async {
    if (activeWebViewController != null) {
      await InAppWebViewController.clearAllCache();
      await activeWebViewController!.evaluateJavascript(
        source: "localStorage.clear();",
      );
    }
    // Clear cookies using the static/singleton CookieManager
    await CookieManager.instance().deleteAllCookies();

    // Browser cookies are gone; the server's own data stays valid.
    _lastBrowserCookies = '';
    _pageMetadata = null;

    debugPrint('Browser storage (cache, local storage, cookies) cleared');
    notifyListeners();
  }
}

/// Production [BrowserLoader]: navigates the active WebView, if there is one.
class _ControllerBrowserLoader implements BrowserLoader {
  final HtmlService _service;
  _ControllerBrowserLoader(this._service);

  @override
  void loadUrl(Uri url) {
    _service.activeWebViewController
        ?.loadUrl(urlRequest: URLRequest(url: WebUri(url.toString())))
        .ignore();
  }
}
