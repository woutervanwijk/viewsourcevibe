import 'package:flutter/material.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/widgets/code_editor_with_context_menu.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/vs.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github-dark-dimmed.dart';
import 'package:re_highlight/styles/androidstudio.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/styles/vs2015.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';
import 'package:re_highlight/styles/monokai.dart';
import 'package:re_highlight/styles/nord.dart';
import 'package:re_highlight/styles/tokyo-night-dark.dart';
import 'package:re_highlight/styles/tokyo-night-light.dart';
import 'package:re_highlight/styles/dark.dart';
import 'package:re_highlight/styles/lightfair.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class HtmlService with ChangeNotifier {
  HtmlFile? _currentFile;
  ScrollController? _verticalScrollController;
  ScrollController? _horizontalScrollController;
  GlobalKey? _codeEditorKey;

  HtmlFile? get currentFile => _currentFile;
  ScrollController? get scrollController => _verticalScrollController;
  ScrollController? get horizontalScrollController =>
      _horizontalScrollController;
  GlobalKey? get codeEditorKey => _codeEditorKey;

  HtmlService() {
    _horizontalScrollController = ScrollController();
    _codeEditorKey = GlobalKey();
  }

  @override
  void dispose() {
    _verticalScrollController?.dispose();
    _horizontalScrollController?.dispose();
    super.dispose();
  }

  /// Ensure filename has proper extension based on content
  String ensureHtmlExtension(String filename, String content) {
    // Handle empty or unclear filenames
    if (filename.isEmpty ||
        filename == '/' ||
        filename == 'index' ||
        !filename.contains('.') && !filename.contains('/')) {
      filename = 'File';
    }

    // If filename already has an extension, use it
    if (filename.contains('.')) {
      return filename;
    }

    // Try to detect content type from content
    final lowerContent = content.toLowerCase();

    // Check for HTML content
    if (lowerContent.contains('<html') ||
        lowerContent.contains('<!doctype html') ||
        lowerContent.contains('<head') ||
        lowerContent.contains('<body')) {
      return 'HTML File';
    }

    // Check for CSS content
    if (lowerContent.contains('body {') ||
        lowerContent.contains('@media') ||
        lowerContent.contains('/* css')) {
      return 'CSS File';
    }

    // Check for JavaScript content
    if (lowerContent.contains('function(') ||
        lowerContent.contains('const ') ||
        lowerContent.contains('let ') ||
        lowerContent.contains('=>')) {
      return 'JavaScript File';
    }

    // Check for XML content first (more specific than HTML)
    if (tryParseAsXml(content)) {
      return 'XML File';
    }

    // Default to .txt if we can't detect the type
    return 'Text File';
  }

  /// Try to parse content as XML
  /// Returns true if content appears to be valid XML
  bool tryParseAsXml(String content) {
    try {
      // Quick checks for XML-like content
      final trimmedContent = content.trim();

      // Must start with XML-like content
      if (!trimmedContent.startsWith('<') || !trimmedContent.contains('>')) {
        return false;
      }

      // Check for common XML patterns
      final lowerContent = trimmedContent.toLowerCase();

      // Common XML declarations and tags
      bool hasXmlDeclaration = lowerContent.startsWith('<?xml');
      bool hasXmlns = lowerContent.contains('xmlns=');
      bool hasXmlTags =
          lowerContent.contains('<') && lowerContent.contains('>');
      bool hasSelfClosingTags = lowerContent.contains('/>');
      bool hasXmlComments =
          lowerContent.contains('<!--') && lowerContent.contains('-->');

      // Common XML document structures
      bool hasRootElement = hasBalancedTags(trimmedContent);

      // If it has XML declaration or namespace, it's definitely XML
      if (hasXmlDeclaration || hasXmlns) {
        return true;
      }

      // If it has balanced tags and XML-like structure, likely XML
      if (hasXmlTags &&
          hasRootElement &&
          (hasSelfClosingTags || hasXmlComments)) {
        return true;
      }

      // Check for common XML document types
      if (lowerContent.contains('<rss ') || lowerContent.contains('<feed ')) {
        return true; // RSS/Atom feeds
      }
      if (lowerContent.contains('<svg ') || lowerContent.contains('<svg>')) {
        return true; // SVG
      }
      if (lowerContent.contains('<soap:envelope') ||
          lowerContent.contains('<soapenv:envelope')) {
        return true; // SOAP
      }
      if (lowerContent.contains('<wsdl:definitions') ||
          lowerContent.contains('<definitions ')) {
        return true; // WSDL
      }

      return false;
    } catch (e) {
      // If parsing fails, it's not valid XML
      return false;
    }
  }

  /// Check if content has balanced tags (simple check)
  bool hasBalancedTags(String content) {
    try {
      // Simple tag balancing check
      int openTags = 0;
      int closeTags = 0;

      for (int i = 0; i < content.length - 1; i++) {
        if (content[i] == '<' && content[i + 1] != '/') {
          // Opening tag (not closing tag)
          if (content[i + 1] != '!' && content[i + 1] != '?') {
            // Not a comment or declaration
            openTags++;
          }
        } else if (content[i] == '<' && content[i + 1] == '/') {
          // Closing tag
          closeTags++;
        }
      }

      // Tags are roughly balanced (allow some tolerance for self-closing tags)
      return openTags >= closeTags && (openTags - closeTags) <= 2;
    } catch (e) {
      return false;
    }
  }

  Future<void> loadFile(HtmlFile file) async {
    await clearFile();
    _currentFile = file;
    notifyListeners();
    await scrollToZero();
  }

  Future<void> scrollToZero() async {
    // Reset both vertical and horizontal scroll positions when loading new file
    if (_verticalScrollController?.hasClients ?? false) {
      _verticalScrollController?.jumpTo(0);
    }
    await Future.delayed(const Duration(milliseconds: 10));
    if (_horizontalScrollController?.hasClients ?? false) {
      _horizontalScrollController?.jumpTo(0);
    }
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> clearFile() async {
    await scrollToZero();
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
        isUrl: false,
      );

      await loadFile(htmlFile);
    } catch (e) {
      debugPrint('Error loading sample file: $e');
      // Fallback to a simple HTML sample if asset loading fails
      const fallbackContent = '''<!DOCTYPE html>
<html>
<head>
    <title>Sample HTML</title>
</head>
<body>
    <h1>Welcome to View Source Vibe</h1>
    <p>This is a sample HTML file for testing.</p>
</body>
</html>''';

      final htmlFile = HtmlFile(
        name: 'sample.html',
        path: 'fallback',
        content: fallbackContent,
        lastModified: DateTime.now(),
        size: fallbackContent.length,
        isUrl: false,
      );

      await loadFile(htmlFile);
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

      // Set proper headers to avoid 403 errors from websites that block non-browser clients
      // Many websites like vn.nl and fiper.net require proper User-Agent headers
      final headers = {
        'User-Agent': 'curl/7.54.1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Upgrade-Insecure-Requests': '1',
      };

      // Make the request with proper headers
      // Note: The http package automatically follows redirects, but doesn't expose the final URL
      // For complete redirect tracking, consider using packages like:
      // - http_with_middleware
      // - dio
      // - http_client with custom redirect handling
      final response = await client.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final content = response.body;

        // Use the original URL since we can't get the final URL after redirects
        // with the standard http package
        // TODO: Consider upgrading to a more advanced HTTP client for full redirect support
        final finalUrl = url;

        final uri = Uri.parse(finalUrl);
        final filename =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'HTML File';

        // Ensure the filename has a proper extension for HTML content
        final processedFilename = ensureHtmlExtension(filename, content);

        final htmlFile = HtmlFile(
          name: processedFilename,
          path: finalUrl,
          content: content,
          lastModified: DateTime.now(),
          size: content.length,
          isUrl: true,
        );

        await loadFile(htmlFile);
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

    // Comprehensive language mapping for common file extensions
    switch (ext) {
      // Web Development
      case 'html':
      case 'htm':
      case 'xhtml':
        return 'xml'; // HTML is handled as XML in re_highlight
      case 'css':
        return 'css';
      case 'js':
      case 'javascript':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'ts':
      case 'typescript':
        return 'typescript';
      case 'jsx':
      case 'tsx':
        return 'javascript'; // JSX/TSX use JavaScript highlighting
      case 'json':
        return 'json';
      case 'json5':
        return 'json';
      case 'xml':
      case 'xsd':
      case 'xsl':
      case 'svg':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'vue':
        return 'vue';
      case 'svelte':
        return 'html'; // Svelte files use HTML highlighting

      // Markup & Documentation
      case 'md':
      case 'markdown':
        return 'markdown';
      case 'txt':
      case 'text':
        return 'plaintext';
      case 'adoc':
      case 'asciidoc':
        return 'asciidoc';

      // Programming Languages
      case 'dart':
        return 'dart';
      case 'py':
      case 'python':
        return 'python';
      case 'java':
        return 'java';
      case 'kt':
      case 'kts':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'go':
        return 'go';
      case 'rs':
      case 'rust':
        return 'rust';
      case 'php':
        return 'php';
      case 'rb':
      case 'ruby':
        return 'ruby';
      case 'cpp':
      case 'cc':
      case 'cxx':
      case 'c++':
      case 'h':
      case 'hpp':
      case 'hxx':
        return 'cpp';
      case 'c':
        return 'c';
      case 'cs':
        return 'csharp';
      case 'scala':
        return 'scala';
      case 'hs':
      case 'haskell':
        return 'haskell';
      case 'lua':
        return 'lua';
      case 'pl':
      case 'perl':
        return 'perl';
      case 'r':
        return 'r';
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
        return 'bash';
      case 'ps1':
      case 'psm1':
        return 'powershell';

      // Configuration & Data
      case 'ini':
      case 'conf':
      case 'config':
        return 'ini';
      case 'properties':
        return 'properties';
      case 'toml':
        return 'toml';
      case 'sql':
        return 'sql';
      case 'graphql':
      case 'gql':
        return 'graphql';
      case 'dockerfile':
        return 'dockerfile';
      case 'makefile':
      case 'mk':
        return 'makefile';
      case 'cmake':
        return 'cmake';

      // Styling & Preprocessors
      case 'scss':
      case 'sass':
        return 'scss';
      case 'less':
        return 'less';
      case 'styl':
      case 'stylus':
        return 'stylus';

      // Other Common Formats
      case 'diff':
      case 'patch':
        return 'diff';
      case 'gitignore':
      case 'ignore':
        return 'gitignore';
      case 'editorconfig':
        return 'ini';

      // Default fallback
      default:
        return 'xml';
    }
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
      {double fontSize = 16.0,
      String themeName = 'github',
      bool wrapText = false,
      bool showLineNumbers = true}) {
    // Get the appropriate language for syntax highlighting
    final languageName = getLanguageForExtension(extension);

    // Create a controller for the code editor
    final controller = CodeLineEditingController.fromText(content);

    // Create context menu controller (not used directly, but available for future enhancements)
    // final contextMenuController = CodeEditorContextMenuController(
    //   context: context,
    //   editingController: controller,
    // );
    _verticalScrollController ??= PrimaryScrollController.of(context);
    // Create a code theme using the selected theme
    final mode =
        _getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;
    final codeTheme = CodeHighlightTheme(
        languages: {languageName: CodeHighlightThemeMode(mode: mode)},
        theme: _getThemeByName(themeName));
    // Create the scroll controller for CodeEditor
    final codeScrollController = CodeScrollController(
        verticalScroller:
            _verticalScrollController ?? PrimaryScrollController.of(context),
        horizontalScroller: _horizontalScrollController);

    // Return CodeEditor with context menu support
    return CodeEditorWithContextMenu(
      controller: controller,
      readOnly: true,
      wordWrap: wrapText,
      padding: const EdgeInsets.fromLTRB(4, 8, 24, 48),
      scrollController: codeScrollController,
      style: CodeEditorStyle(
        codeTheme: codeTheme,
        fontSize: fontSize,
        fontFamily: 'Courier',
        fontFamilyFallback: const ['monospace', 'Courier New'],
        fontHeight: 1.2,
      ),
      sperator: showLineNumbers ? SizedBox(width: fontSize / 2) : null,
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
    // First, try the language name directly
    if (builtinAllLanguages.containsKey(languageName)) {
      return builtinAllLanguages[languageName]!;
    }

    // Map common language names to re_highlight language names
    const languageMap = {
      'html': 'xml',
      'htm': 'xml',
      'javascript': 'javascript',
      'js': 'javascript',
      'typescript': 'typescript',
      'ts': 'typescript',
      'jsx': 'javascript',
      'tsx': 'javascript',
      'yaml': 'yaml',
      'yml': 'yaml',
      'markdown': 'markdown',
      'md': 'markdown',
      'asciidoc': 'asciidoc',
      'adoc': 'asciidoc',
      'cpp': 'cpp',
      'c++': 'cpp',
      'csharp': 'csharp',
      'cs': 'csharp',
      'plaintext': 'plaintext',
      'txt': 'plaintext',
      'text': 'plaintext',
    };

    // Try the mapped language name
    final mappedLanguageName = languageMap[languageName];
    if (mappedLanguageName != null &&
        builtinAllLanguages.containsKey(mappedLanguageName)) {
      return builtinAllLanguages[mappedLanguageName]!;
    }

    // Special cases and fallbacks
    // HTML/XML family
    if (languageName == 'html' ||
        languageName == 'htm' ||
        languageName == 'xhtml') {
      return builtinAllLanguages['xml'] ?? builtinAllLanguages['plaintext']!;
    }

    // JavaScript family
    if (languageName == 'javascript' ||
        languageName == 'js' ||
        languageName == 'jsx' ||
        languageName == 'tsx') {
      return builtinAllLanguages['javascript'] ??
          builtinAllLanguages['plaintext']!;
    }

    // TypeScript
    if (languageName == 'typescript' || languageName == 'ts') {
      return builtinAllLanguages['typescript'] ??
          builtinAllLanguages['javascript'] ??
          builtinAllLanguages['plaintext']!;
    }

    // XML family
    if (languageName == 'xml' ||
        languageName == 'xsd' ||
        languageName == 'xsl' ||
        languageName == 'svg') {
      return builtinAllLanguages['xml'] ?? builtinAllLanguages['plaintext']!;
    }

    // Shell scripting
    if (languageName == 'bash' ||
        languageName == 'sh' ||
        languageName == 'zsh' ||
        languageName == 'fish' ||
        languageName == 'shell') {
      return builtinAllLanguages['bash'] ?? builtinAllLanguages['plaintext']!;
    }

    // Ultimate fallback to plaintext
    return builtinAllLanguages['plaintext']!;
  }

  // Helper method to get the appropriate theme for re_highlight based on theme name
  Map<String, TextStyle> _getThemeByName(String themeName) {
    switch (themeName) {
      case 'github':
        return githubTheme;
      case 'github-dark':
        return githubDarkTheme;
      case 'github-dark-dimmed':
        return githubDarkDimmedTheme;
      case 'androidstudio':
        return androidstudioTheme;
      case 'atom-one-dark':
        return atomOneDarkTheme;
      case 'atom-one-light':
        return atomOneLightTheme;
      case 'vs':
        return vsTheme;
      case 'vs2015':
        return vs2015Theme;
      case 'monokai-sublime':
        return monokaiSublimeTheme;
      case 'monokai':
        return monokaiTheme;
      case 'nord':
        return nordTheme;
      case 'tokyo-night-dark':
        return tokyoNightDarkTheme;
      case 'tokyo-night-light':
        return tokyoNightLightTheme;
      case 'dark':
        return darkTheme;
      case 'lightfair':
        return lightfairTheme;
      default:
        // Fallback to github theme
        return githubTheme;
    }
  }
}
