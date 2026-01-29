import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UrlHistoryService with ChangeNotifier {
  static const String _historyKey = 'url_history';
  final SharedPreferences _prefs;
  List<String> _history = [];

  UrlHistoryService(this._prefs) {
    _loadHistory();
  }

  static Future<UrlHistoryService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return UrlHistoryService(prefs);
  }

  List<String> get history => _history;

  void _loadHistory() {
    _history = _prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addUrl(String url) async {
    if (url.isEmpty) return;

    // Remove if already exists to move it to the top
    _history.remove(url);
    _history.insert(0, url);

    // Limit to 20 items
    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
    }

    await _prefs.setStringList(_historyKey, _history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history = [];
    await _prefs.remove(_historyKey);
    notifyListeners();
  }
}
