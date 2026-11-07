import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_editor/re_editor.dart';
import 'package:http/http.dart' as http;
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
import 'package:view_source_vibe/services/derive/cookies_view.dart';
import 'package:view_source_vibe/services/derive/detections.dart';
import 'package:view_source_vibe/services/derive/detections_view.dart';
import 'package:view_source_vibe/services/derive/divergences.dart';
import 'package:view_source_vibe/services/derive/header_insights.dart';
import 'package:view_source_vibe/services/derive/probe_general.dart';
import 'package:view_source_vibe/services/derive/request_timeline.dart';
import 'package:view_source_vibe/services/derive/security_audit.dart';
import 'package:view_source_vibe/services/derive/media.dart';
import 'package:view_source_vibe/services/derive/metadata.dart';
import 'package:view_source_vibe/services/derive/metadata_view.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/derive/dom_tree.dart';
import 'package:view_source_vibe/services/derive/resource_matching.dart';
import 'package:view_source_vibe/services/derive/source_view.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/legacy_browser_adapter.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/services/collectors/browser_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Extracts page metadata from source (isolate in production, a fake in tests).
typedef MetadataExtractor = Future<Map<String, dynamic>>
    Function(String html, String baseUrl, {Map<String, String>? headers});

typedef SovereigntyAnalyzer = Future<SovereigntyReport> Function({
  required String pageUrl,
  required PageInspection inspection,
  Map<String, dynamic>? metadata,
  List<Detection> detections,
  String? html,
  String home,
});

class HtmlService extends ChangeNotifier {
  final SovereigntyAnalyzer _sovereigntyAnalyzer;
  final DetectionScanner? _detectionScanner;
  final int _detectionIsolateThreshold;
  final DomTreeBuilder? _domTreeBuilder;
  final int _domTreeIsolateThreshold;

  /// Test hook: awaited right after a server file was built.
  @visibleForTesting
  Future<void> Function()? debugAfterServerFileBuilt;

  @visibleForTesting
  Map<String, dynamic>? get lastPageWeight => _pageWeight;

  /// Weight from the browser's resources when it reported them, else the
  /// document's own size from the server body.
  Map<String, dynamic>? get _pageWeight {
    _deriveBrowserData();
    return _browserWeight ?? _lastPageWeight;
  }

  /// The central inspection data (server, browser and file cores).
  final InspectionStore store;
  final bool _ownsStore;
  final ServerFetcher _serverFetcher;
  late final BrowserLoader _browserLoader;
  final MetadataExtractor _metadataExtractor;
  final BrowserCollect? _browserCollectOverride;
  final NativeCookieReader _nativeCookies;
  final ResourceSizeLookup _sizeLookup;
  final BrowserPlatform _platform;
  final List<Duration> _refreshDelays;
  final Duration _spaSettleDelay;
  final List<Timer> _refreshTimers = [];
  bool _disposed = false;

  /// The raw payload of the last collect and the generation it belongs to
  /// (debug export, so real-device fixtures can be recorded).
  ({int gen, String raw})? _lastRawPayload;

  /// What the last collector call returned for the current navigation.
  String? get browserDebugPayload {
    final last = _lastRawPayload;
    return last != null && last.gen == store.current.generation
        ? last.raw
        : null;
  }

  // Legacy views of the browser data, recomputed when the store's browser or
  // server result changes.
  Observed<BrowserSnapshot>? _derivedBrowser;
  Observed<ServerSnapshot>? _derivedServer;
  List<Map<String, dynamic>> _timeline = const [];
  Map<String, dynamic>? _browserWeight;

  void _deriveBrowserData() {
    final current = store.current;
    if (identical(current.browser, _derivedBrowser) &&
        identical(current.server, _derivedServer)) {
      return;
    }
    _derivedBrowser = current.browser;
    _derivedServer = current.server;
    _timeline = legacyResourceTimeline(current);
    _browserWeight = legacyPageWeight(current);
  }

  bool get _browserReachable =>
      _browserCollectOverride != null || activeWebViewController != null;

  Future<Object?> _collect(String url) =>
      (_browserCollectOverride ?? _collectViaController)(url);

  /// The server fetch of the current navigation (null when none runs).
  Future<void>? _serverFetch;


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

  /// Generation the report / error belong to.
  int? _sovereigntyGen;

  /// The legal home the report was asked for (not read back from the report,
  /// so an analyzer that answers with another home cannot cause a loop).
  String? _sovereigntyHome;
  String? _sovereigntyError;
  int _sovereigntyWatchers = 0;
  bool _sovereigntyScheduled = false;
  String? _sovereigntyInputKey;
  Timer? _sovereigntyTimer;
  final Duration _sovereigntyDebounce;
  Observed<SovereigntyReport>? _sovereigntyPresent;

  // Metadata state
  Map<String, dynamic>? _pageMetadata;
  Map<String, dynamic>? get pageMetadata => _pageMetadata;

  // What the last extraction produced besides the map; reset with it.
  DocumentChecks? _metadataChecks;
  List<UnresolvedLink> _metadataUnresolved = const [];
  DataSource? _metadataDocSource;
  String? _metadataError;
  int _metadataRevision = 0;

  void _resetMetadata() {
    _pageMetadata = null;
    _metadataChecks = null;
    _metadataUnresolved = const [];
    _metadataDocSource = null;
    _metadataError = null;
    _metadataRevision++;
  }

  Observed<MetadataModel>? _metadataState;
  int? _metadataStateRevision;
  PageInspection? _metadataStateFor;
  bool? _metadataStateExtracting;

  Observed<MediaModel>? _mediaState;
  Observed<MetadataModel>? _mediaStateFor;

  /// The Media tab's data (images, videos, fonts of the analysed document),
  /// or why there is none. "Empty" only when the extraction succeeded.
  Observed<MediaModel> get mediaState {
    final m = metadataState;
    if (_mediaState == null || !identical(m, _mediaStateFor)) {
      _mediaStateFor = m;
      _mediaState = switch (m) {
        Present<MetadataModel>(value: final v) =>
          Present(deriveMedia(v), source: v.docSource),
        Pending<MetadataModel>() => const Pending(),
        Failed<MetadataModel>(error: final e) => Failed(e),
        Unavailable<MetadataModel>(reason: final r, detail: final d) =>
          Unavailable(r, d),
      };
    }
    return _mediaState!;
  }

  /// Why a link has no size when the browser said nothing about it.
  String _sizeUnknownReason() {
    final b = store.current.browser;
    return switch (b) {
      Present<BrowserSnapshot>(value: final snap) => switch (snap.resources) {
          Present() => 'not among the requests the browser reported',
          Unavailable(reason: final r, detail: final d) =>
            unavailableMessage(r, d),
          Failed(error: final e) => 'browser requests failed: $e',
          Pending() => 'browser requests still loading',
        },
      Pending<BrowserSnapshot>() => 'browser data still loading',
      Failed<BrowserSnapshot>(error: final e) => 'browser data failed: $e',
      Unavailable<BrowserSnapshot>(reason: final r, detail: final d) =>
        store.current.target is FileTarget
            ? 'browser data not available for local files'
            : unavailableMessage(r, d),
    };
  }

  /// The Metadata tab's data, or why there is none (reading, failed, nothing
  /// loaded). Changes identity only when the extraction, its sizes or the
  /// browser data change.
  Observed<MetadataModel> get metadataState {
    final current = store.current;
    if (_metadataState == null ||
        _metadataStateRevision != _metadataRevision ||
        !identical(_metadataStateFor, current) ||
        _metadataStateExtracting != _isExtractingMetadata) {
      _metadataStateRevision = _metadataRevision;
      _metadataStateFor = current;
      _metadataStateExtracting = _isExtractingMetadata;
      final data = _pageMetadata;
      final checks = _metadataChecks;
      _metadataState = _isExtractingMetadata
          ? const Pending()
          : data != null && checks != null
              ? Present(
                  MetadataModel(
                    data: data,
                    docSource: _metadataDocSource ?? DataSource.file,
                    checks: checks,
                    unresolved: _metadataUnresolved,
                    sizeUnknownReason: _sizeUnknownReason(),
                  ),
                  source: _metadataDocSource ?? DataSource.file)
              : _metadataError != null
                  ? Failed(_metadataError!)
                  : _currentFile == null && current.target is NoTarget
                      ? const Unavailable(
                          UnavailableReason.notApplicable, 'nothing loaded')
                      : const Pending();
    }
    return _metadataState!;
  }

  // The document's own wire/decoded size from the server body; used while
  // the browser has no numbers. Browser numbers come from the store.
  Map<String, dynamic>? _lastPageWeight;
  bool _isExtractingMetadata = false;

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
  /// The app's own server answer, final hop: headers without Set-Cookie
  /// (values joined by ", "). Null until the server answered, and for local
  /// files or failed fetches. Never a placeholder.
  Map<String, String>? get _responseHeaders {
    final server = SovereigntyService.serverOf(store.current);
    if (server == null) return null;
    return {
      for (final e in server.hops.last.headers.entries)
        if (e.key != 'set-cookie') e.key: e.value.join(', '),
    };
  }

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

  /// The browser's resources; a size or time it did not report is null.
  List<Map<String, dynamic>> get resourceTimelineData {
    _deriveBrowserData();
    return _timeline;
  }

  List<Detection>? _detections;
  PageInspection? _detectionsFor;

  // The source scan is cached on the identity of the scanned texts, so
  // resource/cookie updates only redo the cheap request/cookie part.
  DetectionTexts? _scanTexts;
  List<Map<String, dynamic>>? _scanned;
  bool _scanPending = false;
  String? _scanError;

  /// True while the source scan runs off-thread (large documents): the
  /// source-based findings are then missing from [detections]; that is not
  /// "none found".
  bool get detectionsPending {
    detections;
    return _scanPending;
  }

  /// Every service, tracker and technology on the page, derived from the
  /// store's snapshots (server headers and source, browser DOM, requests and
  /// cookies); each evidence item says which core it came from.
  List<Detection> get detections {
    final current = store.current;
    final texts = detectionTextsOf(current);
    if (!sameDetectionTexts(texts, _scanTexts)) {
      _scanTexts = texts;
      _scanned = null;
      _scanPending = false;
      _scanError = null;
      _detections = null;
      if (_detectionScanner == null &&
          texts.totalLength <= _detectionIsolateThreshold) {
        _scanned = scanTextsToMaps(texts);
      } else {
        _startDetectionScan(texts);
      }
    }
    if (_detections == null || !identical(current, _detectionsFor)) {
      _detectionsFor = current;
      _detections = deriveDetections(current, scanned: _scanned ?? const []);
    }
    return _detections!;
  }

  /// Set when the source scan failed: the source-based findings are then
  /// absent, which is not "none found".
  String? get detectionsError {
    detections;
    return _scanError;
  }

  DetectionsView? _detectionsView;
  List<Detection>? _detectionsViewList;
  PageInspection? _detectionsViewFor;
  bool? _detectionsViewScanning;
  String? _detectionsViewError;

  /// Findings plus whether they are complete (scanning, failed, which sources
  /// were read). The Services, Privacy and Technology views read this.
  DetectionsView get detectionsView {
    final list = detections;
    final current = store.current;
    final sources =
        describeCheckedSources(current, browserReachable: _browserReachable);
    final scanning = _scanPending || sources.waiting;
    if (_detectionsView == null ||
        !identical(list, _detectionsViewList) ||
        !identical(current, _detectionsViewFor) ||
        scanning != _detectionsViewScanning ||
        sources.line != _detectionsView!.sources.line ||
        _scanError != _detectionsViewError) {
      _detectionsViewList = list;
      _detectionsViewFor = current;
      _detectionsViewScanning = scanning;
      _detectionsViewError = _scanError;
      _detectionsView = DetectionsView(
          detections: list,
          scanning: scanning,
          failure: _scanError,
          sources: sources);
    }
    return _detectionsView!;
  }

  void _startDetectionScan(DetectionTexts texts) {
    _scanPending = true;
    final scan =
        _detectionScanner ?? (DetectionTexts t) => compute(scanTextsToMaps, t);
    void done(List<Map<String, dynamic>>? maps) {
      if (_disposed || !identical(_scanTexts, texts)) return;
      _scanPending = false;
      _scanned = maps;
      _detections = null;
      notifyListeners();
    }

    scan(texts).then(done, onError: (Object e) {
      debugPrint('Detection scan failed: $e');
      if (!_disposed && identical(_scanTexts, texts)) _scanError = '$e';
      done(null);
    });
  }

  SourceView? _sourceView;
  PageInspection? _sourceViewFor;
  String? _sourceViewFallback;

  /// The document the Source tab and DOM tree show (from the store; the
  /// legacy current file only fills in when the store holds no document).
  SourceView get sourceView {
    final current = store.current;
    final fallback = _currentFile?.content;
    if (_sourceView == null ||
        !identical(current, _sourceViewFor) ||
        !identical(fallback, _sourceViewFallback)) {
      _sourceViewFor = current;
      _sourceViewFallback = fallback;
      _sourceView = deriveSourceView(current, fallbackText: fallback);
    }
    return _sourceView!;
  }

  /// The user picked a document in the Source tab's switch.
  void selectSourceDocument(DataSource source) {
    store.setPrimaryDocument(source);
    // The metadata follows the chosen document.
    if (_currentFile != null) _extractMetadata().ignore();
  }

  /// Set when the content was loaded although its TLS certificate is invalid.
  String? get tlsWarning {
    final server = store.current.server;
    if (server is! Present<ServerSnapshot> ||
        !server.value.acceptedInvalidCertificate ||
        server.value.hops.isEmpty ||
        server.value.hops.last.url.scheme != 'https') {
      return null;
    }
    return 'TLS certificate validation failed. Content was loaded anyway for inspection.';
  }

  /// Content-Type of the server's final response; null when unknown.
  String? get serverContentType {
    final server = store.current.server;
    if (server is! Present<ServerSnapshot> || server.value.hops.isEmpty) {
      return null;
    }
    return server.value.hops.last.header('content-type');
  }

  // Trees of the last few documents, by text identity and kind.
  final List<({String text, DomTreeKind kind, DomTree tree})> _domTreeCache =
      [];
  ({String text, DomTreeKind kind})? _domTreeBuilding;

  /// How many trees were built (tests: once per document).
  @visibleForTesting
  int domTreeBuilds = 0;

  /// True while the tree of the shown document is built off-thread.
  bool get domTreePending {
    domTree;
    final key = _currentDomKey();
    final b = _domTreeBuilding;
    return key != null &&
        b != null &&
        identical(b.text, key.text) &&
        b.kind == key.kind &&
        _domTreeBuilding != null;
  }

  // Builds that failed, by text identity and kind: never retried.
  final List<({String text, DomTreeKind kind, String error})> _domTreeFailures =
      [];

  /// Why the shown document's tree could not be built; null otherwise.
  String? get domTreeError {
    final key = _currentDomKey();
    if (key == null) return null;
    for (final f in _domTreeFailures) {
      if (identical(f.text, key.text) && f.kind == key.kind) return f.error;
    }
    return null;
  }

  ({String text, DomTreeKind kind})? _currentDomKey() {
    final view = sourceView;
    final text = view.textOrNull;
    if (text == null) return null;
    return (
      text: text,
      kind:
          domTreeKindFor(contentType: view.contentType, fileName: view.fileName)
    );
  }

  /// The DOM tree of the Source tab's document. Built once per document and
  /// kind; big texts are parsed off the UI thread ([domTreePending] is true
  /// and this is null until done; listeners are notified).
  DomTree? get domTree {
    final view = sourceView;
    final text = view.textOrNull;
    if (text == null) return null;
    final kind =
        domTreeKindFor(contentType: view.contentType, fileName: view.fileName);
    for (final e in _domTreeCache) {
      if (identical(e.text, text) && e.kind == kind) return e.tree;
    }
    if (domTreeError != null) return null;
    if (text.length <= _domTreeIsolateThreshold) {
      domTreeBuilds++;
      final tree = deriveDomTree(text, kind);
      _rememberDomTree(text, kind, tree);
      return tree;
    }
    final b = _domTreeBuilding;
    if (b == null || !identical(b.text, text) || b.kind != kind) {
      _startDomTreeBuild(text, kind);
    }
    return null;
  }

  void _rememberDomTree(String text, DomTreeKind kind, DomTree tree) {
    _domTreeCache.insert(0, (text: text, kind: kind, tree: tree));
    if (_domTreeCache.length > 3) _domTreeCache.removeLast();
  }

  void _startDomTreeBuild(String text, DomTreeKind kind) {
    domTreeBuilds++;
    final mine = _domTreeBuilding = (text: text, kind: kind);
    final build = _domTreeBuilder ??
        (String t, DomTreeKind k) => compute(buildDomTreeRecord, (t, k));
    void finish(DomTree? tree, [String? error]) {
      if (_disposed) return;
      if (tree != null) _rememberDomTree(text, kind, tree);
      if (error != null) {
        _domTreeFailures.insert(0, (text: text, kind: kind, error: error));
        if (_domTreeFailures.length > 3) _domTreeFailures.removeLast();
      }
      if (identical(_domTreeBuilding, mine)) _domTreeBuilding = null;
      notifyListeners();
    }

    build(text, kind).then(finish, onError: (Object e) {
      debugPrint('DOM tree build failed: $e');
      finish(null, '$e');
    });
  }

  List<Divergence>? _divergences;
  PageInspection? _divergencesFor;

  /// Where the app's own request and the browser disagree (UI: Task 10).
  List<Divergence> get divergences {
    final current = store.current;
    if (_divergences == null || !identical(current, _divergencesFor)) {
      _divergencesFor = current;
      _divergences = deriveDivergences(current);
    }
    return _divergences!;
  }

  Observed<GeneralModel>? _general;
  PageInspection? _generalFor;

  /// The General probe tab: server response, content-type check, source
  /// diff, robots, storage, network and browser cards.
  Observed<GeneralModel> get generalView {
    final current = store.current;
    if (_general == null || !identical(current, _generalFor)) {
      _generalFor = current;
      _general = deriveGeneral(current, divergences: divergences);
    }
    return _general!;
  }

  Observed<HeadersModel>? _headers;
  PageInspection? _headersFor;

  /// The Headers tab: insights from the final response, headers per hop.
  Observed<HeadersModel> get headersView {
    final current = store.current;
    if (_headers == null || !identical(current, _headersFor)) {
      _headersFor = current;
      _headers = deriveHeaders(current);
    }
    return _headers!;
  }

  Observed<SecurityModel>? _security;
  PageInspection? _securityFor;

  /// The Security tab: header audit, CSP and certificate of the final
  /// response; no score while the response is unknown.
  Observed<SecurityModel> get securityView {
    final current = store.current;
    if (_security == null || !identical(current, _securityFor)) {
      _securityFor = current;
      _security = deriveSecurity(current);
    }
    return _security!;
  }

  Observed<CookiesModel>? _cookiesView;
  PageInspection? _cookiesViewFor;

  /// The Cookies tab: derived cookies with flags (unknown stays unknown)
  /// and the privacy lens.
  Observed<CookiesModel> get cookiesView {
    final current = store.current;
    if (_cookiesView == null || !identical(current, _cookiesViewFor)) {
      _cookiesViewFor = current;
      _cookiesView = deriveCookiesView(current);
    }
    return _cookiesView!;
  }

  Observed<TimelineModel>? _timelineModel;
  PageInspection? _timelineModelFor;

  /// The Request Timeline tab: the browser's requests (timing and size may
  /// be unknown per row), totals and the redirect chain of the server.
  Observed<TimelineModel> get timelineView {
    final current = store.current;
    if (_timelineModel == null || !identical(current, _timelineModelFor)) {
      _timelineModelFor = current;
      _timelineModel = deriveTimeline(current);
    }
    return _timelineModel!;
  }

  Observed<PageSizeModel>? _pageSize;
  PageInspection? _pageSizeFor;

  /// The Page size tab's data: totals, breakdown and per-file sizes from the
  /// browser's resources, or the state that says why there are none.
  Observed<PageSizeModel> get pageSize {
    final current = store.current;
    if (_pageSize == null || !identical(current, _pageSizeFor)) {
      _pageSizeFor = current;
      _pageSize = derivePageSize(current);
    }
    return _pageSize!;
  }

  bool get isProbing => store.current.server is Pending<ServerSnapshot>;

  /// The report of the current navigation; null while there is none.
  SovereigntyReport? get sovereigntyReport =>
      _sovereigntyGen == store.current.generation ? _sovereigntyReport : null;
  bool get isAnalyzingSovereignty => _isAnalyzingSovereignty;

  /// The Sovereignty tab's data: the report, still pending, failed (with the
  /// error), or why there is nothing to analyse.
  Observed<SovereigntyReport> get sovereigntyState {
    final current = store.current;
    switch (current.target) {
      case NoTarget():
        return const Unavailable(UnavailableReason.notApplicable,
            'Load a URL to analyze where it is hosted.');
      case FileTarget():
        return const Unavailable(UnavailableReason.notApplicable,
            'A local file has no host to analyze.');
      case UrlTarget():
        break;
    }
    final report = sovereigntyReport;
    if (report != null) {
      final cached = _sovereigntyPresent;
      if (cached is Present<SovereigntyReport> &&
          identical(cached.value, report)) {
        return cached;
      }
      return _sovereigntyPresent = Present(report,
          source: DataSource.server, provenance: Provenance.derived);
    }
    final error = _sovereigntyError;
    if (error != null && _sovereigntyGen == current.generation) {
      return Failed(error);
    }
    return const Pending();
  }

  /// The Sovereignty tab calls this when it appears (+1) and disappears
  /// (-1). While a tab watches, the service runs the analysis by itself once
  /// the page is loaded, and again for a new page or a new legal home.
  void watchSovereignty(bool watching) {
    _sovereigntyWatchers =
        (_sovereigntyWatchers + (watching ? 1 : -1)).clamp(0, 1 << 20);
    if (watching) _scheduleSovereignty();
  }

  /// The URL the analysis is about: where the browser is, else where the
  /// app's own request ended, else what was asked for. From the store only.
  Uri? get _sovereigntyUri {
    final current = store.current;
    final target = current.target;
    if (target is! UrlTarget) return null;
    final browser = current.browser;
    if (browser is Present<BrowserSnapshot>) return browser.value.url;
    final server = current.server;
    if (server is Present<ServerSnapshot>) {
      final fin = server.value.finalUrl;
      if (fin is Present<Uri>) return fin.value;
    }
    return target.url;
  }

  String get _sovereigntyHost => _sovereigntyUri?.host ?? '';

  bool get _sovereigntyReady {
    final uri = _sovereigntyUri;
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        store.current.server is! Pending<ServerSnapshot> &&
        !_isLoading &&
        !_isWebViewLoading &&
        !_isExtractingMetadata;
  }

  void _scheduleSovereignty() {
    if (_disposed ||
        _sovereigntyWatchers == 0 ||
        _sovereigntyScheduled ||
        _isAnalyzingSovereignty ||
        !_sovereigntyReady) {
      return;
    }
    final gen = store.current.generation;
    var inputsChanged = false;
    if (_sovereigntyGen == gen) {
      if (_sovereigntyError != null) return; // shown; "Re-run" tries again
      if (_sovereigntyReport != null &&
          _sovereigntyHome == siteJurisdiction.jurisdiction) {
        if (_sovereigntyInputKey == _currentSovereigntyInputKey) return;
        // The browser's data arrived (or grew) after the analysis started.
        inputsChanged = true;
      }
    }
    _sovereigntyScheduled = true;
    void run() {
      _sovereigntyScheduled = false;
      analyzeSovereignty().ignore();
    }

    if (inputsChanged) {
      // Resources keep arriving while a page loads: wait until they settle.
      _sovereigntyTimer?.cancel();
      _sovereigntyTimer = Timer(_sovereigntyDebounce, run);
    } else {
      scheduleMicrotask(run);
    }
  }

  /// What the analysis reads from the browser: whether it is Present, the
  /// URL it is on and how many resources it reported. A change after the
  /// analysis started makes the report stale.
  String get _currentSovereigntyInputKey {
    final browser = store.current.browser;
    final count = SovereigntyService.browserResources(store.current).length;
    return '${browser is Present<BrowserSnapshot>}|$_sovereigntyUri|$count';
  }

  /// Registrable domain the per-site jurisdiction choice is stored under.
  String get sovereigntyDomain =>
      SovereigntyService.registrableDomain(_sovereigntyHost);

  /// Subject of the final hop's certificate, from the store; null unless Present.
  Map? get _finalHopCertificateSubject {
    final server = SovereigntyService.serverOf(store.current);
    return switch (server?.certificate) {
      Present<Map<String, dynamic>>(:final value) =>
        value['subjectParsed'] as Map?,
      _ => null,
    };
  }

  /// Legal home of the current site: chosen manually, else detected,
  /// else the default from settings.
  SiteJurisdiction get siteJurisdiction {
    final manual = _appSettings?.siteJurisdiction(sovereigntyDomain);
    if (manual != null) {
      return (
        jurisdiction: manual,
        source: 'Set manually',
        derived: false,
        warning: null
      );
    }
    final detected = detectSiteJurisdiction(
      host: _sovereigntyHost,
      certificateSubject: _finalHopCertificateSubject,
      structuredData: _pageMetadata?['structuredData'] as List?,
    );
    return detected ??
        (
          jurisdiction:
              _appSettings?.homeJurisdiction ?? defaultHomeJurisdiction(),
          source: 'Not detected; default from Settings',
          derived: true,
          warning: null,
        );
  }

  void setSiteJurisdiction(String? jurisdiction) =>
      _appSettings?.setSiteJurisdiction(sovereigntyDomain, jurisdiction);

  /// Where is this page hosted, and by whom? Run by the service while the
  /// Sovereignty tab is showing (see [watchSovereignty]).
  Future<void> analyzeSovereignty() async {
    final uri = _sovereigntyUri;
    if (_isAnalyzingSovereignty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    _isAnalyzingSovereignty = true;
    _sovereigntyError = null;
    final gen = store.current.generation;
    final home = siteJurisdiction.jurisdiction;
    final inputKey = _currentSovereigntyInputKey;
    notifyListeners();
    try {
      final report = await _sovereigntyAnalyzer(
        pageUrl: uri.toString(),
        inspection: store.current,
        metadata: _pageMetadata,
        detections: detections,
        html: sourceView.textOrNull,
        home: home,
      );
      if (!_disposed && gen == store.current.generation) {
        _sovereigntyReport = report;
        _sovereigntyHome = home;
        _sovereigntyInputKey = inputKey;
        _sovereigntyGen = gen;
      }
    } catch (e) {
      debugPrint('Sovereignty analysis failed: $e');
      if (!_disposed && gen == store.current.generation) {
        _sovereigntyReport = null;
        _sovereigntyError = '$e'.replaceFirst('Exception: ', '');
        _sovereigntyGen = gen;
      }
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
        _responseHeaders?['content-type']?.toLowerCase() ?? '';
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
        _responseHeaders?['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('image/svg+xml')) return true;

    return selectedContentType == 'svg' ||
        (_currentFile?.name.toLowerCase().endsWith('.svg') ?? false);
  }

  bool get isXml {
    final contentType =
        _responseHeaders?['content-type']?.toLowerCase() ?? '';
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
        _responseHeaders?['content-type']?.toLowerCase() ?? '';
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

  /// The UI handled the tab request. Listeners are told (outside of build),
  /// so a stale request does not linger in their selected state.
  void consumeTabSwitchRequest() {
    if (_requestedTabIndex == null) return;
    _requestedTabIndex = null;
    notifyListeners();
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
    DetectionScanner? detectionScanner,
    int detectionIsolateThreshold = 256 * 1024,
    DomTreeBuilder? domTreeBuilder,
    int domTreeIsolateThreshold = 256 * 1024,
    SovereigntyAnalyzer? sovereigntyAnalyzer,
    Duration sovereigntyDebounce = const Duration(milliseconds: 500),
    BrowserCollect? browserCollect,
    NativeCookieReader? nativeCookies,
    ResourceSizeLookup? sizeLookup,
    BrowserPlatform? browserPlatform,
    List<Duration> browserRefreshDelays = const [
      Duration(seconds: 4),
      Duration(seconds: 14),
    ],
    Duration spaSettleDelay = const Duration(milliseconds: 400),
  })  : _sovereigntyDebounce = sovereigntyDebounce,
        _sovereigntyAnalyzer =
            sovereigntyAnalyzer ?? SovereigntyService.analyze,
        _detectionScanner = detectionScanner,
        _detectionIsolateThreshold = detectionIsolateThreshold,
        _domTreeBuilder = domTreeBuilder,
        _domTreeIsolateThreshold = domTreeIsolateThreshold,
        _browserCollectOverride = browserCollect,
        _nativeCookies = nativeCookies ?? _nativeCookiesFromManager,
        _sizeLookup = sizeLookup ?? _lookupResourceSize,
        _platform =
            browserPlatform ?? browserPlatformFor(defaultTargetPlatform),
        _refreshDelays = browserRefreshDelays,
        _spaSettleDelay = spaSettleDelay,
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
  /// What the browser measured lives in the store and goes with its
  /// generation; this clears the rest.
  void _clearBrowserDerivedData() {
    _cancelBrowserRefreshes();
    _lastPageWeight = null;
    _sovereigntyReport = null;
    _sovereigntyError = null;
    _sovereigntyGen = null;
    _lastRawPayload = null;
  }

  @visibleForTesting
  void seedBrowserDataForTest() {
    const known = Present<int>(1, source: DataSource.browser);
    const unknown = Unavailable<int>(UnavailableReason.notApplicable);
    const noTime = Unavailable<double>(UnavailableReason.notApplicable);
    const none = Unavailable<Never>(UnavailableReason.notApplicable);
    store.applyBrowser(
        store.current.generation,
        BrowserSnapshot(
          url: Uri.parse('https://seed.test/'),
          platform: BrowserPlatform.android,
          contentType: none,
          renderedDom: none,
          resources: Present([
            ResourceEntry(
                url: 'https://seed.test/a.js',
                type: 'script',
                source: ResourceSource.observer,
                startTime: noTime,
                duration: noTime,
                transfer: known,
                decoded: unknown)
          ], source: DataSource.browser),
          cookies: none,
          storage: none,
          navigation: none,
          snapshotTimeMs: none,
        ));
    _lastPageWeight = {'transfer': 1, 'decoded': 2};
  }

  /// Reset all loading and result state before a new URL load
  void _resetLoadState({String? newUrl, bool notify = true}) {
    _clearBrowserDerivedData();
    _resetMetadata();
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
    _cancelBrowserRefreshes();
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
      // The browser is on that page: it needs its own browser data.
      if (_browserReachable) syncWebViewState(noted.$2.toString()).ignore();
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
    // The browser's DOM is the document once it is there; the server body
    // only fills in until then.
    if (_browserHasDom) return;
    final built = await _fileFromServer(target.url, server);
    if (_disposed ||
        gen != store.current.generation ||
        _browserHasDom ||
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

  bool get _browserHasDom {
    final b = store.current.browser;
    return b is Present<BrowserSnapshot> &&
        b.value.renderedDom is Present<RenderedDom>;
  }

  /// Without browser numbers, the document's own wire and decoded size.
  void _applyPageWeight(Map<String, dynamic>? weight) {
    if (weight != null && _browserWeight == null) _lastPageWeight = weight;
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

  @visibleForTesting
  void debugNoteBrowserUrl(Uri uri) =>
      _browserUrlDuringFetch = (store.current.generation, uri);

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

  Future<void> reloadCurrentFile({int? switchToTab}) async {
    if (_currentFile == null) return;

    if (_currentFile!.isUrl) {
      return loadUrl(_currentFile!.path,
          forceReload: true, switchToTab: switchToTab);
    } else {
      // Local file reload: always from disk, never as https://<name> (B32).
      if (_currentFile!.path.isNotEmpty) {
        try {
          final snapshot = await FileLoader.fromPath(_currentFile!.path,
              origin: FileOrigin.restore, enforceSandbox: false);
          await loadFile(snapshot.toHtmlFile(),
              clearProbe: true, snapshot: snapshot, switchToTab: switchToTab);
        } catch (e) {
          debugPrint('Error reloading local file: $e');
        }
      }
    }
  }

  /// Pull-to-refresh: reloads what is open. A local file is re-read from
  /// disk; a URL is loaded again. A file without a path (picked or shared
  /// bytes) cannot be re-read and stays as it is.
  Future<void> refresh({int? switchToTab}) async {
    final file = _currentFile;
    if (file != null && !file.isUrl) {
      return reloadCurrentFile(switchToTab: switchToTab);
    }
    final url = _currentInputText;
    if (url != null && url.isNotEmpty) {
      await loadUrl(url, switchToTab: switchToTab);
    }
  }

  /// What the URL bar submits. A name that is the open local file, or a local
  /// file from the history, is read from disk; only the rest is a URL. A local
  /// name therefore never turns into `https://index.html`.
  Future<void> openInputText(String text, {int? switchToTab}) async {
    final input = text.trim();
    final file = _currentFile;
    if (file != null && !file.isUrl && input == file.name) {
      return reloadCurrentFile(switchToTab: switchToTab);
    }
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      for (final entry in _urlHistoryService?.history ?? const <String>[]) {
        if (entry.startsWith('http://') || entry.startsWith('https://')) {
          continue;
        }
        if (entry.replaceAll('\\', '/').split('/').last != input) continue;
        try {
          // The path comes from the app's own history: trusted.
          final snapshot = await FileLoader.fromPath(entry,
              origin: FileOrigin.restore, enforceSandbox: false);
          await loadFile(snapshot.toHtmlFile().copyWith(name: input),
              switchToTab: switchToTab, snapshot: snapshot);
          return;
        } on FileLoadException catch (e) {
          // Gone from disk: fall through to the URL attempt, as before.
          debugPrint('Error loading local file: ${e.message}');
        }
        break;
      }
    }
    await loadUrl(input, switchToTab: switchToTab, forceReload: true);
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
    if (_disposed) return;
    super.notifyListeners();
    _scheduleSovereignty();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelBrowserRefreshes();
    _sovereigntyTimer?.cancel();
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

    // Try to determine content type from the server's answer
    final contentType = _responseHeaders?['content-type'];
    if (contentType != null) {
      final detectedLanguage = getLanguageForMimeType(contentType);
      if (detectedLanguage != null) selectedContentType = detectedLanguage;
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
      final contentType = _responseHeaders?['content-type'];

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
      _cancelBrowserRefreshes();
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
    _resetMetadata();
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

    notifyListeners();
  }

  /// The document metadata runs on: the store's primary document (rendered
  /// DOM, else server body, else file), else the viewer's current file.
  PageDocumentInput _metadataInput(HtmlFile file) =>
      primaryDocumentInput(store.current) ??
      PageDocumentInput(file.content, file.isUrl ? file.path : '',
          file.isUrl ? DataSource.server : DataSource.file);

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
        final input = _metadataInput(file);
        final html = input.text;
        final baseUrl = input.baseUrl;
        final headers = _responseHeaders;

        Map<String, dynamic>? metadata;
        DerivedMetadata? derived;
        DocumentChecks? checks;
        String? error;
        try {
          derived = await deriveMetadata(html, baseUrl, input.source,
              headers: headers, extractor: _metadataExtractor);
          metadata = derived.data;
          checks = html.length > _detectionIsolateThreshold
              ? await compute(deriveDocumentChecks, html)
              : deriveDocumentChecks(html);
        } catch (e, stack) {
          debugPrint('Error extracting metadata in isolate: $e\n$stack');
          error = '$e';
          metadata = null;
        }
        if (_disposed) return;
        final now = _currentFile;
        if (gen != store.current.generation ||
            now == null ||
            _metadataInput(now).text != html) {
          // Stale: dropped. Rerun on what is current now.
          _metadataRerunQueued = now != null;
          continue;
        }

        _pageMetadata = metadata;
        _metadataError = error;
        _metadataChecks = checks;
        _metadataUnresolved = derived?.unresolvedLinks ?? const [];
        _metadataDocSource = input.source;
        _metadataRevision++;
        if (metadata != null) {
          final weight = _pageWeight;
          if (weight != null) metadata['pageWeight'] = weight;
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

  /// The size of a timeline entry for the metadata lists; null when the
  /// browser reported none. Images are judged by their transfer size: WebKit's
  /// decoded size for them is the pixel buffer, so it is not reported.
  static Map<String, dynamic>? _sizeOf(Map match) {
    final tx = match['transfer'] as int?;
    final dec = match['decoded'] as int?;
    if (tx == null && dec == null) {
      final why = match['transferNote'] ?? match['decodedNote'];
      return {
        'transfer': null,
        'decoded': null,
        if (why != null) 'unknownReason': '$why',
      };
    }
    if (dec == null) {
      final isImage = match['initiatorType'] == 'img' ||
          match['initiatorType'] == 'image' ||
          ProbeService.categorizeResource('${match['name']}', '') == 'image';
      if (isImage) {
        return {'transfer': tx, 'decoded': tx, 'decodedFromTransfer': true};
      }
    }
    return {'transfer': tx, 'decoded': dec};
  }

  /// Matches extracted metadata links with performance resource data to find sizes
  void _enrichMetadataWithSizes(String baseUrl) {
    if (_pageMetadata == null) return;

    // Helper to find size using a 4-tier lookup strategy
    final timeline = resourceTimelineData;
    Map<String, dynamic>? findSize(String? src) {
      if (src == null || src.isEmpty) return null;

      // Tier 0: Data URIs / inline SVGs — size is the content itself
      if (src.startsWith('data:') || src.startsWith('<svg')) {
        final bytes = utf8.encode(src).length;
        return {'transfer': bytes, 'decoded': bytes};
      }

      if (timeline.isEmpty) return null;

      // Tier 1: Exact string match
      var match = timeline.firstWhere(
        (r) => r['name'] == src,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        return _sizeOf(match);
      }

      // Tier 2: URL-normalised match (handles trailing slashes, case)
      try {
        match = timeline.firstWhere(
          (r) => areUrlsEqual(r['name'].toString(), src),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          return _sizeOf(match);
        }
      } catch (_) {}

      // Tier 3: Same host+path, query equal modulo cache-busters (CDN
      // versioning like ?v=2 still matches). Content-changing params such as
      // image resize options (?width=112 vs ?width=264 or none) must NOT
      // match: they serve different bytes (e.g. thumbnail vs full original).
      try {
        final srcPath = Uri.parse(src).path;
        if (srcPath.length > 3) {
          match = timeline.firstWhere(
            (r) => sameResourceModuloCacheBusters(src, r['name'].toString()),
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            return _sizeOf(match);
          }
        }
      } catch (_) {}

      // Tier 4: Strict filename suffix match, same query modulo cache-busters.
      // Requires the filename to be preceded by '/' so "chunk.js"
      // does NOT match "vendor-chunk.js"
      try {
        final srcFileName = Uri.parse(src).path.split('/').last;
        final srcQuery = queryWithoutCacheBusters(Uri.parse(src));
        if (srcFileName.length > 4) {
          match = timeline.firstWhere((r) {
            final rName = r['name'].toString();
            if (!(rName.endsWith('/$srcFileName') || rName == srcFileName)) {
              return false;
            }
            try {
              return queryWithoutCacheBusters(Uri.parse(rName)) == srcQuery;
            } catch (_) {
              return false;
            }
          }, orElse: () => {});
          if (match.isNotEmpty) {
            return _sizeOf(match);
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
        for (final r in timeline)
          if (isFontUrl(r['name'] as String? ?? ''))
            {
              'src': r['name'],
              'size': {'transfer': r['transfer'], 'decoded': r['decoded']},
            }
      ];
    }

    _sortMetadataLists();
    _metadataRevision++;
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

  /// Whether a metadata item still has no size at all.
  static bool _sizeUnknown(Map item) {
    final size = item['size'];
    return size is! Map ||
        (size['transfer'] == null && size['decoded'] == null);
  }

  // One own request per URL and navigation, however often the metadata is
  // rebuilt (new document, later refreshes).
  int? _sizeCacheGen;
  final Map<String, Future<int?>> _sizeCache = {};

  Future<int?> _cachedSizeLookup(int gen, String url) {
    if (_sizeCacheGen != gen) {
      _sizeCache.clear();
      _sizeCacheGen = gen;
    }
    return _sizeCache.putIfAbsent(url, () => _sizeLookup(url));
  }

  /// Own requests for the sizes the browser could not report (metadata items
  /// with an unknown size). Only after the browser answered for this
  /// navigation, so a gap really is a gap. Results are marked `estimated`
  /// (our request, may differ from the browser's), are dropped when the
  /// navigation or metadata has moved on, and never replace a known size.
  Future<void> _fetchMissingMetadataSizesAsync() async {
    final metadata = _pageMetadata;
    if (metadata == null) return;
    if (store.current.browser is! Present<BrowserSnapshot>) return;
    final gen = store.current.generation;
    bool stale() =>
        _disposed ||
        gen != store.current.generation ||
        !identical(_pageMetadata, metadata);

    final List<Map> itemsToFetch = [];

    void collect(List list, String key, {bool convertStrings = false}) {
      for (var i = 0; i < list.length; i++) {
        var item = list[i];
        if (item is String && convertStrings) {
          item = <String, dynamic>{key: item};
          list[i] = item;
        }
        if (item is! Map || !_sizeUnknown(item)) continue;
        final url = item[key];
        if (url is String && url.startsWith('http')) itemsToFetch.add(item);
      }
    }

    if (metadata['jsLinks'] is List) {
      collect(metadata['jsLinks'], 'src', convertStrings: true);
    }
    if (metadata['cssLinks'] is List) {
      collect(metadata['cssLinks'], 'href', convertStrings: true);
    }
    final media = metadata['media'];
    if (media is Map && media['images'] is List) {
      collect(media['images'], 'src');
    }

    if (itemsToFetch.isEmpty) return;

    const int batchSize = 5;
    for (var i = 0; i < itemsToFetch.length; i += batchSize) {
      if (stale()) return;
      final batch = itemsToFetch.skip(i).take(batchSize);
      var changed = false;
      await Future.wait(batch.map((item) async {
        final url = (item['src'] ?? item['href']) as String;
        int? size;
        try {
          size = await _cachedSizeLookup(gen, url);
        } catch (e) {
          debugPrint('Size lookup failed for $url: $e');
        }
        if (size == null || stale() || !_sizeUnknown(item)) return;
        // Content-Length is the wire size; the decoded size stays unknown.
        item['size'] = {'transfer': size, 'decoded': null, 'estimated': true};
        changed = true;
      }));
      if (changed && !stale()) {
        _sortMetadataLists();
        _metadataRevision++;
        notifyListeners();
      }
    }
  }

  /// A fresh collect for [gen], merged into the store by the store itself.
  /// Everything that comes back after the navigation moved on is dropped.
  Future<void> _collectAndApply(int gen, String url, Uri uri) async {
    bool stale() => _disposed || gen != store.current.generation;

    Object? raw;
    try {
      raw = await _collect(url);
    } catch (e) {
      if (!stale()) {
        store.applyBrowserFailure(gen, Failed('Browser collection failed: $e'));
      }
      return;
    }

    // The native cookie manager also sees HttpOnly cookies and their flags.
    List<BrowserCookie>? nativeCookies;
    try {
      nativeCookies = parseNativeCookies(await _nativeCookies(url), _platform);
    } catch (e) {
      debugPrint('Native cookies unavailable: $e');
    }
    if (stale()) return;

    _lastRawPayload = (gen: gen, raw: raw is String ? raw : '$raw');
    BrowserSnapshot snapshot;
    try {
      snapshot = parseBrowserPayload(raw, _platform, pageUrl: uri);
    } catch (e) {
      store.applyBrowserFailure(gen, Failed('Payload could not be read: $e'));
      return;
    }
    if (nativeCookies != null &&
        (nativeCookies.isNotEmpty || snapshot.cookies is! Present)) {
      snapshot = snapshot
          .withCookies(Present(nativeCookies, source: DataSource.browser));
    }
    if (!snapshot.hasPresentSection) {
      store.applyBrowserFailure(
          gen,
          switch (snapshot.renderedDom) {
            Failed<RenderedDom>(error: final e) => Failed(e),
            Unavailable<RenderedDom>(reason: final r, detail: final d) =>
              Unavailable(r, d),
            _ => const Failed('The browser returned no data'),
          });
      return;
    }
    store.applyBrowser(gen, snapshot);
  }

  Future<Object?> _collectViaController(String url) {
    final controller = activeWebViewController;
    if (controller == null) throw StateError('no browser view');
    return controller.evaluateJavascript(source: 'window.__vsv_collect()');
  }

  static Future<List<Map>> _nativeCookiesFromManager(String url) async {
    final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
    return [for (final c in cookies) c.toMap()];
  }

  /// Ranged GET (then HEAD) for a resource's size. A size is only reported
  /// when the server states one; 0 and failures are "unknown" (null).
  static Future<int?> _lookupResourceSize(String url) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(url);
      final headers = {'User-Agent': kServerUserAgent};

      // A ranged GET runs the same pipeline as the browser's GET, so query
      // transforms on image CDNs are applied; HEAD can report the origin
      // object's size instead.
      try {
        final request = http.Request('GET', uri);
        request.headers.addAll(headers);
        request.headers['Range'] = 'bytes=0-0';
        final response =
            await client.send(request).timeout(const Duration(seconds: 5));
        final contentLength = response.headers['content-length'];
        final contentRange = response.headers['content-range'];
        response.stream.listen((_) {}).cancel();
        if (response.statusCode >= 200 && response.statusCode < 400) {
          final parts = contentRange?.split('/');
          if (parts != null && parts.length == 2) {
            final size = int.tryParse(parts[1]);
            if (size != null && size > 0) return size;
          }
          final size = int.tryParse(contentLength ?? '');
          if (size != null && size > 0) return size;
        }
      } catch (_) {
        // Fall back to HEAD.
      }

      try {
        final head = await client
            .head(uri, headers: headers)
            .timeout(const Duration(seconds: 5));
        if (head.statusCode >= 200 && head.statusCode < 400) {
          final size = int.tryParse(head.headers['content-length'] ?? '');
          if (size != null && size > 0) return size;
        }
      } catch (_) {
        // unknown
      }
    } catch (e) {
      debugPrint('Error getting resource size for $url: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// The browser reported a URL change (history API / SPA route, redirect).
  /// The same document as the current navigation (R20) is nothing new; any
  /// other URL is a navigation of its own: a new generation with its own
  /// server fetch, then a sync of what the browser shows.
  Future<void> handleBrowserUrlChange(String url) async {
    if (_disposed || !_browserReachable) return;
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    if (store.current.target is! UrlTarget) return;
    // History updates at the start of an ordinary full load are not SPA
    // routes; onLoadStop syncs those.
    if (_isWebViewLoading) return;
    if (_storeCovers(uri)) {
      _noteBrowserUrl(uri);
      return;
    }
    _clearBrowserDerivedData();
    final gen = _startInspection(uri, adoptBody: false);
    // Let the SPA render the new route before its DOM is read.
    await Future<void>.delayed(_spaSettleDelay);
    if (_disposed || gen != store.current.generation) return;
    await syncWebViewState(url);
  }

  /// Reads the page from the WebView (one collector call) and puts it in the
  /// store. A page the current navigation does not cover starts a new
  /// generation first; anything that comes back after the navigation moved on
  /// is dropped. Does nothing for a local file.
  Future<void> syncWebViewState(String url, {bool isPartial = false}) async {
    if (_disposed || !_browserReachable) return;
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    // A local file shown through the WebView stays a file (scan bug 16), and
    // with nothing loaded there is nothing to attach a page to.
    if (store.current.target is! UrlTarget) return;

    if (_currentInputText != url) _currentInputText = url;

    // Server side of the page the browser is on (headers, redirects, robots).
    // A page the current navigation covers is not fetched again; any other
    // starts a new generation, synchronously, before the gen is read below.
    probeUrl(url).ignore();
    final gen = store.current.generation;
    bool stale() => _disposed || gen != store.current.generation;

    if (!isPartial) _cancelBrowserRefreshes();
    await _collectAndApply(gen, url, uri);
    if (stale()) return;

    try {
      final browser = store.current.browser;
      if (browser is Present<BrowserSnapshot>) {
        String filename = 'Page';
        final dom = browser.value.renderedDom;
        try {
          filename = generateDescriptiveFilename(
              uri, dom is Present<RenderedDom> ? dom.value.text : '');
        } catch (_) {}
        final file = legacyDomFile(browser.value, name: filename);
        if (file != null) {
          await loadFile(file, clearProbe: false, isPartial: isPartial);
          if (stale()) return;
        } else {
          // No DOM from the browser: whatever the server gave stays.
          await _adoptServerBodyIfEmpty(gen);
          if (stale()) return;
          _applyBrowserDerivedToMetadata();
        }
        if (!isPartial) _scheduleBrowserRefreshes(gen, url, uri);
      }
    } catch (e) {
      debugPrint('Error syncing WebView state: $e');
    } finally {
      if (!stale()) {
        if (!isPartial) _isLoading = false;
        _isWebViewLoading = false;
        _webViewLoadingUrl = null;
        notifyListeners();
      }
    }
  }

  /// Later passes catch resources that load after onLoadStop (lazy images,
  /// analytics, slow hydration). Each is another collect; the store merges it
  /// into what it has.
  void _scheduleBrowserRefreshes(int gen, String url, Uri uri) {
    _cancelBrowserRefreshes();
    for (final delay in _refreshDelays) {
      _refreshTimers.add(Timer(delay, () async {
        if (_disposed || gen != store.current.generation) return;
        if (!_browserReachable) return;
        await _collectAndApply(gen, url, uri);
        if (_disposed || gen != store.current.generation) return;
        _applyBrowserDerivedToMetadata();
      }));
    }
  }

  void _cancelBrowserRefreshes() {
    for (final t in _refreshTimers) {
      t.cancel();
    }
    _refreshTimers.clear();
  }

  /// New browser numbers: update the weight in the metadata and re-match the
  /// sizes of its links.
  void _applyBrowserDerivedToMetadata() {
    final metadata = _pageMetadata;
    if (metadata != null) {
      final weight = _pageWeight;
      if (weight != null) metadata['pageWeight'] = weight;
      _enrichMetadataWithSizes(
          _currentFile?.isUrl == true ? _currentFile!.path : '');
      _fetchMissingMetadataSizesAsync().ignore();
    }
    notifyListeners();
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

    // Browser cookies are gone; the server's own data stays valid. Read the
    // browser again so its cookies in the store are the empty ones.
    _pageMetadata = null;
    final target = store.current.target;
    if (target is UrlTarget && _browserReachable) {
      await _collectAndApply(store.current.generation,
          _currentFile?.path ?? target.url.toString(), target.url);
    }

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
