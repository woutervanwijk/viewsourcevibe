void main() {
  testLogic("Hello world", "Text only");
  testLogic("https://google.com", "Pure URL");
  testLogic("Check this https://google.com out", "Text with URL");
  testLogic("Check this www.google.com out", "Text with www URL");
  testLogic("   https://google.com   ", "URL with spaces");
}

void testLogic(String content, String scenario) {
  print("\n--- Testing: $scenario ---");
  print("Input: '$content'");

  final trimmedContent = content.trim();
  String? urlToLoad;

  // Logic from UnifiedSharingService.handleSharedContent
  if (isUrl(trimmedContent)) {
    print("MATCH: isUrl() returned true. Opening directly.");
    return;
  }

  if (isPotentialUrl(trimmedContent)) {
    print("MATCH: isPotentialUrl() returned true.");
    // Logic from lines 178-185
    final uri = Uri.tryParse(trimmedContent);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      urlToLoad = trimmedContent;
      print("  -> Valid URI with scheme. urlToLoad = $urlToLoad");
    } else {
      urlToLoad = trimmedContent;
      print("  -> Potential URL without scheme. urlToLoad = $urlToLoad");
    }
  } else {
    print("NO MATCH: isPotentialUrl() returned false.");

    // Check if there's a URL inside the text
    final urlPattern = RegExp(r'https?:\/\/[^\s]+');
    final match = urlPattern.firstMatch(content);
    if (match != null) {
      urlToLoad = match.group(0);
      print("MATCH: Regex found URL: $urlToLoad");
    } else {
      print("NO MATCH: Regex found nothing.");
    }
  }

  if (urlToLoad != null) {
    print("RESULT: Should show Dialog with URL: $urlToLoad");
  } else {
    print("RESULT: Should load as Text File.");
  }
}

// Logic copied from UnifiedSharingService
bool isUrl(String text) {
  final trimmedText = text.trim();
  if (trimmedText.isEmpty) {
    return false;
  }

  // Remove quotes if present
  final cleanText = trimmedText.startsWith('"') && trimmedText.endsWith('"')
      ? trimmedText.substring(1, trimmedText.length - 1)
      : (trimmedText.startsWith("'") && trimmedText.endsWith("'")
          ? trimmedText.substring(1, trimmedText.length - 1)
          : trimmedText);

  // First, check if this is explicitly a file URL (file:// protocol)
  if (cleanText.startsWith('file://') || cleanText.startsWith('file///')) {
    return false;
  }

  // Check if this is an Android content:// URI - these should be treated as file shares
  if (cleanText.startsWith('content://')) {
    return false;
  }

  // Check if this is likely a file path (starts with /) - do this early to avoid false positives
  if (cleanText.startsWith('/')) {
    return false;
  }

  // Try to parse as URI - check if it's a valid HTTP/HTTPS URL first
  try {
    final uri = Uri.tryParse(cleanText);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return true;
    }
  } catch (e) {
    // If parsing fails, continue with other checks
  }

  return false;
}

bool isPotentialUrl(String text) {
  if (text.isEmpty) return false;

  final trimmed = text.trim();

  // Remove common URL wrappers
  final cleanText = trimmed
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('"', '')
      .replaceAll("'", '');

  // Check for common URL patterns
  try {
    final uri = Uri.tryParse(cleanText);
    if (uri != null) {
      // Valid URL with http/https scheme
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return true;
      }
      // Valid URL that might be missing scheme (www.example.com)
      if (uri.host.isNotEmpty && !uri.host.contains(' ')) {
        return true;
      }
    }
  } catch (e) {
    // Parsing failed, try simpler patterns
  }

  // Check for common URL patterns without scheme
  final urlPatterns = [
    r'www\.',
    r'http://',
    r'https://',
    r'\.com',
    r'\.org',
    r'\.net',
    r'\.io',
    r'\.co',
    r'\.app',
    r'\.dev',
  ];

  for (final pattern in urlPatterns) {
    if (cleanText.contains(RegExp(pattern, caseSensitive: false))) {
      // Additional checks to avoid false positives
      if (cleanText.contains(' ') && !cleanText.startsWith('http')) {
        // Contains spaces but doesn't start with http - might not be a URL
        continue;
      }
      return true;
    }
  }

  // Check for common URL structures
  if ((cleanText.contains('.') && cleanText.contains('/')) ||
      (cleanText.contains('.') && cleanText.length > 10)) {
    // Might be a URL, but do additional checks
    final hasInvalidChars = RegExp(r'[\s\n\r\t]').hasMatch(cleanText);
    if (!hasInvalidChars) {
      return true;
    }
  }

  return false;
}
