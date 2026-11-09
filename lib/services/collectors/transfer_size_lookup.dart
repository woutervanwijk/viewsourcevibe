import 'dart:async';
import 'dart:io';

/// A resource is larger than the lookup is willing to download; its size is
/// at least [bytes].
class SizeLimitExceeded implements Exception {
  final int bytes;
  const SizeLimitExceeded(this.bytes);
  @override
  String toString() => 'larger than ${bytes ~/ (1024 * 1024)} MB';
}

/// Our own download of [url], measured the way Lighthouse's transferSize is:
/// the compressed body bytes actually received plus the response header
/// bytes. Compressed like a browser asks for it (gzip, deflate, br; never
/// decoded here), images in modern formats where offered.
///
/// Null when the server gave no usable response (error status, empty body).
/// Throws [SizeLimitExceeded] past [limit] bytes, and on network errors.
Future<int?> lookupTransferSize(
  String url, {
  required String userAgent,
  // Big animated GIFs and hero images can be tens of MB; audio/video are
  // never looked up (see estimate_targets.dart).
  int limit = 50 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 15),
  HttpClient Function()? client,
}) async {
  final http = (client ?? HttpClient.new)()
    ..autoUncompress = false
    ..connectionTimeout = timeout;
  try {
    final request = await http.getUrl(Uri.parse(url)).timeout(timeout);
    request.headers
      ..set(HttpHeaders.userAgentHeader, userAgent)
      ..set(HttpHeaders.acceptHeader,
          'image/avif,image/webp,image/apng,*/*;q=0.8')
      ..set(HttpHeaders.acceptEncodingHeader, 'gzip, deflate, br');
    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 400) {
      response.listen((_) {}).cancel();
      return null;
    }
    var body = 0;
    final done = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    sub = response.listen(
      (chunk) {
        body += chunk.length;
        if (body > limit) {
          sub.cancel();
          if (!done.isCompleted) done.completeError(SizeLimitExceeded(limit));
        }
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future.timeout(timeout * 2);
    if (body == 0) return null;
    return body + _headerBytes(response);
  } finally {
    http.close(force: true);
  }
}

/// Status line plus "name: value" lines plus the blank line, as on the wire
/// (HTTP/1.1; HTTP/2 compresses headers, so this is close, not exact).
int _headerBytes(HttpClientResponse r) {
  var n = 'HTTP/1.1 ${r.statusCode} ${r.reasonPhrase}\r\n'.length + 2;
  r.headers.forEach((name, values) {
    for (final v in values) {
      n += name.length + 2 + v.length + 2;
    }
  });
  return n;
}
