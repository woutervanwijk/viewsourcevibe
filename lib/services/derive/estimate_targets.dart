import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../probe_service.dart';

/// Initiator types of static resources. Choice: a plain GET of a script,
/// stylesheet, font, image or media file is treated as safe to repeat (it is
/// what the browser already did, and such URLs are not API calls). The small
/// remaining risk is a script URL that is really a tracking endpoint; that is
/// accepted because the page size would otherwise stay unknown.
/// Everything else (xhr, fetch, beacon, ping, iframe, navigation, other,
/// unknown) could be an API call or tracking with side effects.
const _estimableTypes = {
  'script',
  'link',
  'css',
  'font',
  'img',
  'image',
  'video',
  'audio',
  'media',
};

/// Whether the app may request this resource again to learn its size.
bool isEstimableResourceType(String rawType, String url) {
  final type = rawType.toLowerCase();
  if (!_estimableTypes.contains(type)) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  // A <link> can also point at a page (alternate, next, prefetch).
  if ((type == 'link' || type == 'css') &&
      ProbeService.resourceTypeFromExtension(url) == 'document') {
    return false;
  }
  return true;
}

/// The URLs worth an own size lookup, at most [limit]: static resources the
/// browser loaded but gave no transfer size, once each. Nothing until the
/// browser's resources are Present. A cached resource is skipped (its decoded
/// size is known), as is a URL that already has an estimate or a failure.
List<String> estimateTargets(PageInspection p, {int limit = 80}) {
  final browser = p.browser;
  if (browser is! Present<BrowserSnapshot>) return const [];
  final res = browser.value.resources;
  if (res is! Present<List<ResourceEntry>>) return const [];
  final out = <String>{};
  for (final r in res.value) {
    if (out.length >= limit) break;
    final tx = r.transfer;
    if (tx is Present<int>) continue;
    if (tx is Unavailable<int> &&
        tx.reason == UnavailableReason.servedFromCache) {
      continue;
    }
    if (p.resourceEstimates.containsKey(r.url)) continue;
    if (!isEstimableResourceType(r.type, r.url)) continue;
    out.add(r.url);
  }
  return out.toList();
}
