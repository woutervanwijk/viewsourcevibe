import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/models/html_file.dart';

class AppStateService with ChangeNotifier {
  static const String _lastFileKey = 'last_file';
  static const String _lastUrlKey = 'last_url';
  static const String _lastScrollPositionKey = 'last_scroll_position';
  static const String _lastHorizontalScrollPositionKey =
      'last_horizontal_scroll_position';
  static const String _lastContentTypeKey = 'last_content_type';
  static const String _lastFileNameKey = 'last_file_name';
  static const String _lastFilePathKey = 'last_file_path';
  static const String _lastFileIsUrlKey = 'last_file_is_url';
  // Removed keys: the old probe result held cookie values. Deleted at startup.
  static const List<String> _legacyKeys = ['is_probe_visible', 'probe_result'];
  static const String _pendingUrlKey = 'pending_url';
  static const String _inputTextKey = 'input_text';

  final SharedPreferences _prefs;

  AppStateService(this._prefs);

  static Future<AppStateService> create() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyKeys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
    return AppStateService(prefs);
  }

  /// Save the current app state
  Future<void> saveAppState({
    HtmlFile? currentFile,
    double? scrollPosition,
    double? horizontalScrollPosition,
    String? contentType,
    String? pendingUrl,
    String? inputText,
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
        await _prefs.setDouble(
            _lastHorizontalScrollPositionKey, horizontalScrollPosition);
      }

      if (contentType != null) {
        await _prefs.setString(_lastContentTypeKey, contentType);
      }

      if (pendingUrl != null) {
        await _prefs.setString(_pendingUrlKey, pendingUrl);
      } else {
        await _prefs.remove(_pendingUrlKey);
      }

      if (inputText != null) {
        await _prefs.setString(_inputTextKey, inputText);
      } else {
        await _prefs.remove(_inputTextKey);
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
      // Check if we have any saved state - check several possible primary keys
      if (!_prefs.containsKey(_lastFilePathKey) &&
          !_prefs.containsKey(_lastFileKey) &&
          !_prefs.containsKey(_lastUrlKey)) {
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
        state.horizontalScrollPosition =
            _prefs.getDouble(_lastHorizontalScrollPositionKey);
      }

      // Load content type
      if (_prefs.containsKey(_lastContentTypeKey)) {
        state.contentType = _prefs.getString(_lastContentTypeKey);
      }

      if (_prefs.containsKey(_pendingUrlKey)) {
        state.pendingUrl = _prefs.getString(_pendingUrlKey);
      }

      if (_prefs.containsKey(_inputTextKey)) {
        state.inputText = _prefs.getString(_inputTextKey);
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
      await _prefs.remove(_pendingUrlKey);
      await _prefs.remove(_inputTextKey);

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
  String? pendingUrl;
  String? inputText;

  @override
  String toString() {
    return 'AppState(filePath: $filePath, fileName: $fileName, isUrl: $isUrl, scrollPosition: $scrollPosition, horizontalScrollPosition: $horizontalScrollPosition, contentType: $contentType, pendingUrl: $pendingUrl, inputText: $inputText)';
  }
}
