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
    if (old is Present<BrowserSnapshot> && !_hasPresentSection(snap)) return;
    final merged =
        old is Present<BrowserSnapshot> ? _merge(old.value, snap) : snap;
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

  void setPrimaryDocument(DataSource? s) {
    if (_current.primaryDocumentPreference == s) return;
    _set(_current.copyWith(primaryDocumentPreference: s));
  }
}

bool _hasPresentSection(BrowserSnapshot b) =>
    b.contentType is Present ||
    b.renderedDom is Present ||
    b.resources is Present ||
    b.cookies is Present ||
    b.storage is Present ||
    b.navigation is Present ||
    b.snapshotTimeMs is Present;

Observed<T> _fresher<T>(Observed<T> old, Observed<T> fresh) =>
    fresh is Present<T> || old is! Present<T> ? fresh : old;

BrowserSnapshot _merge(BrowserSnapshot old, BrowserSnapshot n) {
  final Observed<List<ResourceEntry>> resources;
  final o = old.resources, f = n.resources;
  if (o is Present<List<ResourceEntry>> && f is Present<List<ResourceEntry>>) {
    resources = Present(mergeResources(o.value, f.value),
        source: f.source, provenance: f.provenance);
  } else {
    resources = _fresher(o, f);
  }
  return BrowserSnapshot(
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
}
