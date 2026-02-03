class HtmlFile {
  final String name;
  final String path;
  final String content;
  final DateTime lastModified;
  final int size;
  final bool isUrl;
  final bool isError;
  final Map<String, dynamic>? probeResult;

  HtmlFile({
    required this.name,
    required this.path,
    required this.content,
    required this.lastModified,
    required this.size,
    this.isUrl = false,
    this.probeResult,
    this.isError = false,
  });

  factory HtmlFile.fromContent(String name, String content,
      {bool isUrl = false, bool isError = false}) {
    return HtmlFile(
      name: name,
      path: '',
      content: content,
      lastModified: DateTime.now(),
      size: content.length,
      isUrl: isUrl,
      isError: isError,
    );
  }

  String get fileSize {
    const kb = 1024;
    const mb = kb * 1024;

    if (size >= mb) {
      return '${(size / mb).toStringAsFixed(2)} MB';
    } else if (size >= kb) {
      return '${(size / kb).toStringAsFixed(2)} KB';
    } else {
      return '$size bytes';
    }
  }

  String get extension {
    return name.split('.').last.toLowerCase();
  }

  bool get isHtml {
    return extension == 'html' || extension == 'htm';
  }

  bool get isTextBased {
    // Comprehensive list of text-based file extensions that should get syntax highlighting
    const textExtensions = {
      // Web Development
      'html', 'htm', 'xhtml', 'css', 'js', 'javascript', 'mjs', 'cjs',
      'ts', 'typescript', 'jsx', 'tsx', 'json', 'json5', 'xml', 'xsd',
      'xsl', 'svg', 'yaml', 'yml', 'vue', 'svelte',

      // Markup & Documentation
      'md', 'markdown', 'txt', 'text', 'adoc', 'asciidoc',

      // Programming Languages
      'dart', 'py', 'python', 'java', 'kt', 'kts', 'swift', 'go',
      'rs', 'rust', 'php', 'rb', 'ruby', 'cpp', 'cc', 'cxx', 'c++',
      'h', 'hpp', 'hxx', 'c', 'cs', 'scala', 'hs', 'haskell', 'lua',
      'pl', 'perl', 'r', 'sh', 'bash', 'zsh', 'fish', 'ps1', 'psm1',

      // Configuration & Data
      'ini', 'conf', 'config', 'properties', 'toml', 'sql', 'graphql',
      'gql', 'dockerfile', 'makefile', 'mk', 'cmake',

      // Styling & Preprocessors
      'scss', 'sass', 'less', 'styl', 'stylus',

      // Other Common Formats
      'diff', 'patch', 'gitignore', 'ignore', 'editorconfig',

      // Additional common text formats
      'log', 'env', 'gradle'
    };
    return textExtensions.contains(extension);
  }

  bool get isMedia {
    const mediaExtensions = {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'ico',
      'avif',
      'mp4',
      'webm',
      'ogg',
      'mov',
      'avi',
      'mkv',
      'mp3',
      'wav',
      'flac',
      'aac',
      'm4a'
    };
    return mediaExtensions.contains(extension);
  }

  HtmlFile copyWith({
    String? name,
    String? path,
    String? content,
    DateTime? lastModified,
    int? size,
    bool? isUrl,
    Map<String, dynamic>? probeResult,
    bool? isError,
  }) {
    return HtmlFile(
      name: name ?? this.name,
      path: path ?? this.path,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      size: size ?? this.size,
      isUrl: isUrl ?? this.isUrl,
      probeResult: probeResult ?? this.probeResult,
      isError: isError ?? this.isError,
    );
  }
}
