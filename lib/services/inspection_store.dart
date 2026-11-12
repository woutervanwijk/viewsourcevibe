import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/inspection/browser_snapshot.dart';
import '../models/inspection/file_snapshot.dart';
import '../models/inspection/observed.dart';
import '../models/inspection/page_inspection.dart';
import '../models/inspection/server_snapshot.dart';
import 'collectors/browser_payload.dart';

/// The central reactive data point. Every navigation gets a new generation;
/// results carrying an older generation are ignored (no state change, no
/// notification). Each effective mutation notifies exactly once.
class InspectionStore extends ChangeNotifier {
  PageInspection _current = const PageInspection.empty();

  PageInspection get current => _current;

  void _set(PageInspection next) {
    _current = next;
    notifyListeners();
  }

  int beginUrl(Uri url) {
    final gen = _current.generation + 1;
    _set(PageInspection(
      generation: gen,
      target: UrlTarget(url),
      server: const Pending(),
      browser: const Pending(),
      file: const Unavailable(UnavailableReason.notApplicable, 'not a file'),
      // primaryDocumentPreference is deliberately not carried over: begin* resets it.
    ));
    return gen;
  }

  int beginFile(FileSnapshot f) {
    final gen = _current.generation + 1;
    _set(PageInspection(
      generation: gen,
      target: FileTarget(f),
      server: const Unavailable(UnavailableReason.notApplicable, 'local file'),
      browser: const Unavailable(UnavailableReason.notApplicable, 'local file'),
      file: Present(f, source: DataSource.file),
      robots: const Unavailable(UnavailableReason.notApplicable, 'local file'),
    ));
    return gen;
  }

  /// Nothing is being inspected any more (the user cleared the page). Still a
  /// new generation, so results of the previous navigation are dropped.
  void clear() {
    _set(PageInspection(
      generation: _current.generation + 1,
      target: const NoTarget(),
      server:
          const Unavailable(UnavailableReason.notApplicable, 'nothing loaded'),
      browser:
          const Unavailable(UnavailableReason.notApplicable, 'nothing loaded'),
      file:
          const Unavailable(UnavailableReason.notApplicable, 'nothing loaded'),
      robots:
          const Unavailable(UnavailableReason.notApplicable, 'nothing loaded'),
    ));
  }

  bool _accepts(int gen) =>
      gen == _current.generation && _current.target is UrlTarget;

  void applyServer(int gen, Observed<ServerSnapshot> result) {
    if (!_accepts(gen)) return;
    // A Present server is only replaced by a fresher Present.
    if (_current.server is Present<ServerSnapshot> &&
        result is! Present<ServerSnapshot>) {
      return;
    }
    _set(_current.copyWith(server: result));
  }

  /// Robots are kept separately from the server result, so their arrival
  /// order relative to the main fetch does not matter.
  void applyRobots(int gen, Observed<RobotsInfo> robots) {
    if (!_accepts(gen)) return;
    _set(_current.copyWith(robots: robots));
  }

  /// A browser payload. A later payload for the same generation is merged:
  /// fresher Present sections replace older ones, resources are merged, and a
  /// section that is not Present never overwrites a Present one.
  void applyBrowser(int gen, BrowserSnapshot snap) {
    if (!_accepts(gen)) return;
    final old = _current.browser;
    // Nothing Present to accept over an existing Present result: no change.
    if (old is Present<BrowserSnapshot> && !snap.hasPresentSection) return;
    final merged =
        old is Present<BrowserSnapshot> ? _merge(old.value, snap) : snap;
    // A poll that reported nothing new keeps the same snapshot: no state
    // change, no notification (load polls must not jank the UI).
    if (old is Present<BrowserSnapshot> && identical(merged, old.value)) {
      return;
    }
    _set(_current.copyWith(
        browser: Present(merged, source: DataSource.browser)));
  }

  /// The browser run itself failed or is unavailable. Never overwrites a
  /// Present browser result.
  void applyBrowserFailure(int gen, Observed<BrowserSnapshot> result) {
    if (!_accepts(gen)) return;
    if (_current.browser is Present<BrowserSnapshot>) return;
    _set(_current.copyWith(browser: result));
  }

  /// Own size lookups for resources the browser could not size, merged per
  /// URL. A result that is not Present never replaces a Present estimate.
  /// Nothing new = no change, no notify.
  void applyEstimates(int gen, Map<String, Observed<int>> estimates) {
    if (!_accepts(gen)) return;
    final merged = _mergeEstimates(_current.resourceEstimates, estimates);
    if (merged == null) return;
    _set(_current.copyWith(resourceEstimates: merged));
  }

  /// Null when nothing changes.
  static Map<String, Observed<int>>? _mergeEstimates(
      Map<String, Observed<int>> current, Map<String, Observed<int>> fresh) {
    final merged = {...current};
    var changed = false;
    for (final e in fresh.entries) {
      final old = merged[e.key];
      if (old is Present<int> && e.value is! Present<int>) continue;
      merged[e.key] = e.value;
      changed = true;
    }
    return changed ? merged : null;
  }

  /// The media the page declares in its DOM (see
  /// [PageInspection.declaredMedia]): lazy images the browser may never
  /// fetch still belong in the Page size tab.
  void applyDeclaredMedia(int gen, List<String> urls) {
    if (!_accepts(gen)) return;
    if (listEquals(_current.declaredMedia, urls)) return;
    _set(_current.copyWith(declaredMedia: urls));
  }

  /// The live load stopped requesting (see [PageInspection.browserSettled]).
  void markBrowserSettled(int gen) {
    if (!_accepts(gen) || _current.browserSettled) return;
    _set(_current.copyWith(browserSettled: true));
  }

  /// The fresh (Lighthouse-like) load: Pending while it runs, then its
  /// result and screenshot. A new result drops the lookups and screenshot of
  /// the previous one.
  void applyFreshLoad(int gen, Observed<BrowserSnapshot> result,
      {Observed<Uint8List> screenshot = kNoScreenshot}) {
    if (!_accepts(gen)) return;
    _set(_current.copyWith(
        freshLoad: result,
        freshEstimates: const {},
        freshScreenshot: screenshot));
  }

  /// A screenshot of the live browser; a missing one never replaces a
  /// screenshot already there.
  void applyLiveScreenshot(int gen, Observed<Uint8List> shot) {
    if (!_accepts(gen)) return;
    if (shot is! Present<Uint8List> &&
        _current.liveScreenshot is Present<Uint8List>) {
      return;
    }
    _set(_current.copyWith(liveScreenshot: shot));
  }

  /// Own size lookups for the fresh load, merged like [applyEstimates].
  void applyFreshEstimates(int gen, Map<String, Observed<int>> estimates) {
    if (!_accepts(gen)) return;
    final merged = _mergeEstimates(_current.freshEstimates, estimates);
    if (merged == null) return;
    _set(_current.copyWith(freshEstimates: merged));
  }

  // Up to hundreds of per-URL size lookups finish per page; applying each
  // with its own notifyListeners() re-runs every selector that many times.
  // Queued results are merged and notified once per event-loop turn.
  final Map<String, Observed<int>> _pendingEstimates = {};
  final Map<String, Observed<int>> _pendingFreshEstimates = {};
  int? _pendingEstimatesGen;
  bool _estimateFlushScheduled = false;
  bool _disposed = false;

  /// Queues one own size lookup; everything queued in the same turn is
  /// applied as one notification.
  void queueEstimate(int gen, String url, Observed<int> result) {
    if (!_accepts(gen)) return;
    _queueEstimate(gen, _pendingEstimates, url, result);
  }

  /// Same as [queueEstimate] for the fresh (Lighthouse-like) load.
  void queueFreshEstimate(int gen, String url, Observed<int> result) {
    if (!_accepts(gen)) return;
    _queueEstimate(gen, _pendingFreshEstimates, url, result);
  }

  void _queueEstimate(
      int gen, Map<String, Observed<int>> into, String url, Observed<int> r) {
    if (_pendingEstimatesGen != gen) {
      // A newer navigation started: drop everything queued for the old one.
      _pendingEstimatesGen = gen;
      _pendingEstimates.clear();
      _pendingFreshEstimates.clear();
    }
    into[url] = r;
    if (_estimateFlushScheduled) return;
    _estimateFlushScheduled = true;
    scheduleMicrotask(_flushEstimates);
  }

  void _flushEstimates() {
    _estimateFlushScheduled = false;
    if (_disposed) return;
    final gen = _pendingEstimatesGen;
    final estimates = Map.of(_pendingEstimates);
    final fresh = Map.of(_pendingFreshEstimates);
    _pendingEstimates.clear();
    _pendingFreshEstimates.clear();
    if (gen == null) return;
    if (estimates.isNotEmpty) applyEstimates(gen, estimates);
    if (fresh.isNotEmpty) applyFreshEstimates(gen, fresh);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void setPrimaryDocument(DataSource? s) {
    if (_current.primaryDocumentPreference == s) return;
    _set(_current.copyWith(primaryDocumentPreference: s));
  }
}

Observed<T> _fresher<T>(Observed<T> old, Observed<T> fresh) {
  if (fresh is Present<T> || old is! Present<T>) {
    // Equal values keep the old instance, so a no-op poll merge stays
    // identity-stable and the store can skip notifying.
    if (old is Present<T> && fresh is Present<T> && old.value == fresh.value) {
      return old;
    }
    return fresh;
  }
  return old;
}

/// Whether [a] and [b] hold the same data; used to drop no-op poll merges.
bool _sameBrowser(BrowserSnapshot a, BrowserSnapshot b) {
  if (identical(a, b)) return true;
  final ra = a.resources, rb = b.resources;
  var sameResources = identical(ra, rb);
  if (!sameResources &&
      ra is Present<List<ResourceEntry>> &&
      rb is Present<List<ResourceEntry>>) {
    final la = ra.value, lb = rb.value;
    sameResources = la.length == lb.length;
    for (var i = 0; i < la.length && sameResources; i++) {
      sameResources = resourceEntriesEqual(la[i], lb[i]);
    }
  }
  return a.url == b.url &&
      a.platform == b.platform &&
      sameObserved(a.contentType, b.contentType) &&
      sameObserved(a.renderedDom, b.renderedDom) &&
      sameResources &&
      sameObserved(a.cookies, b.cookies) &&
      sameObserved(a.storage, b.storage) &&
      sameObserved(a.navigation, b.navigation) &&
      sameObserved(a.snapshotTimeMs, b.snapshotTimeMs) &&
      a.resourcesTruncated == b.resourcesTruncated &&
      a.resourcesDropped == b.resourcesDropped &&
      a.rawPayload == b.rawPayload;
}

BrowserSnapshot _merge(BrowserSnapshot old, BrowserSnapshot n) {
  final Observed<List<ResourceEntry>> resources;
  final o = old.resources, f = n.resources;
  if (o is Present<List<ResourceEntry>> && f is Present<List<ResourceEntry>>) {
    resources = Present(mergeResources(o.value, f.value),
        source: f.source, provenance: f.provenance);
  } else {
    resources = _fresher(o, f);
  }
  final merged = BrowserSnapshot(
    url: n.url,
    platform: n.platform,
    contentType: _fresher(old.contentType, n.contentType),
    renderedDom: _fresher(old.renderedDom, n.renderedDom),
    resources: resources,
    cookies: _fresher(old.cookies, n.cookies),
    storage: _fresher(old.storage, n.storage),
    navigation: _fresher(old.navigation, n.navigation),
    snapshotTimeMs: _fresher(old.snapshotTimeMs, n.snapshotTimeMs),
    resourcesTruncated: old.resourcesTruncated || n.resourcesTruncated,
    resourcesDropped: max(old.resourcesDropped, n.resourcesDropped),
    rawPayload: n.rawPayload ?? old.rawPayload,
  );
  return _sameBrowser(old, merged) ? old : merged;
}
