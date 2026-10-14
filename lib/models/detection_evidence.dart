/// Where a detected tracker/service/technology was found.
enum EvidenceKind {
  html,
  request,
  cookie,
  header,

  /// A preconnect / dns-prefetch hint: the page expects to use the host.
  hint,
}

class DetectionEvidence {
  final EvidenceKind kind;

  /// Short headline, e.g. "Cookie _ga" or "HTML line 42".
  final String title;

  /// Supporting detail: the matched tag, URL, header value or cookie description.
  final String? detail;

  /// 1-based line in the page source.
  final int? line;

  const DetectionEvidence(this.kind, this.title, {this.detail, this.line});

  /// Evidence for a match at [index] in [html]: line number plus the
  /// enclosing tag (or a window around the match inside long scripts).
  factory DetectionEvidence.htmlAt(String html, int index, {String? match}) {
    var line = 1;
    for (var i = 0; i < index && i < html.length; i++) {
      if (html.codeUnitAt(i) == 10) line++;
    }
    var start = html.lastIndexOf('<', index);
    var end = html.indexOf('>', index);
    if (start < 0 || index - start > 120) start = index - 60;
    end = end < 0 || end - index > 160 ? index + 100 : end + 1;
    start = start.clamp(0, html.length);
    end = end.clamp(start, html.length);
    var snippet = html.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
    if (snippet.length > 240) snippet = '${snippet.substring(0, 240)}…';
    return DetectionEvidence(
      EvidenceKind.html,
      match == null ? 'HTML line $line' : 'HTML line $line: "$match"',
      detail: snippet.trim(),
      line: line,
    );
  }

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'title': title,
        if (detail != null) 'detail': detail,
        if (line != null) 'line': line,
      };

  static DetectionEvidence? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final kind =
        EvidenceKind.values.where((k) => k.name == raw['kind']).firstOrNull;
    if (kind == null) return null;
    return DetectionEvidence(kind, raw['title']?.toString() ?? '',
        detail: raw['detail']?.toString(), line: raw['line'] as int?);
  }

  /// Description of an analyzed cookie (as stored in `analyzedCookies`).
  factory DetectionEvidence.cookie(Map cookie) {
    final name = cookie['name']?.toString() ?? 'cookie';
    final source = cookie['source']?.toString() ?? '';
    final parts = [
      [
        cookie['category']?.toString() ?? 'unknown',
        'cookie',
        if ((cookie['provider']?.toString() ?? '').isNotEmpty)
          'from ${cookie['provider']}',
      ].join(' '),
      if (source.contains('Server')) 'set via Set-Cookie response header',
      if (source == 'Browser') 'set by page script (document.cookie)',
      if ((cookie['domain']?.toString() ?? '').isNotEmpty)
        'domain ${cookie['domain']}',
      if ((cookie['expires']?.toString() ?? '').isNotEmpty)
        'expires ${cookie['expires']}',
    ];
    final description = parts.join(' · ');
    return DetectionEvidence(EvidenceKind.cookie, 'Cookie $name',
        detail: description[0].toUpperCase() + description.substring(1));
  }
}
