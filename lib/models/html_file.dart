class HtmlFile {
  final String name;
  final String path;
  final String content;
  final DateTime lastModified;
  final int size;

  HtmlFile({
    required this.name,
    required this.path,
    required this.content,
    required this.lastModified,
    required this.size,
  });

  factory HtmlFile.fromContent(String name, String content) {
    return HtmlFile(
      name: name,
      path: '',
      content: content,
      lastModified: DateTime.now(),
      size: content.length,
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
    const textExtensions = ['html', 'htm', 'css', 'js', 'json', 'xml', 'txt'];
    return textExtensions.contains(extension);
  }
}