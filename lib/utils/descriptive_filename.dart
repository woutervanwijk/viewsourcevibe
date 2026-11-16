/// Generate a descriptive filename for URLs without clear filenames
/// Uses domain name, path segments, and content type to create meaningful names
String generateDescriptiveFilename(Uri uri, String content) {
  // Extract domain name (remove www. if present)
  String domain = uri.host;
  if (domain.startsWith('www.')) {
    domain = domain.substring(4);
  }

  // Clean domain name for fallback use
  String humanDomain = domain;
  final domainParts = domain.split('.');
  if (domainParts.length >= 2) {
    final commonTlds = {
      'com',
      'org',
      'net',
      'io',
      'co',
      'dev',
      'app',
      'tech',
      'info',
      'me',
      'tv',
    };
    if (!commonTlds.contains(domainParts[domainParts.length - 1])) {
      humanDomain = domainParts.sublist(0, domainParts.length - 1).join(' ');
    } else {
      humanDomain = domainParts[domainParts.length - 2];
    }
  }
  // Capitalize first letter
  humanDomain = humanDomain.isNotEmpty
      ? humanDomain[0].toUpperCase() + humanDomain.substring(1)
      : 'index';

  // Extract meaningful path segments
  final pathSegments = uri.pathSegments
      .where(
        (segment) =>
            segment.isNotEmpty &&
            !segment.startsWith('_') &&
            segment != 'index' &&
            segment != 'home',
      )
      .toList();

  String baseFilename;
  if (pathSegments.isNotEmpty) {
    baseFilename = pathSegments.last;
  } else {
    baseFilename = humanDomain;
  }

  // Clean up characters but preserve dots for extensions
  baseFilename = baseFilename
      .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.]'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  if (baseFilename.isEmpty) return humanDomain;

  // Check for "proper" extensions we want to preserve
  final baseLower = baseFilename.toLowerCase();
  final knownExtensions = {
    '.html',
    '.htm',
    '.xhtml',
    '.css',
    '.js',
    '.json',
    '.xml',
    '.yaml',
    '.yml',
    '.md',
    '.txt',
    '.py',
    '.java',
    '.dart',
    '.php',
    '.rb',
    '.swift',
    '.go',
    '.rs',
    '.sql',
    '.atom',
    '.rss',
    '.rdf',
  };

  if (knownExtensions.any((ext) => baseLower.endsWith(ext))) {
    return baseFilename;
  }

  // If it's a domain-like name without extension, return it as is
  // detectFileTypeAndGenerateFilename will handle adding extensions if needed
  return baseFilename;
}
