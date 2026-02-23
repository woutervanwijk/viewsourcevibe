import 'package:flutter/material.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/utils/code_beautifier.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/vs.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github-dark-dimmed.dart';
import 'package:re_highlight/styles/androidstudio.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/styles/vs2015.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';
import 'package:re_highlight/styles/monokai.dart';
import 'package:re_highlight/styles/nord.dart';
import 'package:re_highlight/styles/tokyo-night-dark.dart';
import 'package:re_highlight/styles/tokyo-night-light.dart';
import 'package:re_highlight/styles/dark.dart';
import 'package:re_highlight/styles/lightfair.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:view_source_vibe/utils/cookie_utils.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:view_source_vibe/widgets/contextmenu.dart';
import 'package:view_source_vibe/services/file_type_detector.dart';
import 'package:view_source_vibe/services/app_state_service.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/url_history_service.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    hide X509Certificate;
import 'package:xml/xml.dart' as xml;
import 'package:shared_preferences/shared_preferences.dart';

class HtmlService with ChangeNotifier {
  HtmlFile? _currentFile;
  int? _requestedTabIndex;
  int? get requestedTabIndex => _requestedTabIndex;
  HtmlFile? _originalFile; // Store original file for "Automatic" option
  String? _pendingUrl;
  String? _currentInputText;
  bool _isLoading = false;
  String?
      selectedContentType; // Track the selected content type for syntax highlighting
  ScrollController? _verticalScrollController;
  ScrollController? _activeHorizontalScrollController;
  GlobalKey? _codeEditorKey;
  AppStateService? _appStateService;
  AppSettings? _appSettings;
  UrlHistoryService? _urlHistoryService;

  // Navigation stack for "Back" functionality
  final List<HtmlFile> _navigationStack = [];
  bool _isNavigatingBack = false;

  // Probe state
  Map<String, dynamic>? _probeResult;
  bool _isProbing = false;
  String? _probeError;
  String? _currentlyProbingUrl;
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

  InAppWebViewController? activeWebViewController;

  Timer? _autoSaveTimer;
  final List<CodeLineEditingController> _disposalQueue = [];
  Timer? _disposalTimer;

  // Track the currently active find controller
  CodeFindController? _activeFindController;

  // Index of the currently active tab in HomeScreen
  int _activeTabIndex = 0;
  int get activeTabIndex => _activeTabIndex;

  // Dynamic Tab Indices based on settings
  // Dynamic Tab Indices based on settings
  bool get _useBrowserByDefault => _appSettings?.useBrowserByDefault ?? true;
  int get browserTabIndex => _useBrowserByDefault ? 0 : 1;
  int get sourceTabIndex => _useBrowserByDefault ? 1 : 0;

  // Debouncing for syntax highlighting
  Timer? _highlightDebounceTimer;

  HtmlFile? get currentFile => _currentFile;
  ScrollController? get scrollController => _verticalScrollController;
  ScrollController? get horizontalScrollController =>
      _activeHorizontalScrollController;
  GlobalKey? get codeEditorKey => _codeEditorKey;

  // Expose probe state
  Map<String, dynamic>? get probeResult => _probeResult;
  Map<String, dynamic>? get browserProbeResult =>
      _browserProbeResult; // Expose browser probe result
  bool get isProbing => _isProbing;
  bool get canGoBack => _navigationStack.isNotEmpty;
  String? get probeError => _probeError;
  bool get isLoading => _isLoading;
  String? get pendingUrl => _pendingUrl;
  String? get currentInputText => _currentInputText;

  set currentInputText(String? value) {
    if (_currentInputText != value) {
      _currentInputText = value;
      notifyListeners();
    }
  }

  // Expose search state
  CodeFindController? get activeFindController => _activeFindController;
  bool get isSearchActive => _activeFindController?.value != null;

  bool get isHtml {
    final contentType =
        _probeResult?['headers']?['content-type']?.toString().toLowerCase() ??
            '';
    if (contentType.contains('text/html') ||
        contentType.contains('application/xhtml+xml')) {
      return true;
    }

    // Secondary check: selected content type or current file extension
    final bool looksLikeHtml = selectedContentType == 'html' ||
        (_currentFile?.name.toLowerCase().endsWith('.html') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.htm') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.xhtml') ?? false);

    if (looksLikeHtml) return true;

    // Tertiary check: If we are midway through loading a URL and probe/file are not ready,
    // guess from the input text (URL) to keep UI stable.
    final String url = (_currentInputText ?? '').toLowerCase();
    return url.contains('.html') ||
        url.contains('.htm') ||
        url.contains('.xhtml') ||
        (url.startsWith('http') &&
            // Exclude known non-HTML extensions to be safe, but default to true for generic URLs (like domains)
            !url.endsWith('.rss') &&
            !url.endsWith('.xml') &&
            !url.endsWith('.json') &&
            !url.endsWith('.pdf') &&
            !url.endsWith('.zip') &&
            !url.endsWith('.png') &&
            !url.endsWith('.jpg') &&
            !url.endsWith('.jpeg') &&
            !url.endsWith('.gif') &&
            !url.endsWith('.svg'));
  }

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
        (_currentFile?.name.toLowerCase().endsWith('.rss') ?? false) ||
        (_currentFile?.name.toLowerCase().endsWith('.atom') ?? false);

    if (looksLikeXml) return true;

    // Tertiary check: URL guessing for transition stability
    final String url = (_currentInputText ?? '').toLowerCase();
    return url.endsWith('.xml') ||
        url.endsWith('.rss') ||
        url.endsWith('.atom') ||
        url.contains('.xml?') ||
        url.contains('.rss?') ||
        url.contains('.atom?');
  }

  /// internal helper to identify pure XML vs HTML/SVG
  bool get _isStrictXml => isXml && !isHtml && !isSvg;

  /// Metadata/Services/Media extraction is only useful for full web pages
  bool get showMetadataTabs => isHtml;

  /// DOM Tree and Probe tabs are useful for any structured markup
  bool get isHtmlOrXml => isHtml || isXml;

  /// Server-dependent tabs (Probe, Headers, Security, Cookies) only for URLs
  bool get showServerTabs {
    if (_currentFile?.isUrl ?? false) return true;
    // Show during loading of a URL
    if (_isLoading &&
        _currentInputText != null &&
        (_currentInputText!.startsWith('http') ||
            _currentInputText!.contains('://'))) {
      return true;
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

      // If switching to Source tab in Browser-First mode, load the source if missing
      if (index == sourceTabIndex &&
          _useBrowserByDefault &&
          (_currentFile?.content.isEmpty ?? true) &&
          (_currentFile?.isUrl ?? false)) {
        debugPrint('Lazy loading source for: ${_currentFile!.path}');
        _loadSourceOnly(_currentFile!.path);
      }
    }
  }

  /// Lazy load source code without resetting the whole flow
  Future<void> _loadSourceOnly(String url) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final file = await _loadFromUrlInternal(url);

      // Only update if we are still on the same URL
      if (_currentFile?.path == url) {
        await loadFile(file);
      }
    } catch (e) {
      debugPrint('Error lazy loading source: $e');
      _probeError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Trigger a browser reload if the URL has changed and the browser tab is visible
  Future<void> triggerBrowserReload() async {
    if (activeWebViewController != null &&
        _currentFile != null &&
        _currentFile!.isUrl) {
      final currentBrowserUrl = await activeWebViewController!.getUrl();
      if (currentBrowserUrl.toString() != _currentFile!.path) {
        debugPrint('Triggering browser reload for: ${_currentFile!.path}');
        _webViewLoadingUrl = _currentFile!.path; // Set to avoid interception
        await activeWebViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(_currentFile!.path)),
        );
      }
    }
  }

  void updateWebViewLoadingProgress(double progress) {
    if (_webViewLoadingProgress != progress) {
      _webViewLoadingProgress = progress;
      notifyListeners();
    }
  }

  HtmlService() {
    _codeEditorKey = GlobalKey();
    _currentInputText = '';
  }

  /// Reset all loading and result state before a new URL load
  void _resetLoadState({String? newUrl, bool notify = true}) {
    _probeResult = null;
    _browserProbeResult = null;
    _probeError = null;
    _pageMetadata = null;
    _lastPageWeight = null;
    _resourcePerformanceData = null;
    _webViewLoadingProgress = 0.0;
    _isProbing = false;
    _currentlyProbingUrl = null;
    _lastBrowserCookies = '';
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

    // Sanitize
    // Auto-prepend https if no scheme is provided, excluding special schemes like about:
    // We trim the URL first to avoid issues with leading/trailing spaces
    url = url.trim();
    if (!url.contains('://') && !url.startsWith('about:')) {
      url = 'https://$url';
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

    // 4. Trigger background probe ALWAYS
    probeUrl(url, forceReload: forceReload).ignore();

    // 5. Primary Load Path branching
    // Browser-First Mode: If enabled, force WebView (Browser) loading logic
    bool shouldUseBrowserLogic = forceWebView || _useBrowserByDefault;

    if (shouldUseBrowserLogic) {
      // Browser-First Flow:
      // - Browser loads immediately
      // - Source tab is DELAYED (stays null/loading)
      _webViewLoadingUrl = url;
      _isWebViewLoading = true;

      // If Browser isn't selected, request switch (unless already switching somewhere else)
      if (_activeTabIndex != browserTabIndex && switchToTab == null) {
        _requestedTabIndex = browserTabIndex;
      }

      // Add to history immediately for Browser-First Flow
      // This ensures history is updated even when HTML isn't fetched yet
      // We use a temporary HtmlFile to check if it should be added
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

        // Create a placeholder HtmlFile for the current URL in Browser-First Flow
        // This ensures _currentFile is set even when HTML isn't fetched yet
        _currentFile = tempFile;
      }

      notifyListeners();

      // Actually trigger the load in the browser
      if (activeWebViewController != null && !skipWebViewLoad) {
        activeWebViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(url)),
        );
      }

      // We don't fetch HTML here. Source will be lazy loaded when tab is clicked.
    } else {
      // Source-First Flow:
      // - HTML is fetched immediately
      // - Browser tab stays at about:blank (DELAYED)

      // Notify we started loading
      notifyListeners();

      try {
        final file = await _loadFromUrlInternal(url);
        _pendingUrl = null;
        await loadFile(file);
      } catch (e) {
        _pendingUrl = null;
        _isLoading = false;
        notifyListeners();
        rethrow;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> reloadCurrentFile() async {
    if (_currentFile == null) return;

    if (_currentFile!.isUrl) {
      return loadUrl(_currentFile!.path, forceReload: true);
    } else {
      // Local file reload
      if (_currentFile!.path.isNotEmpty) {
        try {
          final file = File(_currentFile!.path);
          if (await file.exists()) {
            final content = await file.readAsString();
            final newFile = _currentFile!.copyWith(
              content: content,
              lastModified: await file.lastModified(),
              size: await file.length(),
            );
            await loadFile(newFile, clearProbe: true);
          }
        } catch (e) {
          debugPrint('Error reloading local file: $e');
        }
      }
    }
  }

  void triggerWebViewLoad(String url) {
    loadUrl(url, switchToTab: 1, forceWebView: true);
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

  Future<void> completeWebViewLoad(String html, String url) async {
    _isWebViewLoading = false;
    _webViewLoadingUrl = null;

    // Construct a basic probe result for the WebView load
    final probeResult = {
      'statusCode': 200,
      'reasonPhrase': 'OK (via Browser)',
      'headers': <String, String>{'content-type': 'text/html'},
      'finalUrl': url,
      'isRedirect': false,
    };

    final filename = generateDescriptiveFilename(Uri.parse(url), html);
    final processedFilename = await detectFileTypeAndGenerateFilename(
      filename,
      html,
      contentType: 'text/html',
    );

    final file = HtmlFile(
      name: processedFilename,
      path: url,
      content: html,
      lastModified: DateTime.now(),
      size: html.length,
      isUrl: true,
      probeResult: probeResult,
    );

    // Note: _probeResult will be updated by loadFile(file)
    _isProbing = false;

    await loadFile(file);
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _disposalTimer?.cancel();
    // Final immediate disposal
    for (final controller in _disposalQueue) {
      controller.dispose();
    }
    _disposalQueue.clear();

    _verticalScrollController?.dispose();
    _activeHorizontalScrollController = null;

    // Dispose all cached re_editor controllers
    for (final controller in _cachedControllers.values) {
      controller.dispose();
    }
    _cachedControllers.clear();

    // Dispose all cached horizontal controllers
    for (final controller in _cachedHorizontalControllers.values) {
      controller.dispose();
    }
    _cachedHorizontalControllers.clear();

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

  /// Restore probe state
  void restoreProbeState(bool? isVisible, String? resultJson) {
    if (isVisible != null) {}
    if (resultJson != null && resultJson.isNotEmpty) {
      try {
        _probeResult = jsonDecode(resultJson);
      } catch (e) {
        debugPrint('❌ Error restoring probe result: $e');
      }
    }
    notifyListeners();
  }

  Future<void> saveCurrentState(AppStateService appStateService) async {
    try {
      await appStateService.saveAppState(
        currentFile: _currentFile,
        scrollPosition: getCurrentScrollPosition(),
        horizontalScrollPosition: getCurrentHorizontalScrollPosition(),
        contentType: selectedContentType,
        isProbeVisible:
            _probeResult != null, // Assuming probe is visible if result exists
        probeResultJson: _probeResult != null ? jsonEncode(_probeResult) : null,
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

  /// Get the final URL after following all redirects manually
  /// This ensures we get the actual redirected URL, not the original
  Future<String> _getFinalUrlAfterRedirects(
    Uri uri,
    http.Client client,
    Map<String, String> headers, {
    Uri? originalUri,
    int redirectDepth = 0,
  }) async {
    try {
      // Prevent infinite redirect loops
      if (redirectDepth > 5) {
        debugPrint('Too many redirects (>5), falling back to original URL');
        return originalUri?.toString() ?? uri.toString();
      }

      // Use HttpClient to manually handle redirects and capture certificate
      final hClient = HttpClient();
      hClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      final hRequest = await hClient.openUrl('GET', uri);
      hRequest.followRedirects = false;

      // Add headers to the request
      headers.forEach((key, value) {
        hRequest.headers.set(key, value);
      });

      final hResponse = await hRequest.close().timeout(
            const Duration(seconds: 30),
          );

      // Capture certificate info if available
      if (hResponse.certificate != null) {
        // We can use this to store the cert, but for now it's in probeResult
      }

      // Check if this is a redirect response
      if (hResponse.statusCode >= 300 &&
          hResponse.statusCode < 400 &&
          hResponse.headers.value('location') != null) {
        final locationHeader = hResponse.headers.value('location')!;
        // Handle relative redirects by resolving against the original URI
        final redirectUri = uri.resolve(locationHeader);

        // Recursively follow the redirect to get the final URL
        // Security: Ensure we don't get redirected to non-http/https schemes (like file://)
        if (redirectUri.scheme == 'http' || redirectUri.scheme == 'https') {
          return await _getFinalUrlAfterRedirects(
            redirectUri,
            http.Client(),
            headers,
            originalUri: originalUri ?? uri, // Preserve the original URI
            redirectDepth: redirectDepth + 1,
          );
        } else {
          debugPrint(
            'Blocked redirect to unsafe scheme: ${redirectUri.scheme}',
          );
          return originalUri?.toString() ?? uri.toString();
        }
      }

      // If not a redirect, return the current URL
      return uri.toString();
    } catch (e) {
      // If redirect handling fails, fall back to the original URL if available
      debugPrint('Error handling redirects: $e');

      // If this is a DNS lookup failure or connection error, fall back to original URL
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        debugPrint(
          'DNS/Connection error detected, falling back to original URL',
        );
        return originalUri?.toString() ?? uri.toString();
      }

      // For other errors, return the original URL if available, otherwise current URI
      return originalUri?.toString() ?? uri.toString();
    }
  }

  /// Ensure filename has proper extension based on content
  String ensureHtmlExtension(String filename, String content) {
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

    // Try to detect content type from content using strict FileTypeDetector logic
    // We avoid duplicating the logic here to ensure consistency

    // Only perform content detection if we don't have a file extension
    // or if we want to double-check specific formats
    if (content.isNotEmpty) {
      // Use the strict detector we just updated
      // We can't easily call likely async FileTypeDetector here without async,
      // but we can use a synchronous helper if we had one, or just replicate the *strict* checks.
      // Since we are in a sync function (or async?), let's check.
      // This function is async: Future<String> detectFileTypeAndGenerateFilename

      // Replicate ONLY the strict checks for filename extension generation
      final lowerContent = content.toLowerCase().trim();

      // HTML (Strict)
      if (lowerContent.startsWith('<!doctype html') ||
          lowerContent.contains('<html')) {
        return '$filename.html';
      }

      // XML/RSS (Strict)
      if (lowerContent.startsWith('<?xml') ||
          lowerContent.startsWith('<rss') ||
          lowerContent.startsWith('<feed')) {
        return '$filename.xml';
      }

      // JSON (Strict)
      if ((lowerContent.startsWith('{') && lowerContent.endsWith('}')) ||
          (lowerContent.startsWith('[') && lowerContent.endsWith(']'))) {
        // Quick check for JSON-like chars
        if (lowerContent.contains('"') && lowerContent.contains(':')) {
          return '$filename.json';
        }
      }

      // YAML (Strict)
      if (lowerContent.startsWith('---\n')) {
        return '$filename.yaml';
      }
    }

    // Default to .txt if no strict match found
    return '$filename.txt';
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
  }) async {
    _isBeautifyEnabled = false; // Reset beautify mode on new file

    // Save current file to navigation stack if we are not going back
    // AND if we are actually navigating to a NEW file (url/path check)
    if (_currentFile != null && !areUrlsEqual(_currentFile!.path, file.path)) {
      _pushToNavigationStack();
    }

    final String? previousLoadingUrl = _webViewLoadingUrl;
    await clearFile(clearProbe: clearProbe);

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

    // Restore probe result if available
    if (file.probeResult != null) {
      _probeResult = file.probeResult;
    }

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
      // For local files, only add the name to history for a cleaner display
      _urlHistoryService?.addUrl(file.isUrl ? file.path : file.name);
    }

    // Set requested tab switch if provided
    if (switchToTab != null) {
      _requestedTabIndex = switchToTab;
    }

    // Switch back to editor if this is a local file
    if (!file.isUrl && switchToTab == null) {
      _requestedTabIndex = sourceTabIndex;
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

    // For local files, show the name in the URL bar instead of the full path
    _currentInputText = file.isUrl ? file.path : file.name;
    // Don't notify here - we'll notify once at the end after metadata extraction
    _autoSave();
    await scrollToZero();

    // Extract metadata if it's HTML or XML
    if (_currentFile != null &&
        (selectedContentType == 'html' ||
            selectedContentType == 'xml' ||
            _currentFile!.name.endsWith('.html') ||
            _currentFile!.name.endsWith('.xml') ||
            _currentFile!.name.endsWith('.xhtml'))) {
      // Metadata extraction will call notifyListeners when done
      _extractMetadata(isPartial: isPartial);
    } else {
      // If content type changed to something without metadata, clear it
      // But don't clear it just because we are loading - wait for detection
      if (_pageMetadata != null &&
          !(selectedContentType == 'html' || selectedContentType == 'xml')) {
        _pageMetadata = null;
      }
      // Notify once at the end if we're not extracting metadata
      notifyListeners();
    }

    // Note: State saving is handled by the AppLifecycleObserver
    // We don't save state here to avoid excessive writes during normal usage
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
      await _prepareForEditorReset();

      _isBeautifyEnabled = !_isBeautifyEnabled;
      notifyListeners();
    } finally {
      // Allow toggling again after a short cooling period
      await Future.delayed(const Duration(milliseconds: 200));
      _isBeautifyToggling = false;
    }
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

  Future<void> scrollToZero() async {
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

  Future<void> clearFile({bool clearProbe = true}) async {
    await _prepareForEditorReset();
    await scrollToZero();
    _currentFile = null;
    _webViewLoadingUrl =
        null; // Clear any pending webview load url to prevent it from overriding local file
    _isWebViewLoading = false; // Reset webview loading state
    _originalFile = null; // Also clear the original file
    selectedContentType = null; // Reset content type selection
    if (clearProbe) {
      _probeResult = null; // Clear probe results
      _probeError = null; // Clear probe errors
    }
    // Always clear page metadata when loading a new file, even if preserving probe
    // This ensures metadata tabs are cleaned when navigating back
    _pageMetadata = null;
    // clearHighlightCache() is now called within _prepareForEditorReset()
    _beautifiedCache.clear(); // Clear beautify cache
    notifyListeners();
    _autoSave();
  }

  /// Get a list of available content types for syntax highlighting
  List<String> getAvailableContentTypes() {
    // Get all available language keys from re_highlight
    final availableLanguages = builtinAllLanguages.keys.toList();

    // Filter and sort the list to show most common types first
    // HTML/XML moved to top after Automatic for better UX
    final commonTypes = [
      'html',
      'xml',
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
      'plaintext',
    ];

    // Add common types first, then add remaining types
    final result = <String>[];

    // Add "Automatic" as the first option
    result.add('automatic');

    // Add HTML/XML first (right after Automatic) if they exist
    for (final type in ['html', 'xml']) {
      if (availableLanguages.contains(type) && !result.contains(type)) {
        result.add(type);
      }
    }

    // Add other common types that exist in re_highlight
    for (final type in commonTypes) {
      if (type != 'html' &&
          type != 'xml' &&
          availableLanguages.contains(type) &&
          !result.contains(type)) {
        result.add(type);
      }
    }

    // Add remaining types (excluding duplicates)
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
      // Use the unified loadUrl entry point.
      // switchToTab 0 ensures we go to the Source tab (or Browser depending on logic)
      await loadUrl(previousFile.path, switchToTab: 0);
    } finally {
      _isNavigatingBack = false;
    }
  }

  Future<HtmlFile> _loadFromUrlInternal(String url) async {
    Map<String, dynamic>? currentProbeResult;

    try {
      // Validate and sanitize URL
      // Auto-prepend https if no scheme is provided, excluding special schemes like about:
      if (!url.contains('://') &&
          !url.startsWith('about:') &&
          !url.startsWith('data:')) {
        url = 'https://$url';
      }

      // Parse and validate the URL
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw Exception('Invalid URL format');
      }

      // Security: Only allow http and https schemes
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw Exception('Only http and https URLs are supported');
      }

      // Use the http package with timeout and security settings
      final client = _createClient();
      final stopwatch = Stopwatch()..start();
      String? ipAddress;

      // Resolve IP (part of probing)
      try {
        final addresses = await InternetAddress.lookup(
          uri.host,
        ).timeout(const Duration(seconds: 2));
        if (addresses.isNotEmpty) {
          ipAddress = addresses.first.address;
        }
      } catch (e) {
        debugPrint('DNS Lookup failed: $e');
      }

      // Set proper headers
      final headers = {
        'User-Agent': 'curl/7.88.1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      };

      // Manual redirect handling
      final finalUrl = await _getFinalUrlAfterRedirects(
        uri,
        client,
        headers,
        originalUri: uri,
      );

      // Update the input text immediately
      if (finalUrl != url) {
        debugPrint('update text html $finalUrl');
        _currentInputText = finalUrl;
        notifyListeners();
      }

      // Use HttpClient for the final request
      final hClient = HttpClient();
      final hRequest = await hClient.openUrl('GET', Uri.parse(finalUrl));

      headers.forEach((key, value) {
        hRequest.headers.set(key, value);
      });

      final hResponse = await hRequest.close().timeout(
            const Duration(seconds: 30),
          );

      // Capture certificate info — must be read before body drain destroys the socket
      Map<String, dynamic>? certInfo;
      try {
        if (hResponse.certificate != null) {
          certInfo = _extractCertificateInfo(hResponse.certificate!);
        }
      } catch (e) {
        debugPrint(
          'Could not read SSL certificate (socket already closed): $e',
        );
      }

      // Read body
      final bytes = await hResponse.fold<List<int>>([], (p, e) => p..addAll(e));
      final content = utf8.decode(bytes, allowMalformed: true);

      stopwatch.stop();

      // Convert HttpClient headers
      final respHeaders = <String, String>{};
      hResponse.headers.forEach((name, values) {
        respHeaders[name.toLowerCase()] = values.join(', ');
      });

      // Construct Probe Result
      final setCookie = respHeaders['set-cookie'];
      final List<String> cookies =
          setCookie != null ? setCookie.split(RegExp(r',(?=[^;]+?=)')) : [];

      final securityHeaders = {
        'Strict-Transport-Security': respHeaders['strict-transport-security'],
        'Content-Security-Policy': respHeaders['content-security-policy'],
        'X-Frame-Options': respHeaders['x-frame-options'],
        'X-Content-Type-Options': respHeaders['x-content-type-options'],
        'Referrer-Policy': respHeaders['referrer-policy'],
        'Permissions-Policy': respHeaders['permissions-policy'],
      };

      int? contentLength = hResponse.contentLength;
      if (contentLength <= 0 && respHeaders.containsKey('content-length')) {
        contentLength = int.tryParse(respHeaders['content-length']!);
      }

      currentProbeResult = {
        'statusCode': hResponse.statusCode,
        'reasonPhrase': hResponse.reasonPhrase,
        'headers': respHeaders,
        'isRedirect': finalUrl != url,
        'contentLength': contentLength,
        'finalUrl': finalUrl,
        'responseTime': stopwatch.elapsedMilliseconds,
        'ipAddress': ipAddress,
        'security': securityHeaders,
        'cookies': cookies,
        'certificate': certInfo,
      };

      if (finalUrl != url) {
        currentProbeResult['redirectLocation'] = finalUrl;
      }

      // Note: _probeResult is NOT updated here anymore.
      // It will be updated by loadFile(file) using the results in HtmlFile.
      _isProbing = false;

      if (hResponse.statusCode == 200) {
        final finalUri = Uri.parse(finalUrl);
        final pathFilename =
            finalUri.pathSegments.isNotEmpty ? finalUri.pathSegments.last : '';

        final filename = pathFilename.isNotEmpty &&
                pathFilename.contains('.') &&
                !pathFilename.startsWith('_') &&
                pathFilename != 'index' &&
                pathFilename != 'home'
            ? pathFilename
            : generateDescriptiveFilename(finalUri, content);

        final contentType = respHeaders['content-type'];
        final processedFilename = await detectFileTypeAndGenerateFilename(
          filename,
          content,
          contentType: contentType,
        );

        return HtmlFile(
          name: processedFilename,
          path: finalUrl,
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
          probeResult: currentProbeResult,
        );
      } else {
        // For non-200 responses, we still return the content
        final finalUri = Uri.parse(finalUrl);
        final filename = finalUri.pathSegments.isNotEmpty
            ? finalUri.pathSegments.last
            : 'response_${hResponse.statusCode}';

        return HtmlFile(
          name: filename,
          path: finalUrl,
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
          probeResult: currentProbeResult,
          isError: hResponse.statusCode >= 400,
        );
      }
    } catch (e) {
      String errorMessage;
      if (e is TimeoutException) {
        errorMessage = 'Request timed out';
      } else if (e is FormatException) {
        errorMessage = 'Invalid URL format';
      } else if (e is SocketException) {
        errorMessage = 'Network error: ${e.message}';
      } else {
        errorMessage = e.toString();
      }

      final errorContent = '''Web URL Could Not Be Loaded

Error: $errorMessage

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

Technical details: $e''';

      return HtmlFile(
        name: url,
        path: url,
        content: errorContent,
        lastModified: DateTime.now(),
        size: errorContent.length,
        isUrl: true,
        isError: true,
        probeResult: currentProbeResult,
      );
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

  // Map<String, dynamic> getHighlightTheme() => githubTheme;

  /// Probe a URL to get status code and headers without downloading the full content
  Future<Map<String, dynamic>> probeUrl(
    String url, {
    bool forceReload = false,
  }) async {
    if (!forceReload && _currentlyProbingUrl == url && _isProbing) {
      return _probeResult ?? {};
    }

    // Skip probing for local/pseudo schemes like about:blank
    if (url.startsWith('about:')) {
      return {};
    }

    final String? existingFinalUrl = _probeResult?['finalUrl'];
    final bool isEquivalent =
        existingFinalUrl != null && areUrlsEqual(existingFinalUrl, url);

    _isProbing = true;
    _currentlyProbingUrl = url;

    // Phase 2: Preserve previous results if the URL is equivalent
    // This prevents UI flickering (N/A) during re-probes of the same site
    // HOWEVER, if forceReload is true, we always clear it to handle it as a "new url"
    if (!isEquivalent || forceReload) {
      _probeResult = null;
      _lastBrowserCookies = ''; // Reset browser cookies on new probe
    }

    _probeError = null;
    debugPrint('probe url $url');
    notifyListeners();
    _autoSave();

    HttpClient? client;
    try {
      // Validate and sanitize URL
      String targetUrl = url.trim();
      // Auto-prepend https if no scheme is provided, excluding special schemes like about:
      if (!targetUrl.contains('://') &&
          !targetUrl.startsWith('about:') &&
          !targetUrl.startsWith('data:')) {
        targetUrl = 'https://$targetUrl';
      }

      final uri = Uri.parse(targetUrl);

      // Use HttpClient directly to get certificate info
      client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      client.connectionTimeout = const Duration(seconds: 10);

      final stopwatch = Stopwatch()..start();
      String? ipAddress;

      // Resolve IP
      if (uri.host.isNotEmpty) {
        try {
          final addresses = await InternetAddress.lookup(
            uri.host,
          ).timeout(const Duration(seconds: 2));
          if (addresses.isNotEmpty) {
            ipAddress = addresses.first.address;
          }
        } catch (e) {
          debugPrint('DNS Lookup failed for ${uri.host}: $e');
        }
      }

      // Headers to mimic a browser/curl
      const userAgent = 'curl/7.88.1';

      HttpClientRequest request;
      HttpClientResponse response;

      try {
        // Try HEAD request first (most efficient)
        request = await client.openUrl('HEAD', uri);
        request.headers.set('User-Agent', userAgent);
        request.headers.set('Accept', '*/*');
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('HEAD request failed, trying GET: $e');
        // Fallback to GET with range
        request = await client.openUrl('GET', uri);
        request.headers.set('User-Agent', userAgent);
        request.headers.set('Accept', '*/*');
        request.headers.set('Range', 'bytes=0-0');
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 15));
      }

      // Capture certificate info — must be read before response is fully drained/closed
      Map<String, dynamic>? certInfo;
      try {
        if (response.certificate != null) {
          certInfo = _extractCertificateInfo(response.certificate!);
        }
      } catch (e) {
        debugPrint('Could not read SSL certificate: $e');
      }

      stopwatch.stop();

      // Drain response to ensure socket is closed properly, but we don't need body.
      // We add a timeout here because if the server ignores the Range header
      // and starts sending a massive file, drain() could hang.
      try {
        await response.drain().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Response drain timed out or failed: $e');
        // We continue anyway since we have the headers we need
      }

      int? contentLength = response.contentLength;

      // Check Content-Length header fallback
      if (contentLength <= 0) {
        final lengthHeader = response.headers.value('content-length');
        if (lengthHeader != null) {
          contentLength = int.tryParse(lengthHeader) ?? 0;
        } else {
          contentLength = 0;
        }
      }

      // Standardize on lowercase keys for consistent lookup
      final normalizedHeaders = <String, String>{};
      response.headers.forEach((key, values) {
        normalizedHeaders[key.toLowerCase()] = values.join(', ');
      });

      // Security Headers Check
      final securityHeaders = {
        'Strict-Transport-Security':
            normalizedHeaders['strict-transport-security'],
        'Content-Security-Policy': normalizedHeaders['content-security-policy'],
        'X-Frame-Options': normalizedHeaders['x-frame-options'],
        'X-Content-Type-Options': normalizedHeaders['x-content-type-options'],
        'Referrer-Policy': normalizedHeaders['referrer-policy'],
        'Permissions-Policy': normalizedHeaders['permissions-policy'],
      };

      // Cookies - use response.cookies to handle multiple Set-Cookie headers correctly
      final List<String> cookies =
          response.cookies.map((c) => c.toString()).toList();

      // Only update state if this probe is still relevant
      if (_currentlyProbingUrl == url) {
        // Construct the result, ONLY from the probe
        _probeResult = {
          'statusCode': response.statusCode,
          'reasonPhrase': response.reasonPhrase,
          'headers': normalizedHeaders,
          'isRedirect': response.isRedirect,
          'contentLength': contentLength,
          'finalUrl': url,
          'responseTime': stopwatch.elapsedMilliseconds,
          'ipAddress': ipAddress,
          'security': securityHeaders,
          'cookies': cookies,
          'certificate': certInfo,
          'analyzedCookies': <Map<String, dynamic>>[],
        };

        // Update _currentFile with the probe results immediately
        // This ensures UI components like BrowserView can see headers/content-type
        // even before the next sync or full load.
        if (_currentFile != null && areUrlsEqual(_currentFile!.path, url)) {
          _currentFile = _currentFile!.copyWith(probeResult: _probeResult);
        }

        // Update cookies with any browser cookies we might already have
        _updateAnalyzedCookies();

        // Extract redirect location if present
        if (response.isRedirect) {
          final location = normalizedHeaders['location'];
          if (location != null && location.isNotEmpty) {
            // Resolve relative URLs
            final redirectUri = uri.resolve(location);
            _probeResult!['redirectLocation'] = redirectUri.toString();
          }
        }

        // AUTO-DETECT RSS/ATOM AND FETCH SOURCE
        final contentType =
            normalizedHeaders['content-type']?.toLowerCase() ?? '';
        final isFeed = contentType.contains('application/rss+xml') ||
            contentType.contains('application/atom+xml') ||
            (contentType.contains('xml') &&
                (targetUrl.endsWith('.rss') ||
                    targetUrl.endsWith('.atom') ||
                    targetUrl.endsWith('.xml')));

        if (isFeed && _useBrowserByDefault) {
          debugPrint(
            'RSS/Atom detected in probe ($contentType), forcing source load.',
          );
          _loadFromUrlInternal(targetUrl).then((file) {
            if (_currentlyProbingUrl == targetUrl ||
                _currentFile?.path == targetUrl) {
              loadFile(file);
            }
          }).catchError((e) {
            debugPrint('Error forcing RSS source load: $e');
          });
        }

        debugPrint('Probe successful for $url');
        return _probeResult!;
      } else {
        debugPrint(
          'Discarding stale probe result for $url (current active probe/sync: $_currentlyProbingUrl)',
        );
        return {};
      }
    } catch (e) {
      debugPrint('Error probing URL $url: $e');
      if (_currentlyProbingUrl == url) {
        _probeError = e.toString();
      }
      return {}; // Return empty instead of rethrowing to avoid unhandled async exceptions
    } finally {
      // Ensure client is closed to free up resources
      try {
        client?.close(force: true);
      } catch (e) {
        debugPrint('Error closing HttpClient: $e');
      }

      // Only reset flags if we are still the active probe
      if (_currentlyProbingUrl == url) {
        _isProbing = false;
        _currentlyProbingUrl = null;
        notifyListeners();
        _autoSave();
      }
    }
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

  Mode? getReHighlightModeForExtension(String extension) {
    final languageName = getLanguageForExtension(extension);

    // Get the mode from re_highlight languages
    try {
      // Check if the language exists in re_highlight
      if (builtinAllLanguages.containsKey(languageName)) {
        return builtinAllLanguages[languageName]!;
      }

      // Fallback for HTML - try xml if html is requested
      if (languageName == 'html' ||
          languageName == 'htm' ||
          languageName == 'xml') {
        return builtinAllLanguages['xml'] ??
            builtinAllLanguages['xml'] ??
            builtinAllLanguages['plaintext']!;
      }

      // Ultimate fallback to plaintext
      return builtinAllLanguages['plaintext']!;
    } catch (e) {
      return builtinAllLanguages[
          'plaintext']!; // Fallback to plaintext if any error occurs
    }
  }

  Widget buildHighlightedText(
    String content,
    String extension,
    BuildContext context, {
    double fontSize = 16.0,
    String themeName = 'github',
    bool wrapText = false,
    bool showLineNumbers = true,
    ScrollController? customScrollController,
  }) {
    // Performance monitoring and warnings for large files
    final contentSize = content.length;
    final contentSizeMB = contentSize / (1024 * 1024);

    // Warn about potential performance issues with large files
    if (contentSize > 1 * 1024 * 1024) {
      if (contentSize > 7 * 1024 * 1024) {
        // 7MB severe warning
        debugPrint(
          '⚠️  Very large file: ${contentSizeMB.toStringAsFixed(2)} MB',
        );
        debugPrint('   Significant performance impact expected');

        // Show warning to user if context is available and mounted
        try {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Large file (${contentSizeMB.toStringAsFixed(1)} MB). Syntax highlighting may be slow.',
                ),
                duration: const Duration(seconds: 4),
                // backgroundColor: Colors.orange,
              ),
            );
          });
        } catch (e) {
          debugPrint('Could not show large file warning: $e');
        }
      } else {
        // 1MB warning threshold
        debugPrint(
          '🚨 Large file detected: ${contentSizeMB.toStringAsFixed(2)} MB',
        );
        debugPrint('   Syntax highlighting may impact performance');
      }
    }

    // Performance optimization: Use simplified highlighting for very large files
    bool useSimplifiedHighlighting =
        contentSize > 1 * 1024 * 1024; // 1MB threshold

    // Get the appropriate language for syntax highlighting
    final languageName = getLanguageForExtension(extension);

    // check widget cache
    // if (_highlightCache.containsKey(fullCacheKey)) {
    //   debugPrint('🔄 Using cached highlighted widget');
    //   return _highlightCache[fullCacheKey]!;
    // }

    // Create a controller for the code editor
    // Performance optimization: Use chunked content for very large files
    String processedContent = content;
    if (useSimplifiedHighlighting) {
      // For very large files, use a simplified approach
      // This reduces memory usage and parsing time
      debugPrint('🔧 Using simplified highlighting for very large file');

      // Limit the amount of content processed for syntax highlighting
      // while still showing the full content
      final maxHighlightLength = 200000; // ~200KB for highlighting
      if (content.length > maxHighlightLength) {
        // Take the first part for highlighting, but keep full content for display
        processedContent = content.substring(0, maxHighlightLength);
        debugPrint(
          '   Processing first ${maxHighlightLength ~/ 1024}KB for highlighting',
        );
      }
    }

    // Always create a new controller to avoid issues with listeners from deactivated widgets
    final controller = CodeLineEditingController.fromText(processedContent);

    // Resolve the vertical scroll controller
    // If customScrollController is provided, use it.
    // Otherwise, try to find one in the context.
    // If that fails, create a temporary one (though this should rarely happen in a valid app structure).
    final effectiveVerticalController =
        customScrollController ?? PrimaryScrollController.of(context);

    // Update our reference for external access (e.g. scrollToZero)
    _verticalScrollController = effectiveVerticalController;

    // Create a code theme using the selected theme
    final mode =
        _getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;
    final codeTheme = CodeHighlightTheme(
      languages: {languageName: CodeHighlightThemeMode(mode: mode)},
      theme: _getThemeByName(themeName),
    );

    // Create the scroll controller for CodeEditor
    final codeScrollController = CodeScrollController(
      verticalScroller: effectiveVerticalController,
      horizontalScroller: _activeHorizontalScrollController,
    );

    // Create the final widget
    final codeEditor = CodeEditor(
      controller: controller,
      showCursorWhenReadOnly: false,
      readOnly: true,
      toolbarController: const ContextMenuControllerImpl(),
      wordWrap: wrapText,
      padding: const EdgeInsets.fromLTRB(4, 8, 24, 48),
      scrollController: codeScrollController,
      style: CodeEditorStyle(
        codeTheme: codeTheme,
        fontSize: fontSize,
        fontFamily: 'Courier',
        fontFamilyFallback: const ['monospace', 'Courier New'],
        fontHeight: 1.2,
      ),
      sperator: showLineNumbers ? SizedBox(width: fontSize / 2) : null,
      indicatorBuilder: showLineNumbers
          ? (context, editingController, chunkController, notifier) {
              return DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Courier',
                  height: 1.2,
                  fontFamilyFallback: const ['monospace', 'Courier New'],
                  color: Colors.grey[600], // Subtle color for line numbers
                ),
              );
            }
          : null,
      findBuilder: (context, controller, readOnly) {
        // Update the active find controller when the builder is called
        // This ensures we always have the correct controller for the current editor
        if (_activeFindController != controller) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateActiveFindController(controller);
          });
        }

        // Return empty container to disable in-editor panel
        // The panel will be rendered in the AppBar instead
        return const PreferredSize(
          preferredSize: Size.zero,
          child: SizedBox.shrink(),
        );
      },
    );

    // Enforce cache size limits
    _enforceCacheSizeLimits();

    // Do not cache the CodeEditor widget itself as it can lead to "CodeCursorBlinkController was used after being disposed"
    // errors when the widget is reused after being unmounted/disposed.
    // _highlightCache[fullCacheKey] = codeEditor;

    return codeEditor;
  }

  // Helper method to get re_highlight mode for language name
  Mode? _getReHighlightMode(String languageName) {
    // First, try the language name directly
    if (builtinAllLanguages.containsKey(languageName)) {
      return builtinAllLanguages[languageName]!;
    }

    // Map common language names to re_highlight language names
    const languageMap = {
      'html': 'xml',
      'htm': 'xml',
      'javascript': 'javascript',
      'js': 'javascript',
      'typescript': 'typescript',
      'ts': 'typescript',
      'jsx': 'javascript',
      'tsx': 'javascript',
      'xml': 'XML',
      'xsd': 'XML',
      'xsl': 'XML',
      'svg': 'XML',
      'rss': 'XML',
      'atom': 'XML',
      'rdf': 'XML',
      'yaml': 'YAML',
      'yml': 'YAML',
      'markdown': 'markdown',
      'md': 'markdown',
      'asciidoc': 'asciidoc',
      'adoc': 'asciidoc',
      'cpp': 'cpp',
      'c++': 'cpp',
      'csharp': 'csharp',
      'cs': 'csharp',
      'plaintext': 'plaintext',
      'txt': 'plaintext',
      'text': 'plaintext',
    };

    // Try the mapped language name
    final mappedLanguageName = languageMap[languageName];
    if (mappedLanguageName != null &&
        builtinAllLanguages.containsKey(mappedLanguageName)) {
      return builtinAllLanguages[mappedLanguageName]!;
    }

    // Special cases and fallbacks
    // HTML/XML family
    if (languageName == 'html' ||
        languageName == 'htm' ||
        languageName == 'xhtml') {
      return builtinAllLanguages['xml'] ?? builtinAllLanguages['plaintext']!;
    }

    // JavaScript family
    if (languageName == 'javascript' ||
        languageName == 'js' ||
        languageName == 'jsx' ||
        languageName == 'tsx') {
      return builtinAllLanguages['javascript'] ??
          builtinAllLanguages['plaintext']!;
    }

    // TypeScript
    if (languageName == 'typescript' || languageName == 'ts') {
      return builtinAllLanguages['typescript'] ??
          builtinAllLanguages['javascript'] ??
          builtinAllLanguages['plaintext']!;
    }

    // XML family
    if (languageName == 'xml' ||
        languageName == 'xsd' ||
        languageName == 'xsl' ||
        languageName == 'svg') {
      return builtinAllLanguages['xml'] ?? builtinAllLanguages['plaintext']!;
    }

    // Shell scripting
    if (languageName == 'bash' ||
        languageName == 'sh' ||
        languageName == 'zsh' ||
        languageName == 'fish' ||
        languageName == 'shell') {
      return builtinAllLanguages['bash'] ?? builtinAllLanguages['plaintext']!;
    }

    // Ultimate fallback to plaintext
    return builtinAllLanguages['plaintext']!;
  }

  // Helper method to get the appropriate theme for re_highlight based on theme name
  Map<String, TextStyle> _getThemeByName(String themeName) {
    switch (themeName) {
      case 'github':
        return githubTheme;
      case 'github-dark':
        return githubDarkTheme;
      case 'github-dark-dimmed':
        return githubDarkDimmedTheme;
      case 'androidstudio':
        return androidstudioTheme;
      case 'atom-one-dark':
        return atomOneDarkTheme;
      case 'atom-one-light':
        return atomOneLightTheme;
      case 'vs':
        return vsTheme;
      case 'vs2015':
        return vs2015Theme;
      case 'monokai-sublime':
        return monokaiSublimeTheme;
      case 'monokai':
        return monokaiTheme;
      case 'nord':
        return nordTheme;
      case 'tokyo-night-dark':
        return tokyoNightDarkTheme;
      case 'tokyo-night-light':
        return tokyoNightLightTheme;
      case 'dark':
        return darkTheme;
      case 'lightfair':
        return lightfairTheme;
      default:
        // Fallback to github theme
        return githubTheme;
    }
  }

  /// Generate a cache key for the CodeLineEditingController (content-dependent only)
  String _generateControllerCacheKey({
    required String content,
    required String extension,
    required bool useSimplified,
  }) {
    final contentHash = _simpleHash(content);
    return 'hl:${contentHash}_ext:${extension}_simple:$useSimplified';
  }

  /// Simple hash function for content
  String _simpleHash(String input) {
    // For very long content, use a substring to avoid performance issues
    final sample = input.length > 1000 ? input.substring(0, 1000) : input;

    // Simple hash using string length and some character positions
    final hashParts = [
      sample.length.toString(),
      sample.isNotEmpty ? sample.codeUnitAt(0).toString() : '0',
      sample.length > 10 ? sample.codeUnitAt(10).toString() : '0',
      sample.length > 100 ? sample.codeUnitAt(100).toString() : '0',
      sample.length > 500 ? sample.codeUnitAt(500).toString() : '0',
    ];

    return hashParts.join('_');
  }

  // Cache for editor state to prevent crashes and flickering
  final Map<String, CodeLineEditingController> _cachedControllers = {};
  final Map<String, GlobalKey> _cachedGlobalKeys = {};
  final Map<String, ScrollController> _cachedHorizontalControllers = {};

  /// Clear the editor cache
  void clearHighlightCache() {
    for (final controller in _cachedControllers.values) {
      _queueForDisposal(controller);
    }
    _cachedControllers.clear();
    _cachedGlobalKeys.clear();
    for (final controller in _cachedHorizontalControllers.values) {
      controller.dispose();
    }
    _cachedHorizontalControllers.clear();
    _activeHorizontalScrollController = null;
    debugPrint('🧹 Queued editor cache for lazy disposal');
  }

  /// Queue a controller for disposal after a delay to ensure it's unmounted
  void _queueForDisposal(CodeLineEditingController controller) {
    _disposalQueue.add(controller);
    _disposalTimer?.cancel();
    _disposalTimer = Timer(const Duration(seconds: 2), () {
      for (final c in _disposalQueue) {
        try {
          c.dispose();
        } catch (e) {
          debugPrint('Error disposing queued controller: $e');
        }
      }
      final count = _disposalQueue.length;
      _disposalQueue.clear();
      debugPrint('♻️ Lazy disposed $count controllers');
    });
  }

  /// Prepare the editor for a reset by unfocusing and waiting for blinkers to stop
  Future<void> _prepareForEditorReset() async {
    // Unfocus the editor to prevent 'CodeCursorBlinkController' crash on dispose
    // This stops the cursor blinking timer before the widget is swapped/disposed
    FocusManager.instance.primaryFocus?.unfocus();
    // Wait for the blinker to stop its current cycle - increased to 250ms for safety
    await Future.delayed(const Duration(milliseconds: 250));
    // Clear the editor cache to force fresh controllers/keys
    clearHighlightCache();
  }

  /// Check and enforce cache size limits
  void _enforceCacheSizeLimits() {
    const maxCacheEntries = 10;

    if (_cachedControllers.length > maxCacheEntries) {
      // Unfocus to prevent blinker crash before disposing evicted controllers
      FocusManager.instance.primaryFocus?.unfocus();

      final keysToRemove = _cachedControllers.keys
          .take(_cachedControllers.length - maxCacheEntries)
          .toList();
      for (final key in keysToRemove) {
        final controller = _cachedControllers.remove(key);
        if (controller != null) {
          _queueForDisposal(controller);
        }
        // Also remove all associated global keys and horizontal controllers for this content
        _cachedGlobalKeys.removeWhere((ekey, _) => ekey.startsWith(key));

        // Find and remove horizontal controllers matching this key prefix
        final hKeysToRemove = _cachedHorizontalControllers.keys
            .where((hKey) => hKey.startsWith(key))
            .toList();

        for (final hKey in hKeysToRemove) {
          _cachedHorizontalControllers[hKey]?.dispose();
          _cachedHorizontalControllers.remove(hKey);
        }
      }
      debugPrint('🔄 Trimmed editor cache to $maxCacheEntries entries');
    }
  }

  /// Clear cache for specific content
  void clearCacheForContent(String content) {
    final contentHash = _simpleHash(content);
    final controllerKeyPrefix = 'hl:$contentHash';

    // Dispose and remove controllers
    final controllerKeys = _cachedControllers.keys
        .where((key) => key.startsWith(controllerKeyPrefix))
        .toList();
    for (final key in controllerKeys) {
      _cachedControllers.remove(key)?.dispose();
    }

    // Dispose and remove horizontal controllers
    final hControllerKeys = _cachedHorizontalControllers.keys
        .where((key) => key.startsWith(controllerKeyPrefix))
        .toList();
    for (final key in hControllerKeys) {
      _cachedHorizontalControllers.remove(key)?.dispose();
    }

    _cachedGlobalKeys.removeWhere(
      (key, _) => key.startsWith(controllerKeyPrefix),
    );

    debugPrint('🧹 Cleared cache for content hash $contentHash');
  }

  /// Build the editor widget, returning strictly synchronous Widget if cached,
  /// or a Future if processing is needed.
  FutureOr<Widget> buildEditor(
    String content,
    String extension,
    BuildContext context, {
    double fontSize = 16.0,
    String themeName = 'github',
    bool wrapText = false,
    bool showLineNumbers = true,
  }) {
    // Performance optimization: Use simplified highlighting for very large files
    final contentSize = content.length;
    bool useSimplifiedHighlighting = contentSize > 1 * 1024 * 1024;

    // Generate keys
    final controllerKey = _generateControllerCacheKey(
      content: content,
      extension: extension,
      useSimplified: useSimplifiedHighlighting,
    );

    final editorKey = controllerKey;

    // check if we have the controller cached
    if (_cachedControllers.containsKey(controllerKey)) {
      final controller = _cachedControllers[controllerKey]!;

      // Get or create GlobalKey for this scroll context
      final globalKey = _cachedGlobalKeys[editorKey] ??= GlobalKey();

      // Get or create cached horizontal scroll controller
      final horizontalController =
          _cachedHorizontalControllers[editorKey] ??= ScrollController();
      _activeHorizontalScrollController = horizontalController;

      return _buildEditorWidget(
        context,
        controller,
        globalKey,
        horizontalController,
        extension,
        themeName,
        fontSize,
        wrapText,
        showLineNumbers,
      );
    }

    // Cache Miss: Perform setup (async)
    return _buildNewEditor(
      content,
      extension,
      context,
      fontSize,
      themeName,
      wrapText,
      showLineNumbers,
      useSimplifiedHighlighting,
      controllerKey,
      editorKey,
    );
  }

  Future<Widget> _buildNewEditor(
    String content,
    String extension,
    BuildContext context,
    double fontSize,
    String themeName,
    bool wrapText,
    bool showLineNumbers,
    bool useSimplifiedHighlighting,
    String controllerKey,
    String editorKey,
  ) async {
    // Unblock UI for initial render
    await Future.delayed(Duration.zero);

    // Process content (simulated async if heavy)
    String processedContent = content;
    if (useSimplifiedHighlighting) {
      final maxHighlightLength = 200000;
      if (content.length > maxHighlightLength) {
        processedContent = content.substring(0, maxHighlightLength);
      }
    }

    // Create Controller & GlobalKey
    // Create Controller & GlobalKey & Horizontal Scroll Controller
    final controller = CodeLineEditingController.fromText(processedContent);
    final globalKey = GlobalKey();
    final horizontalController = ScrollController();

    // Cache them
    _cachedControllers[controllerKey] = controller;
    _cachedGlobalKeys[editorKey] = globalKey;
    _cachedHorizontalControllers[editorKey] = horizontalController;
    _enforceCacheSizeLimits();

    if (!context.mounted) {
      horizontalController
          .dispose(); // Should not happen often but safe cleanup
      return const SizedBox.shrink();
    }

    _activeHorizontalScrollController = horizontalController;

    return _buildEditorWidget(
      context,
      controller,
      globalKey,
      horizontalController,
      extension,
      themeName,
      fontSize,
      wrapText,
      showLineNumbers,
    );
  }

  Widget _buildEditorWidget(
    BuildContext context,
    CodeLineEditingController controller,
    GlobalKey key,
    ScrollController horizontalController,
    String extension,
    String themeName,
    double fontSize,
    bool wrapText,
    bool showLineNumbers,
  ) {
    // Determine language
    String languageName = getLanguageForExtension(
      extension,
    ); // Use existing helper method

    // Resolve Scroll Controller
    final effectiveVerticalController = PrimaryScrollController.of(context);

    _verticalScrollController = effectiveVerticalController;

    // Create Theme
    final mode =
        _getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;
    final codeTheme = CodeHighlightTheme(
      languages: {languageName: CodeHighlightThemeMode(mode: mode)},
      theme: _getThemeByName(themeName),
    );

    // Create CodeScrollController linked to CURRENT effective controller
    final codeScrollController = CodeScrollController(
      verticalScroller: effectiveVerticalController,
      horizontalScroller: horizontalController,
    );

    // Return the Editor Widget, using the GlobalKey to preserve state
    return CodeEditor(
      key: key,
      controller: controller,
      showCursorWhenReadOnly: true,
      readOnly: true,
      toolbarController: const ContextMenuControllerImpl(),
      wordWrap: wrapText,
      padding: const EdgeInsets.fromLTRB(4, 8, 24, 48),
      scrollController: codeScrollController,
      style: CodeEditorStyle(
        codeTheme: codeTheme,
        fontSize: fontSize,
        fontFamily: 'Courier',
        fontFamilyFallback: const ['monospace', 'Courier New'],
        fontHeight: 1.2,
      ),
      sperator: showLineNumbers ? SizedBox(width: fontSize / 2) : null,
      indicatorBuilder: showLineNumbers
          ? (context, editingController, chunkController, notifier) {
              return DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Courier',
                  height: 1.2,
                  fontFamilyFallback: const ['monospace', 'Courier New'],
                  color: Colors.grey[600],
                ),
              );
            }
          : null,
      findBuilder: (context, controller, readOnly) {
        if (_activeFindController != controller) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateActiveFindController(controller);
          });
        }
        return const PreferredSize(
          preferredSize: Size.zero,
          child: SizedBox.shrink(),
        );
      },
    );
  }

  /// Cancel any pending highlight operations
  void cancelPendingHighlight() {
    _highlightDebounceTimer?.cancel();
    debugPrint('⏹️  Cancelled pending highlight operations');
  }

  /// Async version of buildHighlightedText to prevent UI blocking
  Future<Widget> buildHighlightedTextAsync(
    String content,
    String extension,
    BuildContext context, {
    double fontSize = 16.0,
    String themeName = 'github',
    bool wrapText = false,
    bool showLineNumbers = true,
    ScrollController? customScrollController,
  }) async {
    // Small delay to allow initial UI render (spinner)
    await Future.delayed(Duration.zero);

    // Check if mounted before proceeding (though context usage is in buildHighlightedText which is sync)
    if (!context.mounted) {
      return const SizedBox.shrink();
    }

    return buildHighlightedText(
      content,
      extension,
      context,
      fontSize: fontSize,
      themeName: themeName,
      wrapText: wrapText,
      showLineNumbers: showLineNumbers,
      customScrollController: customScrollController,
    );
  }

  /// Toggle the search panel for the current editor
  void toggleSearch() {
    if (_activeFindController != null) {
      if (_activeFindController!.value == null) {
        _activeFindController!.findMode();
      } else {
        _activeFindController!.close();
      }
    }
  }

  /// Update the active find controller and manage listeners
  void _updateActiveFindController(CodeFindController? newController) {
    if (_activeFindController == newController) return;

    // Remove listener from old controller
    if (_activeFindController != null) {
      _activeFindController!.removeListener(_onSearchStateChanged);
    }

    _activeFindController = newController;

    // Add listener to new controller
    if (_activeFindController != null) {
      _activeFindController!.addListener(_onSearchStateChanged);
    }

    // Notify listeners of the change
    notifyListeners();
  }

  /// Callback when the search state changes
  void _onSearchStateChanged() {
    notifyListeners();
  }

  /// Extract metadata from the current file content
  Future<void> _extractMetadata({bool isPartial = false}) async {
    if (_currentFile == null || _isExtractingMetadata) return;

    _isExtractingMetadata = true;
    final html = _currentFile!.content;
    final baseUrl = _currentFile!.isUrl ? _currentFile!.path : '';
    final headers = _probeResult?['headers'] as Map<String, dynamic>?;

    try {
      final rawMetadata = await extractMetadataInIsolate(
        html,
        baseUrl,
        headers: headers?.cast<String, String>(),
      );
      _pageMetadata = Map<String, dynamic>.from(rawMetadata);
      debugPrint(
        'Metadata: Extraction complete. Found title: ${_pageMetadata?['title']}, links: ${_pageMetadata?['cssLinks']?.length} CSS, ${_pageMetadata?['jsLinks']?.length} JS, ${_pageMetadata?['media']?['images']?.length} Images',
      );

      if (_lastPageWeight != null) {
        _pageMetadata!['pageWeight'] = _lastPageWeight;
      }

      // Correlate resource sizes with metadata
      if (_pageMetadata != null) {
        _enrichMetadataWithSizes(baseUrl);
        _fetchMissingMetadataSizesAsync().ignore();
      }
    } catch (e, stack) {
      debugPrint('Error extracting metadata in isolate: $e\n$stack');
      _pageMetadata = null;
    } finally {
      _isExtractingMetadata = false;
      notifyListeners();
    }
  }

  /// Helper to update analyzed cookies by merging server (probe) and browser (webview) cookies
  void _updateAnalyzedCookies() {
    // We need at least one source of cookies to proceed, but we might have empty cookies from both
    // if so, we still want to show an empty list properly if we have a probe result.

    // If we haven't probed yet, we can't really "merge" into the probe result
    // But we might want to show browser cookies anyway?
    // We create a minimal placeholder ONLY if we don't have one, ensuring it doesn't look like an error
    _probeResult ??= {
      'finalUrl': _currentFile?.path ?? _currentInputText ?? 'unknown',
      'analyzedCookies': <Map<String, dynamic>>[],
      'cookies': <String>[],
    };

    final List<String> serverCookies =
        (_probeResult!['cookies'] as List?)?.cast<String>() ?? [];

    final analyzed = CookieUtils.mergeCookies(
      serverCookies,
      _lastBrowserCookies,
    );

    _probeResult!['analyzedCookies'] = analyzed
        .map(
          (c) => {
            'name': c.name,
            'value': c.value,
            'category': c.category.toString().split('.').last,
            'provider': c.provider,
            'source': c.source,
          },
        )
        .toList();

    // Don't notify here - caller will notify
  }

  /// Matches extracted metadata links with performance resource data to find sizes
  void _enrichMetadataWithSizes(String baseUrl) {
    if (_pageMetadata == null) return;

    // Helper to find size
    Map<String, int>? findSize(String? src) {
      if (src == null || src.isEmpty) return null;

      // Special case: Data URIs or Base64 SVGs (already embedded)
      // Extract size from the string itself if possible
      if (src.startsWith('data:') || src.startsWith('<svg')) {
        // Approximate byte size: length * 3/4 for base64, but length is fine for diagnostic use
        return {'transfer': src.length, 'decoded': src.length};
      }

      if (_resourcePerformanceData == null) return null;

      // Try exact match first
      var match = _resourcePerformanceData!.firstWhere(
        (r) => r['name'] == src,
        orElse: () => {},
      );

      if (match.isEmpty) {
        // Try matching by suffix if exact URL fails (handles relative vs absolute, or query params)
        try {
          final uri = Uri.parse(src);
          final path = uri.path;
          if (path.isNotEmpty) {
            final fileName = path.split('/').last;
            if (fileName.length > 3) {
              match = _resourcePerformanceData!.firstWhere((r) {
                final rName = r['name'].toString();
                return rName.endsWith(fileName) || rName.contains(fileName);
              }, orElse: () => {});
            }
          }
        } catch (e) {
          // ignore
        }
      }

      if (match.isNotEmpty) {
        return {'transfer': match['transfer'], 'decoded': match['decoded']};
      }
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

  Map<String, dynamic> _extractCertificateInfo(X509Certificate cert) {
    try {
      return {
        'subject': cert.subject,
        'subjectParsed': _parseX509String(cert.subject),
        'issuer': cert.issuer,
        'issuerParsed': _parseX509String(cert.issuer),
        'startValidity': cert.startValidity.toIso8601String(),
        'endValidity': cert.endValidity.toIso8601String(),
        'der': base64Encode(cert.der),
        'pem': _convertToPem(cert.der),
      };
    } catch (e) {
      debugPrint('Error extracting certificate info: $e');
      return {'error': e.toString()};
    }
  }

  Map<String, String> _parseX509String(String x509) {
    final Map<String, String> labels = {
      'CN': 'Common Name',
      'O': 'Organization',
      'OU': 'Organizational Unit',
      'C': 'Country',
      'L': 'Locality',
      'ST': 'State/Province',
      'E': 'Email',
      'SERIALNUMBER': 'Serial Number',
    };

    final Map<String, String> parsed = {};
    // Typical format: /CN=name/O=org... or CN=name, O=org...
    final parts = x509.split(RegExp(r'[/,]\s*'));
    for (var part in parts) {
      if (part.contains('=')) {
        final kv = part.split('=');
        if (kv.length >= 2) {
          final key = kv[0].trim().toUpperCase();
          final value = kv.sublist(1).join('=').trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            parsed[labels[key] ?? key] = value;
          }
        }
      }
    }
    return parsed;
  }

  String _convertToPem(List<int> der) {
    final base64String = base64Encode(der);
    final chunks = <String>[];
    for (var i = 0; i < base64String.length; i += 64) {
      final end = (i + 64 > base64String.length) ? base64String.length : i + 64;
      chunks.add(base64String.substring(i, end));
    }
    return '-----BEGIN CERTIFICATE-----\n${chunks.join('\n')}\n-----END CERTIFICATE-----';
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
      // which is handled by onPageStarted/onUrlChange in BrowserView calling updateWebViewUrl
    }

    // Trigger probe for the new URL if not already probing it or if it's different from the result
    // Independent Probe: This ensures we have server-side data for Probe/Security tabs
    // In our new architecture, loadFromUrl already triggered the probe.
    // However, if the user navigated INSIDE the WebView (clicked a link), we need to trigger it here.
    final String? existingFinalUrl = _probeResult?['finalUrl'];
    final bool alreadyProbed =
        existingFinalUrl != null && areUrlsEqual(existingFinalUrl, url);

    if (_currentlyProbingUrl != url && !alreadyProbed) {
      // Synchronize _currentlyProbingUrl even if we don't start a new probe
      // This ensures background probes for PREVIOUS pages are correctly identified as stale
      _currentlyProbingUrl = url;

      probeUrl(url).catchError((e) {
        debugPrint('Error probing synced URL: $e');
        return <String, dynamic>{};
      });
    } else {
      // Ensure stale background probes are discarded by updating the active target
      _currentlyProbingUrl = url;
    }

    try {
      // 1. Critical: Get Content (HTML or Raw)
      String content = '';
      try {
        final html = await activeWebViewController!.evaluateJavascript(
          source: '''
              (function() {
                var contentType = document.contentType;
                if (contentType && (contentType.includes('xml') || contentType.includes('rss'))) {
                  return new XMLSerializer().serializeToString(document);
                }
                return document.documentElement.outerHTML;
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
              final preMatch = RegExp(
                r'<pre[^>]*style="[^"]*word-wrap:\s*break-word;\s*white-space:\s*pre-wrap;[^"]*"[^>]*>(.*?)<\/pre>',
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
        final weightRaw = await activeWebViewController!.evaluateJavascript(
          source:
              '(function() { var tTx=0; var tDec=0; var r=performance.getEntriesByType("resource"); var list=[]; var seen=new Set(); for(var i=0; i<r.length; i++) { var name=r[i].name; tTx+=(r[i].transferSize||0); tDec+=(r[i].decodedBodySize||0); list.push({n: name, t: r[i].transferSize||0, d: r[i].decodedBodySize||0}); seen.add(name); } var n=performance.getEntriesByType("navigation")[0]; var nTx=0; var nDec=0; if(n && !seen.has(n.name)) { nTx=(n.transferSize||0); nDec=(n.decodedBodySize||0); if(nDec===0) nDec=document.documentElement.outerHTML.length; tTx+=nTx; tDec+=nDec; list.push({n: n.name, t: nTx, d: nDec}); } else if(!n && !seen.has(document.location.href)) { var size=document.documentElement.outerHTML.length; tDec+=size; tTx+=size; nTx=size; nDec=size; list.push({n: document.location.href, t: size, d: size}); } return JSON.stringify({tx: tTx, dec: tDec, nTx: nTx, nDec: nDec, list: list, cookies: document.cookie}); })();',
        );

        String jsonStr = '';
        if (weightRaw is String) {
          jsonStr = _unquoteHtml(weightRaw);
        }

        if (jsonStr.isNotEmpty) {
          final dynamic decoded = jsonDecode(jsonStr);
          if (decoded is Map) {
            final weightMap = Map<String, dynamic>.from(decoded);

            // Extract cookies
            final String browserCookies =
                weightMap['cookies']?.toString() ?? '';
            _lastBrowserCookies = browserCookies;
            _updateAnalyzedCookies();

            // Parse detailed resource data
            if (weightMap['list'] != null && weightMap['list'] is List) {
              _resourcePerformanceData = List<Map<String, dynamic>>.from(
                (weightMap['list'] as List).map(
                  (e) => {
                    'name': e['n'],
                    'transfer': (e['t'] as num? ?? 0).toInt(),
                    'decoded': (e['d'] as num? ?? 0).toInt(),
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

                if (name.endsWith('.js') ||
                    name.contains('.js?') ||
                    name.contains('script')) {
                  scriptCount++;
                  scriptTx += mTx;
                  scriptDec += mDec;
                } else if (name.endsWith('.css') ||
                    name.contains('.css?') ||
                    name.contains('style')) {
                  cssCount++;
                  cssTx += mTx;
                  cssDec += mDec;
                } else if (name.endsWith('.png') ||
                    name.endsWith('.jpg') ||
                    name.endsWith('.jpeg') ||
                    name.endsWith('.gif') ||
                    name.endsWith('.webp') ||
                    name.endsWith('.svg') ||
                    name.endsWith('.ico') ||
                    name.contains('image')) {
                  imgCount++;
                  imgTx += mTx;
                  imgDec += mDec;
                } else if (name.endsWith('.html') ||
                    name.endsWith('.htm') ||
                    name.contains('document') ||
                    (!name.contains('.') && name.startsWith('http')) ||
                    name == url.toLowerCase()) {
                  htmlCount++;
                  htmlTx += mTx;
                  htmlDec += mDec;
                } else {
                  otherCount++;
                  otherTx += mTx;
                  otherDec += mDec;
                }
              }
            }

            // Populate Browser Probe Result
            _browserProbeResult = {
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

      final file = HtmlFile(
        name: filename,
        path: url,
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
        isUrl: true,
        probeResult: _probeResult,
      );

      await loadFile(file, clearProbe: false, isPartial: isPartial);
    } catch (e) {
      debugPrint('Error syncing WebView state: $e');
    } finally {
      if (!isPartial) {
        _isLoading = false;
        notifyListeners();
      }
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
              // We can't know decoded size without downloading body, so assume transfer ~= decoded
              // This is better than 0.
              resource['decoded'] = size;
            }
          } catch (e) {
            debugPrint('Error fetching size for $resource: $e');
          }
        }),
      );
    }

    // Recalculate totals based on new data
    // _recalculatePageWeight(); // This method might not exist, let's use the explicit logic

    // Recalculate directly to be safe
    int scriptCount = 0, scriptTx = 0, scriptDec = 0;
    int cssCount = 0, cssTx = 0, cssDec = 0;
    int imgCount = 0, imgTx = 0, imgDec = 0;
    int htmlCount = 0, htmlTx = 0, htmlDec = 0;
    int otherCount = 0, otherTx = 0, otherDec = 0;

    final url = _currentFile?.path.toLowerCase() ?? '';

    // Use a Map to unique-ify by name if duplicates exist
    final Map<String, Map<String, dynamic>> uniqueResources = {};
    for (var r in _resourcePerformanceData!) {
      final name = r['name'] as String? ?? '';
      if (name.isNotEmpty) {
        uniqueResources[name] = r;
      }
    }

    // Update the list with unique entries
    _resourcePerformanceData = uniqueResources.values.toList();

    for (var r in _resourcePerformanceData!) {
      final String name = (r['name'] as String? ?? '').toLowerCase();
      final int mTx = (r['transfer'] as num? ?? 0).toInt();
      final int mDec = (r['decoded'] as num? ?? 0).toInt();

      if (name.endsWith('.js') ||
          name.contains('.js?') ||
          name.contains('script')) {
        scriptCount++;
        scriptTx += mTx;
        scriptDec += mDec;
      } else if (name.endsWith('.css') ||
          name.contains('.css?') ||
          name.contains('style')) {
        cssCount++;
        cssTx += mTx;
        cssDec += mDec;
      } else if (name.endsWith('.png') ||
          name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.gif') ||
          name.endsWith('.webp') ||
          name.endsWith('.svg') ||
          name.endsWith('.ico') ||
          name.contains('image')) {
        imgCount++;
        imgTx += mTx;
        imgDec += mDec;
      } else if (name.endsWith('.html') ||
          name.endsWith('.htm') ||
          name.contains('document') ||
          (!name.contains('.') && name.startsWith('http')) ||
          name == url) {
        htmlCount++;
        htmlTx += mTx;
        htmlDec += mDec;
      } else {
        otherCount++;
        otherTx += mTx;
        otherDec += mDec;
      }
    }

    // Mathematical consistency: Total = sum of parts
    final totalTransferSize = scriptTx + cssTx + imgTx + htmlTx + otherTx;
    final totalDecodedSize = scriptDec + cssDec + imgDec + htmlDec + otherDec;

    _lastPageWeight = {
      'transfer': totalTransferSize,
      'decoded': totalDecodedSize,
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

  Future<int> _fetchResourceSize(String url) async {
    try {
      final client = http.Client();
      final uri = Uri.parse(url);
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
      };

      // 1. Try HEAD request first
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
        // Fallback to Streamed GET if HEAD fails or times out
      }

      // 2. Fallback to Streamed GET request
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
        client.close();

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
        client.close();
      }
    } catch (e) {
      debugPrint('Error getting resource size for \$url: \$e');
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

    // Reset probe results as they might contain now-invalid cookie data
    _probeResult = null;
    _pageMetadata = null;

    debugPrint('Browser storage (cache, local storage, cookies) cleared');
    notifyListeners();
  }

  http.Client _createClient() {
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  void updateWebViewUrl(String url) {
    if (_currentInputText != url) {
      _resetLoadState(newUrl: url);

      // Ensure the WebView remains mounted in HomeScreen during its discovery phase
      _isWebViewLoading = true;
      _webViewLoadingUrl = url; // Set this so BrowserView knows it's the target

      notifyListeners();

      // Trigger probe for the new URL to update Headers, Security, etc.
      probeUrl(url).ignore();
    }
  }

  Future<void> extractCurrentWebViewContent() async {
    if (activeWebViewController == null) return;

    try {
      final webUri = await activeWebViewController!.getUrl();
      final url = webUri?.toString();
      final html = await activeWebViewController!.evaluateJavascript(
        source: 'document.documentElement.outerHTML',
      ) as String;

      // Unquote if needed (standard JS result processing)
      String finalHtml = _unquoteHtml(html);

      if (url != null) {
        final processedFilename = await detectFileTypeAndGenerateFilename(
          url,
          finalHtml,
        );

        final htmlFile = HtmlFile(
          name: processedFilename,
          path: url,
          content: finalHtml,
          lastModified: DateTime.now(),
          size: finalHtml.length,
          isUrl: true,
        );

        _currentFile = htmlFile;
        _currentInputText = url;
        _requestedTabIndex =
            0; // Switch to Source tab to show extracted content

        // Clear cache and reset beautify on new file load
        _beautifiedCache.clear();
        _isBeautifyEnabled = false;

        notifyListeners();

        // Trigger metadata extraction in background
        _extractMetadata().then((_) => notifyListeners()).ignore();

        _autoSave();
      }
    } catch (e) {
      debugPrint('Error extracting WebView content: $e');
    }
  }
}
