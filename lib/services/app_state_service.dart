import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/models/html_file.dart';

class AppStateService with ChangeNotifier {
  static const String _lastFileKey = 'last_file';
  static const String _lastUrlKey = 'last_url';
  static const String _lastScrollPositionKey = 'last_scroll_position';
  static const String _lastHorizontalScrollPositionKey = 'last_horizontal_scroll_position';
  static const String _lastContentTypeKey = 'last_content_type';
  static const String _lastFileNameKey = 'last_file_name';
  static const String _lastFilePathKey = 'last_file_path';
  static const String _lastFileIsUrlKey = 'last_file_is_url';

  final SharedPreferences _prefs;

  AppStateService(this._prefs);

  static Future<AppStateService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStateService(prefs);
  }

  /// Save the current app state
  Future<void> saveAppState({
    HtmlFile? currentFile,
    double? scrollPosition,
    double? horizontalScrollPosition,
    String? contentType,
  }) async {
    try {
      if (currentFile != null) {
        // Save file information
        await _prefs.setString(_lastFileNameKey, currentFile.name);
        await _prefs.setString(_lastFilePathKey, currentFile.path);
        await _prefs.setBool(_lastFileIsUrlKey, currentFile.isUrl);
        
        if (currentFile.isUrl) {
          await _prefs.setString(_lastUrlKey, currentFile.path);
        } else {
          // For regular files, we can't save the content, but we can save the path
          // The content will be reloaded when the app restarts
          await _prefs.setString(_lastFileKey, currentFile.path);
        }
      }

      if (scrollPosition != null) {
        await _prefs.setDouble(_lastScrollPositionKey, scrollPosition);
      }

      if (horizontalScrollPosition != null) {
        await _prefs.setDouble(_lastHorizontalScrollPositionKey, horizontalScrollPosition);
      }

      if (contentType != null) {
        await _prefs.setString(_lastContentTypeKey, contentType);
      }

      debugPrint('✅ App state saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving app state: $e');
      rethrow;
    }
  }

  /// Load saved app state
  AppState? loadAppState() {
    try {
      // Check if we have any saved state
      if (!_prefs.containsKey(_lastFileKey) && 
          !_prefs.containsKey(_lastUrlKey) &&
          !_prefs.containsKey(_lastFilePathKey)) {
        debugPrint('📂 No saved app state found');
        return null;
      }

      final state = AppState();

      // Load file information
      if (_prefs.containsKey(_lastFilePathKey)) {
        state.filePath = _prefs.getString(_lastFilePathKey);
        state.isUrl = _prefs.getBool(_lastFileIsUrlKey) ?? false;
        state.fileName = _prefs.getString(_lastFileNameKey) ?? '';
      }

      // Load scroll positions
      if (_prefs.containsKey(_lastScrollPositionKey)) {
        state.scrollPosition = _prefs.getDouble(_lastScrollPositionKey);
      }

      if (_prefs.containsKey(_lastHorizontalScrollPositionKey)) {
        state.horizontalScrollPosition = _prefs.getDouble(_lastHorizontalScrollPositionKey);
      }

      // Load content type
      if (_prefs.containsKey(_lastContentTypeKey)) {
        state.contentType = _prefs.getString(_lastContentTypeKey);
      }

      debugPrint('📂 App state loaded successfully: ${state.toString()}');
      return state;
    } catch (e) {
      debugPrint('❌ Error loading app state: $e');
      return null;
    }
  }

  /// Clear saved app state
  Future<void> clearAppState() async {
    try {
      await _prefs.remove(_lastFileKey);
      await _prefs.remove(_lastUrlKey);
      await _prefs.remove(_lastScrollPositionKey);
      await _prefs.remove(_lastHorizontalScrollPositionKey);
      await _prefs.remove(_lastContentTypeKey);
      await _prefs.remove(_lastFileNameKey);
      await _prefs.remove(_lastFilePathKey);
      await _prefs.remove(_lastFileIsUrlKey);

      debugPrint('🧹 App state cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing app state: $e');
      rethrow;
    }
  }
}

class AppState {
  String? filePath;
  String? fileName;
  bool? isUrl;
  double? scrollPosition;
  double? horizontalScrollPosition;
  String? contentType;

  @override
  String toString() {
    return 'AppState(filePath: $filePath, fileName: $fileName, isUrl: $isUrl, scrollPosition: $scrollPosition, horizontalScrollPosition: $horizontalScrollPosition, contentType: $contentType)';
  }
}