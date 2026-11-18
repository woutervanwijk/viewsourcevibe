import 'dart:async';

import '../utils/site.dart';
import 'detection/catalog.dart';
import 'sovereignty_service.dart';

/// A host on the page's own site whose DNS name is an alias for a tracker.
class CnameAlias {
  final String host; // metrics.shop.test
  final String target; // shop.sc.omtrdc.net
  final String tracker; // catalogue entity name
  const CnameAlias(this.host, this.target, this.tracker);

  Map<String, Object?> toJson() =>
      {'host': host, 'target': target, 'tracker': tracker};
}

class CloakingResult {
  final List<CnameAlias> aliases;
  final List<String> checked;

  /// Hosts whose lookup failed or timed out.
  final List<String> notChecked;
  const CloakingResult({
    this.aliases = const [],
    this.checked = const [],
    this.notChecked = const [],
  });
}

/// CNAME targets of a host: null when the lookup failed, empty when it has none.
typedef CnameLookup = Future<List<String>?> Function(String host);

/// [findCloakedTrackers] without its tuning knobs (a seam for tests).
typedef CloakingFinder = Future<CloakingResult> Function(
    Iterable<String> resourceHosts,
    {required String pageHost,
    required CnameLookup lookup});

/// The app's own DNS-over-HTTPS lookup of CNAME records.
Future<List<String>?> dohCnameLookup(String host) =>
    SovereigntyService.dnsQuery(host, 5);

/// Categories whose services exist to follow visitors. Marketing and CRM
/// entities also own hosting domains (force.com), so an alias for those says
/// nothing about tracking.
const Set<DetectionCategory> kCloakingTrackerCategories = {
  DetectionCategory.advertising,
  DetectionCategory.behavior,
  DetectionCategory.analytics,
};

const int kCloakingMaxHosts = 20;
const int kCloakingParallel = 4;

/// Hosts of [resourceHosts] on the page's own site (same registrable domain,
/// not the page host itself), at most [max]; each is looked up once. A lookup
/// that fails, throws or exceeds [lookupTimeout] lists that host as not
/// checked and does not stop the others.
Future<CloakingResult> findCloakedTrackers(
  Iterable<String> resourceHosts, {
  required String pageHost,
  required CnameLookup lookup,
  int max = kCloakingMaxHosts,
  Duration lookupTimeout = const Duration(seconds: 12),
}) async {
  final page = pageHost.toLowerCase();
  final hosts = <String>[];
  for (final raw in resourceHosts) {
    final h = raw.toLowerCase();
    if (h.isEmpty || h == page || !sameSite(h, page) || hosts.contains(h)) {
      continue;
    }
    hosts.add(h);
    if (hosts.length == max) break;
  }

  Future<List<String>?> safeLookup(String h) async {
    try {
      return await lookup(h).timeout(lookupTimeout);
    } catch (_) {
      return null;
    }
  }

  final results = <String, List<String>?>{};
  for (var i = 0; i < hosts.length; i += kCloakingParallel) {
    final batch = hosts.skip(i).take(kCloakingParallel).toList();
    final answers = await Future.wait(batch.map(safeLookup));
    for (var j = 0; j < batch.length; j++) {
      results[batch[j]] = answers[j];
    }
  }

  final aliases = <CnameAlias>[];
  final checked = <String>[];
  final notChecked = <String>[];
  for (final h in hosts) {
    final targets = results[h];
    if (targets == null) {
      notChecked.add(h);
      continue;
    }
    checked.add(h);
    for (final t in targets) {
      if (sameSite(t, page)) continue;
      final e = entityForHost(t);
      if (e != null && kCloakingTrackerCategories.contains(e.category)) {
        aliases.add(CnameAlias(h, t, e.name));
        break;
      }
    }
  }
  return CloakingResult(
      aliases: aliases, checked: checked, notChecked: notChecked);
}
