import 'package:flutter_test/flutter_test.dart';
import 'detection_helpers.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tech Stack Detection', () {
    test('Detects Nginx and PHP from headers', () async {
      final headers = {
        'server': 'nginx/1.18.0',
        'x-powered-by': 'PHP/8.1',
      };

      final metadata =
          await extractMetadataInIsolate('<html></html>', '', headers: headers);
      final tech = techOf(metadata);

      expect(tech['Web Server'], 'Nginx');
      expect(tech['Backend'], 'PHP');
    });

    test('Detects Next.js from headers and HTML', () async {
      final headers = {
        'x-powered-by': 'Next.js',
      };
      final html = '<html><body><div id="__NEXT_DATA__"></div></body></html>';

      final metadata =
          await extractMetadataInIsolate(html, '', headers: headers);
      final tech = techOf(metadata);

      expect(tech['Framework'], 'Next.js');
    });

    test('Detects React', () async {
      final html = '<html><body><div data-reactroot=""></div></body></html>';

      final metadata = await extractMetadataInIsolate(html, '');
      final tech = techOf(metadata);

      expect(tech['Library'], 'React');
    });

    test('Detects Tailwind CSS', () async {
      final html =
          '<html><head><link href="tailwind.min.css" rel="stylesheet"></head><body class="text-white bg-black p-4"></body></html>';

      final metadata = await extractMetadataInIsolate(html, '');
      final tech = techOf(metadata);

      expect(tech['CSS Framework'], 'Tailwind CSS');
    });

    test('Detects WordPress Version', () async {
      final html =
          '<html><head><meta name="generator" content="WordPress 6.4.2"></head><body></body></html>';

      final metadata = await extractMetadataInIsolate(html, '');
      final tech = techOf(metadata);

      expect(tech['CMS'], 'WordPress');
      expect(tech['WordPress Version'], '6.4.2');
    });

    test('Detects Vercel from Server header', () async {
      final headers = {
        'server': 'Vercel',
      };

      final metadata =
          await extractMetadataInIsolate('<html></html>', '', headers: headers);
      final tech = techOf(metadata);

      expect(tech['Platform'], 'Vercel');
    });

    test('Keeps JSON-LD structured data for the viewer', () async {
      final html = '''
<html><head>
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Article","headline":"Hello"}
</script>
</head><body></body></html>
''';

      final metadata = await extractMetadataInIsolate(html, '');
      final structuredData = metadata['structuredData'] as List;

      expect(structuredData, hasLength(1));
      expect(structuredData.first['@type'], 'Article');
      expect(structuredData.first['headline'], 'Hello');
    });

    test('Flattens @graph JSON-LD into individual schema nodes', () async {
      // As served by www.groningen.nl: one block, entities in @graph,
      // author/publisher as @id references to other graph nodes.
      final html = '''
<html><head>
<script type="application/ld+json">
      {"@context":"https://schema.org","@graph":[{"@type":"WebSite","author":{"@id":"#identity"},"copyrightHolder":{"@id":"#identity"},"copyrightYear":"2023","creator":{"@id":"#creator"},"dateCreated":"2023-08-14T13:17:41+02:00","dateModified":"2026-10-26T13:06:26+01:00","datePublished":"2023-08-14T13:17:00+02:00","description":"De website voor al je informatie over stad en provincie Groningen.","inLanguage":"nl","mainEntityOfPage":"https://www.groningen.nl/","name":"Groningen.nl","publisher":{"@id":"#creator"},"url":"https://www.groningen.nl/"},{"@id":"#identity","@type":"LocalBusiness","priceRange":"\$","sameAs":["https://www.instagram.com/internationalgroningen/"]},{"@id":"#creator","@type":"Organization","name":"Gemeente Groningen"},{"@type":"BreadcrumbList","description":"Breadcrumbs list","itemListElement":[{"@type":"ListItem","item":"https://www.groningen.nl/","name":"Home","position":1}],"name":"Breadcrumbs"}]}
    </script>
</head><body></body></html>
''';

      final metadata =
          await extractMetadataInIsolate(html, 'https://www.groningen.nl/');
      final structuredData = metadata['structuredData'] as List;
      final types = structuredData.map((n) => n['@type']).toList();

      expect(types, containsAll(['WebSite', 'LocalBusiness', 'Organization', 'BreadcrumbList']));
      expect(structuredData, hasLength(4));
      expect(structuredData.first['name'], 'Groningen.nl');

      final article = metadata['article'] as Map;
      expect(article['Published'], '2023-08-14T13:17:00+02:00');
      expect(article['Modified'], '2026-10-26T13:06:26+01:00');
      // publisher is a bare {"@id":"#creator"} reference, resolved to the
      // Organization node that appears later in the same graph.
      expect(article['Publisher'], 'Gemeente Groningen');
    });
  });
}
