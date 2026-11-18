import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/batch_summary.dart';
import 'package:view_source_vibe/services/derive/inspection_summary.dart';

InspectionSummary summaryWith(String title) => InspectionSummary(
      [Finding('x', FindingSeverity.high, title, tab: 'security')],
      {for (final k in summaryFactKeys) k: null}..['url'] = 'https://a.test/',
    );

BatchRow rowFor(String url, {String? title}) => BatchRow(
      url: Uri.parse(url),
      slug: Uri.parse(url).host,
      state: 'done',
      pending: const [],
      summary: summaryWith(title ?? 'Something'),
    );

void main() {
  final at = DateTime.utc(2026, 11, 15);

  test('csv cells from a site cannot become formulas', () {
    expect(csvCell('=HYPERLINK("http://x")'), '"\'=HYPERLINK(""http://x"")"');
    expect(csvCell('@cmd'), "'@cmd");
    expect(csvCell('+1'), "'+1");
    expect(csvCell('\tx'), "'\tx");
    expect(csvCell(-5), '-5');
    expect(csvCell(true), 'true');
    expect(csvCell(null), '');
    expect(csvCell(['a', 'b']), 'a; b');
    expect(csvCell(['=a', 'b']), "'=a; b");
    expect(csvCell('a,b'), '"a,b"');
  });

  test('csv has one row per site and a stable header', () {
    final csv =
        batchSummaryCsv([rowFor('https://a.test/'), rowFor('https://b.test/')]);
    final lines = csv.trimRight().split('\r\n');
    expect(lines, hasLength(3));
    expect(lines.first,
        startsWith('requestedUrl,state,pending,error,url,finalUrl,status,'));
    expect(
        lines.first, endsWith('finding1,finding2,finding3,finding4,finding5'));
    expect(lines[1], contains('High: Something'));
  });

  test('html escapes site text', () {
    final html = batchSummaryHtml(
        [rowFor('https://a.test/', title: '<script>alert(1)</script>')],
        exportedAt: at);
    expect(html, contains('&lt;script&gt;'));
    expect(html, isNot(contains('<script>alert')));
    expect(html, contains('sites/a.test.zip'));
    expect(html, contains('High'));
  });

  test('a failed site has a row without a summary', () {
    final failed = BatchRow(
      url: Uri.parse('https://c.test/'),
      slug: 'c.test',
      state: 'failed',
      pending: const ['security'],
      error: '<b>timeout</b>',
    );
    final csv = batchSummaryCsv([failed]);
    final cells = csv.trimRight().split('\r\n').last.split(',');
    expect(cells.take(4).toList(),
        ['https://c.test/', 'failed', 'security', '<b>timeout</b>']);
    expect(cells.skip(4).every((c) => c.isEmpty), isTrue);
    final json = batchSummaryJson([failed], exportedAt: at);
    final site = (json['sites'] as List).single as Map;
    expect(site['summary'], isNull);
    expect(site['package'], isNull);
    expect(json['unknownIs'], 'null');
    final html = batchSummaryHtml([failed], exportedAt: at);
    expect(html, contains('&lt;b&gt;timeout&lt;/b&gt;'));
    expect(html, isNot(contains('<a href')));
    expect(html, contains('https://c.test/'));
  });
}
