import 'package:flutter/material.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/vs.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class HtmlService with ChangeNotifier {
  HtmlFile? _currentFile;

  HtmlFile? get currentFile => _currentFile;

  void loadFile(HtmlFile file) {
    _currentFile = file;
    notifyListeners();
  }

  void clearFile() {
    _currentFile = null;
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

      // Use the http package's built-in redirect following
      // We'll make the request and then check if there were redirects
      final client = http.Client();

      // Make the request
      // Note: The http package automatically follows redirects, but doesn't expose the final URL
      // For complete redirect tracking, consider using packages like:
      // - http_with_middleware
      // - dio
      // - http_client with custom redirect handling
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final content = response.body;

        // Use the original URL since we can't get the final URL after redirects
        // with the standard http package
        // TODO: Consider upgrading to a more advanced HTTP client for full redirect support
        final finalUrl = url;

        final uri = Uri.parse(finalUrl);
        final filename =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'index';

        final htmlFile = HtmlFile(
          name: filename,
          path: finalUrl,
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

  // Map<String, dynamic> getHighlightTheme() => githubTheme;

  String getLanguageForExtension(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'html' || ext == 'htm'
        ? 'xml' // Use xml for HTML files
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

      // Fallback for HTML - try xml if html is requested
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

  Widget buildHighlightedText(
      String content, String extension, BuildContext context,
      {double fontSize = 14.0,
      String themeName = 'github',
      bool wrapText = false,
      bool showLineNumbers = true,
      ScrollController? scrollController}) {
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
      wordWrap: wrapText,
      scrollController: scrollController != null
          ? CodeScrollController(verticalScroller: scrollController)
          : CodeScrollController(
              verticalScroller: PrimaryScrollController.of(context)),
      style: CodeEditorStyle(
        codeTheme: codeTheme,
        fontSize: fontSize,
        fontFamily: 'Courier',
        fontFamilyFallback: const ['monospace', 'Courier New'],
        fontHeight: 1.2,
      ),
      sperator: showLineNumbers ? SizedBox(width: fontSize / 3) : null,
      indicatorBuilder: showLineNumbers
          ? (context, editingController, chunkController, notifier) {
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
            }
          : null,
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
