import 'dart:convert';

import 'derive/inspection_summary.dart';
import 'report_css.dart';

/// One visited site of a batch.
class BatchRow {
  final Uri url;

  /// Also the package name: `sites/<slug>.zip`.
  final String slug;

  /// 'done' | 'timed out' | 'failed' | 'cancelled'
  final String state;

  /// Analyses unfinished at export.
  final List<String> pending;
  final String? error;

  /// Null when nothing was exported.
  final InspectionSummary? summary;

  const BatchRow({
    required this.url,
    required this.slug,
    required this.state,
    this.pending = const [],
    this.error,
    this.summary,
  });

  String get package => 'sites/$slug.zip';
}

const _escape = HtmlEscape(HtmlEscapeMode.attribute);

Map<String, Object?> batchSummaryJson(List<BatchRow> rows,
        {required DateTime exportedAt}) =>
    {
      'format': 'view-source-vibe-batch',
      'formatVersion': 1,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'unknownIs': 'null',
      'sites': [
        for (final r in rows)
          {
            'url': r.url.toString(),
            'slug': r.slug,
            'package': r.package,
            'state': r.state,
            'pending': r.pending,
            'error': r.error,
            'summary': r.summary?.toJson(),
          }
      ],
    };

/// One CSV cell. Text from a site cannot become a spreadsheet formula.
String csvCell(Object? value) {
  if (value == null) return '';
  if (value is num || value is bool) return value.toString();
  var text = value is List ? value.join('; ') : value.toString();
  if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) text = "'$text";
  if (text.contains(RegExp(r'[,"\r\n]'))) {
    text = '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String batchSummaryCsv(List<BatchRow> rows) {
  final lines = <String>[
    [
      'url', 'state', 'pending', 'error', ...summaryFactKeys, //
      for (var i = 1; i <= 5; i++) 'finding$i',
    ].join(','),
  ];
  for (final r in rows) {
    final s = r.summary;
    final top = s?.top ?? const <Finding>[];
    lines.add([
      csvCell(r.url.toString()),
      csvCell(r.state),
      csvCell(r.pending),
      csvCell(r.error),
      for (final k in summaryFactKeys) csvCell(s?.facts[k]),
      for (var i = 0; i < 5; i++)
        csvCell(i < top.length
            ? '${top[i].severity.label}: ${top[i].title}'
            : null),
    ].join(','));
  }
  return '${lines.join('\r\n')}\r\n';
}

String batchSummaryHtml(List<BatchRow> rows, {required DateTime exportedAt}) {
  String e(Object? v) => _escape.convert('$v');
  final body = StringBuffer();
  for (final r in rows) {
    final s = r.summary;
    final String findings;
    if (s == null) {
      findings = '<span class="muted">${e(r.state)}'
          '${r.error == null ? '' : ': ${e(r.error)}'}</span>';
    } else if (s.top.isEmpty) {
      findings = '<span class="muted">No findings</span>';
    } else {
      findings = '<ul>${[
        for (final f in s.top)
          '<li><strong>${e(f.severity.label)}</strong> ${e(f.title)}</li>'
      ].join()}</ul>';
    }
    final pending = r.pending.isEmpty
        ? ''
        : '<div class="muted">Unfinished: ${e(r.pending.join(', '))}</div>';
    body.writeln('<tr>'
        '<td><a href="${e(r.package)}">${e(r.url)}</a></td>'
        '<td>${e(r.state)}$pending</td>'
        '<td>$findings</td>'
        '</tr>');
  }
  return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>View Source Vibe batch summary</title>
  $reportCss
</head>
<body>
<main>
  <h1>Batch summary</h1>
  <p class="muted">${e(exportedAt.toUtc().toIso8601String())} &middot; ${rows.length} sites</p>
  <table>
    <thead><tr><th>Site</th><th>State</th><th>Key findings</th></tr></thead>
    <tbody>
$body    </tbody>
  </table>
</main>
</body>
</html>''';
}
