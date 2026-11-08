import 'observed.dart';

/// The platform the WebView ran on. WebKit = ios + macos.
enum BrowserPlatform { ios, macos, android, windows, linux, unknown }

extension BrowserPlatformX on BrowserPlatform {
  bool get isWebKit =>
      this == BrowserPlatform.ios || this == BrowserPlatform.macos;
}

/// Where a resource entry came from. The observer wins over the patch (B13).
enum ResourceSource { observer, patch }

/// The serialized DOM as the browser currently holds it.
class RenderedDom {
  /// For HTML/XML the serialized DOM; for plain-text/JSON/JS/CSS documents the
  /// raw document text (the browser's <pre> wrapper removed).
  final String text;

  /// Number of characters (UTF-16 code units) in [text]. Not bytes.
  int get domCharCount => text.length;

  /// True when [text] is the unwrapped content of a non-HTML document.
  final bool unwrappedRawDocument;
  final int iframeCount;
  final int shadowRootCount;

  const RenderedDom({
    required this.text,
    this.unwrappedRawDocument = false,
    this.iframeCount = 0,
    this.shadowRootCount = 0,
  });

  /// Parts of the page that [text] does not contain.
  List<String> get limitations => [
        if (iframeCount > 0) 'iframes not included ($iframeCount)',
        if (shadowRootCount > 0) 'shadow DOM not included ($shadowRootCount)',
      ];
}

class ResourceEntry {
  /// Absolute URL (resolved against the page URL, fragment removed).
  final String url;

  /// initiatorType (observer) or 'fetch' / 'xhr' (patch).
  final String type;
  final ResourceSource source;
  final Observed<double> startTime;
  final Observed<double> duration;

  /// Bytes on the wire (compressed). Never a fabricated 0.
  final Observed<int> transfer;

  /// Decoded body bytes. Never a fabricated 0.
  final Observed<int> decoded;

  /// Served from the browser cache. [transfer] is then the encoded
  /// (compressed) body size, what a fresh load downloads (derived, without
  /// headers), so cache hits are counted like everything else.
  final bool fromCache;

  const ResourceEntry({
    required this.url,
    required this.type,
    required this.source,
    required this.startTime,
    required this.duration,
    required this.transfer,
    required this.decoded,
    this.fromCache = false,
  });
}

class BrowserCookie {
  final String name;
  final String value;
  final Observed<String> domain;
  final Observed<String> path;
  final Observed<DateTime> expires;
  final Observed<bool> isSecure;
  final Observed<bool> isHttpOnly;
  final Observed<String> sameSite;

  const BrowserCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.expires,
    required this.isSecure,
    required this.isHttpOnly,
    required this.sameSite,
  });
}

class StorageItem {
  final String key;

  /// UTF-8 bytes of key + value.
  final int bytes;
  const StorageItem(this.key, this.bytes);
}

class StorageArea {
  final int count;

  /// UTF-8 byte length of all keys + values (computed in Dart).
  final Observed<int> bytes;

  /// Largest items first (at most 10).
  final List<StorageItem> topItems;
  const StorageArea(
      {required this.count, required this.bytes, required this.topItems});
}

class BrowserStorage {
  final Observed<StorageArea> local;
  final Observed<StorageArea> session;
  const BrowserStorage({required this.local, required this.session});
}

class NavigationTiming {
  final Observed<double> timeToFirstByte;
  final Observed<double> domInteractive;
  final Observed<double> domContentLoaded;
  final Observed<double> loadEvent;
  final Observed<String> protocol;
  const NavigationTiming({
    required this.timeToFirstByte,
    required this.domInteractive,
    required this.domContentLoaded,
    required this.loadEvent,
    required this.protocol,
  });
}

/// Everything the WebView told us about the current page, one section each.
class BrowserSnapshot {
  final Uri url;
  final BrowserPlatform platform;
  final Observed<String> contentType;
  final Observed<RenderedDom> renderedDom;
  final Observed<List<ResourceEntry>> resources;
  final Observed<List<BrowserCookie>> cookies;
  final Observed<BrowserStorage> storage;
  final Observed<NavigationTiming> navigation;

  /// performance.now() when the snapshot was taken: resources are a snapshot up
  /// to this time.
  final Observed<double> snapshotTimeMs;

  /// True when the collector hit its buffer cap and dropped resource entries:
  /// [resources] is then incomplete. [resourcesDropped] is how many.
  final bool resourcesTruncated;
  final int resourcesDropped;

  /// The raw collector payload (debug export / fixture recording).
  final String? rawPayload;

  const BrowserSnapshot({
    required this.url,
    required this.platform,
    required this.contentType,
    required this.renderedDom,
    required this.resources,
    required this.cookies,
    required this.storage,
    required this.navigation,
    required this.snapshotTimeMs,
    this.resourcesTruncated = false,
    this.resourcesDropped = 0,
    this.rawPayload,
  });

  /// True when at least one section holds a value.
  bool get hasPresentSection =>
      contentType is Present ||
      renderedDom is Present ||
      resources is Present ||
      cookies is Present ||
      storage is Present ||
      navigation is Present ||
      snapshotTimeMs is Present;

  /// A copy with [cookies] replaced (e.g. by the native cookie manager's).
  BrowserSnapshot withCookies(Observed<List<BrowserCookie>> cookies) =>
      BrowserSnapshot(
        url: url,
        platform: platform,
        contentType: contentType,
        renderedDom: renderedDom,
        resources: resources,
        cookies: cookies,
        storage: storage,
        navigation: navigation,
        snapshotTimeMs: snapshotTimeMs,
        resourcesTruncated: resourcesTruncated,
        resourcesDropped: resourcesDropped,
        rawPayload: rawPayload,
      );

  /// Every section [Unavailable] with the same reason.
  factory BrowserSnapshot.unavailable(
    Uri url,
    BrowserPlatform platform,
    UnavailableReason reason,
    String detail, {
    String? rawPayload,
  }) =>
      BrowserSnapshot(
        url: url,
        platform: platform,
        contentType: Unavailable(reason, detail),
        renderedDom: Unavailable(reason, detail),
        resources: Unavailable(reason, detail),
        cookies: Unavailable(reason, detail),
        storage: Unavailable(reason, detail),
        navigation: Unavailable(reason, detail),
        snapshotTimeMs: Unavailable(reason, detail),
        rawPayload: rawPayload,
      );

  /// Every section [Failed] with the same error.
  factory BrowserSnapshot.failed(
    Uri url,
    BrowserPlatform platform,
    String error, {
    String? rawPayload,
  }) =>
      BrowserSnapshot(
        url: url,
        platform: platform,
        contentType: Failed(error),
        renderedDom: Failed(error),
        resources: Failed(error),
        cookies: Failed(error),
        storage: Failed(error),
        navigation: Failed(error),
        snapshotTimeMs: Failed(error),
        rawPayload: rawPayload,
      );
}
