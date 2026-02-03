import 'package:flutter/material.dart';
import 'package:view_source_vibe/models/html_file.dart';
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
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:view_source_vibe/widgets/contextmenu.dart';
import 'package:view_source_vibe/services/file_type_detector.dart';
import 'package:view_source_vibe/services/app_state_service.dart';
import 'package:view_source_vibe/services/url_history_service.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;

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
  UrlHistoryService? _urlHistoryService;

  // Navigation stack for "Back" functionality
  final List<HtmlFile> _navigationStack = [];
  bool _isNavigatingBack = false;

  // Probe state
  Map<String, dynamic>? _probeResult;
  bool _isProbing = false;
  String? _probeError;

  // Metadata state
  Map<String, dynamic>? _pageMetadata;
  Map<String, dynamic>? get pageMetadata => _pageMetadata;

  bool _isWebViewMode = false;
  bool get isWebViewMode => _isWebViewMode;

  // WebView extraction state
  bool _isWebViewLoading = false;
  bool get isWebViewLoading => _isWebViewLoading;
  String? _webViewLoadingUrl;
  String? get webViewLoadingUrl => _webViewLoadingUrl;
  bool _isBeautifyEnabled = false;
  bool get isBeautifyEnabled => _isBeautifyEnabled;
  wf.WebViewController? activeWebViewController;

  // Cache for highlighted content to improve performance
  final Map<String, Widget> _highlightCache = {};

  // Track the currently active find controller
  CodeFindController? _activeFindController;

  // Debouncing for syntax highlighting
  Timer? _highlightDebounceTimer;

  HtmlFile? get currentFile => _currentFile;
  ScrollController? get scrollController => _verticalScrollController;
  ScrollController? get horizontalScrollController =>
      _activeHorizontalScrollController;
  GlobalKey? get codeEditorKey => _codeEditorKey;

  // Expose probe state
  Map<String, dynamic>? get probeResult => _probeResult;
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

  bool get isHtml =>
      selectedContentType == 'html' ||
      (_currentFile?.name.toLowerCase().endsWith('.html') ?? false) ||
      (_currentFile?.name.toLowerCase().endsWith('.htm') ?? false) ||
      (_currentFile?.name.toLowerCase().endsWith('.xhtml') ?? false);

  bool get isSvg =>
      selectedContentType == 'svg' ||
      (_currentFile?.name.toLowerCase().endsWith('.svg') ?? false);

  bool get isXml =>
      selectedContentType == 'xml' ||
      isSvg ||
      (_currentFile?.name.toLowerCase().endsWith('.xml') ?? false) ||
      (_currentFile?.name.toLowerCase().endsWith('.rss') ?? false) ||
      (_currentFile?.name.toLowerCase().endsWith('.atom') ?? false);

  /// Metadata/Services/Media extraction is only useful for full web pages
  bool get showMetadataTabs => isHtml;

  /// DOM Tree and Probe tabs are useful for any structured markup
  bool get isHtmlOrXml => isHtml || isXml;

  bool get isMedia =>
      selectedContentType == 'image' ||
      selectedContentType == 'video' ||
      selectedContentType == 'audio' ||
      (_currentFile?.isMedia ?? false);

  void consumeTabSwitchRequest() {
    _requestedTabIndex = null;
  }

  HtmlService() {
    _codeEditorKey = GlobalKey();
    _currentInputText = '';
  }

  void triggerWebViewLoad(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    _webViewLoadingUrl = url;
    _isWebViewLoading = true;
    _isLoading = true;
    notifyListeners();
  }

  void cancelWebViewLoad() {
    _webViewLoadingUrl = null;
    _isWebViewLoading = false;
    _isLoading = false;
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
        filename, html,
        contentType: 'text/html');

    final file = HtmlFile(
      name: processedFilename,
      path: url,
      content: html,
      lastModified: DateTime.now(),
      size: html.length,
      isUrl: true,
      probeResult: probeResult,
    );

    // Save probes to local state so they can be viewed
    _probeResult = probeResult;
    _isProbing = false;

    await loadFile(file);
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _verticalScrollController?.dispose();
    _activeHorizontalScrollController = null;

    // Dispose all cached horizontal controllers
    for (final controller in _cachedHorizontalControllers.values) {
      controller.dispose();
    }
    _cachedHorizontalControllers.clear();

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

  void setUrlHistoryService(UrlHistoryService service) {
    _urlHistoryService = service;
  }

  /// Auto-save the current state if a service is available
  void _autoSave() {
    if (_appStateService != null) {
      saveCurrentState(_appStateService!);
    }
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
      debugPrint('💾 Saved current app state');
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
        'tv'
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
        .where((segment) =>
            segment.isNotEmpty &&
            !segment.startsWith('_') &&
            segment != 'index' &&
            segment != 'home')
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
      '.rdf'
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
      Uri uri, http.Client client, Map<String, String> headers,
      {Uri? originalUri, int redirectDepth = 0}) async {
    try {
      // Prevent infinite redirect loops
      if (redirectDepth > 5) {
        debugPrint('Too many redirects (>5), falling back to original URL');
        return originalUri?.toString() ?? uri.toString();
      }

      // Use HttpClient to manually handle redirects and capture certificate
      final hClient = HttpClient();
      final hRequest = await hClient.openUrl('GET', uri);
      hRequest.followRedirects = false;

      // Add headers to the request
      headers.forEach((key, value) {
        hRequest.headers.set(key, value);
      });

      final hResponse =
          await hRequest.close().timeout(const Duration(seconds: 30));

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
        return await _getFinalUrlAfterRedirects(
            redirectUri, http.Client(), headers,
            originalUri: originalUri ?? uri, // Preserve the original URI
            redirectDepth: redirectDepth + 1);
      }

      // If not a redirect, return the current URL
      return uri.toString();
    } catch (e) {
      // If redirect handling fails, fall back to the original URL if available
      debugPrint('Error handling redirects: $e');

      // If this is a DNS lookup failure or connection error, fall back to original URL
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        debugPrint(
            'DNS/Connection error detected, falling back to original URL');
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

    // Try to detect content type from content
    final lowerContent = content.toLowerCase();

    // HTML detection - prioritize and make extremely robust using scoring system
    // Check for HTML-specific patterns first, before other languages
    int htmlScore = 0;

    // Strong HTML indicators (high score)
    if (lowerContent.contains('<html') ||
        lowerContent.contains('<!doctype html')) {
      htmlScore += 10;
    }
    if (lowerContent.contains('<!doctype')) {
      htmlScore += 8;
    }
    if (lowerContent.contains('<head') || lowerContent.contains('<body')) {
      htmlScore += 8;
    }
    if (lowerContent.contains('</html>') ||
        lowerContent.contains('</head>') ||
        lowerContent.contains('</body>')) {
      htmlScore += 8;
    }

    // Medium HTML indicators
    if (lowerContent.contains('<div') || lowerContent.contains('<span')) {
      htmlScore += 5;
    }
    if (lowerContent.contains('<script') || lowerContent.contains('<style')) {
      htmlScore += 5;
    }
    if (lowerContent.contains('<meta') || lowerContent.contains('<link')) {
      htmlScore += 5;
    }
    if (lowerContent.contains('<title') || lowerContent.contains('<noscript')) {
      htmlScore += 5;
    }

    // Weak HTML indicators
    if (lowerContent.contains('<!')) {
      htmlScore += 3;
    }
    if (lowerContent.contains('</')) {
      htmlScore += 3;
    }
    if (lowerContent.contains('<img') || lowerContent.contains('<a ')) {
      htmlScore += 3;
    }
    if (lowerContent.contains('<p') ||
        lowerContent.contains('<h') ||
        lowerContent.contains('<section')) {
      htmlScore += 3;
    }

    // Consider it HTML if we have strong evidence
    bool isHtml = htmlScore >= 5;

    // CSS detection - only if not HTML
    bool isCss = !isHtml &&
        (lowerContent.contains('body {') ||
            lowerContent.contains('@media') ||
            lowerContent.contains('/* css') ||
            lowerContent.contains('@import') ||
            lowerContent.contains('@font-face') ||
            lowerContent.contains('@keyframes') ||
            (lowerContent.contains('{') &&
                lowerContent.contains('}') &&
                lowerContent.contains(':') &&
                lowerContent.contains(';') &&
                !lowerContent.contains('<') &&
                !lowerContent.contains('>') &&
                !lowerContent.contains('function') &&
                !lowerContent.contains('const ') &&
                !lowerContent.contains('let ')));

    // JavaScript detection - only if not HTML, and much more specific patterns
    // Avoid false positives from JavaScript in HTML attributes
    bool isJavaScript = !isHtml &&
        !isCss &&
        ((lowerContent.contains('function ') &&
                lowerContent.contains('{') &&
                lowerContent.contains('}')) ||
            (lowerContent.contains('const ') &&
                lowerContent.contains('=') &&
                lowerContent.contains(';') &&
                !lowerContent.contains('onclick=') &&
                !lowerContent.contains('onload=') &&
                !lowerContent.contains('onclick =')) ||
            (lowerContent.contains('let ') &&
                lowerContent.contains('=') &&
                lowerContent.contains(';') &&
                !lowerContent.contains('onclick=') &&
                !lowerContent.contains('onload=') &&
                !lowerContent.contains('onclick =')) ||
            (lowerContent.contains('=>') &&
                lowerContent.contains('{') &&
                lowerContent.contains('}')) ||
            (lowerContent.contains('class ') &&
                lowerContent.contains('extends') &&
                lowerContent.contains('{')) ||
            (lowerContent.contains('import ') &&
                lowerContent.contains('from') &&
                lowerContent.contains(';')) ||
            (lowerContent.contains('export ') &&
                lowerContent.contains('{') &&
                lowerContent.contains('}')));

    // XML detection - check for RSS/Atom feeds and general XML
    // This should happen before HTML detection to avoid false positives
    bool isXml = lowerContent.contains('<rss ') ||
        lowerContent.contains('<feed ') ||
        lowerContent.contains('<?xml') ||
        lowerContent.contains('xmlns=') ||
        lowerContent.contains('<channel ') ||
        lowerContent.contains('<item ') ||
        (!isHtml && tryParseAsXml(content));

    // Assign file type based on detection (priority: XML > HTML > CSS > JS > other languages)
    // XML detection comes first to fix RSS feed issue
    if (isXml) {
      return 'XML File';
    } else if (isHtml) {
      return 'HTML File';
    } else if (isCss) {
      return 'CSS File';
    } else if (isJavaScript) {
      return 'JavaScript File';
    } else if (isXml) {
      return 'XML File';
    }

    // Other language detections (only if not HTML/CSS/JS)
    if (!isHtml && !isCss && !isJavaScript) {
      // Check for Java content
      if (lowerContent.contains('public class ') ||
          lowerContent.contains('import java.') ||
          lowerContent.contains('package ') ||
          lowerContent.contains('system.out.println')) {
        return 'Java File';
      }

      // Check for C/C++ content
      if (lowerContent.contains('#include ') ||
          lowerContent.contains('int main(') ||
          lowerContent.contains('cout <<') ||
          lowerContent.contains('cin >>') ||
          lowerContent.contains('namespace ')) {
        return 'C++ File';
      }

      // Check for Python content
      if (lowerContent.contains('def ') ||
          lowerContent.contains('class ') ||
          lowerContent.contains('import ') ||
          lowerContent.contains('from ') ||
          lowerContent.contains('print(') ||
          lowerContent.contains('#!/usr/bin/env python')) {
        return 'Python File';
      }

      // Check for Ruby content
      if (lowerContent.contains('puts ') ||
          lowerContent.contains('require ') ||
          lowerContent.contains('gem ') ||
          lowerContent.contains('bundle ')) {
        return 'Ruby File';
      }

      // Check for SQL content
      if (lowerContent.contains('select ') ||
          lowerContent.contains('from ') ||
          lowerContent.contains('where ') ||
          lowerContent.contains('insert into ') ||
          lowerContent.contains('update ') ||
          lowerContent.contains('delete from ')) {
        return 'SQL File';
      }

      // Check for PHP content
      if (lowerContent.contains('<?php') ||
          lowerContent.contains('<?=') ||
          lowerContent.contains(r'$') ||
          lowerContent.contains('echo ')) {
        return 'PHP File';
      }

      // Check for JSON content
      if ((lowerContent.startsWith('{') && lowerContent.endsWith('}')) ||
          (lowerContent.startsWith('[') && lowerContent.endsWith(']'))) {
        if (lowerContent.contains('"') || lowerContent.contains(":")) {
          return 'JSON File';
        }
      }

      // Check for YAML content
      if (lowerContent.startsWith('---') ||
          lowerContent.contains(': ') ||
          lowerContent.contains('  - ') ||
          lowerContent.contains('key: value')) {
        return 'YAML File';
      }

      // Check for Markdown content
      if (lowerContent.startsWith('# ') ||
          lowerContent.contains('## ') ||
          lowerContent.contains('### ') ||
          lowerContent.contains('#### ') ||
          lowerContent.contains('##### ') ||
          lowerContent.contains('###### ') ||
          lowerContent.contains('**') ||
          lowerContent.contains('* ') ||
          lowerContent.contains('1. ')) {
        return 'Markdown File';
      }
    }

    // Default to text file if we can't detect the type
    return 'Text File';
  }

  /// Detect file type and generate appropriate filename using robust detection
  Future<String> detectFileTypeAndGenerateFilename(
      String filename, String content,
      {String? contentType}) async {
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
        // Use simple descriptive names without extensions
        if (filename.contains('rss') || filename.contains('feed')) {
          return 'RSS Page.xml';
        }
        return 'index.html'; // Simple fallback for generated filenames
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
      return _fallbackContentDetection(filename, content);
    }
  }

  /// Fallback content detection when robust detection fails
  String _fallbackContentDetection(String filename, String content) {
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

    // Simple content-based detection
    final lowerContent = content.toLowerCase();

    if (lowerContent.contains('<html') ||
        lowerContent.contains('<!doctype html')) {
      return 'HTML File';
    }
    if (lowerContent.contains('body {') || lowerContent.contains('@media')) {
      return 'CSS File';
    }
    if (lowerContent.contains('function ') || lowerContent.contains('const ')) {
      return 'JavaScript File';
    }
    if ((lowerContent.startsWith('{') && lowerContent.endsWith('}')) ||
        (lowerContent.startsWith('[') && lowerContent.endsWith(']'))) {
      return 'JSON File';
    }
    if (lowerContent.startsWith('---') || lowerContent.contains(': ')) {
      return 'YAML File';
    }
    if (lowerContent.startsWith('# ') || lowerContent.contains('## ')) {
      return 'Markdown File';
    }
    if (tryParseAsXml(content)) {
      return 'XML File';
    }
    if (lowerContent.contains('public class ') ||
        lowerContent.contains('system.out.println')) {
      return 'Java File';
    }
    if (lowerContent.contains('#include ') ||
        lowerContent.contains('int main(')) {
      return 'C++ File';
    }
    if (lowerContent.contains('def ') || lowerContent.contains('print(')) {
      return 'Python File';
    }
    if (lowerContent.contains('select ') || lowerContent.contains('from ')) {
      return 'SQL File';
    }

    return 'Text File';
  }

  /// Try to parse content as XML
  /// Returns true if content appears to be valid XML
  bool tryParseAsXml(String content) {
    try {
      // Quick checks for XML-like content
      final trimmedContent = content.trim();

      // Must start with XML-like content
      if (!trimmedContent.startsWith('<') || !trimmedContent.contains('>')) {
        return false;
      }

      // Check for common XML patterns
      final lowerContent = trimmedContent.toLowerCase();

      // Common XML declarations and tags
      bool hasXmlDeclaration = lowerContent.startsWith('<?xml');
      bool hasXmlns = lowerContent.contains('xmlns=');
      bool hasXmlTags =
          lowerContent.contains('<') && lowerContent.contains('>');
      bool hasSelfClosingTags = lowerContent.contains('/>');
      bool hasXmlComments =
          lowerContent.contains('<!--') && lowerContent.contains('-->');

      // Common XML document structures
      bool hasRootElement = hasBalancedTags(trimmedContent);

      // If it has XML declaration or namespace, it's definitely XML
      if (hasXmlDeclaration || hasXmlns) {
        return true;
      }

      // If it has balanced tags and XML-like structure, likely XML
      if (hasXmlTags &&
          hasRootElement &&
          (hasSelfClosingTags || hasXmlComments)) {
        return true;
      }

      // Check for common XML document types
      if (lowerContent.contains('<rss ') || lowerContent.contains('<feed ')) {
        return true; // RSS/Atom feeds
      }
      if (lowerContent.contains('<svg ') || lowerContent.contains('<svg>')) {
        return true; // SVG
      }
      if (lowerContent.contains('<soap:envelope') ||
          lowerContent.contains('<soapenv:envelope')) {
        return true; // SOAP
      }
      if (lowerContent.contains('<wsdl:definitions') ||
          lowerContent.contains('<definitions ')) {
        return true; // WSDL
      }

      return false;
    } catch (e) {
      // If parsing fails, it's not valid XML
      return false;
    }
  }

  /// Check if content has balanced tags (simple check)
  bool hasBalancedTags(String content) {
    try {
      // Simple tag balancing check
      int openTags = 0;
      int closeTags = 0;

      for (int i = 0; i < content.length - 1; i++) {
        if (content[i] == '<' && content[i + 1] != '/') {
          // Opening tag (not closing tag)
          if (content[i + 1] != '!' && content[i + 1] != '?') {
            // Not a comment or declaration
            openTags++;
          }
        } else if (content[i] == '<' && content[i + 1] == '/') {
          // Closing tag
          closeTags++;
        }
      }

      // Tags are roughly balanced (allow some tolerance for self-closing tags)
      return openTags >= closeTags && (openTags - closeTags) <= 2;
    } catch (e) {
      return false;
    }
  }

  /// internal helper to cleaner check if file is valid for history
  bool _shouldAddToHistory(HtmlFile file) {
    if (file.path.isEmpty) return false;
    // Don't add shared text content to history
    if (file.path.startsWith('shared://')) return false;
    // Don't add content URIs (shared files) to history
    if (file.path.startsWith('content://')) return false;
    // Don't add error pages
    if (file.name == 'Content File Error' || file.name == 'Error') return false;

    return true;
  }

  Future<void> loadFile(HtmlFile file, {bool clearProbe = true}) async {
    _isWebViewMode = false; // Reset view mode on new file
    _isBeautifyEnabled = false; // Reset beautify mode on new file
    // Save current file to navigation stack if we are not going back
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
            probeResult: _probeResult ?? _currentFile!.probeResult);

        // Prevent duplicates in back stack (don't push if same as top)
        if (_navigationStack.isEmpty ||
            _navigationStack.last.path != fileToStack.path) {
          _navigationStack.add(fileToStack);
        }
      }
    }

    await clearFile(clearProbe: clearProbe);
    _currentFile = file;
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
          debugPrint('Detected language from content-type: $detectedLanguage');
          selectedContentType = detectedLanguage;
        }
      }
    }

    // Record in history if it has a path/URL
    if (_shouldAddToHistory(file)) {
      _urlHistoryService?.addUrl(file.path);
    }

    // Switch back to editor if this is a local file
    if (!file.isUrl) {}

    // Performance warning for large files
    final fileSizeMB = file.size / (1024 * 1024);
    if (file.size > 1 * 1024 * 1024) {
      // 1MB warning threshold
      debugPrint(
          '📄 Loading large file: ${file.name} (${fileSizeMB.toStringAsFixed(2)} MB)');
      if (file.size > 5 * 1024 * 1024) {
        // 5MB severe warning
        debugPrint(
            '⚠️  Very large file loading: ${file.name} (${fileSizeMB.toStringAsFixed(2)} MB)');
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
      // This handles cases where file extension might not match actual content type
      selectedContentType = _mapDetectedTypeToContentType(detectedType);

      // Ensure filename has correct extension based on detection
      // This is crucial for URLs that don't have file extensions (e.g. API endpoints returning images)
      if (file.isUrl) {
        final correctFilename = await detectFileTypeAndGenerateFilename(
          file.name,
          file.content,
          contentType: contentType,
        );

        if (correctFilename != file.name) {
          debugPrint('Fixing filename: ${file.name} -> $correctFilename');
          // Create new file with corrected name
          file = file.copyWith(name: correctFilename);
          _currentFile = file;
        }
      }
    } catch (e) {
      // If detection fails, fall back to automatic (null)
      selectedContentType = null;
    }

    _currentInputText = file.path;
    notifyListeners();
    _autoSave();
    await scrollToZero();

    // Extract metadata if it's HTML or XML
    if (_currentFile != null &&
        (selectedContentType == 'html' ||
            selectedContentType == 'xml' ||
            _currentFile!.name.endsWith('.html') ||
            _currentFile!.name.endsWith('.xml') ||
            _currentFile!.name.endsWith('.xhtml'))) {
      _extractMetadata();
    } else {
      _pageMetadata = null;
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

  void toggleIsWebViewMode() {
    _isWebViewMode = !_isWebViewMode;
    notifyListeners();
  }

  void toggleIsBeautifyEnabled() {
    _isBeautifyEnabled = !_isBeautifyEnabled;
    notifyListeners();
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
    await scrollToZero();
    _currentFile = null;
    _originalFile = null; // Also clear the original file
    selectedContentType = null; // Reset content type selection
    if (clearProbe) {
      _probeResult = null; // Clear probe results
      _probeError = null; // Clear probe errors
    }
    clearHighlightCache(); // Clear syntax highlighting cache
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
      'plaintext'
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
    _isNavigatingBack = true;
    try {
      await loadFile(previousFile, clearProbe: true);
    } finally {
      // Ensure we reset the flag even if loading fails
      _isNavigatingBack = false;
    }
  }

  Future<HtmlFile> _loadFromUrlInternal(String url) async {
    try {
      // Validate and sanitize URL
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      // Record in history is now handled in loadFile

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
      final client = http.Client();
      final stopwatch = Stopwatch()..start();
      String? ipAddress;

      // Resolve IP (part of probing)
      try {
        final addresses = await InternetAddress.lookup(uri.host)
            .timeout(const Duration(seconds: 2));
        if (addresses.isNotEmpty) {
          ipAddress = addresses.first.address;
        }
      } catch (e) {
        debugPrint('DNS Lookup failed: $e');
      }

      // Set proper headers to avoid 403 errors from websites that block non-browser clients
      final headers = {
        'User-Agent': 'curl/7.88.1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      };

      // Manual redirect handling to get the final URL and capture certificate
      final finalUrl = await _getFinalUrlAfterRedirects(uri, client, headers,
          originalUri: uri);

      // Update the input text immediately so the UI reflects the redirect while loading body
      if (finalUrl != url) {
        _currentInputText = finalUrl;
        notifyListeners();
      }

      // Use HttpClient for the final request to ensure we have the certificate
      final hClient = HttpClient();
      final hRequest = await hClient.openUrl('GET', Uri.parse(finalUrl));

      headers.forEach((key, value) {
        hRequest.headers.set(key, value);
      });

      final hResponse =
          await hRequest.close().timeout(const Duration(seconds: 30));

      // Capture certificate info
      Map<String, dynamic>? certInfo;
      if (hResponse.certificate != null) {
        certInfo = _extractCertificateInfo(hResponse.certificate!);
      }

      // Read body
      final bytes = await hResponse.fold<List<int>>([], (p, e) => p..addAll(e));
      final content = utf8.decode(bytes, allowMalformed: true);

      stopwatch.stop();

      // Convert HttpClient headers to a Map<String, String> for compatibility
      // Standardize on lowercase keys for consistent lookup
      final respHeaders = <String, String>{};
      hResponse.headers.forEach((name, values) {
        respHeaders[name.toLowerCase()] = values.join(', ');
      });

      // Construct Probe Result from the response
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
      // Check Content-Length header fallback
      if (contentLength <= 0 && respHeaders.containsKey('content-length')) {
        contentLength = int.tryParse(respHeaders['content-length']!);
      }

      final probeResult = {
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

      // Check for redirect location if it was a redirect (though we followed it, we might want to show original redirect info if possible, but manual redirect following makes this tricky. We can assume if finalUrl != url, a redirect happened)
      if (finalUrl != url) {
        // rough approximation since we followed redirects
        probeResult['redirectLocation'] = finalUrl;
      }

      // Update local probe result
      _probeResult = probeResult;
      _isProbing = false;

      if (hResponse.statusCode == 200) {
        // Security: Limit maximum content size to prevent memory issues
        if (content.length > 10 * 1024 * 1024) {
          // 10MB limit
          throw Exception('File size exceeds maximum limit (10MB)');
        }

        // Security: Limit maximum content size to prevent memory issues
        if (content.length > 10 * 1024 * 1024) {
          // 10MB limit
          throw Exception('File size exceeds maximum limit (10MB)');
        }

        // Parse the final URL to extract filename and other information
        final finalUri = Uri.parse(finalUrl);

        // Extract filename from final URL path segments
        final pathFilename =
            finalUri.pathSegments.isNotEmpty ? finalUri.pathSegments.last : '';

        // Generate descriptive filename if the path segment is not a clear filename
        final filename = pathFilename.isNotEmpty &&
                pathFilename.contains('.') &&
                !pathFilename.startsWith('_') &&
                pathFilename != 'index' &&
                pathFilename != 'home'
            ? pathFilename
            : generateDescriptiveFilename(finalUri, content);

        // Use robust file type detection to generate appropriate filename
        final headers = probeResult['headers'] as Map<String, String>?;
        final contentType = headers?['content-type'];
        final processedFilename = await detectFileTypeAndGenerateFilename(
            filename, content,
            contentType: contentType);

        final htmlFile = HtmlFile(
          name: processedFilename,
          path: finalUrl, // Use the final URL after redirects for the file path
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
          probeResult: probeResult,
        );

        return htmlFile;
      } else {
        throw Exception(
            'Failed to load URL: ${hResponse.statusCode} ${hResponse.reasonPhrase}');
      }
    } catch (e) {
      // Display error in the editor instead of throwing exception
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

      // Create error content similar to how file loading errors are handled
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

      final htmlFile = HtmlFile(
        name: url,
        path: url,
        content: errorContent,
        lastModified: DateTime.now(),
        size: errorContent.length,
        isUrl: true,
        isError: true,
      );

      return htmlFile;
    }
  }

  Future<void> loadFromUrl(String url, {int? switchToTab}) async {
    try {
      _currentInputText = url;
      _pendingUrl = url;
      _requestedTabIndex = switchToTab;
      _isLoading = true;
      notifyListeners();

      final file = await _loadFromUrlInternal(url);
      _pendingUrl = null;
      await loadFile(file);
      // loadFile already calls _autoSave() but we can be explicit here too
      _autoSave();
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

  // Map<String, dynamic> getHighlightTheme() => githubTheme;

  /// Probe a URL to get status code and headers without downloading the full content
  Future<Map<String, dynamic>> probeUrl(String url) async {
    _isProbing = true;
    _probeResult = null; // Reset previous results immediately
    _probeError = null;
    notifyListeners();
    _autoSave();
    try {
      // Validate and sanitize URL
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      final uri = Uri.parse(url);
      final client = http.Client();
      final stopwatch = Stopwatch()..start();
      String? ipAddress;

      // Resolve IP
      try {
        final addresses = await InternetAddress.lookup(uri.host)
            .timeout(const Duration(seconds: 2));
        if (addresses.isNotEmpty) {
          ipAddress = addresses.first.address;
        }
      } catch (e) {
        debugPrint('DNS Lookup failed: $e');
      }

      // Headers to mimic a browser/curl
      final headers = {
        'User-Agent': 'curl/7.88.1',
        'Accept': '*/*',
      };

      // Try HEAD request first (most efficient)
      final request = http.Request('HEAD', uri)..followRedirects = false;
      headers.forEach((key, value) => request.headers[key] = value);

      http.StreamedResponse streamedResponse;
      try {
        streamedResponse =
            await client.send(request).timeout(const Duration(seconds: 10));
      } catch (e) {
        // If HEAD fails (some servers block it), try GET with range header
        // or just close stream immediately
        debugPrint('HEAD request failed, trying GET: $e');
        final getRequest = http.Request('GET', uri)..followRedirects = false;
        headers.forEach((key, value) => getRequest.headers[key] = value);
        // Try to get just the first byte
        getRequest.headers['Range'] = 'bytes=0-0';

        streamedResponse =
            await client.send(getRequest).timeout(const Duration(seconds: 10));
      }

      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();
      client.close();

      int? contentLength = response.contentLength;

      debugPrint('Probe Headers: ${response.headers}');
      debugPrint('Initial ContentLength: $contentLength');

      // Check Content-Length header fallback
      if ((contentLength == null || contentLength == 0) &&
          response.headers.containsKey('content-length')) {
        contentLength = int.tryParse(response.headers['content-length']!);
        debugPrint('Parsed ContentLength from header: $contentLength');
      }

      // Check Content-Range header (for 206 Partial Content)
      // Format: bytes 0-0/12345
      if (response.headers.containsKey('content-range')) {
        final contentRange = response.headers['content-range']!;
        debugPrint('Parsing Content-Range: $contentRange');
        // Extract the total size (after the slash)
        final parts = contentRange.split('/');
        if (parts.length == 2 && parts[1] != '*') {
          final totalSize = int.tryParse(parts[1]);
          if (totalSize != null) {
            contentLength = totalSize;
            debugPrint(
                'Parsed Total Length from Content-Range: $contentLength');
          }
        }
      }

      // Standardize on lowercase keys for consistent lookup
      final normalizedHeaders = <String, String>{};
      response.headers.forEach((key, value) {
        normalizedHeaders[key.toLowerCase()] = value;
      });

      // Security Headers Check (using normalized lowercase keys)
      final securityHeaders = {
        'Strict-Transport-Security':
            normalizedHeaders['strict-transport-security'],
        'Content-Security-Policy': normalizedHeaders['content-security-policy'],
        'X-Frame-Options': normalizedHeaders['x-frame-options'],
        'X-Content-Type-Options': normalizedHeaders['x-content-type-options'],
        'Referrer-Policy': normalizedHeaders['referrer-policy'],
        'Permissions-Policy': normalizedHeaders['permissions-policy'],
      };

      // Cookies
      final setCookie = response.headers['set-cookie'];
      final List<String> cookies =
          setCookie != null ? setCookie.split(RegExp(r',(?=[^;]+?=)')) : [];

      final result = {
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
      };

      // Extract redirect location if present
      if (response.isRedirect) {
        final location = normalizedHeaders['location'];
        if (location != null && location.isNotEmpty) {
          // Resolve relative URLs
          final uri = Uri.parse(url);
          final redirectUri = uri.resolve(location);
          result['redirectLocation'] = redirectUri.toString();
        }
      }

      _probeResult = result;
      _isProbing = false;
      notifyListeners();
      _autoSave();

      return result;
    } catch (e) {
      debugPrint('Error probing URL: $e');
      _probeError = e.toString();
      _isProbing = false;
      notifyListeners();
      rethrow;
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
      String content, String extension, BuildContext context,
      {double fontSize = 16.0,
      String themeName = 'github',
      bool wrapText = false,
      bool showLineNumbers = true,
      ScrollController? customScrollController}) {
    // Performance monitoring and warnings for large files
    final contentSize = content.length;
    final contentSizeMB = contentSize / (1024 * 1024);

    // Warn about potential performance issues with large files
    if (contentSize > 1 * 1024 * 1024) {
      // 1MB warning threshold
      debugPrint(
          '🚨 Large file detected: ${contentSizeMB.toStringAsFixed(2)} MB');
      debugPrint('   Syntax highlighting may impact performance');
      debugPrint('   File extension: $extension');

      if (contentSize > 5 * 1024 * 1024) {
        // 5MB severe warning
        debugPrint(
            '⚠️  Very large file: ${contentSizeMB.toStringAsFixed(2)} MB');
        debugPrint('   Significant performance impact expected');

        // Show warning to user if context is available and mounted
        try {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Large file (${contentSizeMB.toStringAsFixed(1)} MB). Syntax highlighting may be slow.'),
                duration: const Duration(seconds: 4),
                // backgroundColor: Colors.orange,
              ),
            );
          });
        } catch (e) {
          debugPrint('Could not show large file warning: $e');
        }
      }
    }

    // Performance optimization: Use simplified highlighting for very large files
    bool useSimplifiedHighlighting =
        contentSize > 10 * 1024 * 1024; // 10MB threshold

    // Get the appropriate language for syntax highlighting
    final languageName = getLanguageForExtension(extension);

    // Generate a cache key based on content hash and parameters
    final cacheKey = _generateHighlightCacheKey(
        content: content,
        extension: extension,
        fontSize: fontSize,
        themeName: themeName,
        wrapText: wrapText,
        showLineNumbers: showLineNumbers,
        useSimplified: useSimplifiedHighlighting);

    // Add scroll controller identity to cache key to avoid issues if it changes
    final String fullCacheKey =
        '${cacheKey}_scroll:${customScrollController?.hashCode ?? 'none'}';

    // check widget cache
    if (_highlightCache.containsKey(fullCacheKey)) {
      debugPrint('🔄 Using cached highlighted widget');
      return _highlightCache[fullCacheKey]!;
    }

    // Create a controller for the code editor
    // Performance optimization: Use chunked content for very large files
    String processedContent = content;
    if (useSimplifiedHighlighting) {
      // For very large files, use a simplified approach
      // This reduces memory usage and parsing time
      debugPrint('🔧 Using simplified highlighting for very large file');

      // Limit the amount of content processed for syntax highlighting
      // while still showing the full content
      final maxHighlightLength = 50000; // ~50KB for highlighting
      if (content.length > maxHighlightLength) {
        // Take the first part for highlighting, but keep full content for display
        processedContent = content.substring(0, maxHighlightLength);
        debugPrint(
            '   Processing first ${maxHighlightLength ~/ 1024}KB for highlighting');
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
        theme: _getThemeByName(themeName));

    // Create the scroll controller for CodeEditor
    final codeScrollController = CodeScrollController(
        verticalScroller: effectiveVerticalController,
        horizontalScroller: _activeHorizontalScrollController);

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

    _highlightCache[fullCacheKey] = codeEditor;

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

  /// Generate cache key for highlighted content
  String _generateHighlightCacheKey({
    required String content,
    required String extension,
    required double fontSize,
    required String themeName,
    required bool wrapText,
    required bool showLineNumbers,
    required bool useSimplified,
  }) {
    // Create a hash of the content to use as part of the cache key
    final contentHash = _simpleHash(content);

    return 'hl:${contentHash}_ext:${extension}_fs:${fontSize.toStringAsFixed(1)}_th:${themeName}_wrap:${wrapText}_lines:${showLineNumbers}_simple:$useSimplified';
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
    _cachedControllers.clear();
    _cachedGlobalKeys.clear();
    for (final controller in _cachedHorizontalControllers.values) {
      controller.dispose();
    }
    _cachedHorizontalControllers.clear();
    _activeHorizontalScrollController = null;
    debugPrint('🧹 Cleared editor cache');
  }

  /// Check and enforce cache size limits
  void _enforceCacheSizeLimits() {
    const maxCacheEntries = 10;

    if (_cachedControllers.length > maxCacheEntries) {
      final keysToRemove = _cachedControllers.keys
          .take(_cachedControllers.length - maxCacheEntries)
          .toList();
      for (final key in keysToRemove) {
        _cachedControllers.remove(key);
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

    _cachedControllers
        .removeWhere((key, _) => key.startsWith(controllerKeyPrefix));
    _cachedGlobalKeys
        .removeWhere((key, _) => key.startsWith(controllerKeyPrefix));

    debugPrint('🧹 Cleared cache for content hash $contentHash');
  }

  /// Build the editor widget, returning strictly synchronous Widget if cached,
  /// or a Future if processing is needed.
  FutureOr<Widget> buildEditor(
      String content, String extension, BuildContext context,
      {double fontSize = 16.0,
      String themeName = 'github',
      bool wrapText = false,
      bool showLineNumbers = true}) {
    // Performance optimization: Use simplified highlighting for very large files
    final contentSize = content.length;
    bool useSimplifiedHighlighting = contentSize > 10 * 1024 * 1024;

    // Generate keys
    final controllerKey = _generateControllerCacheKey(
        content: content,
        extension: extension,
        useSimplified: useSimplifiedHighlighting);

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
          showLineNumbers);
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
        editorKey);
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
      final maxHighlightLength = 50000;
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
        showLineNumbers);
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
    String languageName =
        getLanguageForExtension(extension); // Use existing helper method

    // Resolve Scroll Controller
    final effectiveVerticalController = PrimaryScrollController.of(context);

    _verticalScrollController = effectiveVerticalController;

    // Create Theme
    final mode =
        _getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;
    final codeTheme = CodeHighlightTheme(
        languages: {languageName: CodeHighlightThemeMode(mode: mode)},
        theme: _getThemeByName(themeName));

    // Create CodeScrollController linked to CURRENT effective controller
    final codeScrollController = CodeScrollController(
        verticalScroller: effectiveVerticalController,
        horizontalScroller: horizontalController);

    // Return the Editor Widget, using the GlobalKey to preserve state
    return CodeEditor(
      key: key,
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
      String content, String extension, BuildContext context,
      {double fontSize = 16.0,
      String themeName = 'github',
      bool wrapText = false,
      bool showLineNumbers = true,
      ScrollController? customScrollController}) async {
    // Small delay to allow initial UI render (spinner)
    await Future.delayed(Duration.zero);

    // Check if mounted before proceeding (though context usage is in buildHighlightedText which is sync)
    if (!context.mounted) {
      return const SizedBox.shrink();
    }

    return buildHighlightedText(content, extension, context,
        fontSize: fontSize,
        themeName: themeName,
        wrapText: wrapText,
        showLineNumbers: showLineNumbers,
        customScrollController: customScrollController);
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
  Future<void> _extractMetadata() async {
    if (_currentFile == null) return;
    final html = _currentFile!.content;
    final baseUrl = _currentFile!.isUrl ? _currentFile!.path : '';

    try {
      _pageMetadata = await extractMetadataInIsolate(html, baseUrl);
    } catch (e) {
      debugPrint('Error extracting metadata in isolate: $e');
      _pageMetadata = null;
    }

    notifyListeners();
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

  Future<void> syncWebViewState(String url) async {
    if (activeWebViewController == null) return;

    // Update URL bar immediately
    if (_currentInputText != url) {
      _currentInputText = url;
      notifyListeners();
    }

    // Trigger probe for the new URL
    // We don't await this to keep UI responsive
    probeUrl(url).catchError((e) {
      debugPrint('Error probing synced URL: $e');
      return <String, dynamic>{};
    });

    try {
      final html = await activeWebViewController!.runJavaScriptReturningResult(
          'document.documentElement.outerHTML') as String;

      // Unquote if needed
      String finalHtml = html;
      if (finalHtml.startsWith('"') && finalHtml.endsWith('"')) {
        try {
          finalHtml = finalHtml
              .substring(1, finalHtml.length - 1)
              .replaceAll('\\"', '"')
              .replaceAll('\\\\', '\\')
              .replaceAll('\\n', '\n')
              .replaceAll('\\r', '\r')
              .replaceAll('\\t', '\t');
        } catch (e) {
          debugPrint('Error unquoting HTML: $e');
        }
      }

      // Update current file with new content BUT maintain webview mode
      final processedFilename =
          await detectFileTypeAndGenerateFilename(url, finalHtml);

      final htmlFile = HtmlFile(
          name: processedFilename,
          path: url,
          content: finalHtml,
          lastModified: DateTime.now(),
          size: finalHtml.length,
          isUrl: true);

      _currentFile = htmlFile;

      // Trigger metadata extraction for the new content
      await _extractMetadata();

      notifyListeners();
      _autoSave();
    } catch (e) {
      debugPrint('Error syncing WebView state: $e');
    }
  }

  void updateWebViewUrl(String url) {
    if (_currentInputText != url) {
      _currentInputText = url;
      notifyListeners();
    }
  }

  Future<void> extractCurrentWebViewContent() async {
    if (activeWebViewController == null) return;

    try {
      final url = await activeWebViewController!.currentUrl();
      final html = await activeWebViewController!.runJavaScriptReturningResult(
          'document.documentElement.outerHTML') as String;

      // Unquote if needed (standard JS result processing)
      String finalHtml = html;
      if (finalHtml.startsWith('"') && finalHtml.endsWith('"')) {
        try {
          finalHtml = finalHtml
              .substring(1, finalHtml.length - 1)
              .replaceAll('\\"', '"')
              .replaceAll('\\\\', '\\')
              .replaceAll('\\n', '\n')
              .replaceAll('\\r', '\r')
              .replaceAll('\\t', '\t');
        } catch (e) {
          debugPrint('Error unquoting HTML: $e');
        }
      }

      if (url != null) {
        final processedFilename =
            await detectFileTypeAndGenerateFilename(url, finalHtml);

        final htmlFile = HtmlFile(
            name: processedFilename,
            path: url,
            content: finalHtml,
            lastModified: DateTime.now(),
            size: finalHtml.length,
            isUrl: true);

        _currentFile = htmlFile;
        _currentInputText = url;
        _isWebViewMode = false; // Switch back to editor to show source
        notifyListeners();
        _autoSave();
      }
    } catch (e) {
      debugPrint('Error extracting WebView content: $e');
    }
  }
}
