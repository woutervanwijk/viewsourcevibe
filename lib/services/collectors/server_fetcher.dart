import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../models/inspection/observed.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/text_decoding.dart';
import '../certificate_security_service.dart';
import '../probe_service.dart';

/// Curl-like direct fetch of a URL, independent of any WebView.
abstract class ServerFetcher {
  /// Never throws for network problems: failures end up as [Failed] values in
  /// the snapshot, and hops recorded before the failure are kept.
  Future<ServerSnapshot> fetch(Uri url,
      {required String userAgent, int maxBytes = 10 << 20});

  Future<RobotsInfo> fetchRobots(Uri origin, {required String userAgent});
}

class IoServerFetcher implements ServerFetcher {
  static const maxRedirects = 5;
  static const _maxRobotsBytes = 256 * 1024;

  final Duration connectTimeout;
  final Duration headersTimeout;
  final Duration bodyTimeout;

  const IoServerFetcher({
    this.connectTimeout = const Duration(seconds: 10),
    this.headersTimeout = const Duration(seconds: 15),
    this.bodyTimeout = const Duration(seconds: 30),
  });

  HttpClient _newClient(String userAgent) => HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = connectTimeout
    ..userAgent = userAgent
    ..badCertificateCallback =
        CertificateSecurityService.defaultBadCertificateCallback;

  Future<HttpClientResponse> _send(
      HttpClient client, String method, Uri url, String userAgent,
      {required bool follow}) {
    return CertificateSecurityService.withCertificatePrompt(url.host, () async {
      final request = await client.openUrl(method, url);
      request.followRedirects = follow;
      request.headers
        ..set(HttpHeaders.userAgentHeader, userAgent)
        ..set(HttpHeaders.acceptHeader, '*/*')
        ..set(HttpHeaders.acceptEncodingHeader, 'gzip, deflate');
      return request.close().timeout(headersTimeout);
    });
  }

  static String _describe(Object e) {
    if (e is TimeoutException) return 'timeout: ${e.message ?? 'timed out'}';
    if (e is SocketException) return 'network error: ${e.message}';
    if (e is HandshakeException) return 'TLS error: ${e.message}';
    return 'error: $e';
  }

  static HttpHop _hopFrom(Uri url, HttpClientResponse r) {
    final headers = <String, List<String>>{};
    r.headers.forEach((name, values) {
      headers[name.toLowerCase()] = List<String>.of(values);
    });
    final addr = r.connectionInfo?.remoteAddress.address;
    Observed<Map<String, dynamic>> cert;
    final x = r.certificate;
    if (url.scheme != 'https') {
      cert = const Unavailable(UnavailableReason.notApplicable, 'not https');
    } else if (x == null) {
      cert = const Unavailable(UnavailableReason.notReportedByPlatform);
    } else {
      final info = ProbeService.extractCertificateInfo(x);
      cert = info.containsKey('error')
          ? Unavailable(
              UnavailableReason.notReportedByPlatform, '${info['error']}')
          : Present(info, source: DataSource.server);
    }
    return HttpHop(
      url: url,
      statusCode: r.statusCode,
      reasonPhrase: r.reasonPhrase,
      headers: headers,
      setCookies: List<String>.of(headers['set-cookie'] ?? const []),
      remoteAddress: addr == null
          ? const Unavailable(UnavailableReason.notReportedByPlatform)
          : Present(addr, source: DataSource.server),
      certificate: cert,
    );
  }

  @override
  Future<ServerSnapshot> fetch(Uri url,
      {required String userAgent, int maxBytes = 10 << 20}) async {
    final sw = Stopwatch()..start();
    final hops = <HttpHop>[];

    ServerSnapshot done(Observed<Uri> finalUrl, Observed<ServerBody> body) =>
        ServerSnapshot(
          requestedUrl: url,
          userAgent: userAgent,
          hops: List.unmodifiable(hops),
          finalUrl: finalUrl,
          body: body,
          timingMs: Present(sw.elapsedMilliseconds, source: DataSource.server),
          certificate: hops.isEmpty
              ? const Unavailable(
                  UnavailableReason.notApplicable, 'no response')
              : hops.last.certificate,
        );

    if (url.scheme != 'http' && url.scheme != 'https') {
      final f = Failed<Uri>('unsupported scheme: ${url.scheme}');
      return done(f, Failed<ServerBody>(f.error));
    }

    final client = _newClient(userAgent);
    try {
      var current = url;
      while (true) {
        final HttpClientResponse response;
        try {
          response =
              await _send(client, 'GET', current, userAgent, follow: false);
        } catch (e) {
          final msg = _describe(e);
          return done(Failed(msg), Failed(msg));
        }
        final hop = _hopFrom(current, response);
        hops.add(hop);

        final location = hop.header('location');
        final isRedirect =
            const {301, 302, 303, 307, 308}.contains(hop.statusCode) &&
                location != null;
        if (!isRedirect) {
          final body = await _readBody(response, maxBytes);
          return done(Present(current, source: DataSource.server), body);
        }

        // Redirect: the body is irrelevant, drain best-effort.
        try {
          await response.drain<void>().timeout(bodyTimeout);
        } catch (_) {}

        final Uri next;
        try {
          next = current.resolve(location);
        } catch (_) {
          const f = Unavailable<Uri>(
              UnavailableReason.blockedBySite, 'invalid redirect location');
          return done(
              f,
              const Unavailable(UnavailableReason.blockedBySite,
                  'invalid redirect location'));
        }
        if (next.scheme != 'http' && next.scheme != 'https') {
          final d = 'redirect to ${next.scheme} blocked';
          return done(Unavailable(UnavailableReason.blockedBySite, d),
              Unavailable(UnavailableReason.blockedBySite, d));
        }
        if (hops.length > maxRedirects) {
          const d = 'more than $maxRedirects redirects';
          return done(const Unavailable(UnavailableReason.exceedsLimit, d),
              const Unavailable(UnavailableReason.exceedsLimit, d));
        }
        current = next;
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<Observed<ServerBody>> _readBody(
      HttpClientResponse response, int maxBytes) async {
    final encoding =
        (response.headers.value(HttpHeaders.contentEncodingHeader) ?? '')
            .trim()
            .toLowerCase();
    Stream<List<int>> Function(Stream<List<int>>)? decode;
    switch (encoding) {
      case '':
      case 'identity':
        decode = (s) => s;
      case 'gzip' || 'x-gzip':
        decode = (s) => s.transform(gzip.decoder);
      case 'deflate':
        decode = (s) => s.transform(zlib.decoder);
    }
    if (decode == null) {
      return Unavailable(UnavailableReason.unsupportedPlatform,
          'content-encoding $encoding not supported');
    }

    var wire = 0;
    final buf = BytesBuilder(copy: false);
    var truncated = false;
    Object? error;
    final stream = decode(response.map((c) {
      wire += c.length;
      return c;
    }));

    // The reader never throws, so a timed-out leftover cannot leak an error.
    final reading = () async {
      try {
        await for (final chunk in stream) {
          final room = maxBytes - buf.length;
          if (chunk.length > room) {
            buf.add(chunk.sublist(0, room));
            truncated = true;
            break;
          }
          buf.add(chunk);
        }
      } catch (e) {
        error = e;
      }
    }();
    try {
      await reading.timeout(bodyTimeout);
    } on TimeoutException catch (e) {
      return Failed(_describe(e));
    }
    if (error != null) return Failed(_describe(error!));

    final lengthHeader =
        response.headers.value(HttpHeaders.contentLengthHeader);
    final declared = int.tryParse(lengthHeader ?? '');
    final decoded = decodeText(buf.takeBytes(),
        contentType: response.headers.value(HttpHeaders.contentTypeHeader));
    return Present(
      ServerBody(
        decoded: decoded,
        transferLength: wire,
        truncated: truncated,
        contentLength: declared == null
            ? const Unavailable(UnavailableReason.notReportedByServer)
            : Present(declared, source: DataSource.server),
        contentEncoding: encoding.isEmpty ? null : encoding,
      ),
      source: DataSource.server,
    );
  }

  @override
  Future<RobotsInfo> fetchRobots(Uri origin,
      {required String userAgent}) async {
    final base = Uri(
        scheme: origin.scheme,
        host: origin.host,
        port: origin.hasPort ? origin.port : null);
    final client = _newClient(userAgent);
    try {
      return await _robots(client, base, userAgent);
    } finally {
      client.close(force: true);
    }
  }

  Future<RobotsInfo> _robots(
      HttpClient client, Uri base, String userAgent) async {
    Present<T> p<T>(T v) => Present(v, source: DataSource.server);

    // sitemap.xml: HEAD, status only.
    Observed<int> sitemapStatus;
    try {
      final r = await _send(
          client, 'HEAD', base.resolve('/sitemap.xml'), userAgent,
          follow: true);
      await r.drain<void>().timeout(bodyTimeout);
      sitemapStatus = p(r.statusCode);
    } catch (e) {
      sitemapStatus = Failed(_describe(e));
    }

    HttpClientResponse r;
    try {
      r = await _send(client, 'GET', base.resolve('/robots.txt'), userAgent,
          follow: true);
    } catch (e) {
      final m = _describe(e);
      return RobotsInfo(
        robotsStatus: Failed(m),
        robotsText: Failed(m),
        disallowCount: Failed(m),
        allowCount: Failed(m),
        sitemaps: Failed(m),
        sitemapStatus: sitemapStatus,
      );
    }
    final status = r.statusCode;
    final body = await _readBody(r, _maxRobotsBytes);
    Unavailable<T> no<T>(String d) =>
        Unavailable(UnavailableReason.notReportedByServer, d);

    if (status != 200 || body is! Present<ServerBody>) {
      final String detail;
      if (status != 200) {
        detail = 'robots.txt returned $status';
      } else if (body is Failed<ServerBody>) {
        detail = body.error;
      } else {
        detail = 'robots.txt body unavailable';
      }
      Observed<T> miss<T>() => body is Failed<ServerBody> && status == 200
          ? Failed(detail)
          : no(detail);
      return RobotsInfo(
        robotsStatus: p(status),
        robotsText: miss(),
        disallowCount: miss(),
        allowCount: miss(),
        sitemaps: miss(),
        sitemapStatus: sitemapStatus,
      );
    }
    final text = body.value.decoded.text;
    var disallow = 0, allow = 0;
    final sitemaps = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n|\r'))) {
      final line = raw.split('#').first.trim();
      final i = line.indexOf(':');
      if (i <= 0) continue;
      final key = line.substring(0, i).trim().toLowerCase();
      final value = line.substring(i + 1).trim();
      if (value.isEmpty) continue;
      if (key == 'disallow') disallow++;
      if (key == 'allow') allow++;
      if (key == 'sitemap') sitemaps.add(value);
    }
    return RobotsInfo(
      robotsStatus: p(status),
      robotsText: p(text),
      disallowCount: p(disallow),
      allowCount: p(allow),
      sitemaps: p(sitemaps),
      sitemapStatus: sitemapStatus,
    );
  }
}
