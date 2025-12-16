import 'package:flutter/material.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

class SharingService {
  /// Handle incoming shared content (URLs or files)
  static Future<void> handleSharedContent(
    BuildContext context, {
    String? sharedText,
    String? sharedUrl,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      final htmlService = Provider.of<HtmlService>(context, listen: false);
      
      // Debug log the shared content
      debugPrint('SharingService: Handling shared content');
      debugPrint('Shared text: ${sharedText ?? 'null'}');
      debugPrint('Shared URL: ${sharedUrl ?? 'null'}');
      debugPrint('File path: ${filePath ?? 'null'}');
      debugPrint('File name: ${fileName ?? 'null'}');
      debugPrint('File bytes length: ${fileBytes?.length ?? 'null'}');
      
      // Priority 1: Handle shared URL
      if (sharedUrl != null && sharedUrl.isNotEmpty) {
        await _handleSharedUrl(context, htmlService, sharedUrl);
        return;
      }
      
      // Priority 2: Handle shared text that looks like a URL
      if (sharedText != null && sharedText.isNotEmpty && _isUrl(sharedText)) {
        await _handleSharedUrl(context, htmlService, sharedText);
        return;
      }
      
      // Priority 3: Handle file bytes
      if (fileBytes != null && fileBytes.isNotEmpty) {
        await _handleSharedFileBytes(context, htmlService, fileBytes, fileName);
        return;
      }
      
      // Priority 4: Handle file path
      if (filePath != null && filePath.isNotEmpty) {
        await _handleSharedFilePath(context, htmlService, filePath);
        return;
      }
      
      // Priority 5: Handle shared text as content
      if (sharedText != null && sharedText.isNotEmpty) {
        await _handleSharedText(context, htmlService, sharedText);
        return;
      }
      
      // If nothing was handled
      debugPrint('SharingService: No valid shared content found');
      _showSnackBar(context, 'No valid content to display');
      
    } catch (e, stackTrace) {
      debugPrint('SharingService: Error handling shared content: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar(context, 'Error loading shared content: ${e.toString()}');
    }
  }
  
  /// Handle shared URL
  static Future<void> _handleSharedUrl(
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
      
    } catch (e) {
      debugPrint('SharingService: Error loading URL: $e');
      _showSnackBar(context, 'Error loading URL: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Handle shared file bytes
  static Future<void> _handleSharedFileBytes(
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
  
  /// Handle shared file path
  static Future<void> _handleSharedFilePath(
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
  
  /// Handle shared text content
  static Future<void> _handleSharedText(
    BuildContext context,
    HtmlService htmlService,
    String text,
  ) async {
    try {
      debugPrint('SharingService: Handling shared text (${text.length} characters)');
      
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
  
  /// Check if a string is a URL
  static bool _isUrl(String text) {
    return text.startsWith('http://') || 
           text.startsWith('https://') ||
           text.startsWith('www.');
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
}