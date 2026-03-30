import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_monaco/flutter_monaco.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:view_source_vibe/services/find_controller.dart';

class MonacoSourceViewerEditor {
  static final Map<String, MonacoController> _cachedControllers = {};
  static final Map<String, FindController> _cachedFindControllers = {};

  FindController? activeFindController;
  Function(FindController)? onFindControllerChanged;
  Function()? onSearchClosed;

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
      case 'bash':
      case 'sh':
        return 'bash';
      case 'plaintext':
      case 'txt':
      case 'text':
      default:
        return 'plaintext';
    }
  }

  static List<String> getAvailableLanguages() =>
      builtinAllLanguages.keys.toList();

  static MonacoTheme getMonacoThemeByName(String themeName) {
    switch (themeName.toLowerCase()) {
      case 'vs':
      case 'github':
        return MonacoTheme.vs;
      case 'vs-dark':
      case 'github-dark':
        return MonacoTheme.vsDark;
      case 'hc-black':
        return MonacoTheme.hcBlack;
      case 'hc-light':
        return MonacoTheme.hcLight;
      default:
        return MonacoTheme.vsDark;
    }
  }

  static Future<Widget> buildEditor({
    required String content,
    required String extension,
    required BuildContext context,
    ScrollController? verticalController,
    ScrollController? horizontalController,
    double fontSize = 16.0,
    String fontFamily = 'Courier',
    String themeName = 'github',
    bool wrapText = false,
    bool showLineNumbers = true,
    bool isBeautified = false,
    bool isSearchEnabled = false,
    FindController? activeFindController,
    Function(FindController)? onFindControllerChanged,
    Function()? onSearchClosed,
    Color backgroundColor = Colors.black,
  }) async {
    // For Monaco editor, we don't use external scroll controllers
    // as it handles scrolling internally for smooth performance
    // Ignore the passed scroll controllers
    // Update the instance variables if provided
    final editor = MonacoSourceViewerEditor();
    if (activeFindController != null) {
      editor.activeFindController = activeFindController;
    }
    if (onFindControllerChanged != null) {
      editor.onFindControllerChanged = onFindControllerChanged;
    }
    if (onSearchClosed != null) {
      editor.onSearchClosed = onSearchClosed;
    }

    final languageName = getLanguageForExtension(extension);

    // Use the actual content hash to ensure uniqueness
    // Include font size and other options in the key so changes force controller recreation
    final controllerKey = [
      extension,
      content.hashCode,
      content.length,
      isBeautified ? 'beautified' : 'raw',
      fontSize,
      themeName,
      wrapText,
      showLineNumbers
    ].join('_');

    // Check if we need to create a fresh controller due to content or option changes
    final existingController = _cachedControllers[controllerKey];
    final needFreshController = existingController == null;

    MonacoController? controller;
    FindController? findController;

    if (needFreshController) {
      // Dispose old controller if it exists
      existingController?.dispose();
      _cachedFindControllers[controllerKey]?.dispose();

      try {
        // Create Monaco controller with minimal options
        controller = await MonacoController.create(
          options: EditorOptions(
            language: _getMonacoLanguage(languageName),
            theme: getMonacoThemeByName(themeName),
            automaticLayout: true,
          ),
        );

        // Set the content
        await controller.setValue(content);

        _cachedControllers[controllerKey] = controller;

        findController = FindController();
        if (isSearchEnabled) {
          findController.isActive = true;
        }
        _cachedFindControllers[controllerKey] = findController;
      } catch (e) {
        debugPrint('Error creating Monaco controller: $e');
        return const Center(child: Text('Failed to load editor'));
      }
    } else {
      controller = existingController;
      findController = _cachedFindControllers[controllerKey];

      // Update content if changed
      try {
        final currentValue = await controller.getValue();
        if (currentValue != content) {
          await controller.setValue(content);
        }
      } catch (e) {
        debugPrint('Error updating content: $e');
      }
    }

    // Enforce cache limits
    if (_cachedControllers.length > 5) {
      final firstKey = _cachedControllers.keys.first;
      if (firstKey != controllerKey) {
        _cachedControllers.remove(firstKey)?.dispose();
        _cachedFindControllers.remove(firstKey)?.dispose();
      }
    }

    // Simple return - directly return the MonacoEditor
    if (content.isEmpty) {
      return const Center(
        child:
            Text('No content to display', style: TextStyle(color: Colors.grey)),
      );
    }
    if (Platform.isIOS) {
      fontSize *= 2.0;
    }
    return MonacoEditor(
      controller: controller,
      options: EditorOptions(
        language: _getMonacoLanguage(languageName),
        theme: getMonacoThemeByName(themeName),
        fontSize: fontSize,
        fontFamily: fontFamily,
        wordWrap: wrapText,
        lineNumbers: showLineNumbers,
        readOnly: true,
        automaticLayout: true,
        minimap: false,
      ),
      backgroundColor: Colors.black,
    );
  }

  static MonacoLanguage _getMonacoLanguage(String languageName) {
    switch (languageName.toLowerCase()) {
      case 'javascript':
      case 'js':
        return MonacoLanguage.javascript;
      case 'typescript':
      case 'ts':
        return MonacoLanguage.typescript;
      case 'html':
      case 'htm':
      case 'xhtml':
        return MonacoLanguage.html;
      case 'css':
        return MonacoLanguage.css;
      case 'json':
        return MonacoLanguage.json;
      case 'xml':
      case 'xsd':
      case 'xsl':
      case 'rss':
      case 'atom':
      case 'rdf':
      case 'svg':
        return MonacoLanguage.xml;
      case 'yaml':
      case 'yml':
        return MonacoLanguage.yaml;
      case 'markdown':
      case 'md':
        return MonacoLanguage.markdown;
      case 'python':
      case 'py':
        return MonacoLanguage.python;
      case 'dart':
        return MonacoLanguage.dart;
      case 'java':
        return MonacoLanguage.java;
      case 'c':
      case 'h':
        return MonacoLanguage.cpp;
      case 'cpp':
      case 'hpp':
        return MonacoLanguage.cpp;
      case 'csharp':
      case 'cs':
        return MonacoLanguage.csharp;
      case 'php':
        return MonacoLanguage.php;
      case 'ruby':
      case 'rb':
        return MonacoLanguage.ruby;
      case 'swift':
        return MonacoLanguage.swift;
      case 'go':
        return MonacoLanguage.go;
      case 'rust':
      case 'rs':
        return MonacoLanguage.rust;
      case 'sql':
        return MonacoLanguage.sql;
      case 'bash':
      case 'sh':
        return MonacoLanguage.shell;
      case 'plaintext':
      case 'txt':
      case 'text':
      default:
        return MonacoLanguage.plaintext;
    }
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
  }
}
