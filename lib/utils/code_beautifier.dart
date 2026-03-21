import 'package:flutter/foundation.dart';

class BeautifyRequest {
  final String content;
  final String type;

  BeautifyRequest(this.content, this.type);
}

// Top-level function for compute
String _beautifyEntry(BeautifyRequest request) {
  return CodeBeautifier.beautify(request.content, request.type);
}

class CodeBeautifier {
  static Future<String> beautifyAsync(String content, String type) async {
    debugPrint('CodeBeautifier: Starting beautification for ${type.toUpperCase()}, content length: ${content.length}');
    final result = await compute(_beautifyEntry, BeautifyRequest(content, type));
    debugPrint('CodeBeautifier: Completed beautification for ${type.toUpperCase()}, result length: ${result.length}');
    return result;
  }

  static String beautify(String content, String type) {
    if (content.isEmpty) return content;

    // Safety limits to prevent memory issues and crashes
    const maxSafeLength = 10 * 1024 * 1024; // 10MB
    if (content.length > maxSafeLength) {
      debugPrint('CodeBeautifier: Content too large (${content.length} chars), skipping beautification');
      return content;
    }

    try {
      String result;
      switch (type.toLowerCase()) {
        case 'html':
        case 'xml':
        case 'xhtml':
          result = _beautifyHtml(content);
          break;
        case 'css':
          result = _beautifyCss(content);
          break;
        case 'javascript':
        case 'js':
        case 'json':
          result = _beautifyJs(content);
          break;
        default:
          return content;
      }

      // Fallback: if beautification failed for any reason and returned empty, 
      // but the original wasn't empty, return the original.
      return result.isEmpty ? content : result;
    } catch (e, stackTrace) {
      debugPrint('CodeBeautifier: Error during beautification: $e\n$stackTrace');
      // Return original content if beautification fails
      return content;
    }
  }

  static String _beautifyHtml(String html) {
    if (html.isEmpty) return html;
    
    // Safety checks for malformed content
    const maxTokens = 100000; // Prevent excessive processing
    const maxOutputLength = 20 * 1024 * 1024; // 20MB output limit
    
    final buffer = StringBuffer();
    var indent = 0; 
    var tokenCount = 0;
    
    // More robust regex: 
    // 1. Matches tags: <...>
    // 2. Matches text: everything until next <
    // 3. Matches a stray < if it's not starting a tag (though tags part usually catches it)
    final tokens = RegExp(r'(<[^>]*>|[^<]+|<)').allMatches(html);

    for (final token in tokens) {
      // Safety: prevent excessive processing
      tokenCount++;
      if (tokenCount > maxTokens) {
        debugPrint('CodeBeautifier: Too many tokens ($tokenCount), aborting beautification');
        return html; // Return original if too complex
      }
      
      // Safety: prevent excessive output size
      if (buffer.length > maxOutputLength) {
        debugPrint('CodeBeautifier: Output too large (${buffer.length} chars), aborting beautification');
        return html; // Return original if output gets too large
      }
      
      final value = token.group(0)!;
      
      try {
        if (value.startsWith('</')) {
          indent = (indent - 1).clamp(0, 50);
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write('${'  ' * indent}$value');
        } else if (value.startsWith('<') &&
            !value.endsWith('/>') &&
            !value.startsWith('<!') &&
            !value.startsWith('<!--') &&
            !value.startsWith('<?')) {
          
          final tagNameMatch = RegExp(r'<([a-zA-Z0-9]+)').firstMatch(value);
          final tagName = tagNameMatch?.group(1)?.toLowerCase();
          final selfClosing =
              {'br', 'hr', 'img', 'input', 'link', 'meta', 'area', 'base', 'col', 'embed', 'keygen', 'param', 'source', 'track', 'wbr'}.contains(tagName);

          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write('${'  ' * indent}$value');
          if (!selfClosing && tagName != null) indent++;
        } else if (value.startsWith('<')) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write('${'  ' * indent}$value');
        } else {
          final text = value.trim();
          if (text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write('${'  ' * indent}$text');
          }
        }
      } catch (e) {
        debugPrint('CodeBeautifier: Error processing token "$value": $e');
        // Skip problematic token but continue processing
        continue;
      }
    }
    
    // Final safety check
    final result = buffer.toString().trim();
    if (result.length > maxOutputLength) {
      debugPrint('CodeBeautifier: Final output too large (${result.length} chars), returning original');
      return html;
    }
    
    return result;
  }

  static String _beautifyCss(String css) {
    if (css.isEmpty) return css;
    
    // Safety limits
    const maxLength = 5 * 1024 * 1024; // 5MB
    if (css.length > maxLength) {
      debugPrint('CodeBeautifier: CSS content too large (${css.length} chars), skipping beautification');
      return css;
    }
    
    try {
      final buffer = StringBuffer();
      var indent = 0; 
      
      // Simple normalization: collapse whitespace but keep content
      final normalized = css.replaceAll(RegExp(r'\s+'), ' ');

      for (var i = 0; i < normalized.length; i++) {
        final char = normalized[i];
        if (char == '{') {
          buffer.write(' {\n${'  ' * (indent + 1)}');
          indent++;
        } else if (char == '}') {
          indent = (indent - 1).clamp(0, 50);
          // Add newline and indent before the brace, but don't clear the buffer
          buffer.write('\n${'  ' * indent}}');
        } else if (char == ';') {
          buffer.write(';\n${'  ' * indent}');
        } else {
          buffer.write(char);
        }
        
        // Safety: prevent excessive output
        if (buffer.length > maxLength) {
          debugPrint('CodeBeautifier: CSS output too large (${buffer.length} chars), aborting');
          return css;
        }
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('CodeBeautifier: Error beautifying CSS: $e');
      return css;
    }
  }

  static String _beautifyJs(String js) {
    if (js.isEmpty) return js;
    
    // Safety limits
    const maxLength = 5 * 1024 * 1024; // 5MB
    if (js.length > maxLength) {
      debugPrint('CodeBeautifier: JS content too large (${js.length} chars), skipping beautification');
      return js;
    }
    
    try {
      final buffer = StringBuffer();
      var indent = 0;
      var inString = false;
      var quoteChar = '';

      for (var i = 0; i < js.length; i++) {
        final char = js[i];

        // Handle strings (simple)
        if ((char == "'" || char == '"' || char == '`') &&
            (i == 0 || js[i - 1] != '\\')) {
          if (!inString) {
            inString = true;
            quoteChar = char;
          } else if (char == quoteChar) {
            inString = false;
          }
        }

        if (inString) {
          buffer.write(char);
          continue;
        }

        if (char == '{') {
          buffer.write(' {\n${'  ' * (indent + 1)}');
          indent++;
        } else if (char == '}') {
          indent = (indent - 1).clamp(0, 50);
          buffer.write('\n${'  ' * indent}}');
        } else if (char == ';') {
          buffer.write(';\n${'  ' * indent}');
        } else {
          buffer.write(char);
        }
        
        // Safety: prevent excessive output
        if (buffer.length > maxLength) {
          debugPrint('CodeBeautifier: JS output too large (${buffer.length} chars), aborting');
          return js;
        }
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('CodeBeautifier: Error beautifying JS: $e');
      return js;
    }
  }
}
