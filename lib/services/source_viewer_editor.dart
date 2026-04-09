import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:view_source_vibe/widgets/code_find_panel.dart';
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
import 'package:view_source_vibe/widgets/contextmenu.dart';

class SourceViewerEditor {
  static final Map<String, CodeLineEditingController> _cachedControllers = {};
  static final Map<String, CodeFindController> _cachedFindControllers = {};
  // Keyed by verticalScroller identity so CodeEditor gets a stable object
  // across rebuilds, preventing scroll listener teardown/re-setup jank.
  static final Map<ScrollController, CodeScrollController> _scrollControllerCache = {};

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
    required CodeFindController? activeFindController,
    required Function(CodeFindController) onFindControllerChanged,
    VoidCallback? onSearchClosed,
    double fontSize = 16.0,
    String fontFamily = 'Courier',
    String themeName = 'github',
    bool wrapText = false,
    bool showLineNumbers = true,
    bool isBeautified = false,
    bool isSearchEnabled = false,
    bool forceCodeForge = false,
  }) {
    final languageName = getLanguageForExtension(extension);
    final mode =
        getReHighlightMode(languageName) ?? builtinAllLanguages['plaintext']!;

    String processedContent = content;

    final contentHash = content.hashCode;
    final controllerKey =
        '${extension}_${contentHash}_${content.length}_${isBeautified ? 'beautified' : 'raw'}';

    final existingController = _cachedControllers[controllerKey];
    final needFreshController = existingController == null ||
        existingController.text != processedContent;

    if (needFreshController) {
      // CodeLineEditingController.fromText() only splits lines — actual syntax
      // highlighting is deferred to paint time by re_highlight. Creating it
      // synchronously avoids the FutureBuilder flash that previously showed a
      // "Parsing code..." spinner on every new file or tab switch.
      existingController?.dispose();
      _cachedFindControllers[controllerKey]?.dispose();

      final controller = CodeLineEditingController.fromText(processedContent);
      _cachedControllers[controllerKey] = controller;

      final findController = CodeFindController(controller);
      _cachedFindControllers[controllerKey] = findController;

      if (_cachedControllers.length > 5) {
        final firstKey = _cachedControllers.keys.first;
        if (firstKey != controllerKey) {
          _cachedControllers.remove(firstKey)?.dispose();
          _cachedFindControllers.remove(firstKey)?.dispose();
        }
      }
    }

    final controller = _cachedControllers[controllerKey]!;
    final findController = _cachedFindControllers[controllerKey]!;

    return _buildEditorWidget(
      controller,
      findController,
      wrapText,
      fontSize,
      languageName,
      mode,
      themeName,
      showLineNumbers,
      verticalController,
      horizontalController,
      activeFindController,
      onFindControllerChanged,
      isSearchEnabled,
      content,
    );
  }

  static Widget _buildEditorWidget(
    CodeLineEditingController controller,
    CodeFindController findController,
    bool wrapText,
    double fontSize,
    String languageName,
    Mode mode,
    String themeName,
    bool showLineNumbers,
    ScrollController verticalController,
    ScrollController? horizontalController,
    CodeFindController? activeFindController,
    Function(CodeFindController) onFindControllerChanged,
    bool isSearchEnabled,
    String content,
  ) {

    // Only register the callback when something actually needs to change,
    // to avoid queuing work on every rebuild that causes unnecessary jank.
    final needsFindControllerUpdate = activeFindController != findController;
    final needsSearchStateUpdate = isSearchEnabled
        ? findController.value == null
        : findController.value != null;
    if (needsFindControllerUpdate || needsSearchStateUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (activeFindController != findController) {
          onFindControllerChanged(findController);
        }
        if (isSearchEnabled && findController.value == null) {
          findController.findMode();
        } else if (!isSearchEnabled && findController.value != null) {
          findController.close();
        }
      });
    }

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
        try {
          if (content.isEmpty) {
            return const Center(
              child: Text('No content to display',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final scrollController = _scrollControllerCache.putIfAbsent(
            verticalController,
            () => CodeScrollController(
              verticalScroller: verticalController,
              horizontalScroller: horizontalController,
            ),
          );
          return RepaintBoundary(
            child: CodeEditor(
            scrollController: scrollController,
            controller: controller,
            findController: findController,
            wordWrap: wrapText,
            readOnly: true,
            style: CodeEditorStyle(
              fontSize: fontSize,
              fontFamily: 'Courier',
              fontFamilyFallback: const [
                'monospace',
                'Courier New',
                'Consolas',
              ],
              fontHeight: 1.2,
              codeTheme: CodeHighlightTheme(
                  languages: {languageName: CodeHighlightThemeMode(mode: mode)},
                  theme: getThemeByName(themeName)),
            ),
            indicatorBuilder:
                (context, editingController, chunkController, notifier) {
              return Row(
                children: [
                  if (showLineNumbers)
                    DefaultCodeLineNumber(
                      controller: editingController,
                      notifier: notifier,
                      textStyle: TextStyle(
                        fontSize: fontSize,
                        fontFamily: 'Courier',
                        height: 1.2,
                        fontFamilyFallback: const ['monospace', 'Courier New'],
                        color: Colors.grey[600],
                      ),
                    ),
                  DefaultCodeChunkIndicator(
                      width: 20,
                      controller: chunkController,
                      notifier: notifier)
                ],
              );
            },
            toolbarController: const ContextMenuControllerImpl(),
            findBuilder: (context, controller, readOnly) =>
                CodeFindPanelView(controller: controller, readOnly: readOnly),
          ));
        } catch (e, stackTrace) {
          debugPrint('Error rendering editor: $e\n$stackTrace');
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
                  fontFamilyFallback: const ['monospace', 'Courier New'],
                  height: 1.2,
                ),
              ),
            ),
          );
        }
      }

      return const Center(child: CircularProgressIndicator());
    });
  }

  static void clearCache() {
    for (final controller in _cachedControllers.values) {
      controller.dispose();
    }
    for (final controller in _cachedFindControllers.values) {
      controller.dispose();
    }
    _cachedControllers.clear();
    _cachedFindControllers.clear();
    _scrollControllerCache.clear();
  }
}
