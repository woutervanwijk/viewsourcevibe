import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

List<int> fixture(String name) =>
    File('test/fixtures/file/$name').readAsBytesSync();

void main() {
  test('utf-8 without hints falls back to utf-8', () {
    final bytes = fixture('utf8.html');
    final d = decodeText(bytes);
    expect(d.text, contains('café €'));
    expect(d.charset, 'utf-8');
    expect(d.charsetSource, CharsetSource.fallback);
    expect(d.hadMalformed, isFalse);
    expect(d.isBinary, isFalse);
    expect(d.byteLength, bytes.length);
  });

  test('latin-1 with <meta charset> decodes cafe-acute', () {
    final d = decodeText(fixture('latin1_meta.html'));
    expect(d.text, contains('café'));
    expect(d.charset, 'windows-1252'); // WHATWG label mapping
    expect(d.charsetSource, CharsetSource.meta);
  });

  test('http-equiv content-type meta is honoured', () {
    final bytes =
        'x<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">caf'
                .codeUnits +
            [0xe9];
    final d = decodeText(bytes);
    expect(d.text, endsWith('café'));
    expect(d.charsetSource, CharsetSource.meta);
  });

  test('header windows-1252 maps 0x80 to euro', () {
    final d = decodeText(fixture('win1252_header.bin'),
        contentType: 'text/plain; charset=windows-1252');
    expect(d.text, 'price € 5');
    expect(d.charsetSource, CharsetSource.header);
    expect(d.charset, 'windows-1252');
  });

  test('header beats meta', () {
    final d = decodeText(fixture('latin1_meta.html'),
        contentType: 'text/html; charset="utf-8"');
    expect(d.charsetSource, CharsetSource.header);
    expect(d.charset, 'utf-8');
    expect(d.hadMalformed, isTrue);
  });

  test('utf-16le BOM wins over header', () {
    final bytes = fixture('utf16le_bom.txt');
    final d = decodeText(bytes, contentType: 'text/plain; charset=utf-8');
    expect(d.text, 'café');
    expect(d.charset, 'utf-16le');
    expect(d.charsetSource, CharsetSource.bom);
    expect(d.byteLength, bytes.length);
    expect(d.byteLength, isNot(d.text.length));
  });

  test('utf-16be BOM and utf-8 BOM', () {
    final be = decodeText([0xfe, 0xff, 0x00, 0x41, 0x00, 0xe9]);
    expect(be.text, 'Aé');
    expect(be.charset, 'utf-16be');
    final u8 = decodeText([0xef, 0xbb, 0xbf, 0x41]);
    expect(u8.text, 'A');
    expect(u8.charsetSource, CharsetSource.bom);
  });

  test('png is binary', () {
    final d = decodeText(fixture('binary.png'));
    expect(d.isBinary, isTrue);
    expect(d.byteLength, fixture('binary.png').length);
  });

  test('NUL bytes in non-utf16 data count as binary', () {
    expect(decodeText([0x41, 0x00, 0x42, 0x00, 0x00, 0x43]).isBinary, isTrue);
  });

  test('iso-8859-1 meta + 0x93 decodes as windows-1252 curly quote', () {
    final bytes = '<meta charset=iso-8859-1>'.codeUnits + [0x93, 0x9F];
    final d = decodeText(bytes);
    expect(d.text, endsWith('\u201C\u0178'));
  });

  test('unsupported charset declared via meta keeps its name', () {
    final d = decodeText('<meta charset=shift_jis>ab'.codeUnits);
    expect(d.unsupportedCharset, isTrue);
    expect(d.declaredCharset, 'shift_jis');
    expect(d.charsetSource, CharsetSource.fallback);
  });

  test('shift_jis is unsupported and falls back', () {
    final d =
        decodeText([0x41, 0x42], contentType: 'text/html; charset=shift_jis');
    expect(d.unsupportedCharset, isTrue);
    expect(d.declaredCharset, 'shift_jis');
    expect(d.charsetSource, CharsetSource.fallback);
    expect(d.charset, 'utf-8');
  });

  test('malformed utf-8 is flagged', () {
    final d = decodeText([0x41, 0xff, 0x42]);
    expect(d.hadMalformed, isTrue);
    expect(d.text, contains('�'));
  });

  test('empty input', () {
    final d = decodeText([]);
    expect(d.text, '');
    expect(d.byteLength, 0);
    expect(d.isBinary, isFalse);
  });
}
