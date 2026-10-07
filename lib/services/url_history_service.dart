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
    // Normalise and dedupe entries saved by older versions.
    _history = dedupe(_prefs.getStringList(_historyKey) ?? []);
  }

  /// Canonical form, as a browser's URL parser would store it:
  /// lowercase scheme and host, `/` for an empty path, no fragment.
  /// Non-http(s) entries (local file names) are returned unchanged.
  static String normalize(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return url;
    }
    return uri
        .replace(path: uri.path.isEmpty ? '/' : uri.path)
        .removeFragment()
        .toString();
  }

  /// What makes two entries the same suggestion: like Chrome's address bar,
  /// ignore the scheme, a leading `www.` and a trailing slash.
  static String dedupeKey(String url) {
    final uri = Uri.tryParse(normalize(url));
    if (uri == null || uri.host.isEmpty) return url;
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    var path = uri.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    return '$host$path${uri.hasQuery ? '?${uri.query}' : ''}';
  }

  /// Normalises [urls] and keeps the first (most recent) of each duplicate.
  static List<String> dedupe(List<String> urls) {
    final seen = <String>{};
    return [
      for (final url in urls.map(normalize))
        if (seen.add(dedupeKey(url))) url,
    ];
  }

  Future<void> addUrl(String url) async {
    if (url.isEmpty) return;

    // Replace any equivalent entry and move it to the top.
    final normalized = normalize(url);
    final key = dedupeKey(normalized);
    _history.removeWhere((entry) => dedupeKey(entry) == key);
    _history.insert(0, normalized);

    // Limit to 200 items
    if (_history.length > 200) {
      _history = _history.sublist(0, 200);
    }

    await _prefs.setStringList(_historyKey, _history);
    notifyListeners();
  }

  /// [from] redirected to [to]: keep only the destination, as browsers hide
  /// redirect sources from address bar suggestions.
  Future<void> replaceUrl(String from, String to) async {
    final key = dedupeKey(from);
    _history.removeWhere((entry) => dedupeKey(entry) == key);
    await addUrl(to);
  }

  Future<void> clearHistory() async {
    _history = [];
    await _prefs.remove(_historyKey);
    notifyListeners();
  }
}
