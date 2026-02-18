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
    return compute(_beautifyEntry, BeautifyRequest(content, type));
  }

  static String beautify(String content, String type) {
    if (content.isEmpty) return content;

    switch (type.toLowerCase()) {
      case 'html':
      case 'xml':
      case 'xhtml':
        return _beautifyHtml(content);
      case 'css':
        return _beautifyCss(content);
      case 'javascript':
      case 'js':
      case 'json':
        return _beautifyJs(content);
      default:
        return content;
    }
  }

  static String _beautifyHtml(String html) {
    final buffer = StringBuffer();
    var indent = 0;
    final tokens = RegExp(r'(<[^>]+>|[^<]+)').allMatches(html);

    for (final token in tokens) {
      final value = token.group(0)!;
      if (value.startsWith('</')) {
        indent--;
        buffer.write('\n${'  ' * indent}$value');
      } else if (value.startsWith('<') &&
          !value.endsWith('/>') &&
          !value.startsWith('<!') &&
          !value.startsWith('<?')) {
        // Basic check for self-closing tags (not exhaustive)
        final tagName =
            RegExp(r'<(\w+)').firstMatch(value)?.group(1)?.toLowerCase();
        final selfClosing =
            {'br', 'hr', 'img', 'input', 'link', 'meta'}.contains(tagName);

        buffer.write('\n${'  ' * indent}$value');
        if (!selfClosing) indent++;
      } else if (value.startsWith('<')) {
        buffer.write('\n${'  ' * indent}$value');
      } else {
        final text = value.trim();
        if (text.isNotEmpty) {
          buffer.write('\n${'  ' * indent}$text');
        }
      }
    }
    return buffer.toString().trim();
  }

  static String _beautifyCss(String css) {
    final buffer = StringBuffer();
    var indent = 0;
    // Remove existing newlines and extra spaces to normalize
    final normalized = css.replaceAll(RegExp(r'\s+'), ' ');

    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (char == '{') {
        buffer.write(' {\n${'  ' * (indent + 1)}');
        indent++;
      } else if (char == '}') {
        indent--;
        // Trim trailing whitespace from buffer before closing brace
        final current = buffer.toString().trimRight();
        buffer.clear();
        buffer.write('$current\n${'  ' * indent}}\n${'  ' * indent}');
      } else if (char == ';') {
        buffer.write(';\n${'  ' * indent}');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString().trim();
  }

  static String _beautifyJs(String js) {
    // Very basic JS beautifier focused on braces and semicolons
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
        indent--;
        final current = buffer.toString().trimRight();
        buffer.clear();
        buffer.write('$current\n${'  ' * indent}}');
        // Add newline if next char isn't a semicolon or something similar
        if (i + 1 < js.length &&
            js[i + 1] != ';' &&
            js[i + 1] != ',' &&
            js[i + 1] != ')') {
          buffer.write('\n${'  ' * indent}');
        }
      } else if (char == ';') {
        buffer.write(';\n${'  ' * indent}');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString().trim();
  }
}
