import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

/// Shared building blocks for the inspection fixtures (full_page, local_file,
/// ios_partial, bot_blocked) used by the widget tests.

Present<T> server<T>(T v) => Present(v, source: DataSource.server);
Present<T> browser<T>(T v) => Present(v, source: DataSource.browser);
Present<T> file<T>(T v) => Present(v, source: DataSource.file);

HttpHop hop(
  String url,
  int status, {
  Map<String, List<String>> headers = const {},
  List<String> setCookies = const [],
}) =>
    HttpHop(
      url: Uri.parse(url),
      statusCode: status,
      reasonPhrase:
          status == 200 ? 'OK' : (status == 403 ? 'Forbidden' : 'Moved'),
      headers: headers,
      setCookies: setCookies,
      remoteAddress: server('93.184.216.34'),
      certificate:
          const Unavailable(UnavailableReason.notApplicable, 'not collected'),
    );

DecodedText decoded(
  String text, {
  String charset = 'utf-8',
  CharsetSource source = CharsetSource.header,
  int? byteLength,
  bool unsupported = false,
  String? declared,
}) =>
    DecodedText(
      text: text,
      charset: charset,
      charsetSource: source,
      byteLength: byteLength ?? text.length,
      unsupportedCharset: unsupported,
      declaredCharset: declared,
    );

ServerSnapshot serverSnapshot({
  required String url,
  required List<HttpHop> hops,
  required String body,
  DecodedText? decodedBody,
  int? transferLength,
  bool acceptedInvalidCertificate = false,
}) {
  final d = decodedBody ?? decoded(body);
  return ServerSnapshot(
    requestedUrl: Uri.parse(url),
    userAgent: kServerUserAgent,
    hops: hops,
    finalUrl: server(hops.last.url),
    body: server(ServerBody(
      decoded: d,
      transferLength: transferLength ?? d.byteLength,
      truncated: false,
      contentLength: server(d.byteLength),
    )),
    timingMs: server(42),
    certificate:
        const Unavailable(UnavailableReason.notApplicable, 'not collected'),
    acceptedInvalidCertificate: acceptedInvalidCertificate,
  );
}

Unavailable<T> _na<T>() => Unavailable<T>(UnavailableReason.notApplicable);

BrowserSnapshot browserSnapshot({
  required String url,
  required String dom,
  BrowserPlatform platform = BrowserPlatform.macos,
  List<ResourceEntry>? resources,
  List<BrowserCookie>? cookies,
}) =>
    BrowserSnapshot(
      url: Uri.parse(url),
      platform: platform,
      contentType: browser('text/html'),
      renderedDom: browser(RenderedDom(text: dom)),
      resources:
          resources == null ? _na<List<ResourceEntry>>() : browser(resources),
      cookies: cookies == null ? _na<List<BrowserCookie>>() : browser(cookies),
      storage: _na<BrowserStorage>(),
      navigation: _na<NavigationTiming>(),
      snapshotTimeMs: browser(1200.0),
    );

ResourceEntry resource(
  String url,
  String type, {
  Observed<int> transfer = const Pending(),
  Observed<int> decoded = const Pending(),
}) =>
    ResourceEntry(
      url: url,
      type: type,
      source: ResourceSource.observer,
      startTime: browser(10.0),
      duration: browser(20.0),
      transfer: transfer,
      decoded: decoded,
    );

PageInspection urlInspection({
  required String url,
  required Observed<ServerSnapshot> serverResult,
  required Observed<BrowserSnapshot> browserResult,
  Observed<RobotsInfo> robots = const Pending(),
}) =>
    PageInspection(
      generation: 1,
      target: UrlTarget(Uri.parse(url)),
      server: serverResult,
      browser: browserResult,
      file: const Unavailable(UnavailableReason.notApplicable, 'not a file'),
      robots: robots,
    );
