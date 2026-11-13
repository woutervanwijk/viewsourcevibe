import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Whether a website-data record belongs to [host]. Records are named by
/// their registrable domain ("w3.org"), the host may be a subdomain of it
/// ("www.w3.org").
bool siteDataRecordMatches(String host, String? recordName) {
  if (recordName == null || recordName.isEmpty || host.isEmpty) return false;
  final h = host.toLowerCase();
  final r = recordName.toLowerCase();
  return h == r || h.endsWith('.$r') || r.endsWith('.$h');
}

/// Removes everything the in-app browser stored for the site of [url]:
/// cookies (also those set on a parent domain), cache, local storage,
/// IndexedDB and the like. Each step is best effort; a step a platform
/// does not support is skipped.
///
/// On Apple platforms and Linux this is per site. Android's WebView cache is
/// shared by all sites and can only be cleared as a whole, so there (and as a
/// fallback elsewhere) the whole cache is cleared; other sites' cookies and
/// storage stay.
Future<void> clearSiteData(Uri url) async {
  final host = url.host;
  final webUri = WebUri(url.toString());

  final cookies = CookieManager.instance();
  try {
    for (final cookie in await cookies.getCookies(url: webUri)) {
      await cookies.deleteCookie(
        url: webUri,
        name: cookie.name,
        domain: cookie.domain,
        path: cookie.path ?? '/',
      );
    }
    await cookies.deleteCookies(url: webUri);
  } catch (e) {
    debugPrint('Clearing cookies for $host failed: $e');
  }

  final storage = WebStorageManager.instance();
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await storage.deleteOrigin(origin: url.origin);
      await InAppWebViewController.clearAllCache();
    } else {
      final records =
          await storage.fetchDataRecords(dataTypes: WebsiteDataType.ALL);
      final ofSite = [
        for (final r in records)
          if (siteDataRecordMatches(host, r.displayName)) r,
      ];
      if (ofSite.isNotEmpty) {
        await storage.removeDataFor(
            dataTypes: WebsiteDataType.ALL, dataRecords: ofSite);
      }
    }
  } catch (e) {
    debugPrint('Clearing site storage for $host failed, clearing cache: $e');
    try {
      await InAppWebViewController.clearAllCache();
    } catch (_) {}
  }
}
