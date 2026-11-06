import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SharingService {
  static const MethodChannel _channel =
      MethodChannel('info.wouter.sourceview.sharing');

  /// Share text content using native platform sharing
  static Future<void> shareText(String text) async {
    try {
      await _channel.invokeMethod('shareText', {'text': text});
    } on PlatformException catch (e) {
      debugPrint("Failed to share text: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share HTML content with optional filename
  static Future<void> shareHtml(String html, {String? filename}) async {
    try {
      // Handle empty or null filenames by providing a sensible default
      final effectiveFilename =
          filename?.isNotEmpty == true ? filename! : 'shared_content.html';

      await _channel.invokeMethod(
          'shareHtml', {'html': html, 'filename': effectiveFilename});
    } on PlatformException catch (e) {
      debugPrint("Failed to share HTML: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share file content
  static Future<void> shareFile(String filePath, {String? mimeType}) async {
    try {
      await _channel.invokeMethod('shareFile',
          {'filePath': filePath, 'mimeType': mimeType ?? 'text/html'});
    } on PlatformException catch (e) {
      debugPrint("Failed to share file: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share URL content using native platform sharing
  static Future<void> shareUrl(String url) async {
    try {
      await _channel.invokeMethod('shareUrl', {'url': url});
    } on PlatformException catch (e) {
      debugPrint("Failed to share URL: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Check if a string is a URL using Dart's Uri class for robust parsing
  @visibleForTesting
  static bool isUrl(String text) {
    // Remove any surrounding whitespace and quotes
    final trimmedText = text.trim();

    // Handle empty strings
    if (trimmedText.isEmpty) {
      return false;
    }

    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'"))
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText;

    // First, check if this is explicitly a file URL (file:// protocol)
    if (cleanText.startsWith('file://') || cleanText.startsWith('file///')) {
      debugPrint('SharingService: Detected file URL, not HTTP URL: $cleanText');
      return false; // This is a file URL, not an HTTP URL
    }

    // Check if this is likely a file path (starts with /) - do this early to avoid false positives
    if (cleanText.startsWith('/')) {
      debugPrint(
          'SharingService: Detected absolute file path, not URL: $cleanText');
      return false; // This is an absolute file path, not a URL
    }

    // Try to parse as URI - this is more robust than regex
    // Check if it's a valid HTTP/HTTPS URL first
    try {
      final uri = Uri.tryParse(cleanText);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        // This is a valid HTTP/HTTPS URL
        return true;
      }
    } catch (e) {
      // If parsing fails, continue with other checks
    }

    // Don't try to detect URLs without http:// or https:// schemes
    // This prevents false positives for text like "example.com" or "www.example.com"
    // Only explicit http:// or https:// URLs should be detected as URLs

    // Check for file path patterns in the text
    if (cleanText.contains('Users/') ||
        cleanText.contains('Library/') ||
        cleanText.contains('Containers/') ||
        cleanText.contains('Applications/')) {
      debugPrint(
          'SharingService: Detected file path pattern, not URL: $cleanText');
      return false; // This contains file path patterns, not a URL
    }

    return false; // Not a URL
  }

  /// Check if a string is a file path
  @visibleForTesting
  static bool isFilePath(String text) {
    // Remove any surrounding whitespace and quotes
    final trimmedText = text.trim();

    // Handle empty strings
    if (trimmedText.isEmpty) {
      return false;
    }

    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'"))
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText;

    // First, check if it's definitely NOT a file path (it's a URL)
    if (cleanText.startsWith('http://') ||
        cleanText.startsWith('https://') ||
        cleanText.startsWith('www.') ||
        cleanText.startsWith('ftp://')) {
      return false;
    }

    // Check for file path patterns - be more specific
    // First check for absolute paths and special prefixes
    if (cleanText.startsWith('/') ||
        cleanText.startsWith('file://') ||
        cleanText.startsWith('file///') ||
        cleanText.startsWith('./') ||
        cleanText.startsWith('../')) {
      debugPrint(
          'SharingService: Detected file path (absolute/relative): $cleanText');
      return true;
    }

    // Then check for paths containing directory separators and common directory names
    if (cleanText.contains('/Users/') ||
        cleanText.contains('/Library/') ||
        cleanText.contains('/Containers/') ||
        cleanText.contains('/Applications/') ||
        cleanText.contains('/var/mobile/') ||
        cleanText.contains('/private/var/') ||
        cleanText.contains('.app/') ||
        cleanText.contains('/Documents/') ||
        cleanText.contains('/Downloads/') ||
        cleanText.contains('/Desktop/') ||
        cleanText.contains('Documents/') ||
        cleanText.contains('Downloads/') ||
        cleanText.contains('Desktop/') ||
        cleanText.contains('assets/') ||
        cleanText.contains('resources/') ||
        cleanText.contains('temp/') ||
        cleanText.contains('cache/') ||
        cleanText.contains('data/') ||
        cleanText.contains('files/') ||
        cleanText.contains('documents/') ||
        cleanText.contains('images/') ||
        cleanText.contains('videos/')) {
      debugPrint(
          'SharingService: Detected file path (with directory): $cleanText');
      return true;
    }

    // Check for simple filenames with extensions (but not URLs)
    if (!cleanText.contains('/') &&
        !cleanText.contains('\\') && // Don't match Windows paths
        !cleanText.contains('://') &&
        cleanText.contains('.') &&
        !cleanText
            .startsWith('.') && // Don't match hidden files like .gitignore
        cleanText.length > 3) {
      // At least "a.b"
      debugPrint('SharingService: Detected simple filename: $cleanText');
      return true;
    }

    return false;
  }

  /// Check for shared content when app is launched
  static Future<Map<String, dynamic>?> checkForSharedContent() async {
    try {
      const MethodChannel channel =
          MethodChannel('info.wouter.sourceviewer/shared_content');
      final result = await channel.invokeMethod('getSharedContent');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      debugPrint('Error checking for shared content: $e');
      return null;
    }
  }
}
