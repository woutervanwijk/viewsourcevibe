import 'package:flutter/foundation.dart';
import 'package:mime_type/mime_type.dart';

import 'package:xml/xml.dart' as xml;

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
          'sh',
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'avif',
          'ico',
          'svg',
          'mp4',
          'webm',
          'mp3',
          'wav'
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

    // Strategy 4: Content-based detection with strict rules
    if (content != null && content.isNotEmpty) {
      if (content.length > 32 * 1024) {
        detectedType = await compute(_detectByContentInternal, content);
      } else {
        detectedType = _detectByContentInternal(content);
      }

      // Special handling for URLs: if content detection returns 'Text' for a URL,
      // it means the content is unclear.
      // User requested "Only change the type when it's really clear."
      // So we keep it as Text unless we have a specific reason to default to HTML for URLs
      // that look like web pages but lack clear doctypes (rare in modern web).
      // However, for usability, if it's a root URL (no extension) and we ruled out everything else,
      // HTML is still a safe bet for a browser app, but let's be stricter.
      if (detectedType == 'Text' && _isUrlFilename(filename)) {
        // Only default to HTML if it really looks like a web page URL (http/https)
        // AND we haven't found any other type.
        // But per user request: "Default to plain text. Only when it's sure... use probed content type"
        // The probed content type strategy (Strategy 0) already handled the "sure" cases.
        // So here we should stick to Text if we are unsure.
        // detectedType = 'HTML'; // DISABLED per user request for strictness
      }

      _detectionCache[cacheKey] = detectedType;
      return detectedType;
    }

    // Strategy 4.5: Final URL fallback
    // If we have a URL but NO content, we can't be sure.
    // Default to Text as requested, unless it's clearly a website root?
    // Actually, "probed content type" should have caught this in Strategy 0 if available.
    // If we are here, we might be offline or just have a string.
    // Let's stick to Text to be safe and obedient to "Default to plain text".

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

  /// Detect file type by content analysis with STRICT rules
  static String _detectByContentInternal(String content) {
    // For large files, only analyze the first 16KB for performance
    String analysisContent = content;
    if (content.length > 16 * 1024) {
      analysisContent = content.substring(0, 16 * 1024);
    }

    final lowerContent = analysisContent.toLowerCase().trim();

    // Empty content is Text
    if (lowerContent.isEmpty) return 'Text';

    // 1. XML/RSS/Atom Detection (Strict)
    // Must start with XML declaration OR have root element
    if (lowerContent.startsWith('<?xml')) {
      return 'XML';
    }
    // Check for root elements if no declaration
    if (lowerContent.startsWith('<rss') ||
        lowerContent.startsWith('<feed') ||
        lowerContent.startsWith('<svg') ||
        lowerContent.contains('<rdf:rdf')) {
      // It's likely XML structure
      try {
        final doc = xml.XmlDocument.parse(analysisContent);
        if (doc.children.any((node) => node is xml.XmlElement)) {
          return 'XML';
        }
      } catch (_) {}
    }

    // 2. HTML Detection (Strict)
    // Must have DOCTYPE or <html> tag
    if (lowerContent.startsWith('<!doctype html') ||
        lowerContent.contains('<html')) {
      return 'HTML';
    }
    // Ambiguous HTML tags like <div> or <p> are NOT enough for strict detection
    // unless accompanied by <head> AND <body>
    if (lowerContent.contains('<head') && lowerContent.contains('<body')) {
      return 'HTML';
    }

    // 3. JSON Detection (Strict)
    // Must parse as valid JSON
    if ((lowerContent.startsWith('{') && lowerContent.endsWith('}')) ||
        (lowerContent.startsWith('[') && lowerContent.endsWith(']'))) {
      try {
        // explicit check to avoid simple strings masquerading as JSON
        // purely structural check isn't enough, but full parse is safe
        // We use a lighter check first:
        if (lowerContent.contains('"') ||
            lowerContent.contains(':') ||
            lowerContent.contains(',') ||
            lowerContent == '{}' ||
            lowerContent == '[]') {
          // It might be JSON, but let's be sure it's not just a code block
          // Verify it doesn't look like a function body
          if (!lowerContent.contains('function') &&
              !lowerContent.contains('=>')) {
            return 'JSON';
          }
        }
      } catch (_) {}
    }

    // 4. YAML Detection (Strict)
    // Must start with document separator
    if (lowerContent.startsWith('---\n') ||
        lowerContent.startsWith('---\r\n')) {
      return 'YAML';
    }
    // Or key-value pairs at root with strict indentation
    // This is hard to detect strictly without parsing.
    // We will default to Text for "unmarked" YAML to avoid false positives with Todo lists etc.
    // Only exception: explicit map/list structures that are clearly data
    if (lowerContent.startsWith('name: ') ||
        lowerContent.contains('\nname: ')) {
      // "name:" is a very common YAML key, a bit weak but acceptable if combined with other YAML features?
      // Let's stick to stricter markers for now.
    }

    // 5. Code Detection (Strict)
    // Only detect if strongly typed or has distinct signatures

    // Java/C#/C++ (Strong)
    if (lowerContent.contains('public class ') ||
        lowerContent.contains('namespace ') ||
        lowerContent.contains('#include <') ||
        lowerContent.contains('using namespace ')) {
      // Further distinguish if needed, but "Text" is a safe fallback if ambiguous
      if (lowerContent.contains('#include')) return 'C++';
      if (lowerContent.contains('public class')) return 'Java'; // or C#
    }

    // Python (Strong)
    if (lowerContent.contains('def ') &&
        lowerContent.contains(':\n') &&
        (lowerContent.contains('import ') || lowerContent.contains('class '))) {
      return 'Python';
    }

    // Dart (Strong)
    if (lowerContent.contains('import \'package:') ||
        lowerContent.contains('void main()')) {
      return 'Dart';
    }

    // Default to Text for everything else
    // This removes the aggressive keyword counting for JS/CSS/etc.
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
      'application/pdf',
      'application/x-sh',
      'application/x-shellscript',
    ];
    return knownMimes.any((m) => mimeType == m || mimeType.startsWith(m));
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
