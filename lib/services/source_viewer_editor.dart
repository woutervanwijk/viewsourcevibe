import 'package:flutter/material.dart';
import 'package:code_forge/code_forge.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:view_source_vibe/widgets/custom_search_panel.dart';
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

class SourceViewerEditor {
  static final Map<String, CodeForgeController> _cachedControllers = {};

  static List<String> getAvailableLanguages() =>
      builtinAllLanguages.keys.toList();

  static String getLanguageForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'html':
      case 'htm':
      case 'xhtml':
        return 'html';
      case 'css':
        return 'css';
      case 'javascript':
      case 'js':
      case 'jsx':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'typescript':
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'json':
      case 'ipynb':
        return 'json';
      case 'xml':
      case 'xsd':
      case 'xsl':
      case 'rss':
      case 'atom':
      case 'rdf':
      case 'svg':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'markdown':
      case 'md':
        return 'markdown';
      case 'python':
      case 'py':
        return 'python';
      case 'dart':
        return 'dart';
      case 'java':
        return 'java';
      case 'c':
      case 'h':
        return 'c';
      case 'cpp':
      case 'hpp':
      case 'cc':
      case 'cxx':
        return 'cpp';
      case 'csharp':
      case 'cs':
        return 'csharp';
      case 'php':
        return 'php';
      case 'ruby':
      case 'rb':
        return 'ruby';
      case 'swift':
        return 'swift';
      case 'go':
        return 'go';
      case 'rust':
      case 'rs':
        return 'rust';
      case 'sql':
        return 'sql';
      case 'sh':
      case 'bash':
      case 'zsh':
        return 'bash';
      case 'plaintext':
      case 'txt':
      case 'text':
      default:
        return 'plaintext';
    }
  }

  static Mode? getReHighlightMode(String languageName) {
    if (builtinAllLanguages.containsKey(languageName)) {
      return builtinAllLanguages[languageName]!;
    }

    const languageMap = {
      'html': 'xml',
      'htm': 'xml',
      'javascript': 'javascript',
      'js': 'javascript',
      'typescript': 'typescript',
      'ts': 'typescript',
      'jsx': 'javascript',
      'tsx': 'javascript',
      'xml': 'xml',
      'xsd': 'xml',
      'xsl': 'xml',
      'svg': 'xml',
      'rss': 'xml',
      'atom': 'xml',
      'rdf': 'xml',
      'yaml': 'yaml',
      'yml': 'yaml',
      'markdown': 'markdown',
      'md': 'markdown',
      'python': 'python',
      'py': 'python',
      'dart': 'dart',
      'java': 'java',
      'c': 'c',
      'h': 'c',
      'cpp': 'cpp',
      'hpp': 'cpp',
      'csharp': 'csharp',
      'cs': 'csharp',
      'php': 'php',
      'ruby': 'ruby',
      'rb': 'ruby',
      'swift': 'swift',
      'go': 'go',
      'rust': 'rust',
      'rs': 'rust',
      'sql': 'sql',
      'bash': 'bash',
      'sh': 'bash',
      'plaintext': 'plaintext',
      'txt': 'plaintext',
      'text': 'plaintext',
    };

    final mappedLanguageName = languageMap[languageName];
    if (mappedLanguageName != null &&
        builtinAllLanguages.containsKey(mappedLanguageName)) {
      return builtinAllLanguages[mappedLanguageName]!;
    }
    return builtinAllLanguages['plaintext']!;
  }

  static Map<String, TextStyle> getThemeByName(String themeName) {
    switch (themeName.toLowerCase()) {
      case 'vs':
        return vsTheme;
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
        return githubTheme;
    }
  }

  static Widget buildEditor({
    required String content,
    required String extension,
    required BuildContext context,
    required ScrollController verticalController,
    ScrollController? horizontalController,
    required FindController? activeFindController,
    required Function(FindController) onFindControllerChanged,
    double fontSize = 16.0,
    String fontFamily = 'Courier',
    String themeName = 'github',
    bool wrapText = false,
    bool showLineNumbers = true,
    bool isBeautified = false,
    bool isSearchEnabled = false,
    bool forceCodeForge = false, // Force CodeForge even for large files
  }) {
    debugPrint('=== SourceViewerEditor.buildEditor called ===');
    debugPrint('isSearchEnabled: $isSearchEnabled');
    debugPrint('activeFindController: ${activeFindController != null}');
    
    final languageName = getLanguageForExtension(extension);
    final mode =
        getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;

    // Performance optimization for large files
    String processedContent = content;
    final contentSize = content.length;

    if (contentSize > 512 * 1024) {
      final maxHighlightLength = 512 * 1024;
      if (content.length > maxHighlightLength) {
        processedContent = content.substring(0, maxHighlightLength);
      }
    }

    // We need a unique key for the controller to avoid collisions
    // Use the actual content hash to ensure uniqueness
    final contentHash = content.hashCode;
    final controllerKey =
        '${extension}_${contentHash}_${content.length}_${isBeautified ? 'beautified' : 'raw'}';

    // Check if we need to create a fresh controller due to content changes
    final existingController = _cachedControllers[controllerKey];
    final needFreshController = existingController == null ||
        existingController.text != processedContent;

    if (needFreshController) {
      // Dispose old controller if it exists
      existingController?.dispose();

      // Create fresh controller with new content
      final controller = CodeForgeController()..text = processedContent;
      _cachedControllers[controllerKey] = controller;

      debugPrint(
          'SourceView: Created fresh controller for key: $controllerKey');
    }

    final controller = _cachedControllers[controllerKey]!;

    // Enforce cache limits
    if (_cachedControllers.length > 5) {
      final firstKey = _cachedControllers.keys.first;
      if (firstKey != controllerKey) {
        _cachedControllers.remove(firstKey)?.dispose();
      }
    }

    // We don't use a ValueKey on CodeForge itself anymore to prevent the 'ScrollController attached to multiple scroll views'
    // error during transitions (like toggling Beautify). By using the same widget type in the same tree position
    // without a key that changes with content, Flutter will perform an 'update' instead of a 'swap',
    // which gracefully handles the transition of the shared ScrollController.

    // Use LayoutBuilder to ensure we have proper constraints before rendering CodeForge
    return LayoutBuilder(builder: (context, constraints) {
      // Debug log constraints to help diagnose empty editor issues
      if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
        debugPrint(
            'CodeForge: Waiting for valid constraints - w: ${constraints.maxWidth}, h: ${constraints.maxHeight}');
      } else {
        debugPrint(
            'CodeForge: Rendering with constraints - w: ${constraints.maxWidth}, h: ${constraints.maxHeight}, content length: ${content.length}');
      }

      // Only render CodeForge if we have valid constraints
      if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
        try {
          // Additional check: don't render if content is empty
          if (content.isEmpty) {
            debugPrint('CodeForge: Content is empty, showing empty state');
            return const Center(
              child: Text('No content to display',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          return CodeForge(
            controller: controller,
            enableSuggestions: false,
            autoFocus: false,
            enableKeyboardSuggestions: false,
            readOnly: true,
            enableGutterDivider: false,
            enableGuideLines: false,
            lineWrap: wrapText,
            innerPadding: const EdgeInsets.fromLTRB(4, 8, 24, 48),
            verticalScrollController: verticalController,
            editorTheme: getThemeByName(themeName),
            language: mode,
            textStyle: TextStyle(
              fontSize: fontSize,
              fontFamily: 'Courier',
              height: 1.2,
            ),
            enableGutter: showLineNumbers,


            // Show the finder UI for search functionality
            finderBuilder: (context, finderController) {
              debugPrint('=== SourceViewerEditor.finderBuilder called ===');
              debugPrint('finderController: ${finderController.hashCode}');
              debugPrint('activeFindController: ${activeFindController?.hashCode}');
              
              // Always update the active find controller
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (activeFindController != finderController) {
                  debugPrint('=== Calling onFindControllerChanged ===');
                  onFindControllerChanged(finderController);
                } else {
                  debugPrint('=== Find controller unchanged, skipping callback ===');
                }
              });
              
              debugPrint('=== Returning CustomSearchPanel ===');
              return CustomSearchPanel(
                controller: finderController,
              );
            },
          );
        } catch (e, stackTrace) {
          debugPrint('Error rendering CodeForge editor: $e\n$stackTrace');
          // If CodeForge fails to render, show a fallback with the raw content
          return SingleChildScrollView(
            controller: verticalController,
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Courier',
                  height: 1.2,
                ),
              ),
            ),
          );
        }
      }

      // If constraints are not valid yet, show a loading indicator
      return const Center(child: CircularProgressIndicator());
    });
  }

  static void clearCache() {
    for (final controller in _cachedControllers.values) {
      controller.dispose();
    }
    _cachedControllers.clear();
  }
}
