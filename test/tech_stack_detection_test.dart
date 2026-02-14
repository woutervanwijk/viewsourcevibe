import 'package:flutter_test/flutter_test.dart';
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
      final tech = metadata['detectedTech'];

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
      final tech = metadata['detectedTech'];

      expect(tech['Framework'], 'Next.js');
    });

    test('Detects React', () async {
      final html = '<html><body><div data-reactroot=""></div></body></html>';

      final metadata = await extractMetadataInIsolate(html, '');
      final tech = metadata['detectedTech'];

      expect(tech['Library'], 'React');
    });

    test('Detects Tailwind CSS', () async {
      final html =
          '<html><head><link href="tailwind.min.css" rel="stylesheet"></head><body class="text-white bg-black p-4"></body></html>';

      final metadata = await extractMetadataInIsolate(html, '');
      final tech = metadata['detectedTech'];

      expect(tech['CSS Framework'], 'Tailwind CSS');
    });

    test('Detects WordPress Version', () async {
      final html =
          '<html><head><meta name="generator" content="WordPress 6.4.2"></head><body></body></html>';

      final metadata = await extractMetadataInIsolate(html, '');
      final tech = metadata['detectedTech'];

      expect(tech['CMS'], 'WordPress');
      expect(tech['WordPress Version'], '6.4.2');
    });

    test('Detects Vercel from Server header', () async {
      final headers = {
        'server': 'Vercel',
      };

      final metadata =
          await extractMetadataInIsolate('<html></html>', '', headers: headers);
      final tech = metadata['detectedTech'];

      expect(tech['Platform'], 'Vercel');
    });
  });
}
