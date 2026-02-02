import 'dart:typed_data';
import 'package:mime_type/mime_type.dart';

// Extension method for comparing lists
extension ListEquals on List<int> {
  bool equals(List<int> other) {
    if (length != other.length) return false;
    for (int i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}

/// Robust file type detection service using multiple strategies
class FileTypeDetector {
  // Cache for detection results to improve performance
  final Map<String, String> _detectionCache = {};

  /// Detect file type using multiple strategies
  /// Returns a file type identifier (e.g., 'HTML', 'JavaScript', 'Python')
  /// Throws FileTypeError for binary/unsupported files
  Future<String> detectFileType({
    String? filename,
    String? content,
    Uint8List? bytes,
    String? contentType,
  }) async {
    // Generate a cache key based on available inputs
    final cacheKey =
        _generateCacheKey(filename: filename, content: content, bytes: bytes);

    // Return cached result if available
    if (_detectionCache.containsKey(cacheKey)) {
      return _detectionCache[cacheKey]!;
    }

    String detectedType = 'Text';

    // Strategy 0: Content-Type prioritization
    if (contentType != null && contentType.isNotEmpty) {
      final mimeType = contentType.split(';').first.trim().toLowerCase();
      if (_isKnownMimeType(mimeType)) {
        detectedType = _mimeToFileType(mimeType);
        if (detectedType != 'Text') {
          _detectionCache[cacheKey] = detectedType;
          return detectedType;
        }
      }
    }

    // Strategy 1: Check for binary files first
    if (bytes != null && bytes.isNotEmpty) {
      try {
        // Check if this is a binary file
        if (await _isBinaryFile(bytes, filename: filename)) {
          throw FileTypeError(
              'Binary files are not supported. Only text files can be loaded.');
        }
      } catch (e) {
        // If binary detection fails, continue with text detection
      }
    }

    // Strategy 2: Extension-based detection (fastest)
    // For URLs, we need to be more careful about extension detection
    bool isUrl = _isUrlFilename(filename);
    if (filename != null && filename.contains('.')) {
      // For URLs, only do extension detection if it looks like a real file extension
      // (not just a domain name)
      if (isUrl) {
        // Extract the last part after the last dot
        final lastDotIndex = filename.lastIndexOf('.');
        final lastPart = filename.substring(lastDotIndex + 1);

        // Check if this looks like a real file extension (not a domain TLD)
        // Real file extensions are typically 2-4 characters and are known extensions
        final knownExtensions = [
          'html',
          'htm',
          'css',
          'js',
          'json',
          'xml',
          'yaml',
          'yml',
          'md',
          'txt',
          'py',
          'java',
          'dart',
          'cpp',
          'c',
          'cs',
          'php',
          'rb',
          'swift',
          'go',
          'rs',
          'kt',
          'hs',
          'lua',
          'pl',
          'r',
          'sh'
        ];

        if (knownExtensions.contains(lastPart.toLowerCase())) {
          detectedType = _detectByExtension(filename);
          if (detectedType != 'Text') {
            _detectionCache[cacheKey] = detectedType;
            return detectedType;
          }
        }
        // If not a known extension, skip extension detection for URLs
        // and let content-based detection handle it
      } else {
        // For non-URLs, use normal extension detection
        detectedType = _detectByExtension(filename);
        if (detectedType != 'Text') {
          _detectionCache[cacheKey] = detectedType;
          return detectedType;
        }
      }
    }

    // Strategy 3: MIME type detection from bytes
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

    // Strategy 4: Content-based detection with scoring
    if (content != null && content.isNotEmpty) {
      detectedType = _detectByContent(content);

      // Special handling for URLs: if content detection returns 'Text' for a URL,
      // it means the content is unclear, so default to HTML
      if (detectedType == 'Text' && _isUrlFilename(filename)) {
        detectedType = 'HTML';
      }

      _detectionCache[cacheKey] = detectedType;
      return detectedType;
    }

    // Strategy 4.5: Final URL fallback - if we get here with a URL and no clear detection, default to HTML
    // Only apply this if we have a URL but no content to analyze
    if (_isUrlFilename(filename) &&
        detectedType == 'Text' &&
        (content == null || content.isEmpty)) {
      detectedType = 'HTML';
      _detectionCache[cacheKey] = detectedType;
      return detectedType;
    }

    // If we have bytes but no content, check if it's binary
    if (bytes != null && bytes.isNotEmpty && content == null) {
      try {
        if (await _isBinaryFile(bytes, filename: filename)) {
          throw FileTypeError(
              'Binary files are not supported. Only text files can be loaded.');
        }
      } catch (e) {
        if (e is FileTypeError) {
          rethrow;
        }
        // Continue with fallback for other errors
      }
    }

    // Final fallback
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
      'xml': 'XML', 'xsd': 'XML', 'xsl': 'XML', 'svg': 'XML', 'atom': 'XML',
      'rss': 'XML', 'rdf': 'XML',
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
      'cpp': 'C++', 'cc': 'C++', 'cxx': 'C++', 'h': 'C++', 'hpp': 'C++',
      'hxx': 'C++',
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
      'txt': 'Text', 'text': 'Text', 'log': 'Text',

      // Images
      'png': 'Image', 'jpg': 'Image', 'jpeg': 'Image', 'gif': 'Image',
      'webp': 'Image', 'bmp': 'Image', 'ico': 'Image', 'avif': 'Image',

      // Videos
      'mp4': 'Video', 'webm': 'Video', 'ogg': 'Video', 'mov': 'Video',
      'avi': 'Video', 'mkv': 'Video',

      // Audio
      'mp3': 'Audio', 'wav': 'Audio', 'flac': 'Audio', 'aac': 'Audio',
      'm4a': 'Audio',
    };

    // For URL loading, if there's no clear file extension, default to HTML
    // This handles cases where URLs don't have clear file extensions
    // Only apply this logic for actual URLs, not local filenames
    bool isUrl = filename.contains('http://') ||
        filename.contains('https://') ||
        filename.contains('www.') ||
        (filename.contains('.com') && filename.contains('/')) ||
        (filename.contains('.org') && filename.contains('/')) ||
        (filename.contains('.net') && filename.contains('/')) ||
        (filename.contains('.io') && filename.contains('/')) ||
        (filename.contains('.co') && filename.contains('/'));

    if (isUrl) {
      // Check if the extension is clearly not HTML (CSS, JS, etc.)
      final nonHtmlExtensions = [
        'css',
        'js',
        'json',
        'xml',
        'yaml',
        'yml',
        'md',
        'txt',
        'py',
        'java',
        'dart',
        'cpp',
        'c',
        'cs',
        'php',
        'rb',
        'swift',
        'go',
        'rs',
        'kt',
        'hs',
        'lua',
        'pl',
        'r',
        'sh',
        'ps1'
      ];

      if (!nonHtmlExtensions.contains(ext)) {
        return 'HTML'; // Default to HTML for URLs without clear non-HTML extensions
      }
    }

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

      // Media types
      'image/png': 'Image', 'image/jpeg': 'Image', 'image/gif': 'Image',
      'image/webp': 'Image', 'image/bmp': 'Image', 'image/x-icon': 'Image',
      'image/avif': 'Image',
      'video/mp4': 'Video', 'video/webm': 'Video', 'video/ogg': 'Video',
      'video/quicktime': 'Video',
      'audio/mpeg': 'Audio', 'audio/wav': 'Audio', 'audio/ogg': 'Audio',
      'audio/aac': 'Audio', 'audio/x-m4a': 'Audio',
    };

    return mimeMap[mimeType] ?? 'Text';
  }

  /// Detect file type by content analysis with scoring
  String _detectByContent(String content) {
    final lowerContent = content.toLowerCase();
    final scores = <String, int>{};

    // HTML detection - be specific to avoid false positives with XML/RSS
    // Only detect as HTML if we have clear HTML indicators and no XML indicators
    bool hasHtmlIndicators =
        lowerContent.contains('<html') || lowerContent.contains('<!doctype');
    bool hasXmlIndicators = lowerContent.contains('<rss ') ||
        lowerContent.contains('<feed ') ||
        lowerContent.contains('<?xml') ||
        lowerContent.contains('xmlns=');

    if (hasHtmlIndicators && !hasXmlIndicators) {
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
    final jsKeywords = [
      'function',
      'const',
      'let',
      '=>',
      'import',
      'export',
      'class'
    ];
    final jsScore = jsKeywords.where((kw) => lowerContent.contains(kw)).length;
    if (jsScore > 2) scores['JavaScript'] = jsScore * 3;

    // TypeScript detection
    if (lowerContent.contains('interface ') ||
        lowerContent.contains('type ') ||
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
        (lowerContent.contains(': ') &&
            !lowerContent.contains('{') &&
            !lowerContent.contains('}')) ||
        lowerContent.contains('  - ') ||
        lowerContent.contains('key: value') ||
        lowerContent.contains('list:') ||
        lowerContent.contains('map:')) {
      // Make sure it's not CSS by checking for YAML-specific structure
      if (!lowerContent.contains('body {') &&
          !lowerContent.contains('@media')) {
        scores['YAML'] = 18; // Higher confidence for YAML
      } else {
        scores['YAML'] = 5; // Low confidence if CSS patterns are present
      }
    }

    // Markdown detection
    if (lowerContent.startsWith('# ') ||
        lowerContent.contains('## ') ||
        lowerContent.contains('**') ||
        lowerContent.contains('* ') ||
        lowerContent.contains('1. ')) {
      scores['Markdown'] = 12;
    }

    // XML detection - prioritize XML detection and make it more comprehensive
    // Check for XML declarations, self-closing tags, and specific XML formats like RSS/Atom
    bool isXml = lowerContent.startsWith('<?xml') ||
        lowerContent.contains('<xml ') ||
        lowerContent.contains('<rss ') ||
        lowerContent.contains('<feed ') || // Atom feeds
        lowerContent.contains('<channel ') ||
        lowerContent.contains('<item ') ||
        lowerContent.contains('xmlns=') ||
        (lowerContent.contains('<') &&
            lowerContent.contains('>') &&
            lowerContent.contains('/>'));

    // Give higher score to XML if we find strong XML indicators
    if (isXml) {
      // Even higher score for clear XML formats
      if (lowerContent.contains('<rss ') ||
          lowerContent.contains('<feed ') ||
          lowerContent.contains('<?xml') ||
          lowerContent.contains('xmlns=')) {
        scores['XML'] = 25; // High confidence for clear XML
      } else {
        scores['XML'] = 20; // Still high confidence for general XML
      }
    }

    // Python detection
    final pyKeywords = ['def ', 'class ', 'import ', 'from ', 'print('];
    final pyScore = pyKeywords.where((kw) => lowerContent.contains(kw)).length;
    if (pyScore > 2) scores['Python'] = pyScore * 4;

    // Java detection
    if (lowerContent.contains('public class ') ||
        lowerContent.contains('system.out.println') ||
        lowerContent.contains('package ')) {
      scores['Java'] = 25; // High confidence
    }

    // C++ detection
    if (lowerContent.contains('#include ') ||
        lowerContent.contains('int main(') ||
        lowerContent.contains('cout <<') ||
        lowerContent.contains('namespace ')) {
      scores['C++'] = 20;
    }

    // C detection
    if (lowerContent.contains('#include ') ||
        lowerContent.contains('int main(') ||
        lowerContent.contains('printf(')) {
      scores['C'] = 18;
    }

    // Ruby detection
    if (lowerContent.contains('puts ') ||
        lowerContent.contains('require ') ||
        lowerContent.contains('gem ') ||
        lowerContent.contains('bundle ')) {
      scores['Ruby'] = 15;
    }

    // PHP detection
    if (lowerContent.contains('<?php') ||
        lowerContent.contains('<?=') ||
        lowerContent.contains('echo ')) {
      scores['PHP'] = 20;
    }

    // SQL detection
    final sqlKeywords = [
      'select ',
      'from ',
      'where ',
      'join ',
      'insert into',
      'update ',
      'delete from'
    ];
    final sqlScore =
        sqlKeywords.where((kw) => lowerContent.contains(kw)).length;
    if (sqlScore > 2) scores['SQL'] = sqlScore * 5;

    // Dart detection
    if (lowerContent.contains('void main(') ||
        lowerContent.contains('class ') ||
        (lowerContent.contains('import ') && lowerContent.contains('dart:'))) {
      scores['Dart'] = 18;
    }

    // Swift detection
    if (lowerContent.contains('import swift') ||
        lowerContent.contains('class ') ||
        lowerContent.contains('func ')) {
      scores['Swift'] = 15;
    }

    // Go detection
    if (lowerContent.contains('package main') ||
        lowerContent.contains('import (') ||
        lowerContent.contains('func main(')) {
      scores['Go'] = 18;
    }

    // Rust detection
    if (lowerContent.contains('fn main(') ||
        lowerContent.contains('use std::') ||
        lowerContent.contains('impl ')) {
      scores['Rust'] = 15;
    }

    // Kotlin detection
    if (lowerContent.contains('fun main(') ||
        lowerContent.contains('class ') ||
        lowerContent.contains('val ') ||
        lowerContent.contains('var ')) {
      scores['Kotlin'] = 15;
    }

    // Find the highest scoring match
    if (scores.isNotEmpty) {
      final bestMatch =
          scores.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (bestMatch.value > 10) {
        // Minimum confidence threshold
        return bestMatch.key;
      }
    }

    // Fallback to simple heuristics
    return _simpleContentDetection(content);
  }

  /// Simple content detection as fallback
  String _simpleContentDetection(String content) {
    final lowerContent = content.toLowerCase();

    if (lowerContent.contains('<html') ||
        lowerContent.contains('<!doctype html')) {
      return 'HTML';
    }
    if (lowerContent.contains('body {') || lowerContent.contains('@media')) {
      return 'CSS';
    }
    if (lowerContent.contains('function ') ||
        lowerContent.contains('const ') ||
        lowerContent.contains('let ') ||
        lowerContent.contains('=>')) {
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
    if (lowerContent.contains('<?xml') ||
        lowerContent.contains('<xml ') ||
        lowerContent.contains('<rss ') ||
        lowerContent.contains('<feed ') ||
        lowerContent.contains('<channel ') ||
        lowerContent.contains('xmlns=')) {
      return 'XML';
    }
    if (lowerContent.contains('public class ') ||
        lowerContent.contains('system.out.println')) {
      return 'Java';
    }
    if (lowerContent.contains('#include ') ||
        lowerContent.contains('int main(')) {
      return 'C++';
    }
    if (lowerContent.contains('def ') || lowerContent.contains('print(')) {
      return 'Python';
    }
    if (lowerContent.contains('select ') ||
        lowerContent.contains('from ') ||
        lowerContent.contains('where ')) {
      return 'SQL';
    }

    return 'Text';
  }

  /// Check if file content represents a binary file
  Future<bool> _isBinaryFile(Uint8List bytes, {String? filename}) async {
    // Check for null bytes (common in binary files)
    if (bytes.contains(0)) {
      return true;
    }

    // Check for common binary file signatures
    final binarySignatures = [
      // PDF
      Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      // ZIP
      Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]),
      // PNG
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      // JPEG
      Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      // GIF
      Uint8List.fromList([0x47, 0x49, 0x46, 0x38]),
      // EXE (Windows)
      Uint8List.fromList([0x4D, 0x5A]),
      // ELF (Linux)
      Uint8List.fromList([0x7F, 0x45, 0x4C, 0x46]),
      // Mach-O (macOS)
      Uint8List.fromList([0xFE, 0xED, 0xFA, 0xCE]),
      // MP3
      Uint8List.fromList([0x49, 0x44, 0x33]),
      // MP4
      Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]),
    ];

    // Check if file starts with any binary signature
    for (final signature in binarySignatures) {
      if (bytes.length >= signature.length &&
          bytes
              .sublist(0, signature.length)
              .toList()
              .equals(signature.toList())) {
        return true;
      }
    }

    // Check for high frequency of non-text characters
    final textChars = RegExp(r'[\x20-\x7E\r\n\t]');
    final textCharCount = bytes
        .where((byte) => textChars.hasMatch(String.fromCharCode(byte)))
        .length;
    final textRatio = textCharCount / bytes.length;

    // If less than 80% of characters are text-like, it's probably binary
    if (textRatio < 0.8) {
      return true;
    }

    // Check for common binary file extensions
    if (filename != null && filename.contains('.')) {
      final ext = filename.split('.').last.toLowerCase();
      final binaryExtensions = [
        'pdf',
        'zip',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'bmp',
        'webp',
        'mp3',
        'mp4',
        'avi',
        'mov',
        'mkv',
        'wav',
        'flac',
        'exe',
        'dll',
        'so',
        'dylib',
        'bin',
        'img',
        'iso',
        'class',
        'jar',
        'war',
        'ear',
        'apk',
        'ipa',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'psd',
        'ai',
        'indd',
        'eps',
        'ttf',
        'otf',
      ];

      if (binaryExtensions.contains(ext)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a filename appears to be a URL
  bool _isUrlFilename(String? filename) {
    if (filename == null) return false;

    return filename.contains('http://') ||
        filename.contains('https://') ||
        filename.contains('www.') ||
        (filename.contains('.com') && filename.contains('/')) ||
        (filename.contains('.org') && filename.contains('/')) ||
        (filename.contains('.net') && filename.contains('/')) ||
        (filename.contains('.io') && filename.contains('/')) ||
        (filename.contains('.co') && filename.contains('/'));
  }

  /// Generate cache key for detection results
  String _generateCacheKey(
      {String? filename, String? content, Uint8List? bytes}) {
    final parts = <String>[];

    if (filename != null) parts.add('fn:$filename');
    if (content != null) parts.add('ct:${content.length}');
    if (bytes != null) parts.add('by:${bytes.length}');

    return parts.join('|');
  }

  /// Check if a MIME type is known and should be prioritized
  bool _isKnownMimeType(String mimeType) {
    const knownMimes = [
      'text/html',
      'application/xhtml+xml',
      'text/css',
      'text/javascript',
      'application/javascript',
      'application/json',
      'application/xml',
      'text/xml',
      'text/markdown',
      'text/x-python',
      'text/x-java',
      'text/x-dart',
      'image/',
      'video/',
      'audio/',
    ];
    return knownMimes.any((m) => mimeType.contains(m));
  }

  /// Clear detection cache
  void clearCache() {
    _detectionCache.clear();
  }
}

/// Custom error for file type detection failures
class FileTypeError extends Error {
  final String message;
  final String? details;

  FileTypeError(this.message, [this.details]);

  @override
  String toString() =>
      'FileTypeError: $message${details != null ? ' (${details!})' : ''}';
}

/// Singleton instance for easy access
final fileTypeDetector = FileTypeDetector();
