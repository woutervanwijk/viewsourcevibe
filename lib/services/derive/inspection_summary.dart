import '../../models/app_tab.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/site.dart';
import '../detection/engine.dart';
import '../sovereignty_service.dart';
import 'block_page.dart';
import 'cookies_view.dart';
import 'detections_view.dart';
import 'divergences.dart';
import 'page_size.dart';
import 'page_weight.dart';
import 'probe_general.dart';
import 'security_audit.dart';

/// Product thresholds (no external norm), in one place.
const kHeadersPoor = 50;
const kHeadersGood = 80;
const kWeightHeavy = 5 * 1024 * 1024;
const kWeightNotable = 2 * 1024 * 1024;
const kFrameShareNotable = 0.20;

enum FindingSeverity {
  high('High'),
  medium('Medium'),
  low('Low'),
  info('Info');

  final String label;
  const FindingSeverity(this.label);
}

class Finding {
  final String id;
  final FindingSeverity severity;

  /// One line, complete on its own.
  final String title;

  /// [AppTab.tag] of the tab with the detail.
  final String? tab;

  const Finding(this.id, this.severity, this.title, {this.tab});

  Map<String, Object?> toJson() =>
      {'id': id, 'severity': severity.name, 'title': title, 'tab': tab};
}

class SummaryInputs {
  final PageInspection inspection;
  final Observed<GeneralModel> general;
  final Observed<SecurityModel> security;
  final Observed<CookiesModel> cookies;
  final DetectionsView detections;
  final Observed<SovereigntyReport> sovereignty;
  final BlockPage? blockPage;
  final List<Divergence> divergences;

  const SummaryInputs({
    required this.inspection,
    required this.general,
    required this.security,
    required this.cookies,
    required this.detections,
    required this.sovereignty,
    required this.blockPage,
    required this.divergences,
  });
}

const List<String> summaryFactKeys = [
  'url', 'finalUrl', 'status', 'blocked', 'requests', 'thirdPartyHosts',
  'transferBytes', 'transferIsLowerBound', 'trackers', 'trackerNames',
  'consentTool', 'cookies', 'advertisingCookies', 'analyticsCookies',
  'securityHeadersPct', 'cspScore', 'certValidUntil',
  'sovereigntyScore', 'sovereigntyGrade', 'sovereigntyCoverage',
];

class InspectionSummary {
  /// Sorted by severity, then rule order.
  final List<Finding> findings;

  /// Keys in [summaryFactKeys]; null = unknown.
  final Map<String, Object?> facts;

  const InspectionSummary(this.findings, this.facts);

  List<Finding> get top => findings.take(5).toList();

  Map<String, Object?> toJson() => {
        'findings': [for (final f in findings) f.toJson()],
        'facts': facts,
      };
}

T? _value<T>(Observed<T> o) => o is Present<T> ? o.value : null;

InspectionSummary deriveSummary(SummaryInputs i) {
  final p = i.inspection;
  final general = _value(i.general);
  final status = general == null ? null : _value(general.status);
  final security = _value(i.security);
  final audit = security == null ? null : _value(security.audit);
  final csp = security == null ? null : _value(security.csp);
  final cert = security == null ? null : _value(security.certificate);
  final cookies = _value(i.cookies);
  final report = _value(i.sovereignty);
  final server = _value(p.server);
  final browser = _value(p.browser);
  final resources = browser == null ? null : _value(browser.resources);
  final blocked = i.blockPage != null;

  final finalUrl = status == null ? null : _value(status.finalUrl);
  final pageUrl = finalUrl ?? browser?.url;
  final pageHost = pageUrl?.host;

  final weight = blocked ? null : derivePageWeight(p);
  final trackers = blocked
      ? null
      : (i.detections.detections.isNotEmpty || i.detections.complete
          ? [
              for (final d in i.detections.detections)
                if (d.category.isTracking && !d.hintOnly) d
            ]
          : null);
  final consent = blocked
      ? null
      : i.detections.detections
          .where((d) => d.category == DetectionCategory.consent)
          .firstOrNull;
  final thirdHosts = (resources == null || pageHost == null || blocked)
      ? null
      : {
          for (final r in resources)
            if (Uri.tryParse(r.url)?.host case final h?
                when h.isNotEmpty && !sameSite(h, pageHost))
              h.toLowerCase()
        };

  final findings = <Finding>[
    ..._notLoaded(p),
    ..._blockPage(i.blockPage),
    ..._invalidCertAccepted(server),
    ..._noHttps(finalUrl ?? browser?.url),
    ..._certExpired(cert),
    ..._certHost(cert),
    ..._preConsent(blocked, consent, trackers),
    ..._trackers(blocked, trackers),
    ..._adCookies(blocked, cookies),
    ..._certExpiring(cert),
    ..._securityHeaders(audit),
    ..._pageWeight(weight),
    ..._sovereignty(report),
    ..._cspWeak(csp),
    ..._divergences(i.divergences),
    ..._thirdParties(thirdHosts),
  ];
  // Dart's List.sort is not stable; sort by (severity, rule order).
  final order = {for (var n = 0; n < findings.length; n++) findings[n]: n};
  findings.sort((a, b) {
    final bySeverity = a.severity.index.compareTo(b.severity.index);
    return bySeverity != 0 ? bySeverity : order[a]!.compareTo(order[b]!);
  });

  final facts = <String, Object?>{
    'url': switch (p.target) {
      UrlTarget(:final url) => url.toString(),
      _ => null,
    },
    'finalUrl': pageUrl?.toString(),
    'status': status?.last.status,
    'blocked': blocked ? true : (browser != null ? false : null),
    'requests': blocked ? null : resources?.length,
    'thirdPartyHosts': thirdHosts?.length,
    'transferBytes': weight?.transfer,
    'transferIsLowerBound':
        weight?.transfer == null ? null : weight!.transferLowerBound,
    'trackers': trackers?.length,
    'trackerNames': trackers == null ? null : [for (final d in trackers) d.name],
    'consentTool': consent?.name,
    'cookies': blocked ? null : cookies?.total,
    'advertisingCookies': blocked ? null : cookies?.advertisingCount,
    'analyticsCookies': blocked ? null : cookies?.analyticsCount,
    'securityHeadersPct': audit?.percentage,
    'cspScore': csp?.score,
    'certValidUntil': cert?.validUntil,
    'sovereigntyScore': report?.score,
    'sovereigntyGrade': report?.grade,
    'sovereigntyCoverage':
        report == null ? null : (report.coverage * 100).round(),
  };
  return InspectionSummary(findings, facts);
}

bool _missing(Observed<Object?> o) => o is Failed || o is Unavailable;

/// Neither the app's own request nor the browser got the page.
List<Finding> _notLoaded(PageInspection p) =>
    p.target is UrlTarget && _missing(p.server) && _missing(p.browser)
        ? [
            Finding('not-loaded', FindingSeverity.high, 'The page did not load',
                tab: AppTab.probe.tag)
          ]
        : const [];

List<Finding> _blockPage(BlockPage? b) => b == null
    ? const []
    : [
        Finding('block-page', FindingSeverity.high,
            'Not the site: ${b.detail}',
            tab: AppTab.browser.tag)
      ];

List<Finding> _invalidCertAccepted(ServerSnapshot? s) =>
    s != null && s.acceptedInvalidCertificate
        ? [
            Finding('invalid-cert-accepted', FindingSeverity.high,
                'Loaded with an untrusted certificate (accepted by the user)',
                tab: AppTab.security.tag)
          ]
        : const [];

List<Finding> _noHttps(Uri? url) => url != null && url.scheme == 'http'
    ? [
        Finding('no-https', FindingSeverity.high,
            'No HTTPS: the page is served over plain HTTP',
            tab: AppTab.security.tag)
      ]
    : const [];

List<Finding> _certExpired(CertificateModel? c) => c != null &&
        c.validityExpired
    ? [
        Finding('cert-expired', FindingSeverity.high,
            'Certificate expired (${c.validUntil})',
            tab: AppTab.security.tag)
      ]
    : const [];

List<Finding> _certHost(CertificateModel? c) => c != null && !c.hostMatches
    ? [
        Finding('cert-host', FindingSeverity.high,
            'Certificate does not match the host',
            tab: AppTab.security.tag)
      ]
    : const [];

bool _active(Detection d) => d.requests > 0 || d.cookies.isNotEmpty;

List<Finding> _preConsent(
    bool blocked, Detection? consent, List<Detection>? trackers) {
  if (blocked || consent == null || trackers == null) return const [];
  final n = trackers.where(_active).length;
  if (n == 0) return const [];
  return [
    Finding('pre-consent', FindingSeverity.high,
        '$n tracker(s) active while ${consent.name} is present',
        tab: AppTab.privacy.tag)
  ];
}

List<Finding> _trackers(bool blocked, List<Detection>? trackers) {
  if (blocked || trackers == null || trackers.isEmpty) return const [];
  final names = trackers.take(3).map((d) => d.name).join(', ');
  final more = trackers.length > 3 ? ' (+${trackers.length - 3})' : '';
  final high = trackers.any((d) => d.category.tracking >= 4);
  return [
    Finding('trackers', high ? FindingSeverity.high : FindingSeverity.medium,
        '${trackers.length} tracker(s): $names$more',
        tab: AppTab.privacy.tag)
  ];
}

List<Finding> _adCookies(bool blocked, CookiesModel? c) =>
    !blocked && c != null && c.advertisingCount > 0
        ? [
            Finding('ad-cookies', FindingSeverity.medium,
                '${c.advertisingCount} advertising cookie(s) set',
                tab: AppTab.cookies.tag)
          ]
        : const [];

List<Finding> _certExpiring(CertificateModel? c) => c != null &&
        !c.validityExpired &&
        (c.validityTone == CertTone.warn || c.validityTone == CertTone.bad)
    ? [
        Finding('cert-expiring', FindingSeverity.medium,
            'Certificate: ${c.validityLabel}',
            tab: AppTab.security.tag)
      ]
    : const [];

List<Finding> _securityHeaders(SecurityAudit? a) {
  final pct = a?.percentage;
  if (a == null || pct == null || pct >= kHeadersGood) return const [];
  final missing = a.checks
      .where((c) => c.applicable && !c.passing)
      .map((c) => c.label)
      .join(', ');
  return [
    Finding('security-headers',
        pct < kHeadersPoor ? FindingSeverity.medium : FindingSeverity.low,
        'Security headers: $pct% (missing: $missing)',
        tab: AppTab.security.tag)
  ];
}

List<Finding> _pageWeight(PageWeight? w) {
  final t = w?.transfer;
  if (w == null || t == null || t <= kWeightNotable) return const [];
  final frames = w.breakdown['thirdPartyFrames']?.transfer;
  final share = frames == null ? 0.0 : frames / t;
  final frameText = share >= kFrameShareNotable
      ? ', ${(share * 100).round()}% in third-party iframes'
      : '';
  return [
    Finding('page-weight',
        t > kWeightHeavy ? FindingSeverity.medium : FindingSeverity.low,
        'Page weight ${formatDownloadSize(t, prefix: w.transferPrefix)}$frameText',
        tab: AppTab.size.tag)
  ];
}

List<Finding> _sovereignty(SovereigntyReport? r) {
  final grade = r?.grade;
  if (r == null || grade == null || (grade != 'Poor' && grade != 'Fair')) {
    return const [];
  }
  return [
    Finding('sovereignty',
        grade == 'Poor' ? FindingSeverity.medium : FindingSeverity.low,
        'Sovereignty: ${r.score} ($grade), coverage ${(r.coverage * 100).round()}%',
        tab: AppTab.sovereignty.tag)
  ];
}

List<Finding> _cspWeak(CspModel? csp) {
  final s = csp?.score;
  return s != null && s < 50
      ? [
          Finding('csp-weak', FindingSeverity.low,
              'Content-Security-Policy is weak (score $s)',
              tab: AppTab.security.tag)
        ]
      : const [];
}

List<Finding> _divergences(List<Divergence> ds) => [
      for (final d in ds)
        if (!d.lowSeverity)
          Finding('divergence', FindingSeverity.low, d.message,
              tab: AppTab.probe.tag)
    ];

List<Finding> _thirdParties(Set<String>? hosts) =>
    hosts == null || hosts.isEmpty
        ? const []
        : [
            Finding('third-parties', FindingSeverity.info,
                '${hosts.length} third-party host(s) contacted',
                tab: AppTab.timeline.tag)
          ];
