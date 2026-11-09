import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

Present<T> b<T>(T v) => Present(v, source: DataSource.browser);
Present<T> s<T>(T v) => Present(v, source: DataSource.server);

const gone = Unavailable<Never>(UnavailableReason.notApplicable);

ResourceEntry res(
  String url, {
  String type = 'script',
  Observed<int> tx = const Unavailable(UnavailableReason.blockedByPlatform),
  Observed<int> dec = const Unavailable(UnavailableReason.blockedByPlatform),
  bool fromCache = false,
  String? frameOrigin,
}) =>
    ResourceEntry(
      url: url,
      type: type,
      source: ResourceSource.observer,
      startTime: const Unavailable(UnavailableReason.notReportedByPlatform),
      duration: const Unavailable(UnavailableReason.notReportedByPlatform),
      transfer: tx,
      decoded: dec,
      fromCache: fromCache,
      frameOrigin: frameOrigin,
    );

BrowserCookie cookie(String name,
        {String value = 'v',
        Observed<String> domain =
            const Unavailable(UnavailableReason.notReportedByPlatform),
        Observed<String> path =
            const Unavailable(UnavailableReason.notReportedByPlatform),
        Observed<DateTime> expires =
            const Unavailable(UnavailableReason.notReportedByPlatform),
        Observed<bool> secure =
            const Unavailable(UnavailableReason.notExposedToPage),
        Observed<bool> httpOnly =
            const Unavailable(UnavailableReason.notExposedToPage)}) =>
    BrowserCookie(
        name: name,
        value: value,
        domain: domain,
        path: path,
        expires: expires,
        isSecure: secure,
        isHttpOnly: httpOnly,
        sameSite: const Unavailable(UnavailableReason.notReportedByPlatform));

BrowserSnapshot browserSnap({
  String url = 'https://a.test/page',
  BrowserPlatform platform = BrowserPlatform.android,
  String? dom = '<html></html>',
  List<ResourceEntry>? resources = const [],
  List<BrowserCookie>? cookies,
  String contentType = 'text/html',
  bool truncated = false,
}) =>
    BrowserSnapshot(
      url: Uri.parse(url),
      platform: platform,
      contentType: b(contentType),
      renderedDom: dom == null
          ? const Unavailable(UnavailableReason.notApplicable)
          : b(RenderedDom(text: dom)),
      resources: resources == null
          ? const Unavailable(UnavailableReason.unsupportedPlatform)
          : b(resources),
      cookies: cookies == null
          ? const Unavailable<List<BrowserCookie>>(
              UnavailableReason.notApplicable)
          : b(cookies),
      storage:
          const Unavailable<BrowserStorage>(UnavailableReason.notApplicable),
      navigation:
          const Unavailable<NavigationTiming>(UnavailableReason.notApplicable),
      snapshotTimeMs: b(1000.0),
      resourcesTruncated: truncated,
    );

ServerSnapshot serverSnap({
  String url = 'https://a.test/page',
  String? finalUrl,
  int status = 200,
  Map<String, List<String>> headers = const {
    'content-type': ['text/html']
  },
  List<String> setCookies = const [],
  String? body = '<html></html>',
  String ua = 'TestUA/1.0',
}) {
  final hop = HttpHop(
    url: Uri.parse(finalUrl ?? url),
    statusCode: status,
    reasonPhrase: '',
    headers: headers,
    setCookies: setCookies,
    remoteAddress: const Unavailable(UnavailableReason.notReportedByPlatform),
    certificate: const Unavailable(UnavailableReason.notApplicable),
  );
  return ServerSnapshot(
    requestedUrl: Uri.parse(url),
    userAgent: ua,
    hops: [hop],
    finalUrl: s(Uri.parse(finalUrl ?? url)),
    body: body == null
        ? const Unavailable(UnavailableReason.notApplicable)
        : s(ServerBody(
            decoded: DecodedText(
                text: body,
                charset: 'utf-8',
                charsetSource: CharsetSource.header,
                byteLength: body.length),
            transferLength: body.length,
            truncated: false,
            contentLength:
                const Unavailable(UnavailableReason.notReportedByServer),
          )),
    timingMs: s(5),
    certificate: const Unavailable(UnavailableReason.notApplicable),
  );
}

PageInspection inspection({
  ServerSnapshot? server,
  BrowserSnapshot? browser,
  FileSnapshot? file,
  InspectionTarget? target,
}) =>
    PageInspection(
      generation: 1,
      target: target ??
          (file != null
              ? FileTarget(file)
              : UrlTarget(Uri.parse('https://a.test/page'))),
      server: server == null
          ? const Unavailable(UnavailableReason.notApplicable)
          : s(server),
      browser: browser == null
          ? const Unavailable(UnavailableReason.notApplicable)
          : b(browser),
      file: file == null
          ? const Unavailable(UnavailableReason.notApplicable)
          : Present(file, source: DataSource.file),
    );

FileSnapshot fileSnap(String text, {String name = 'a.html'}) => FileSnapshot(
      name: name,
      path: '/tmp/$name',
      origin: FileOrigin.picker,
      bytes: text.codeUnits,
      text: DecodedText(
          text: text,
          charset: 'utf-8',
          charsetSource: CharsetSource.bom,
          byteLength: text.length),
      lastModified: const Unavailable(UnavailableReason.notReportedByPlatform),
    );
