import 'dart:typed_data';
import 'package:mime_type/mime_type.dart';

/// Robust file type detection service using multiple strategies
class FileTypeDetector {
  // Cache for detection results to improve performance
  final Map<String, String> _detectionCache = {};

  /// Detect file type using multiple strategies
  /// Returns a file type identifier (e.g., 'HTML', 'JavaScript', 'Python')
  Future<String> detectFileType({
    String? filename,
    String? content,
    Uint8List? bytes,
  }) async {
    // Generate a cache key based on available inputs
    final cacheKey = _generateCacheKey(filename: filename, content: content, bytes: bytes);
    
    // Return cached result if available
    if (_detectionCache.containsKey(cacheKey)) {
      return _detectionCache[cacheKey]!;
    }

    String detectedType = 'Text';

    // Strategy 1: Extension-based detection (fastest)
    if (filename != null && filename.contains('.')) {
      detectedType = _detectByExtension(filename);
      if (detectedType != 'Text') {
        _detectionCache[cacheKey] = detectedType;
        return detectedType;
      }
    }

    // Strategy 2: MIME type detection from bytes
    if (bytes != null && bytes.isNotEmpty) {
      try {
        final mimeType = _detectMimeFromBytes(bytes);
        if (mimeType != null) {
          detectedType = _mimeToFileType(mimeType);
          if (detectedType != 'Text') {
            _detectionCache[cacheKey] = detectedType;
            return detectedType;
          }
        }
      } catch (e) {
        // Fall through to content analysis
      }
    }

    // Strategy 3: Content-based detection with scoring
    if (content != null && content.isNotEmpty) {
      detectedType = _detectByContent(content);
      _detectionCache[cacheKey] = detectedType;
      return detectedType;
    }

    // Fallback
    _detectionCache[cacheKey] = detectedType;
    return detectedType;
  }

  /// Detect file type by extension
  String _detectByExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    
    // Map extensions to file types
    const extensionMap = {
      // Web formats
      'html': 'HTML', 'htm': 'HTML', 'xhtml': 'HTML',
      'css': 'CSS',
      'js': 'JavaScript', 'mjs': 'JavaScript', 'cjs': 'JavaScript',
      'ts': 'TypeScript', 'jsx': 'JavaScript', 'tsx': 'TypeScript',
      'json': 'JSON', 'json5': 'JSON',
      'xml': 'XML', 'xsd': 'XML', 'xsl': 'XML', 'svg': 'XML',
      'yaml': 'YAML', 'yml': 'YAML',
      'vue': 'Vue', 'svelte': 'HTML',
      'md': 'Markdown', 'markdown': 'Markdown',
      'adoc': 'AsciiDoc', 'asciidoc': 'AsciiDoc',
      
      // Programming languages
      'dart': 'Dart',
      'py': 'Python', 'python': 'Python',
      'java': 'Java',
      'kt': 'Kotlin', 'kts': 'Kotlin',
      'swift': 'Swift',
      'go': 'Go',
      'rs': 'Rust', 'rust': 'Rust',
      'php': 'PHP',
      'rb': 'Ruby', 'ruby': 'Ruby',
      'cpp': 'C++', 'cc': 'C++', 'cxx': 'C++', 'h': 'C++', 'hpp': 'C++', 'hxx': 'C++',
      'c': 'C',
      'cs': 'C#',
      'scala': 'Scala',
      'hs': 'Haskell', 'haskell': 'Haskell',
      'lua': 'Lua',
      'pl': 'Perl', 'perl': 'Perl',
      'r': 'R',
      'sh': 'Bash', 'bash': 'Bash', 'zsh': 'Bash', 'fish': 'Bash',
      'ps1': 'PowerShell', 'psm1': 'PowerShell',
      
      // Configuration & Data
      'ini': 'INI', 'conf': 'INI', 'config': 'INI',
      'properties': 'Properties',
      'toml': 'TOML',
      'sql': 'SQL',
      'graphql': 'GraphQL', 'gql': 'GraphQL',
      'dockerfile': 'Dockerfile',
      'makefile': 'Makefile', 'mk': 'Makefile',
      'cmake': 'CMake',
      
      // Styling & Preprocessors
      'scss': 'SCSS', 'sass': 'SCSS',
      'less': 'LESS',
      'styl': 'Stylus', 'stylus': 'Stylus',
      
      // Other formats
      'diff': 'Diff', 'patch': 'Diff',
      'gitignore': 'Gitignore', 'ignore': 'Gitignore',
      'editorconfig': 'INI',
      'txt': 'Text', 'text': 'Text',
    };

    return extensionMap[ext] ?? 'Text';
  }

  /// Detect MIME type from file extension or content
  String? _detectMimeFromBytes(Uint8List bytes) {
    try {
      // Convert bytes to string for mime detection
      final content = String.fromCharCodes(bytes);
      return mime(content);
    } catch (e) {
      return null;
    }
  }

  /// Convert MIME type to file type
  String _mimeToFileType(String mimeType) {
    const mimeMap = {
      // Text formats
      'text/html': 'HTML',
      'text/css': 'CSS',
      'text/javascript': 'JavaScript',
      'application/javascript': 'JavaScript',
      'text/x-javascript': 'JavaScript',
      'application/json': 'JSON',
      'text/json': 'JSON',
      'application/xml': 'XML',
      'text/xml': 'XML',
      'text/x-markdown': 'Markdown',
      'text/markdown': 'Markdown',
      'text/plain': 'Text',
      
      // Programming languages
      'text/x-dart': 'Dart',
      'text/x-python': 'Python',
      'text/x-java': 'Java',
      'text/x-kotlin': 'Kotlin',
      'text/x-swift': 'Swift',
      'text/x-go': 'Go',
      'text/x-rust': 'Rust',
      'text/x-php': 'PHP',
      'text/x-ruby': 'Ruby',
      'text/x-c++': 'C++',
      'text/x-c': 'C',
      'text/x-csharp': 'C#',
      'text/x-scala': 'Scala',
      'text/x-haskell': 'Haskell',
      'text/x-lua': 'Lua',
      'text/x-perl': 'Perl',
      'text/x-r': 'R',
      'text/x-shellscript': 'Bash',
      'text/x-powershell': 'PowerShell',
      
      // Configuration files
      'text/x-ini': 'INI',
      'text/x-properties': 'Properties',
      'text/x-toml': 'TOML',
      'text/x-sql': 'SQL',
      'text/x-graphql': 'GraphQL',
      'text/x-dockerfile': 'Dockerfile',
      'text/x-makefile': 'Makefile',
      'text/x-cmake': 'CMake',
      
      // Web formats
      'text/x-scss': 'SCSS',
      'text/x-less': 'LESS',
      'text/x-stylus': 'Stylus',
    };

    return mimeMap[mimeType] ?? 'Text';
  }

  /// Detect file type by content analysis with scoring
  String _detectByContent(String content) {
    final lowerContent = content.toLowerCase();
    final scores = <String, int>{};

    // HTML detection
    if (lowerContent.contains('<html') || lowerContent.contains('<!doctype')) {
      scores['HTML'] = 20;
    }

    // CSS detection - more specific patterns
    if (lowerContent.contains('body {') || 
        lowerContent.contains('@media') ||
        lowerContent.contains('color: ') ||
        lowerContent.contains('font-') ||
        lowerContent.contains('margin:') ||
        lowerContent.contains('padding:') ||
        lowerContent.contains('display:') ||
        lowerContent.contains('position:') ||
        lowerContent.contains('text-align:') ||
        lowerContent.contains('background-')) {
      // Make sure it's not YAML by checking for CSS-specific structure
      if (lowerContent.contains('{') && lowerContent.contains('}')) {
        scores['CSS'] = 20; // Higher confidence for CSS
      } else {
        scores['CSS'] = 15;
      }
    }

    // JavaScript detection
    final jsKeywords = ['function', 'const', 'let', '=>', 'import', 'export', 'class'];
    final jsScore = jsKeywords.where((kw) => lowerContent.contains(kw)).length;
    if (jsScore > 2) scores['JavaScript'] = jsScore * 3;

    // TypeScript detection
    if (lowerContent.contains('interface ') || lowerContent.contains('type ') ||
        (lowerContent.contains('import ') && lowerContent.contains('from '))) {
      scores['TypeScript'] = 12;
    }

    // JSON detection
    if ((lowerContent.startsWith('{') && lowerContent.endsWith('}')) ||
        (lowerContent.startsWith('[') && lowerContent.endsWith(']'))) {
      if (lowerContent.contains('"') || lowerContent.contains(':')) {
        scores['JSON'] = 18;
      }
    }

    // YAML detection - more specific patterns
    if (lowerContent.startsWith('---') || 
        (lowerContent.contains(': ') && !lowerContent.contains('{') && !lowerContent.contains('}')) ||
        lowerContent.contains('  - ') ||
        lowerContent.contains('key: value') ||
        lowerContent.contains('list:') ||
        lowerContent.contains('map:')) {
      // Make sure it's not CSS by checking for YAML-specific structure
      if (!lowerContent.contains('body {') && !lowerContent.contains('@media')) {
        scores['YAML'] = 18; // Higher confidence for YAML
      } else {
        scores['YAML'] = 5; // Low confidence if CSS patterns are present
      }
    }

    // Markdown detection
    if (lowerContent.startsWith('# ') || lowerContent.contains('## ') ||
        lowerContent.contains('**') || lowerContent.contains('* ') ||
        lowerContent.contains('1. ')) {
      scores['Markdown'] = 12;
    }

    // XML detection
    if (lowerContent.startsWith('<?xml') || lowerContent.contains('<xml ') ||
        (lowerContent.contains('<') && lowerContent.contains('>') &&
         lowerContent.contains('/>'))) {
      scores['XML'] = 15;
    }

    // Python detection
    final pyKeywords = ['def ', 'class ', 'import ', 'from ', 'print('];
    final pyScore = pyKeywords.where((kw) => lowerContent.contains(kw)).length;
    if (pyScore > 2) scores['Python'] = pyScore * 4;

    // Java detection
    if (lowerContent.contains('public class ') || lowerContent.contains('system.out.println') ||
        lowerContent.contains('package ')) {
      scores['Java'] = 25; // High confidence
    }

    // C++ detection
    if (lowerContent.contains('#include ') || lowerContent.contains('int main(') ||
        lowerContent.contains('cout <<') || lowerContent.contains('namespace ')) {
      scores['C++'] = 20;
    }

    // C detection
    if (lowerContent.contains('#include ') || lowerContent.contains('int main(') ||
        lowerContent.contains('printf(')) {
      scores['C'] = 18;
    }

    // Ruby detection
    if (lowerContent.contains('puts ') || lowerContent.contains('require ') ||
        lowerContent.contains('gem ') || lowerContent.contains('bundle ')) {
      scores['Ruby'] = 15;
    }

    // PHP detection
    if (lowerContent.contains('<?php') || lowerContent.contains('<?=') ||
        lowerContent.contains('echo ')) {
      scores['PHP'] = 20;
    }

    // SQL detection
    final sqlKeywords = ['select ', 'from ', 'where ', 'join ', 'insert into', 'update ', 'delete from'];
    final sqlScore = sqlKeywords.where((kw) => lowerContent.contains(kw)).length;
    if (sqlScore > 2) scores['SQL'] = sqlScore * 5;

    // Dart detection
    if (lowerContent.contains('void main(') || lowerContent.contains('class ') ||
        (lowerContent.contains('import ') && lowerContent.contains('dart:'))) {
      scores['Dart'] = 18;
    }

    // Swift detection
    if (lowerContent.contains('import swift') || lowerContent.contains('class ') ||
        lowerContent.contains('func ')) {
      scores['Swift'] = 15;
    }

    // Go detection
    if (lowerContent.contains('package main') || lowerContent.contains('import (') ||
        lowerContent.contains('func main(')) {
      scores['Go'] = 18;
    }

    // Rust detection
    if (lowerContent.contains('fn main(') || lowerContent.contains('use std::') ||
        lowerContent.contains('impl ')) {
      scores['Rust'] = 15;
    }

    // Kotlin detection
    if (lowerContent.contains('fun main(') || lowerContent.contains('class ') ||
        lowerContent.contains('val ') || lowerContent.contains('var ')) {
      scores['Kotlin'] = 15;
    }

    // Find the highest scoring match
    if (scores.isNotEmpty) {
      final bestMatch = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (bestMatch.value > 10) { // Minimum confidence threshold
        return bestMatch.key;
      }
    }

    // Fallback to simple heuristics
    return _simpleContentDetection(content);
  }

  /// Simple content detection as fallback
  String _simpleContentDetection(String content) {
    final lowerContent = content.toLowerCase();

    if (lowerContent.contains('<html') || lowerContent.contains('<!doctype html')) {
      return 'HTML';
    }
    if (lowerContent.contains('body {') || lowerContent.contains('@media')) {
      return 'CSS';
    }
    if (lowerContent.contains('function ') || lowerContent.contains('const ') ||
        lowerContent.contains('let ') || lowerContent.contains('=>')) {
      return 'JavaScript';
    }
    if ((lowerContent.startsWith('{') && lowerContent.endsWith('}')) ||
        (lowerContent.startsWith('[') && lowerContent.endsWith(']'))) {
      return 'JSON';
    }
    if (lowerContent.startsWith('---') || lowerContent.contains(': ')) {
      return 'YAML';
    }
    if (lowerContent.startsWith('# ') || lowerContent.contains('## ')) {
      return 'Markdown';
    }
    if (lowerContent.contains('<?xml') || lowerContent.contains('<xml ')) {
      return 'XML';
    }
    if (lowerContent.contains('public class ') || lowerContent.contains('system.out.println')) {
      return 'Java';
    }
    if (lowerContent.contains('#include ') || lowerContent.contains('int main(')) {
      return 'C++';
    }
    if (lowerContent.contains('def ') || lowerContent.contains('print(')) {
      return 'Python';
    }
    if (lowerContent.contains('select ') || lowerContent.contains('from ') ||
        lowerContent.contains('where ')) {
      return 'SQL';
    }

    return 'Text';
  }

  /// Generate cache key for detection results
  String _generateCacheKey({String? filename, String? content, Uint8List? bytes}) {
    final parts = <String>[];
    
    if (filename != null) parts.add('fn:$filename');
    if (content != null) parts.add('ct:${content.length}');
    if (bytes != null) parts.add('by:${bytes.length}');
    
    return parts.join('|');
  }

  /// Clear detection cache
  void clearCache() {
    _detectionCache.clear();
  }
}

/// Singleton instance for easy access
final fileTypeDetector = FileTypeDetector();