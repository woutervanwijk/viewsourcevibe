import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:htmlviewer/services/html_service.dart';

class SharingService {
  static const MethodChannel _channel = MethodChannel('com.htmlviewer.sharing');

  /// Share text content using native platform sharing
  static Future<void> shareText(String text) async {
    try {
      await _channel.invokeMethod('shareText', {'text': text});
    } on PlatformException catch (e) {
      print("Failed to share text: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share HTML content with optional filename
  static Future<void> shareHtml(String html, {String? filename}) async {
    try {
      await _channel.invokeMethod('shareHtml',
          {'html': html, 'filename': filename ?? 'shared_content.html'});
    } on PlatformException catch (e) {
      print("Failed to share HTML: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share file content
  static Future<void> shareFile(String filePath, {String? mimeType}) async {
    try {
      await _channel.invokeMethod('shareFile',
          {'filePath': filePath, 'mimeType': mimeType ?? 'text/html'});
    } on PlatformException catch (e) {
      print("Failed to share file: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Handle shared content received from other apps
  static Future<void> handleSharedContent(
    BuildContext context, {
    String? sharedText,
    String? sharedUrl,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      debugPrint('shared $sharedText - $sharedUrl');
      final htmlService = Provider.of<HtmlService>(context, listen: false);

      // Process the shared content based on type
      // Priority 1: Handle explicit URL sharing
      if (sharedUrl != null && sharedUrl.isNotEmpty) {
        // Handle shared URL
        await _processSharedUrl(context, htmlService, sharedUrl);
      }
      // Priority 2: Check if shared text is actually a URL
      else if (sharedText != null &&
          sharedText.isNotEmpty &&
          _isUrl(sharedText)) {
        // Handle text that looks like a URL
        await _processSharedUrl(context, htmlService, sharedText);
      }
      // Priority 3: Handle regular text content
      else if (sharedText != null && sharedText.isNotEmpty) {
        // Handle shared text
        await _processSharedText(context, htmlService, sharedText);
      }
      // Priority 4: Handle file bytes
      else if (fileBytes != null && fileBytes.isNotEmpty) {
        // Handle shared file bytes
        await _processSharedFileBytes(
            context, htmlService, fileBytes, fileName);
      }
      // Priority 5: Handle file path
      else if (filePath != null && filePath.isNotEmpty) {
        // Handle shared file path
        await _processSharedFilePath(context, htmlService, filePath);
      } else {
        // No valid content found
        debugPrint('SharingService: No valid shared content found');
        _showSnackBar(context, 'No valid content to display');
      }
    } catch (e, stackTrace) {
      debugPrint('SharingService: Error handling shared content: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar(context, 'Error loading shared content: ${e.toString()}');
    }
  }

  /// Process shared URL by loading it into the HTML service
  static Future<void> _processSharedUrl(
    BuildContext context,
    HtmlService htmlService,
    String url,
  ) async {
    try {
      debugPrint('SharingService: Loading URL: $url');

      // Show loading indicator
      _showSnackBar(context, 'Loading URL...');

      // Load the URL using the existing HTML service
      await htmlService.loadFromUrl(url);

      // Show success message
      _showSnackBar(context, 'URL loaded successfully!');

      // Ensure the content is displayed by notifying listeners
      // This is a workaround to ensure the UI updates properly
      htmlService.notifyListeners();

      // Add a small delay to ensure the URL input field updates properly
      // This gives the UI time to process the file change and update the URL display
      await Future.delayed(const Duration(milliseconds: 100));

      // Force another notification to ensure URL input updates
      htmlService.notifyListeners();
    } catch (e) {
      debugPrint('SharingService: Error loading URL: $e');
      _showSnackBar(context, 'Error loading URL: ${e.toString()}');
      rethrow;
    }
  }

  /// Process shared text by loading it as a new file
  static Future<void> _processSharedText(
    BuildContext context,
    HtmlService htmlService,
    String text,
  ) async {
    try {
      debugPrint(
          'SharingService: Handling shared text (${text.length} characters)');

      final htmlFile = HtmlFile(
        name: 'shared_text.txt',
        path: 'shared://text',
        content: text,
        lastModified: DateTime.now(),
        size: text.length,
      );

      htmlService.loadFile(htmlFile);
      _showSnackBar(context, 'Text loaded successfully!');
    } catch (e) {
      debugPrint('SharingService: Error handling shared text: $e');
      _showSnackBar(context, 'Error loading text: ${e.toString()}');
      rethrow;
    }
  }

  /// Process shared file bytes by creating a file and loading it
  static Future<void> _processSharedFileBytes(
    BuildContext context,
    HtmlService htmlService,
    List<int> bytes,
    String? fileName,
  ) async {
    try {
      debugPrint('SharingService: Handling file bytes (${bytes.length} bytes)');

      final content = String.fromCharCodes(bytes);
      final name = fileName ?? 'shared_file.txt';

      final htmlFile = HtmlFile(
        name: name,
        path: 'shared://file',
        content: content,
        lastModified: DateTime.now(),
        size: bytes.length,
      );

      htmlService.loadFile(htmlFile);
      _showSnackBar(context, 'File loaded successfully!');
    } catch (e) {
      debugPrint('SharingService: Error handling file bytes: $e');
      _showSnackBar(context, 'Error loading file: ${e.toString()}');
      rethrow;
    }
  }

  /// Process shared file path by reading and loading the file
  static Future<void> _processSharedFilePath(
    BuildContext context,
    HtmlService htmlService,
    String filePath,
  ) async {
    try {
      debugPrint('SharingService: Handling file path: $filePath');

      // Show loading indicator
      _showSnackBar(context, 'Loading file...');

      // Read file from filesystem
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      final fileName = filePath.split('/').last;

      final htmlFile = HtmlFile(
        name: fileName,
        path: filePath,
        content: content,
        lastModified: await file.lastModified(),
        size: await file.length(),
      );

      htmlService.loadFile(htmlFile);
      _showSnackBar(context, 'File loaded successfully!');
    } catch (e) {
      debugPrint('SharingService: Error handling file path: $e');
      _showSnackBar(context, 'Error loading file: ${e.toString()}');
      rethrow;
    }
  }

  /// Show snackbar message
  static void _showSnackBar(BuildContext context, String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('SharingService: Error showing snackbar: $e');
    }
  }

  /// Check if a string is a URL
  static bool _isUrl(String text) {
    // Remove any surrounding whitespace and quotes
    final trimmedText = text.trim();
    final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
        ? trimmedText.substring(1, trimmedText.length - 1)
        : (trimmedText.startsWith("'") && trimmedText.endsWith("'"))
            ? trimmedText.substring(1, trimmedText.length - 1)
            : trimmedText;

    // Check for common URL patterns
    final urlPattern = RegExp(
      r'^(https?://)?' // Optional http:// or https://
      r'([\w-]+\.)+[\w-]+' // Domain name
      r'(/[\w-./?%&=]*)?' // Optional path
      r'(\?[\w-./?%&=]*)?' // Optional query
      r'(#[\w-]*)?$', // Optional fragment
      caseSensitive: false,
    );

    // Additional checks for common URL characteristics
    final hasProtocol =
        cleanText.startsWith('http://') || cleanText.startsWith('https://');
    final hasDomain = cleanText.contains('.') && !cleanText.endsWith('.');
    final hasPathOrQuery = cleanText.contains('/') ||
        cleanText.contains('?') ||
        cleanText.contains('=');

    // Consider it a URL if it matches the pattern and has domain characteristics
    return urlPattern.hasMatch(cleanText) &&
        (hasProtocol || (hasDomain && hasPathOrQuery));
  }

  /// Check for shared content when app is launched
  static Future<Map<String, dynamic>?> checkForSharedContent() async {
    try {
      const MethodChannel channel =
          MethodChannel('info.wouter.sourceviewer/shared_content');
      final result = await channel.invokeMethod('getSharedContent');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      print('Error checking for shared content: $e');
      return null;
    }
  }
}
