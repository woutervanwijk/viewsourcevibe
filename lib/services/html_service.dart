import 'package:flutter/material.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:http/http.dart' as http;

class HtmlService with ChangeNotifier {
  HtmlFile? _currentFile;
  String _searchQuery = '';
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;

  HtmlFile? get currentFile => _currentFile;
  String get searchQuery => _searchQuery;
  List<int> get searchResults => _searchResults;
  int get currentSearchIndex => _currentSearchIndex;

  void loadFile(HtmlFile file) {
    _currentFile = file;
    _searchQuery = '';
    _searchResults = [];
    _currentSearchIndex = -1;
    notifyListeners();
  }

  void clearFile() {
    _currentFile = null;
    _searchQuery = '';
    _searchResults = [];
    _currentSearchIndex = -1;
    notifyListeners();
  }

  Future<void> loadFromUrl(String url) async {
    try {
      // Validate URL
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final content = response.body;
        final uri = Uri.parse(url);
        final filename = uri.pathSegments.isNotEmpty 
            ? uri.pathSegments.last 
            : 'webpage.html';
        
        final htmlFile = HtmlFile(
          name: filename,
          path: url,
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
        );
        
        loadFile(htmlFile);
      } else {
        throw Exception('Failed to load URL: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading URL: $e');
    }
  }

  void searchText(String query) {
    if (_currentFile == null || query.isEmpty) {
      _searchQuery = '';
      _searchResults = [];
      _currentSearchIndex = -1;
      notifyListeners();
      return;
    }

    _searchQuery = query;
    _searchResults = [];
    _currentSearchIndex = -1;
    
    final content = _currentFile!.content;
    final queryLower = query.toLowerCase();
    final contentLower = content.toLowerCase();
    
    int index = 0;
    while (true) {
      index = contentLower.indexOf(queryLower, index);
      if (index == -1) break;
      _searchResults.add(index);
      index += query.length;
    }
    
    if (_searchResults.isNotEmpty) {
      _currentSearchIndex = 0;
    }
    
    notifyListeners();
  }

  void navigateSearchResults(bool forward) {
    if (_searchResults.isEmpty) return;
    
    if (forward) {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    } else {
      _currentSearchIndex = (_currentSearchIndex - 1) % _searchResults.length;
      if (_currentSearchIndex < 0) _currentSearchIndex = _searchResults.length - 1;
    }
    
    notifyListeners();
  }

  Map<String, dynamic> getHighlightTheme() => githubTheme;

  String getLanguageForExtension(String extension) {
    final ext = extension.toLowerCase();
    return ext.contains('html') ? 'html'
         : ext == 'css' ? 'css'
         : ext == 'js' ? 'javascript'
         : ext == 'json' ? 'json'
         : ext == 'xml' ? 'xml'
         : 'html'; // Default
  }

  Widget buildHighlightedText(String content, String extension) => HighlightView(
    content,
    language: getLanguageForExtension(extension),
    theme: githubTheme,
    padding: const EdgeInsets.all(12),
    textStyle: const TextStyle(fontSize: 14),
  );
}