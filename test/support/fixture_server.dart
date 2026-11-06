import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// One canned response for [FixtureServer].
class FixtureRoute {
  final int status;

  /// Header values are a String or a List<String> (repeated header).
  final Map<String, Object> headers;
  final List<int> body;

  /// Delay before the response starts.
  final Duration delay;

  /// Gzip the body and send `Content-Encoding: gzip`.
  final bool gzip;

  /// When false the response is chunked and has no Content-Length.
  final bool sendContentLength;

  /// Write the first half of the body, wait this long, then write the rest.
  final Duration? stallMidBody;

  const FixtureRoute({
    this.status = 200,
    this.headers = const {},
    this.body = const [],
    this.delay = Duration.zero,
    this.gzip = false,
    this.sendContentLength = true,
    this.stallMidBody,
  });

  factory FixtureRoute.redirect(String location,
          {int status = 302, Map<String, Object> headers = const {}}) =>
      FixtureRoute(status: status, headers: {...headers, 'location': location});
}

class RecordedRequest {
  final String method;
  final String path;
  final Map<String, String> headers;
  RecordedRequest(this.method, this.path, this.headers);
}

/// Small local HTTP server for offline collector tests.
class FixtureServer {
  final HttpServer _server;
  final Map<String, FixtureRoute> routes;
  final List<RecordedRequest> requests = [];

  FixtureServer._(this._server, this.routes) {
    _server.listen(_handle);
  }

  static Future<FixtureServer> start(Map<String, FixtureRoute> routes) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FixtureServer._(server, routes);
  }

  int get port => _server.port;
  Uri url([String path = '/']) =>
      Uri.parse('http://${_server.address.address}:$port$path');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final headers = <String, String>{};
    request.headers.forEach((n, v) => headers[n] = v.join(', '));
    requests.add(RecordedRequest(request.method, request.uri.path, headers));
    final route = routes[request.uri.path];
    final response = request.response;
    try {
      if (route == null) {
        response.statusCode = 404;
        await response.close();
        return;
      }
      if (route.delay > Duration.zero) await Future.delayed(route.delay);
      response.statusCode = route.status;
      route.headers.forEach((name, value) {
        if (value is List) {
          for (final v in value) {
            response.headers.add(name, v as String);
          }
        } else {
          response.headers.set(name, value as String);
        }
      });
      var bytes = route.body;
      if (route.gzip) {
        bytes = gzip.encode(bytes);
        response.headers.set('content-encoding', 'gzip');
      }
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }
      if (route.sendContentLength) {
        response.contentLength = bytes.length;
      } else {
        response.headers.chunkedTransferEncoding = true;
      }
      final stall = route.stallMidBody;
      final data = Uint8List.fromList(bytes);
      final half = stall == null ? data.length : data.length ~/ 2;
      for (var i = 0; i < half; i += 65536) {
        response.add(Uint8List.sublistView(
            data, i, i + 65536 > half ? half : i + 65536));
        await response.flush();
      }
      if (stall != null) {
        await Future.delayed(stall);
        response.add(Uint8List.sublistView(data, half));
      }
      await response.close();
    } catch (_) {
      // Client went away (truncation/timeouts); fine for a fixture.
    }
  }
}
