import 'package:flutter/services.dart';

class PlatformSharingHandler {
  static const MethodChannel _channel =
      MethodChannel('info.wouter.sourceviewer/sharing');

  static void setup() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'handleSharedText':
            final text = call.arguments as String?;
            return _handleSharedText(text);
          case 'handleSharedUrl':
            final url = call.arguments as String?;
            return _handleSharedUrl(url);
          case 'handleSharedFile':
            final args = call.arguments as Map<dynamic, dynamic>?;
            return _handleSharedFile(args);
          default:
            throw MissingPluginException(
                'Method ${call.method} not implemented');
        }
      } catch (e) {
        print('Error handling platform sharing: $e');
        return {'error': e.toString()};
      }
    });
  }

  static Future<Map<String, dynamic>> _handleSharedText(String? text) async {
    try {
      if (text != null && text.isNotEmpty) {
        // Note: We can't access BuildContext here, so we'll handle this
        // in the platform-specific code and pass it to the main app
        return {'success': true, 'type': 'text', 'content': text};
      }
      return {'success': false, 'error': 'No text provided'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _handleSharedUrl(String? url) async {
    try {
      if (url != null && url.isNotEmpty) {
        return {'success': true, 'type': 'url', 'content': url};
      }
      return {'success': false, 'error': 'No URL provided'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _handleSharedFile(
      Map<dynamic, dynamic>? args) async {
    try {
      if (args != null && args.isNotEmpty) {
        final filePath = args['path'] as String?;
        final fileName = args['name'] as String?;
        final bytes = args['bytes'] as List<int>?;

        if (filePath != null || bytes != null) {
          return {
            'success': true,
            'type': 'file',
            'path': filePath,
            'name': fileName,
            'bytes': bytes
          };
        }
      }
      return {'success': false, 'error': 'No file data provided'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Call this method when the app is ready to handle shared content
  static Future<Map<String, dynamic>?> checkForInitialSharedContent() async {
    try {
      final result = await _channel.invokeMethod('getInitialSharedContent');
      if (result != null && result is Map) {
        final type = result['type'] as String?;
        final content = result['content'];

        if (type != null && content != null) {
          print('Initial shared content found: $type');
          return {
            'type': type,
            'content': content,
            'fileName': result['fileName'],
            'filePath': result['filePath'],
            'fileBytes': result['fileBytes']
          };
        }
      }
    } catch (e) {
      print('No initial shared content or error checking: $e');
    }
    return null;
  }

  /// Register a callback to handle shared content when the app is launched with it
  static void registerSharedContentHandler(
      Function(Map<String, dynamic>) handler) {
    _sharedContentHandler = handler;
  }

  /// Internal handler for shared content
  static Function(Map<String, dynamic>)? _sharedContentHandler;

  /// Process shared content using the registered handler
  static Future<void> processSharedContent(
      Map<String, dynamic> sharedData) async {
    if (_sharedContentHandler != null) {
      try {
        _sharedContentHandler!(sharedData);
      } catch (e) {
        print('Error in shared content handler: $e');
      }
    }
  }
}
