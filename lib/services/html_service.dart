import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/vs.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

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

  Future<void> loadSampleFile() async {
    try {
      // Load sample HTML file from assets
      final content = await rootBundle.loadString('assets/sample.html');

      final htmlFile = HtmlFile(
        name: 'sample.html',
        path: 'assets/sample.html',
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
      );

      loadFile(htmlFile);
    } catch (e) {
      debugPrint('Error loading sample file: $e');
      // Fallback to a simple HTML sample if asset loading fails
      const fallbackContent = '''<!DOCTYPE html>
<html>
<head>
    <title>Sample HTML</title>
</head>
<body>
    <h1>Welcome to HTML Viewer</h1>
    <p>This is a sample HTML file for testing.</p>
</body>
</html>''';

      final htmlFile = HtmlFile(
        name: 'sample.html',
        path: 'fallback',
        content: fallbackContent,
        lastModified: DateTime.now(),
        size: fallbackContent.length,
      );

      loadFile(htmlFile);
    }
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
      if (_currentSearchIndex < 0) {
        _currentSearchIndex = _searchResults.length - 1;
      }
    }

    notifyListeners();
  }

  // Map<String, dynamic> getHighlightTheme() => githubTheme;

  String getLanguageForExtension(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'html' || ext == 'htm'
        ? 'xml' // Use vbscript-html for HTML files
        : ext == 'css'
            ? 'css'
            : ext == 'js'
                ? 'javascript'
                : ext == 'json'
                    ? 'json'
                    : ext == 'xml'
                        ? 'xml'
                        : 'plaintext'; // Default to plaintext if unknown
  }

  Mode? getReHighlightModeForExtension(String extension) {
    final languageName = getLanguageForExtension(extension);

    // Get the mode from re_highlight languages
    try {
      // Check if the language exists in re_highlight
      if (builtinAllLanguages.containsKey(languageName)) {
        return builtinAllLanguages[languageName]!;
      }

      // Fallback for HTML - try vbscript-html if html is requested
      if (languageName == 'html' ||
          languageName == 'htm' ||
          languageName == 'xml') {
        return builtinAllLanguages['xml'] ??
            builtinAllLanguages['xml'] ??
            builtinAllLanguages['plaintext']!;
      }

      // Ultimate fallback to plaintext
      return builtinAllLanguages['plaintext']!;
    } catch (e) {
      return builtinAllLanguages[
          'plaintext']!; // Fallback to plaintext if any error occurs
    }
  }

  Widget buildHighlightedText(String content, String extension,
      {double fontSize = 14.0, String themeName = 'github'}) {
    // Get the appropriate language for syntax highlighting
    final languageName = getLanguageForExtension(extension);

    // Create a controller for the code editor
    final controller = CodeLineEditingController.fromText(content);

    // Create a code theme using the VS theme
    final mode =
        _getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;
    final codeTheme = CodeHighlightTheme(
        languages: {languageName: CodeHighlightThemeMode(mode: mode)},
        theme: _getVsTheme());
    // final codeTheme = CodeHighlightTheme(
    //     languages: {'xml': CodeHighlightThemeMode(mode: langXml)},
    //     theme: atomOneLightTheme);

    return CodeEditor(
      controller: controller,
      readOnly: true,
      wordWrap: true,
      style: CodeEditorStyle(
        codeTheme: codeTheme,
        fontSize: fontSize,
        fontFamily: 'Courier',
        fontFamilyFallback: const ['monospace', 'Courier New'],
        fontHeight: 1.2,
      ),
      sperator: SizedBox(width: fontSize / 3),
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
        return DefaultCodeLineNumber(
          controller: editingController,
          notifier: notifier,
          textStyle: TextStyle(
            fontSize: fontSize,
            fontFamily: 'Courier',
            height: 1.2,
            fontFamilyFallback: const ['monospace', 'Courier New'],
            color: Colors.grey[600], // Subtle color for line numbers
          ),
        );
      },
    );
  }

  // Helper method to get re_highlight mode for language name
  Mode? _getReHighlightMode(String languageName) {
    // Map language names to re_highlight language names
    const languageMap = {
      'html': 'xml',
      'htm': 'xml',
      'css': 'css',
      'javascript': 'javascript',
      'js': 'javascript',
      'json': 'json',
      'xml': 'xml',
      'plaintext': 'plaintext',
    };

    final reLanguageName = languageMap[languageName] ?? 'plaintext';

    // Get the mode from re_highlight languages
    try {
      if (builtinAllLanguages.containsKey(reLanguageName)) {
        return builtinAllLanguages[reLanguageName]!;
      }
      return builtinAllLanguages['plaintext']!; // Fallback to plaintext
    } catch (e) {
      return builtinAllLanguages[
          'plaintext']!; // Fallback to plaintext if any error occurs
    }
  }

  // Helper method to get the VS theme for re_highlight
  Map<String, TextStyle> _getVsTheme() {
    // Use the built-in VS theme from re_highlight
    return vsTheme;
  }
}
