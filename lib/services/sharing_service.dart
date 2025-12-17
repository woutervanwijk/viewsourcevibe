import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      await _channel.invokeMethod('shareHtml', {
        'html': html,
        'filename': filename ?? 'shared_content.html'
      });
    } on PlatformException catch (e) {
      print("Failed to share HTML: '${e.message}'.");
      throw Exception("Sharing failed: ${e.message}");
    }
  }

  /// Share file content
  static Future<void> shareFile(String filePath, {String? mimeType}) async {
    try {
      await _channel.invokeMethod('shareFile', {
        'filePath': filePath,
        'mimeType': mimeType ?? 'text/html'
      });
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
      // This method would be implemented to handle content shared TO this app
      // For now, we'll just show a message indicating shared content was received
      
      String message = 'Received shared content:';
      if (sharedText != null) {
        message += '\nText: ${sharedText.substring(0, sharedText.length > 50 ? 50 : sharedText.length)}...';
      }
      if (sharedUrl != null) {
        message += '\nURL: $sharedUrl';
      }
      if (filePath != null) {
        message += '\nFile: $filePath';
      }
      if (fileBytes != null) {
        message += '\nFile bytes: ${fileBytes.length} bytes';
      }
      
      // Print the message for testing and debugging
      print(message);
      
      // Only show snackbar if we have a valid context and it's mounted
      // This check prevents errors in test environments
      try {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        // Ignore errors in test environments
        print('Snackbar display failed (likely in test): $e');
      }
      
      // Here you would typically process the shared content
      // For example, load it into the editor or save it as a file
      
    } catch (e) {
      print("Failed to handle shared content: '$e'.");
      try {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error handling shared content: $e')),
          );
        }
      } catch (e) {
        // Ignore errors in test environments
        print('Error snackbar display failed (likely in test): $e');
      }
    }
  }
}