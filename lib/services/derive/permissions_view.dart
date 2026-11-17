import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/permission_request.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/site.dart';
import 'permissions_policy.dart';

/// One feature the page's own policy header speaks about.
class DeclaredFeature {
  final String feature;

  /// 'nobody' | 'this site' | 'everyone' | 'this site, https://a.test'
  final String allowed;
  final bool powerful;
  const DeclaredFeature(this.feature, this.allowed, this.powerful);
}

/// An iframe the page gave an `allow` attribute.
class Delegation {
  /// '' for srcdoc / about:blank frames.
  final String frameHost;
  final bool thirdParty;

  /// Features the frame may use; powerful ones first.
  final List<String> features;
  final bool sandboxed;
  const Delegation({
    required this.frameHost,
    required this.thirdParty,
    required this.features,
    required this.sandboxed,
  });
}

class PermissionsModel {
  /// Present: the header was sent (possibly with no features). Unavailable
  /// (notReportedByServer): no Permissions-Policy or Feature-Policy header.
  final Observed<List<DeclaredFeature>> declared;
  final List<String> invalidDeclarations;

  /// Only Feature-Policy was sent.
  final bool legacyHeaderOnly;

  /// Only frames with an allow attribute.
  final Observed<List<Delegation>> delegations;
  final int frameCount;
  final List<PermissionRequestEvent> requests;
  final Observed<SiteStorage> stored;

  /// Plain sentences for the top of the tab.
  final List<String> notes;

  const PermissionsModel({
    required this.declared,
    required this.invalidDeclarations,
    required this.legacyHeaderOnly,
    required this.delegations,
    required this.frameCount,
    required this.requests,
    required this.stored,
    required this.notes,
  });
}

/// Same state, another value type (never a value).
Observed<R> _carry<R>(Observed<Object?> o, String missing) => switch (o) {
      Pending() => Pending<R>(o.detail),
      Failed() => Failed<R>(o.error),
      Unavailable() => Unavailable<R>(o.reason, o.detail),
      Present() => Unavailable<R>(UnavailableReason.notApplicable, missing),
    };

List<String> _ordered(Iterable<String> features) {
  final set = features.toSet();
  return [
    ...powerfulFeatures.where(set.contains),
    ...(set.difference(powerfulFeatures).toList()..sort()),
  ];
}

String _allowedText(Allowlist a) {
  if (a.none) return 'nobody';
  if (a.all) return 'everyone';
  return [
    if (a.self) 'this site',
    if (a.src) "the frame's own origin",
    ...a.origins,
  ].join(', ');
}

String? _header(Map<String, List<String>> headers, String name) {
  return headers[name]?.join(', ');
}

String _seconds(Duration d) {
  final tenths = (d.inMilliseconds / 100).round();
  return tenths < 100
      ? '${(tenths / 10).toStringAsFixed(1)} s'
      : '${(tenths / 10).round()} s';
}

Observed<PermissionsModel> derivePermissions(PageInspection p) {
  if (p.target is! UrlTarget) {
    return const Unavailable(
        UnavailableReason.notApplicable, 'only for web pages');
  }

  final server = p.server, browser = p.browser;
  final serverSnap = server is Present<ServerSnapshot> ? server.value : null;
  final browserSnap =
      browser is Present<BrowserSnapshot> ? browser.value : null;
  if (serverSnap == null && browserSnap == null) {
    if (server is Pending || browser is Pending) return const Pending();
    return const Unavailable(UnavailableReason.notApplicable,
        'neither the server nor the browser answered');
  }

  final pageUrl = (p.target as UrlTarget).url;
  final pageHost = browserSnap?.url.host ?? pageUrl.host;

  // Declared policy, from the final response's headers.
  Observed<List<DeclaredFeature>> declared;
  var invalid = <String>[];
  var legacyOnly = false;
  var noHeader = false;
  if (serverSnap == null || serverSnap.hops.isEmpty) {
    declared = server is Pending
        ? const Pending()
        : const Unavailable(UnavailableReason.notReportedByServer,
            'the server response is not available');
  } else {
    final headers = serverSnap.hops.last.headers;
    final pp = _header(headers, 'permissions-policy');
    final fp = _header(headers, 'feature-policy');
    if (pp == null && fp == null) {
      noHeader = true;
      declared = const Unavailable(UnavailableReason.notReportedByServer,
          'no Permissions-Policy or Feature-Policy header');
    } else {
      legacyOnly = pp == null;
      final features = <String, Allowlist>{};
      if (fp != null) {
        final parsed = parseFeaturePolicy(fp);
        features.addAll(parsed.features);
        invalid = [...parsed.invalid];
      }
      if (pp != null) {
        final parsed = parsePermissionsPolicy(pp);
        features.addAll(parsed.features); // the newer header wins
        invalid = [...parsed.invalid, ...invalid];
      }
      declared = Present([
        for (final f in _ordered(features.keys))
          DeclaredFeature(
              f, _allowedText(features[f]!), powerfulFeatures.contains(f)),
      ], source: DataSource.server, provenance: Provenance.derived);
    }
  }

  // Delegation to iframes.
  Observed<List<Delegation>> delegations;
  final frames = browserSnap?.frames;
  if (frames is Present<List<FrameInfo>>) {
    final list = <Delegation>[];
    for (final f in frames.value) {
      if (f.allow.trim().isEmpty) continue;
      final allowed = parseFeaturePolicy(f.allow, iframeAllow: true)
          .features
          .entries
          .where((e) => !e.value.none)
          .map((e) => e.key);
      final host = f.src.isEmpty ? '' : (Uri.tryParse(f.src)?.host ?? '');
      list.add(Delegation(
        frameHost: host,
        thirdParty: host.isNotEmpty && !sameSite(host, pageHost),
        features: _ordered(allowed),
        sandboxed: f.sandbox != null,
      ));
    }
    delegations = Present(list,
        source: DataSource.browser, provenance: Provenance.derived);
  } else {
    delegations = _carry<List<Delegation>>(
        frames ?? browser, 'the browser did not report frames');
  }

  final stored = browserSnap?.siteStorage ??
      _carry<SiteStorage>(browser, 'the browser did not report storage');

  final notes = <String>[
    if (noHeader)
      "No Permissions-Policy header: embedded frames keep the browser's defaults.",
  ];
  if (delegations is Present<List<Delegation>>) {
    final risky = delegations.value
        .where((d) => d.thirdParty && d.features.any(powerfulFeatures.contains))
        .toList();
    if (risky.isNotEmpty) {
      final union = _ordered(
          risky.expand((d) => d.features.where(powerfulFeatures.contains)));
      notes.add(
          '${risky.length} third-party frame(s) may use: ${union.join(', ')}');
    }
  }
  for (final r in p.permissionRequests) {
    notes.add(
        'The page asked for ${r.resources.join(', ')} ${_seconds(r.sinceLoadStart)} after it started loading.');
  }
  if (stored is Present<SiteStorage>) {
    final sw = stored.value.serviceWorkers;
    if (sw is Present<List<ServiceWorkerInfo>> && sw.value.isNotEmpty) {
      notes.add(
          'A service worker is installed: the site can run code in the background.');
    }
  }

  return Present(
      PermissionsModel(
        declared: declared,
        invalidDeclarations: invalid,
        legacyHeaderOnly: legacyOnly,
        delegations: delegations,
        frameCount: browserSnap?.frameCount ?? 0,
        requests: p.permissionRequests,
        stored: stored,
        notes: notes,
      ),
      source: DataSource.browser,
      provenance: Provenance.derived);
}
