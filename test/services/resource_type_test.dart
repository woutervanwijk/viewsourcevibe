import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/probe_service.dart';

void main() {
  group('ProbeService.resourceTypeFromExtension', () {
    test('uses the path extension, not query or fragment', () {
      expect(ProbeService.resourceTypeFromExtension('https://a.com/p.JPG?x=1'),
          'image');
      expect(ProbeService.resourceTypeFromExtension('https://a.com/v.mp4#t=3'),
          'image');
      expect(ProbeService.resourceTypeFromExtension('https://a.com/a.css?v=2'),
          'style');
      expect(ProbeService.resourceTypeFromExtension('https://a.com/f.woff2'),
          'font');
      expect(ProbeService.resourceTypeFromExtension('https://a.com/x.html'),
          'document');
    });

    test('null without a known extension', () {
      expect(ProbeService.resourceTypeFromExtension('https://a.com/api/data'),
          isNull);
      expect(ProbeService.resourceTypeFromExtension('https://a.com/x.php?id=1'),
          isNull);
      expect(ProbeService.resourceTypeFromExtension('https://a.com/?f=a.jpg'),
          isNull);
    });
  });

  group('ProbeService.categorizeResource', () {
    test('extension wins over name heuristics', () {
      expect(ProbeService.categorizeResource('https://a.com/stylish.jpg', ''),
          'image');
      expect(ProbeService.categorizeResource('https://a.com/scripts/x.png', ''),
          'image');
      expect(ProbeService.categorizeResource('https://a.com/f.woff2', ''),
          'other');
    });

    test('falls back to heuristics without an extension', () {
      expect(
          ProbeService.categorizeResource('https://a.com/loadscript?id=1', ''),
          'script');
    });
  });
}
