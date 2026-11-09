import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../probe_service.dart';
import 'page_weight.dart' show unfetchedDeclaredMedia;

/// Initiator types of static resources. Choice: a plain GET of a script,
/// stylesheet, font, image or media file is treated as safe to repeat (it is
/// what the browser already did, and such URLs are not API calls). The small
/// remaining risk is a script URL that is really a tracking endpoint; that is
/// accepted because the page size would otherwise stay unknown.
/// Everything else (xhr, fetch, beacon, ping, iframe, navigation, other,
/// unknown) could be an API call or tracking with side effects. Audio and
/// video are not downloaded: the browser streams only part of them, so a
/// full download would not be what the page cost.
const _estimableTypes = {
  'script',
  'link',
  'css',
  'font',
  'img',
  'image',
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
/// browser loaded but gave no transfer size, once each, plus images the page
/// declares in its DOM but this load never fetched (lazy images), so the Page
/// size tab can list them too. Nothing until the browser's resources are
/// Present. A cache hit without an encoded size is looked up too (it is
/// counted like a fresh load). A URL that already has an estimate or a failure.
List<String> estimateTargets(PageInspection p, {int limit = 400}) =>
    estimateTargetsOf(p.browser, p.resourceEstimates,
        limit: limit, declaredMedia: p.declaredMedia);

/// [estimateTargets] for one load ([browser]) and its lookups so far.
List<String> estimateTargetsOf(
    Observed<BrowserSnapshot> browser, Map<String, Observed<int>> estimates,
    {int limit = 400, List<String> declaredMedia = const []}) {
  if (browser is! Present<BrowserSnapshot>) return const [];
  final res = browser.value.resources;
  if (res is! Present<List<ResourceEntry>>) return const [];
  final out = <String>{};
  final resourceUrls = <String>[];
  for (final r in res.value) {
    resourceUrls.add(r.url);
    if (out.length >= limit) break;
    final tx = r.transfer;
    if (tx is Present<int>) continue;
    if (estimates.containsKey(r.url)) continue;
    if (!isEstimableResourceType(r.type, r.url)) continue;
    out.add(r.url);
  }
  // Declared in the DOM but never fetched: an image, so a plain GET is safe.
  for (final u in unfetchedDeclaredMedia(resourceUrls, declaredMedia)) {
    if (out.length >= limit) break;
    if (estimates.containsKey(u)) continue;
    if (!isEstimableResourceType('img', u)) continue;
    out.add(u);
  }
  return out.toList();
}
