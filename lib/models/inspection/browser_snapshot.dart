import 'observed.dart';

/// The platform the WebView ran on. WebKit = ios + macos.
enum BrowserPlatform { ios, macos, android, windows, linux, unknown }

extension BrowserPlatformX on BrowserPlatform {
  bool get isWebKit =>
      this == BrowserPlatform.ios || this == BrowserPlatform.macos;
}

/// Where a resource entry came from. The observer wins over the patch (B13).
/// Where an entry came from: the resource-timing observer, the fetch/XHR
/// patch, an image shown on the page that neither reported (WebKit gives
/// no timing entry for an image served from its memory cache), or a URL the
/// collector's buffer dropped (no sizes at all; any real source beats it).
enum ResourceSource { observer, patch, shownImage, dropped }

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

  @override
  bool operator ==(Object other) =>
      other is RenderedDom &&
      other.text == text &&
      other.unwrappedRawDocument == unwrappedRawDocument &&
      other.iframeCount == iframeCount &&
      other.shadowRootCount == shadowRootCount;

  @override
  int get hashCode =>
      Object.hash(text, unwrappedRawDocument, iframeCount, shadowRootCount);

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

  /// Origin of the iframe that loaded it (ads, embeds), as the iframe
  /// reported it; '' when it could not tell. Null: the page itself.
  final String? frameOrigin;

  /// Loaded inside an iframe, not by the page itself.
  bool get inFrame => frameOrigin != null;

  const ResourceEntry({
    required this.url,
    required this.type,
    required this.source,
    required this.startTime,
    required this.duration,
    required this.transfer,
    required this.decoded,
    this.fromCache = false,
    this.frameOrigin,
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

  @override
  bool operator ==(Object other) =>
      other is BrowserCookie &&
      other.name == name &&
      other.value == value &&
      sameObserved(other.domain, domain) &&
      sameObserved(other.path, path) &&
      sameObserved(other.expires, expires) &&
      sameObserved(other.isSecure, isSecure) &&
      sameObserved(other.isHttpOnly, isHttpOnly) &&
      sameObserved(other.sameSite, sameSite);

  @override
  int get hashCode => Object.hash(
      name, value, domain, path, expires, isSecure, isHttpOnly, sameSite);
}

class StorageItem {
  final String key;

  /// UTF-8 bytes of key + value.
  final int bytes;
  const StorageItem(this.key, this.bytes);

  @override
  bool operator ==(Object other) =>
      other is StorageItem && other.key == key && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(key, bytes);
}

class StorageArea {
  final int count;

  /// UTF-8 byte length of all keys + values (computed in Dart).
  final Observed<int> bytes;

  /// Largest items first (at most 10).
  final List<StorageItem> topItems;
  const StorageArea(
      {required this.count, required this.bytes, required this.topItems});

  @override
  bool operator ==(Object other) {
    if (other is! StorageArea) return false;
    if (other.count != count || !sameObserved(other.bytes, bytes)) {
      return false;
    }
    if (other.topItems.length != topItems.length) return false;
    for (var i = 0; i < topItems.length; i++) {
      if (other.topItems[i] != topItems[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(count, bytes, topItems.length);
}

class BrowserStorage {
  final Observed<StorageArea> local;
  final Observed<StorageArea> session;
  const BrowserStorage({required this.local, required this.session});

  @override
  bool operator ==(Object other) =>
      other is BrowserStorage &&
      sameObserved(other.local, local) &&
      sameObserved(other.session, session);

  @override
  int get hashCode => Object.hash(local, session);
}

class NavigationTiming {
  final Observed<double> timeToFirstByte;
  final Observed<double> domInteractive;
  final Observed<double> domContentLoaded;
  final Observed<double> loadEvent;
  final Observed<String> protocol;

  /// Size of the HTML document as the browser downloaded / decoded it.
  final Observed<int> documentTransfer;
  final Observed<int> documentDecoded;
  const NavigationTiming({
    required this.timeToFirstByte,
    required this.domInteractive,
    required this.domContentLoaded,
    required this.loadEvent,
    required this.protocol,
    this.documentTransfer =
        const Unavailable(UnavailableReason.notReportedByPlatform),
    this.documentDecoded =
        const Unavailable(UnavailableReason.notReportedByPlatform),
  });

  @override
  bool operator ==(Object other) =>
      other is NavigationTiming &&
      sameObserved(other.timeToFirstByte, timeToFirstByte) &&
      sameObserved(other.domInteractive, domInteractive) &&
      sameObserved(other.domContentLoaded, domContentLoaded) &&
      sameObserved(other.loadEvent, loadEvent) &&
      sameObserved(other.protocol, protocol) &&
      sameObserved(other.documentTransfer, documentTransfer) &&
      sameObserved(other.documentDecoded, documentDecoded);

  @override
  int get hashCode => Object.hash(timeToFirstByte, domInteractive,
      domContentLoaded, loadEvent, protocol, documentTransfer, documentDecoded);
}

/// One iframe as the page declares it.
class FrameInfo {
  /// Absolute URL; '' for srcdoc / about:blank frames.
  final String src;

  /// The raw `allow` attribute, '' when absent.
  final String allow;

  /// The raw `sandbox` attribute; null = no sandbox attribute.
  final String? sandbox;
  const FrameInfo({required this.src, this.allow = '', this.sandbox});

  @override
  bool operator ==(Object other) =>
      other is FrameInfo &&
      other.src == src &&
      other.allow == allow &&
      other.sandbox == sandbox;

  @override
  int get hashCode => Object.hash(src, allow, sandbox);
}

class ServiceWorkerInfo {
  final String scope;
  final String script;
  const ServiceWorkerInfo({required this.scope, required this.script});

  @override
  bool operator ==(Object other) =>
      other is ServiceWorkerInfo &&
      other.scope == scope &&
      other.script == script;

  @override
  int get hashCode => Object.hash(scope, script);
}

/// What the site keeps on the device besides cookies and Web Storage.
class SiteStorage {
  final Observed<int> usageBytes;
  final Observed<int> quotaBytes;
  final Observed<List<String>> indexedDbNames;
  final Observed<List<String>> cacheNames;
  final Observed<List<ServiceWorkerInfo>> serviceWorkers;
  const SiteStorage({
    required this.usageBytes,
    required this.quotaBytes,
    required this.indexedDbNames,
    required this.cacheNames,
    required this.serviceWorkers,
  });

  @override
  bool operator ==(Object other) =>
      other is SiteStorage &&
      sameObserved(other.usageBytes, usageBytes) &&
      sameObserved(other.quotaBytes, quotaBytes) &&
      sameObserved(other.indexedDbNames, indexedDbNames) &&
      sameObserved(other.cacheNames, cacheNames) &&
      sameObserved(other.serviceWorkers, serviceWorkers);

  @override
  int get hashCode => Object.hash(
      usageBytes.runtimeType,
      quotaBytes.runtimeType,
      indexedDbNames.runtimeType,
      cacheNames.runtimeType,
      serviceWorkers.runtimeType);
}

const kFramesNotCollected = Unavailable<List<FrameInfo>>(
    UnavailableReason.notReportedByPlatform, 'not collected');
const kSiteStorageNotCollected = Unavailable<SiteStorage>(
    UnavailableReason.notReportedByPlatform, 'not collected');

const kCapabilityNotCollected = Unavailable<bool>(
    UnavailableReason.notReportedByPlatform, 'not collected');

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

  /// HTTP status of the main document as the browser received it
  /// (PerformanceNavigationTiming.responseStatus, or the WebView's main-frame
  /// HTTP error callback for >= 400 where the page cannot see it).
  final Observed<int> mainStatus;

  /// performance.now() when the snapshot was taken: resources are a snapshot up
  /// to this time.
  final Observed<double> snapshotTimeMs;

  /// True when the collector hit its buffer cap and dropped resource entries:
  /// [resources] is then incomplete. [resourcesDropped] is how many.
  final bool resourcesTruncated;
  final int resourcesDropped;

  /// The iframes the page declares (at most 200) and how many there are.
  final Observed<List<FrameInfo>> frames;
  final int frameCount;

  /// Quota usage, IndexedDB, Cache Storage and service workers.
  final Observed<SiteStorage> siteStorage;

  /// Whether the page can ask for camera/microphone and for location at all
  /// (navigator.mediaDevices.getUserMedia / navigator.geolocation exist).
  final Observed<bool> mediaDevices;
  final Observed<bool> geolocation;

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
    this.mainStatus = mainStatusNotReported,
    this.resourcesTruncated = false,
    this.resourcesDropped = 0,
    this.frames = kFramesNotCollected,
    this.frameCount = 0,
    this.siteStorage = kSiteStorageNotCollected,
    this.mediaDevices = kCapabilityNotCollected,
    this.geolocation = kCapabilityNotCollected,
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

  static const mainStatusNotReported = Unavailable<int>(
      UnavailableReason.notReportedByPlatform,
      'the browser did not report the HTTP status of the page');

  /// A copy with [cookies] replaced (e.g. by the native cookie manager's).
  BrowserSnapshot withCookies(Observed<List<BrowserCookie>> cookies) =>
      copyWith(cookies: cookies);

  /// A copy with [mainStatus] replaced (e.g. by the WebView's HTTP error).
  BrowserSnapshot withMainStatus(Observed<int> mainStatus) =>
      copyWith(mainStatus: mainStatus);

  BrowserSnapshot copyWith(
          {Observed<List<BrowserCookie>>? cookies,
          Observed<int>? mainStatus,
          Observed<bool>? mediaDevices,
          Observed<bool>? geolocation}) =>
      BrowserSnapshot(
        url: url,
        platform: platform,
        contentType: contentType,
        renderedDom: renderedDom,
        resources: resources,
        cookies: cookies ?? this.cookies,
        storage: storage,
        navigation: navigation,
        snapshotTimeMs: snapshotTimeMs,
        mainStatus: mainStatus ?? this.mainStatus,
        resourcesTruncated: resourcesTruncated,
        resourcesDropped: resourcesDropped,
        frames: frames,
        frameCount: frameCount,
        siteStorage: siteStorage,
        mediaDevices: mediaDevices ?? this.mediaDevices,
        geolocation: geolocation ?? this.geolocation,
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
        frames: Unavailable(reason, detail),
        siteStorage: Unavailable(reason, detail),
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
        frames: Failed(error),
        siteStorage: Failed(error),
        rawPayload: rawPayload,
      );
}
