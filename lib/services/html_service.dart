import 'package:flutter/material.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:re_editor/re_editor.dart';
import 'dart:async';
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
import 'package:flutter/services.dart';
import 'package:view_source_vibe/widgets/contextmenu.dart';
import 'package:view_source_vibe/services/file_type_detector.dart';

class HtmlService with ChangeNotifier {
  HtmlFile? _currentFile;
  HtmlFile? _originalFile; // Store original file for "Automatic" option
  String?
      _selectedContentType; // Track the selected content type for syntax highlighting
  ScrollController? _verticalScrollController;
  ScrollController? _horizontalScrollController;
  GlobalKey? _codeEditorKey;

  HtmlFile? get currentFile => _currentFile;
  String? get selectedContentType => _selectedContentType;
  ScrollController? get scrollController => _verticalScrollController;
  ScrollController? get horizontalScrollController =>
      _horizontalScrollController;
  GlobalKey? get codeEditorKey => _codeEditorKey;

  HtmlService() {
    _horizontalScrollController = ScrollController();
    _codeEditorKey = GlobalKey();
  }

  @override
  void dispose() {
    _verticalScrollController?.dispose();
    _horizontalScrollController?.dispose();
    super.dispose();
  }

  /// Generate a descriptive filename for URLs without clear filenames
  /// Uses domain name, path segments, and content type to create meaningful names
  String generateDescriptiveFilename(Uri uri, String content) {
    // Extract domain name (remove www. if present)
    String domain = uri.host;
    if (domain.startsWith('www.')) {
      domain = domain.substring(4);
    }

    // Clean domain name (remove common TLDs and subdomains)
    final domainParts = domain.split('.');
    if (domainParts.length >= 2) {
      // Keep main domain and first subdomain if it's meaningful
      // Remove common TLDs like com, org, net, io, etc.
      final commonTlds = {
        'com',
        'org',
        'net',
        'io',
        'co',
        'dev',
        'app',
        'tech',
        'info'
      };
      if (domainParts.length >= 3 &&
          commonTlds.contains(domainParts[domainParts.length - 2])) {
        // Pattern like example.co.uk or example.com.br
        domain = domainParts.sublist(domainParts.length - 3).join('.');
      } else {
        domain = domainParts.sublist(domainParts.length - 2).join('.');
      }
    }

    // Extract meaningful path segments (avoid common path segments)
    final pathSegments = uri.pathSegments
        .where((segment) =>
            segment.isNotEmpty &&
            !segment.startsWith('_') &&
            segment != 'index' &&
            segment != 'home' &&
            segment != 'page' &&
            segment != 'view')
        .toList();

    // Generate base filename
    String baseFilename;
    if (pathSegments.isNotEmpty) {
      // Use the last meaningful path segment
      baseFilename = pathSegments.last;
    } else {
      // Use domain name as base
      baseFilename = domain;
    }

    // Clean up the base filename
    baseFilename = baseFilename
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'),
            '-') // Replace special chars with hyphens
        .replaceAll(RegExp(r'-+'), '-') // Collapse multiple hyphens
        .replaceAll(RegExp(r'^-|-$'), ''); // Remove leading/trailing hyphens

    // Ensure reasonable length (max 40 characters for base, leaving room for content type suffix)
    if (baseFilename.length > 40) {
      baseFilename = baseFilename.substring(0, 40);
    }

    // If we end up with an empty filename, use a default
    if (baseFilename.isEmpty) {
      baseFilename = domain;
      if (baseFilename.isEmpty) {
        baseFilename = 'WebPage';
      }
    }

    // Check if base filename already has a proper file extension
    // If it does, we still need to verify it matches the content type
    final baseFilenameLower = baseFilename.toLowerCase();

    // First, detect the content type
    final lowerContent = content.toLowerCase();
    String detectedExtension = '';

    // HTML detection - be specific to avoid false positives with XML/RSS
    // Only detect as HTML if we have clear HTML indicators and no XML indicators
    bool hasHtmlIndicators = lowerContent.contains('<html') ||
        lowerContent.contains('<!doctype') ||
        lowerContent.contains('<head') ||
        lowerContent.contains('<body') ||
        lowerContent.contains('<div') ||
        lowerContent.contains('<span') ||
        lowerContent.contains('<style') ||
        lowerContent.contains('<script') ||
        lowerContent.contains('<meta') ||
        lowerContent.contains('<link') ||
        lowerContent.contains('<title') ||
        lowerContent.contains('<p') ||
        lowerContent.contains('<h') ||
        lowerContent.contains('<a ') ||
        lowerContent.contains('<img') ||
        lowerContent.contains('<table') ||
        lowerContent.contains('<ul') ||
        lowerContent.contains('<li');
    bool hasXmlIndicators = lowerContent.contains('<rss ') ||
        lowerContent.contains('<feed ') ||
        lowerContent.contains('<?xml') ||
        lowerContent.contains('xmlns=');

    bool isHtml = hasHtmlIndicators && !hasXmlIndicators;

    // CSS detection - only if not HTML
    // Be careful not to detect CSS embedded in HTML (like in <style> tags)
    bool isCss = !isHtml &&
        (lowerContent.contains('body {') || lowerContent.contains('@media'));

    // JavaScript detection - only if not HTML or CSS
    // Be very careful to avoid false positives in HTML files with script tags
    bool isJavaScript = !isHtml &&
        !isCss &&
        ((lowerContent.contains('function ') &&
                lowerContent.contains('{') &&
                lowerContent.contains('}')) ||
            (lowerContent.contains('const ') &&
                lowerContent.contains('=') &&
                lowerContent.contains(';') &&
                !lowerContent.contains('<script') &&
                !lowerContent.contains('</script>')) ||
            (lowerContent.contains('let ') &&
                lowerContent.contains('=') &&
                lowerContent.contains(';') &&
                !lowerContent.contains('<script') &&
                !lowerContent.contains('</script>')));

    // XML detection - check for RSS/Atom feeds and general XML
    bool isXml = lowerContent.contains('<rss ') ||
        lowerContent.contains('<feed ') ||
        lowerContent.contains('<?xml') ||
        lowerContent.contains('xmlns=') ||
        lowerContent.contains('<channel ') ||
        lowerContent.contains('<item ');

    // Determine the correct extension based on content
    // Prioritize XML detection over other types to fix RSS feed issue
    if (isXml) {
      detectedExtension = '.xml';
    } else if (isHtml) {
      detectedExtension = '.html';
    } else if (isCss) {
      detectedExtension = '.css';
    } else if (isJavaScript) {
      detectedExtension = '.js';
    }

    // If the filename already has an extension that matches the content type, use it
    if (detectedExtension.isNotEmpty) {
      if (baseFilenameLower.endsWith(detectedExtension)) {
        return baseFilename; // Extension matches content type
      } else {
        // Extension doesn't match content type, replace it
        // Remove any existing extension first
        final baseWithoutExt = baseFilename.split('.').first;
        return '$baseWithoutExt';
      }
    }

    // If no specific content type detected, check if filename has a proper extension
    final hasProperExtension = baseFilenameLower.endsWith('.html') ||
        baseFilenameLower.endsWith('.htm') ||
        baseFilenameLower.endsWith('.css') ||
        baseFilenameLower.endsWith('.js') ||
        baseFilenameLower.endsWith('.json') ||
        baseFilenameLower.endsWith('.xml') ||
        baseFilenameLower.endsWith('.yaml') ||
        baseFilenameLower.endsWith('.yml') ||
        baseFilenameLower.endsWith('.md') ||
        baseFilenameLower.endsWith('.txt') ||
        baseFilenameLower.endsWith('.py') ||
        baseFilenameLower.endsWith('.java') ||
        baseFilenameLower.endsWith('.dart') ||
        baseFilenameLower.endsWith('.cpp') ||
        baseFilenameLower.endsWith('.c') ||
        baseFilenameLower.endsWith('.cs') ||
        baseFilenameLower.endsWith('.php') ||
        baseFilenameLower.endsWith('.rb') ||
        baseFilenameLower.endsWith('.swift') ||
        baseFilenameLower.endsWith('.go') ||
        baseFilenameLower.endsWith('.rs') ||
        baseFilenameLower.endsWith('.sql');

    if (hasProperExtension) {
      return baseFilename;
    }

    // Don't add extensions for generated filenames
    return baseFilename;
  }

  /// Get the final URL after following all redirects manually
  /// This ensures we get the actual redirected URL, not the original
  Future<String> _getFinalUrlAfterRedirects(
      Uri uri, http.Client client, Map<String, String> headers) async {
    try {
      // Create a request that doesn't automatically follow redirects
      final request = http.Request('GET', uri)..followRedirects = false;

      // Add headers to the request
      headers.forEach((key, value) {
        request.headers[key] = value;
      });

      // Send the request
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));

      // Check if this is a redirect response
      if (response.isRedirect) {
        // Get the redirect location from headers
        final locationHeader = response.headers['location'];

        if (locationHeader != null && locationHeader.isNotEmpty) {
          // Handle relative redirects by resolving against the original URI
          final redirectUri = uri.resolve(locationHeader);

          // Recursively follow the redirect to get the final URL
          return await _getFinalUrlAfterRedirects(redirectUri, client, headers);
        }
      }

      // If not a redirect, return the original URL
      return uri.toString();
    } catch (e) {
      // If redirect handling fails, fall back to the original URL
      debugPrint('Error handling redirects: $e');
      return uri.toString();
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
        lowerContent.contains('<!doctype html')) htmlScore += 10;
    if (lowerContent.contains('<!doctype')) htmlScore += 8;
    if (lowerContent.contains('<head') || lowerContent.contains('<body'))
      htmlScore += 8;
    if (lowerContent.contains('</html>') ||
        lowerContent.contains('</head>') ||
        lowerContent.contains('</body>')) htmlScore += 8;

    // Medium HTML indicators
    if (lowerContent.contains('<div') || lowerContent.contains('<span'))
      htmlScore += 5;
    if (lowerContent.contains('<script') || lowerContent.contains('<style'))
      htmlScore += 5;
    if (lowerContent.contains('<meta') || lowerContent.contains('<link'))
      htmlScore += 5;
    if (lowerContent.contains('<title') || lowerContent.contains('<noscript'))
      htmlScore += 5;

    // Weak HTML indicators
    if (lowerContent.contains('<!')) htmlScore += 3;
    if (lowerContent.contains('</')) htmlScore += 3;
    if (lowerContent.contains('<img') || lowerContent.contains('<a '))
      htmlScore += 3;
    if (lowerContent.contains('<p') ||
        lowerContent.contains('<h') ||
        lowerContent.contains('<section')) htmlScore += 3;

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
      String filename, String content) async {
    try {
      // Use the robust file type detector
      final detectedType = await fileTypeDetector.detectFileType(
        filename: filename,
        content: content,
      );

      // Don't add extensions for generated filenames - preserve original or use simple names
      if (filename.isEmpty ||
          filename == '/' ||
          filename == 'index' ||
          !filename.contains('.') && !filename.contains('/')) {
        // Use simple descriptive names without extensions
        if (filename.contains('rss') || filename.contains('feed')) {
          return 'RSS Page';
        } // Simple fallback for generated filen}
        return 'Web Page'; // Simple fallback for generated filenames
      }

      // If filename already has a proper file extension, use it
      // Check for common file extensions to avoid false positives
      final filenameLower = filename.toLowerCase();
      final hasProperExtension = filenameLower.endsWith('.html') ||
          filenameLower.endsWith('.htm') ||
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
          filenameLower.endsWith('.sql');

      if (hasProperExtension) {
        return filename;
      }

      // Generate filename based on detected type with proper extension
      String properFilename;
      switch (detectedType.toLowerCase()) {
        case 'html':
          properFilename = 'document.html';
          break;
        case 'css':
          properFilename = 'styles.css';
          break;
        case 'javascript':
          properFilename = 'script.js';
          break;
        case 'typescript':
          properFilename = 'script.ts';
          break;
        case 'json':
          properFilename = 'data.json';
          break;
        case 'xml':
          properFilename = 'data.xml';
          break;
        case 'yaml':
        case 'yml':
          properFilename = 'config.yaml';
          break;
        case 'markdown':
        case 'md':
          properFilename = 'document.md';
          break;
        case 'python':
          properFilename = 'script.py';
          break;
        case 'java':
          properFilename = 'Main.java';
          break;
        case 'dart':
          properFilename = 'main.dart';
          break;
        case 'c':
        case 'cpp':
        case 'c++':
          properFilename = 'program.cpp';
          break;
        case 'csharp':
        case 'cs':
          properFilename = 'Program.cs';
          break;
        case 'php':
          properFilename = 'index.php';
          break;
        case 'ruby':
          properFilename = 'script.rb';
          break;
        case 'swift':
          properFilename = 'main.swift';
          break;
        case 'go':
          properFilename = 'main.go';
          break;
        case 'rust':
          properFilename = 'main.rs';
          break;
        case 'sql':
          properFilename = 'query.sql';
          break;
        case 'plaintext':
        case 'txt':
        case 'text':
          properFilename = 'document.txt';
          break;
        default:
          properFilename = 'document.$detectedType';
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

  Future<void> loadFile(HtmlFile file) async {
    await clearFile();
    _currentFile = file;
    _originalFile = file; // Store original file for "Automatic" option

    // Automatically detect content type for syntax highlighting
    // This ensures HTML content gets proper syntax highlighting even when loaded from URLs
    try {
      final detectedType = await fileTypeDetector.detectFileType(
        filename: file.name,
        content: file.content,
      );

      // Map detected type to appropriate content type for syntax highlighting
      // This handles cases where file extension might not match actual content type
      _selectedContentType = _mapDetectedTypeToContentType(detectedType);
    } catch (e) {
      // If detection fails, fall back to automatic (null)
      _selectedContentType = null;
    }

    notifyListeners();
    await scrollToZero();
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
    };

    return typeMapping[detectedType] ?? 'plaintext';
  }

  Future<void> scrollToZero() async {
    // Reset both vertical and horizontal scroll positions when loading new file
    if (_verticalScrollController?.hasClients ?? false) {
      _verticalScrollController?.jumpTo(0);
    }
    await Future.delayed(const Duration(milliseconds: 10));
    if (_horizontalScrollController?.hasClients ?? false) {
      _horizontalScrollController?.jumpTo(0);
    }
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> clearFile() async {
    await scrollToZero();
    _currentFile = null;
    notifyListeners();
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
        _selectedContentType = null; // Clear selected content type
        notifyListeners();
      }
      return;
    }

    // Update the selected content type for syntax highlighting
    _selectedContentType = newContentType;

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
  }

  Future<void> loadSampleFile() async {
    try {
      // Load sample HTML file from assets
      final content = await rootBundle.loadString('assets/sample.html');

      final htmlFile = HtmlFile(
        name: 'sample.html',
        path: 'assets/sample.html',
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
        isUrl: false,
      );

      await loadFile(htmlFile);
    } catch (e) {
      debugPrint('Error loading sample file: $e');
      // Fallback to a simple HTML sample if asset loading fails
      const fallbackContent = '''<!DOCTYPE html>
<html>
<head>
    <title>Sample HTML</title>
</head>
<body>
    <h1>Welcome to View Source Vibe</h1>
    <p>This is a sample HTML file for testing.</p>
</body>
</html>''';

      final htmlFile = HtmlFile(
        name: 'sample.html',
        path: 'fallback',
        content: fallbackContent,
        lastModified: DateTime.now(),
        size: fallbackContent.length,
        isUrl: false,
      );

      await loadFile(htmlFile);
    }
  }

  Future<void> loadFromUrl(String url) async {
    try {
      // Validate and sanitize URL
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
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
      final client = http.Client();

      // Set proper headers to avoid 403 errors from websites that block non-browser clients
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (compatible; ViewSourceVibe/1.0; +https://github.com/wouterviewsource/viewsourcevibe)',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      };

      // Manual redirect handling to get the actual redirected URL
      final finalUrl = await _getFinalUrlAfterRedirects(uri, client, headers);

      // Make the request to the final URL with timeout
      final response = await client
          .get(
            Uri.parse(finalUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final content = response.body;

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
        final processedFilename =
            await detectFileTypeAndGenerateFilename(filename, content);

        final htmlFile = HtmlFile(
          name: processedFilename,
          path: finalUrl,
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
        );

        await loadFile(htmlFile);
      } else {
        throw Exception(
            'Failed to load URL: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      // Provide more specific error messages
      if (e is TimeoutException) {
        throw Exception('Request timed out');
      } else if (e is FormatException) {
        throw Exception('Invalid URL format');
      } else {
        throw Exception('Error loading URL: $e');
      }
    }
  }

  // Map<String, dynamic> getHighlightTheme() => githubTheme;

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
      bool showLineNumbers = true}) {
    // Get the appropriate language for syntax highlighting
    final languageName = getLanguageForExtension(extension);

    // Create a controller for the code editor
    final controller = CodeLineEditingController.fromText(content);

    // Create context menu controller (not used directly, but available for future enhancements)
    // final contextMenuController = CodeEditorContextMenuController(
    //   context: context,
    //   editingController: controller,
    // );
    _verticalScrollController ??= PrimaryScrollController.of(context);
    // Create a code theme using the selected theme
    final mode =
        _getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;
    final codeTheme = CodeHighlightTheme(
        languages: {languageName: CodeHighlightThemeMode(mode: mode)},
        theme: _getThemeByName(themeName));
    // Create the scroll controller for CodeEditor
    final codeScrollController = CodeScrollController(
        verticalScroller:
            _verticalScrollController ?? PrimaryScrollController.of(context),
        horizontalScroller: _horizontalScrollController);

    // Return CodeEditor with context menu support
    return CodeEditor(
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
    );
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
      'yaml': 'yaml',
      'yml': 'yaml',
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
}
