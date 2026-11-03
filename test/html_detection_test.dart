import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('HtmlService.isNonHtmlContentType', () {
    test('specific non-HTML types are authoritative', () {
      for (final type in [
        'application/json; charset=utf-8',
        'text/css',
        'application/javascript',
        'text/xml',
        'image/png',
      ]) {
        expect(HtmlService.isNonHtmlContentType(type), isTrue, reason: type);
      }
    });

    test('HTML, empty and generic types are not', () {
      for (final type in [
        'text/html; charset=utf-8',
        'application/xhtml+xml',
        '',
        'text/plain',
        'application/octet-stream',
      ]) {
        expect(HtmlService.isNonHtmlContentType(type), isFalse, reason: type);
      }
    });
  });

  group('HtmlService.contentLooksLikeHtml', () {
    test('recognizes HTML documents and fragments', () {
      expect(HtmlService.contentLooksLikeHtml('<!DOCTYPE html><html></html>'),
          isTrue);
      expect(HtmlService.contentLooksLikeHtml('\uFEFF  <html lang="en">'), isTrue);
      expect(
          HtmlService.contentLooksLikeHtml('<div class="x">hi</div>'), isTrue);
      expect(
          HtmlService.contentLooksLikeHtml(
              '<?xml version="1.0"?><!DOCTYPE html><html xmlns="x"></html>'),
          isTrue);
    });

    test('JS, CSS and JSON containing tags are not HTML', () {
      expect(
          HtmlService.contentLooksLikeHtml(
              'const t = "<div>" + x + "</div>"; document.body.append(t);'),
          isFalse);
      expect(
          HtmlService.contentLooksLikeHtml('body { color: red } /* <style> */'),
          isFalse);
      expect(HtmlService.contentLooksLikeHtml('{"html": "<body></body>"}'),
          isFalse);
    });

    test('feeds and plain XML are not HTML', () {
      expect(
          HtmlService.contentLooksLikeHtml(
              '<?xml version="1.0"?><rss><channel><title>x</title></channel></rss>'),
          isFalse);
      expect(HtmlService.contentLooksLikeHtml('<?xml version="1.0"?><note/>'),
          isFalse);
    });
  });
}
