import '../../utils/text_decoding.dart';
import 'observed.dart';

/// One request/response in a redirect chain.
class HttpHop {
  final Uri url;
  final int statusCode;
  final String reasonPhrase;

  /// Lowercased names; repeated headers keep every value.
  final Map<String, List<String>> headers;
  final List<String> setCookies;

  /// The connected socket's address (no DNS lookup).
  final Observed<String> remoteAddress;

  /// TLS leaf certificate info (https only).
  final Observed<Map<String, dynamic>> certificate;

  const HttpHop({
    required this.url,
    required this.statusCode,
    required this.reasonPhrase,
    required this.headers,
    required this.setCookies,
    required this.remoteAddress,
    required this.certificate,
  });

  String? header(String name) {
    final v = headers[name.toLowerCase()];
    return v == null || v.isEmpty ? null : v.join(', ');
  }
}

/// The final response body as received from the server.
class ServerBody {
  final DecodedText decoded;

  /// Decoded (after Content-Encoding) bytes kept; same as `decoded.byteLength`.
  int get byteLength => decoded.byteLength;

  /// Bytes received on the wire for the body (compressed size if compressed).
  /// When [truncated], only the bytes read before the cutoff are counted.
  final int transferLength;

  /// True when the body was cut off at the byte limit.
  final bool truncated;

  /// The Content-Length header, when the server sent one.
  final Observed<int> contentLength;
  final String? contentEncoding;

  const ServerBody({
    required this.decoded,
    required this.transferLength,
    required this.truncated,
    required this.contentLength,
    this.contentEncoding,
  });
}

/// robots.txt and sitemap.xml findings for an origin.
class RobotsInfo {
  final Observed<int> robotsStatus;
  final Observed<String> robotsText;

  /// True when robots.txt exceeded the size limit: [robotsText] is only the
  /// first part and the counts/sitemaps are Unavailable.
  final bool robotsTruncated;

  /// Counts over all user-agent groups.
  final Observed<int> disallowCount;
  final Observed<int> allowCount;
  final Observed<List<String>> sitemaps;
  final Observed<int> sitemapStatus;

  const RobotsInfo({
    required this.robotsStatus,
    required this.robotsText,
    required this.disallowCount,
    required this.allowCount,
    required this.sitemaps,
    required this.sitemapStatus,
    this.robotsTruncated = false,
  });
}

/// What a direct (curl-like) fetch of a URL returned.
class ServerSnapshot {
  final Uri requestedUrl;
  final String userAgent;
  final List<HttpHop> hops;

  /// Last URL of a completed chain; never the requested URL when the chain
  /// was cut short or failed.
  final Observed<Uri> finalUrl;
  final Observed<ServerBody> body;

  /// Total duration of the whole fetch in milliseconds.
  final Observed<int> timingMs;

  /// Certificate of the final hop.
  final Observed<Map<String, dynamic>> certificate;

  /// Pending until `fetchRobots` has run; use [withRobots].
  final Observed<RobotsInfo> robots;

  /// True when the user accepted an untrusted TLS certificate for this fetch
  /// (the content was loaded anyway, for inspection).
  final bool acceptedInvalidCertificate;

  const ServerSnapshot({
    required this.requestedUrl,
    required this.userAgent,
    required this.hops,
    required this.finalUrl,
    required this.body,
    required this.timingMs,
    required this.certificate,
    this.robots = const Pending(),
    this.acceptedInvalidCertificate = false,
  });

  ServerSnapshot withRobots(Observed<RobotsInfo> robots) => ServerSnapshot(
        requestedUrl: requestedUrl,
        userAgent: userAgent,
        hops: hops,
        finalUrl: finalUrl,
        body: body,
        timingMs: timingMs,
        certificate: certificate,
        robots: robots,
        acceptedInvalidCertificate: acceptedInvalidCertificate,
      );
}
