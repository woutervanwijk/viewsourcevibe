/// Query params that don't change the resource content (cache-busters).
const _cacheBusterParams = {
  'v',
  'ver',
  'version',
  't',
  'ts',
  'timestamp',
  'hash',
  '_',
  'cache',
  'cachebuster',
  'cb',
  'nocache',
  'rev',
  'revision',
};

/// Query string with cache-busting params removed, sorted for comparison.
String queryWithoutCacheBusters(Uri uri) {
  final params = Map<String, String>.from(uri.queryParameters);
  params
      .removeWhere((key, _) => _cacheBusterParams.contains(key.toLowerCase()));
  final keys = params.keys.toList()..sort();
  return keys.map((k) => '$k=${params[k]}').join('&');
}

/// True when [url1] and [url2] point to the same resource: same host and
/// path, and query params equal after dropping cache-busters. CDN
/// versioning (`?v=1` vs `?v=2`) still matches, but content-changing params
/// such as image resize options (`?width=112` vs `?width=264` or none)
/// never do.
bool sameResourceModuloCacheBusters(String url1, String url2) {
  if (url1 == url2) return true;
  try {
    final uri1 = Uri.parse(url1);
    final uri2 = Uri.parse(url2);
    if (uri1.host.toLowerCase() != uri2.host.toLowerCase()) return false;
    if (uri1.path != uri2.path) return false;
    return queryWithoutCacheBusters(uri1) == queryWithoutCacheBusters(uri2);
  } catch (_) {
    return false;
  }
}
