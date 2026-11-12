import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import 'observed_text.dart';
import 'probe_general.dart' show probeGate;

class SecurityCheck {
  final String label;
  final bool applicable;
  final bool passing;
  final String detail;
  const SecurityCheck(this.label, this.applicable, this.passing, this.detail);
}

/// One audited header: [value] is what the server sent, null = not sent.
class SecurityHeaderRow {
  final String name;
  final String? value;
  const SecurityHeaderRow(this.name, this.value);
}

/// Scorecard of the security headers of a response that exists.
class SecurityAudit {
  final List<SecurityCheck> checks;
  final List<SecurityHeaderRow> rows;

  const SecurityAudit(this.checks, this.rows);

  List<SecurityCheck> get _applicable =>
      checks.where((c) => c.applicable).toList();
  int get total => _applicable.length;
  int get passed => _applicable.where((c) => c.passing).length;

  /// 0..100, null when no check applies (never a made-up 0).
  int? get percentage => total == 0 ? null : (passed / total * 100).round();
}

enum CspSeverity { low, medium, high }

class CspFinding {
  final CspSeverity severity;
  final String text;
  const CspFinding(this.severity, this.text);
}

class CspPolicy {
  /// (directive, number of sources)
  final List<(String, int)> directives;
  final List<CspFinding> findings;
  final int score;
  const CspPolicy(this.directives, this.findings, this.score);
}

/// The Content-Security-Policy of the response. No header = no [policies]
/// and no [score].
class CspModel {
  final List<CspPolicy> policies;
  const CspModel(this.policies);

  /// The weakest policy's score; null without a policy.
  int? get score => policies.isEmpty
      ? null
      : policies.map((p) => p.score).reduce((a, b) => a < b ? a : b);
}

enum CertTone { good, warn, bad, neutral }

class CertificateModel {
  final String validityLabel;
  final CertTone validityTone;
  final bool validityExpired;
  final String hostLabel;
  final bool hostMatches;
  final Map<String, String> subject;
  final String subjectRaw;
  final Map<String, String> issuer;
  final String issuerRaw;
  final String validFrom;
  final String validUntil;
  final String? derHint;
  final String? pem;

  const CertificateModel({
    required this.validityLabel,
    required this.validityTone,
    required this.validityExpired,
    required this.hostLabel,
    required this.hostMatches,
    required this.subject,
    required this.subjectRaw,
    required this.issuer,
    required this.issuerRaw,
    required this.validFrom,
    required this.validUntil,
    required this.derHint,
    required this.pem,
  });
}

class SecurityModel {
  final Observed<SecurityAudit> audit;
  final Observed<CspModel> csp;
  final Observed<CertificateModel> certificate;

  /// Set when the content was loaded although the certificate is invalid.
  final String? tlsWarning;

  const SecurityModel({
    required this.audit,
    required this.csp,
    required this.certificate,
    required this.tlsWarning,
  });
}

// --- audit -----------------------------------------------------------------

const _auditedHeaders = [
  ('Strict-Transport-Security', 'strict-transport-security'),
  ('Content-Security-Policy', 'content-security-policy'),
  ('X-Frame-Options', 'x-frame-options'),
  ('X-Content-Type-Options', 'x-content-type-options'),
  ('Referrer-Policy', 'referrer-policy'),
  ('Permissions-Policy', 'permissions-policy'),
];

String? _value(HttpHop hop, String name) {
  final v = hop.header(name)?.trim();
  return v == null || v.isEmpty ? null : v;
}

/// Fetch spec "determine nosniff": the first comma-separated value,
/// trimmed, equals `nosniff` case-insensitively. Shared with the Headers tab.
bool isNosniff(String? value) =>
    value != null && value.split(',').first.trim().toLowerCase() == 'nosniff';

/// Mozilla HTTP Observatory: HSTS counts from six months.
const hstsMinSeconds = 15552000;

/// The max-age of a Strict-Transport-Security value; null when missing or
/// invalid. Shared with the Sovereignty page.
int? hstsMaxAge(String? hsts) =>
    int.tryParse(RegExp(r'max-age\s*=\s*"?(\d+)', caseSensitive: false)
            .firstMatch(hsts ?? '')
            ?.group(1) ??
        '');

const _goodReferrer = {
  'no-referrer',
  'same-origin',
  'strict-origin',
  'strict-origin-when-cross-origin',
  'origin',
  'origin-when-cross-origin',
};
const _knownReferrer = {
  ..._goodReferrer,
  'no-referrer-when-downgrade',
  'unsafe-url',
};

SecurityCheck _hstsCheck(String? hsts, bool isHttps) {
  if (!isHttps) {
    return const SecurityCheck(
        'HSTS', true, false, 'Page is not served over HTTPS.');
  }
  if (hsts == null) {
    return const SecurityCheck(
        'HSTS', true, false, 'Missing Strict-Transport-Security on HTTPS.');
  }
  final seconds = hstsMaxAge(hsts);
  if (seconds == null) {
    return const SecurityCheck(
        'HSTS', true, false, 'Strict-Transport-Security has no valid max-age.');
  }
  return seconds >= hstsMinSeconds
      ? SecurityCheck(
          'HSTS', true, true, 'Strict-Transport-Security max-age=$seconds.')
      : SecurityCheck('HSTS', true, false,
          'Strict-Transport-Security max-age=$seconds is under 6 months ($hstsMinSeconds).');
}

SecurityAudit _audit(HttpHop hop) {
  final cspText = _value(hop, 'content-security-policy');
  final csp = cspText == null ? null : _parseCsp(cspText.toLowerCase());
  final protectsScripts = csp != null &&
      (csp.containsKey('default-src') || csp.containsKey('script-src'));
  final xfo = _value(hop, 'x-frame-options')?.toLowerCase();
  final frames = xfo == 'deny' ||
      xfo == 'sameorigin' ||
      (csp?.containsKey('frame-ancestors') ?? false);
  final nosniff = isNosniff(_value(hop, 'x-content-type-options'));
  final referrer = _value(hop, 'referrer-policy');
  final referrerToken = referrer
      ?.toLowerCase()
      .split(',')
      .map((t) => t.trim())
      .lastWhere(_knownReferrer.contains, orElse: () => '');
  final referrerGood = _goodReferrer.contains(referrerToken);
  final permissions = _value(hop, 'permissions-policy');

  return SecurityAudit(
      [
        _hstsCheck(_value(hop, 'strict-transport-security'),
            hop.url.scheme == 'https'),
        SecurityCheck(
            'CSP',
            true,
            protectsScripts,
            protectsScripts
                ? 'Content-Security-Policy restricts scripts.'
                : csp != null
                    ? 'Content-Security-Policy has no default-src or script-src.'
                    : 'Missing Content-Security-Policy.'),
        SecurityCheck(
            'Frames',
            true,
            frames,
            frames
                ? 'Frame protection is present.'
                : 'Missing X-Frame-Options (DENY/SAMEORIGIN) or CSP frame-ancestors.'),
        SecurityCheck(
            'No Sniff',
            true,
            nosniff,
            nosniff
                ? 'X-Content-Type-Options includes nosniff.'
                : 'Missing X-Content-Type-Options: nosniff.'),
        SecurityCheck(
            'Referrer',
            true,
            referrerGood,
            referrer == null
                ? 'Missing Referrer-Policy.'
                : referrerGood
                    ? 'Referrer-Policy is $referrerToken.'
                    : 'Referrer-Policy "$referrer" leaks the full URL or is not recognised.'),
        SecurityCheck(
            'Permissions',
            true,
            permissions != null,
            permissions != null
                ? 'Permissions-Policy is present.'
                : 'Missing Permissions-Policy.'),
      ],
      [
        for (final (title, key) in _auditedHeaders)
          SecurityHeaderRow(title, _value(hop, key)),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
}

// --- csp -------------------------------------------------------------------

Map<String, List<String>> _parseCsp(String csp) {
  final result = <String, List<String>>{};
  for (final part in csp.split(';')) {
    final tokens = part.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.first.isEmpty) continue;
    // CSP3: a repeated directive is ignored, the first one wins.
    result.putIfAbsent(
        tokens.first.toLowerCase(), () => tokens.skip(1).toList());
  }
  return result;
}

bool _isBroadSource(String t) =>
    t == '*' ||
    t == 'http:' ||
    t == 'https:' ||
    t == 'data:' ||
    t.startsWith('*.') ||
    t.contains('://*.');

List<CspFinding> _cspFindings(Map<String, List<String>> d,
    {bool frameOptionsSet = false}) {
  final findings = <CspFinding>[];
  final defaultSrc = d['default-src'] ?? const [];
  final scriptSrc = d['script-src'] ?? defaultSrc;
  final objectSrc = d['object-src'] ?? defaultSrc;
  if (scriptSrc.contains("'unsafe-inline'")) {
    // CSP3: a nonce, hash or 'strict-dynamic' makes browsers ignore it.
    final ignored = scriptSrc.any((t) =>
        t == "'strict-dynamic'" ||
        t.startsWith("'nonce-") ||
        t.startsWith("'sha256-") ||
        t.startsWith("'sha384-") ||
        t.startsWith("'sha512-"));
    findings.add(ignored
        ? const CspFinding(CspSeverity.low,
            "script-src has 'unsafe-inline' next to a nonce, hash or 'strict-dynamic': it is only a fallback for old browsers.")
        : const CspFinding(
            CspSeverity.high, "script-src allows 'unsafe-inline'."));
  }
  if (scriptSrc.contains("'unsafe-eval'")) {
    findings.add(
        const CspFinding(CspSeverity.high, "script-src allows 'unsafe-eval'."));
  }
  if (defaultSrc.any(_isBroadSource) || scriptSrc.any(_isBroadSource)) {
    findings.add(const CspFinding(
        CspSeverity.medium, 'Wildcard source allows broad loading.'));
  }
  if (!objectSrc.contains("'none'")) {
    findings.add(const CspFinding(
        CspSeverity.medium, "object-src should usually be 'none'."));
  }
  if (d['base-uri'] == null) {
    findings.add(
        const CspFinding(CspSeverity.medium, 'Missing base-uri protection.'));
  }
  if (d['frame-ancestors'] == null) {
    findings.add(CspFinding(
        frameOptionsSet ? CspSeverity.low : CspSeverity.medium,
        frameOptionsSet
            ? 'No frame-ancestors; X-Frame-Options covers clickjacking.'
            : 'Missing frame-ancestors clickjacking control.'));
  }
  if (findings.isEmpty) {
    findings.add(const CspFinding(
        CspSeverity.low, 'Policy looks reasonably constrained.'));
  }
  return findings;
}

CspModel _csp(HttpHop hop) {
  // Several policies may arrive as repeated headers or comma-separated; each
  // one is enforced, so each is judged.
  final raw = hop.headers['content-security-policy'] ?? const <String>[];
  final xfo = _value(hop, 'x-frame-options')?.toLowerCase();
  final frameOptionsSet = xfo == 'deny' || xfo == 'sameorigin';
  final policies = <CspPolicy>[];
  for (final value in raw) {
    for (final text in value.split(',')) {
      final directives = _parseCsp(text);
      if (directives.isEmpty) continue;
      final findings =
          _cspFindings(directives, frameOptionsSet: frameOptionsSet);
      final score = (100 -
              findings.where((f) => f.severity == CspSeverity.high).length *
                  22 -
              findings.where((f) => f.severity == CspSeverity.medium).length *
                  12)
          .clamp(0, 100);
      policies.add(CspPolicy(
        [for (final e in directives.entries) (e.key, e.value.length)],
        findings,
        score,
      ));
    }
  }
  return CspModel(policies);
}

// --- certificate -----------------------------------------------------------

bool _hostMatches(String host, String commonName) {
  if (host.isEmpty || commonName.isEmpty) return false;
  final h = host.toLowerCase();
  final cn = commonName.toLowerCase();
  if (cn == h) return true;
  if (cn.startsWith('*.')) {
    return h.endsWith(cn.substring(1)) &&
        h.split('.').length == cn.split('.').length;
  }
  return false;
}

String _formatDate(String iso) {
  if (iso.isEmpty) return 'Unknown';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

Map<String, String> _fields(Object? parsed) => parsed is Map
    ? {for (final e in parsed.entries) '${e.key}': '${e.value}'}
    : const {};

CertificateModel _certificate(
    Map<String, dynamic> cert, String host, DateTime now) {
  final end = cert['endValidity']?.toString() ?? '';
  final endDate = DateTime.tryParse(end);
  String label;
  CertTone tone;
  var expired = false;
  if (endDate == null) {
    label = 'Validity unknown';
    tone = CertTone.neutral;
  } else {
    final days = endDate.difference(now).inDays;
    if (days < 0) {
      label = 'Expired ${days.abs()}d ago';
      tone = CertTone.bad;
      expired = true;
    } else if (days < 14) {
      label = 'Expires in ${days}d';
      tone = CertTone.bad;
    } else if (days < 45) {
      label = 'Expires in ${days}d';
      tone = CertTone.warn;
    } else {
      label = 'Valid for ${days}d';
      tone = CertTone.good;
    }
  }
  final subject = _fields(cert['subjectParsed']);
  final commonName = subject['Common Name'] ?? '';
  final matches = _hostMatches(host, commonName);
  final hostLabel = host.isEmpty
      ? 'Host unknown'
      : commonName.isEmpty
          ? 'Common name unknown'
          : matches
              ? 'CN matches host'
              : 'CN differs from host (SAN not checked)';
  final der = cert['der']?.toString();
  return CertificateModel(
    validityLabel: label,
    validityTone: tone,
    validityExpired: expired,
    hostLabel: hostLabel,
    hostMatches: matches,
    subject: subject,
    subjectRaw: cert['subject']?.toString() ?? 'Unknown',
    issuer: _fields(cert['issuerParsed']),
    issuerRaw: cert['issuer']?.toString() ?? 'Unknown',
    validFrom: _formatDate(cert['startValidity']?.toString() ?? ''),
    validUntil: _formatDate(end),
    derHint: der?.substring(0, der.length < 32 ? der.length : 32),
    pem: cert['pem']?.toString(),
  );
}

/// The Security tab. Everything is judged on the final response of the
/// server snapshot; when that response is not Present there is no score,
/// no CSP verdict and no certificate (each carries the state instead).
Observed<SecurityModel> deriveSecurity(PageInspection p, {DateTime? now}) {
  final gate = probeGate<SecurityModel>(p);
  if (gate != null) return gate;
  final server = p.server;
  if (server is! Present<ServerSnapshot> || server.value.hops.isEmpty) {
    final state = server is Present<ServerSnapshot>
        ? const Failed<ServerSnapshot>('The server did not answer.')
        : server;
    return Present(
        SecurityModel(
          audit: notPresentAs(state),
          csp: notPresentAs(state),
          certificate: notPresentAs(state),
          tlsWarning: null,
        ),
        source: DataSource.server,
        provenance: Provenance.derived);
  }
  final s = server.value;
  final last = s.hops.last;
  final host = s.finalUrl is Present<Uri>
      ? (s.finalUrl as Present<Uri>).value.host
      : last.url.host;
  final certState = s.certificate;
  final Observed<CertificateModel> certificate = last.url.scheme != 'https'
      ? const Unavailable(UnavailableReason.notApplicable,
          'the page was loaded over HTTP, not HTTPS: there is no certificate')
      : certState is Present<Map<String, dynamic>>
          ? Present(_certificate(certState.value, host, now ?? DateTime.now()),
              source: DataSource.server)
          : notPresentAs(certState);
  return Present(
      SecurityModel(
        audit: Present(_audit(last),
            source: DataSource.server, provenance: Provenance.derived),
        csp: Present(_csp(last),
            source: DataSource.server, provenance: Provenance.derived),
        certificate: certificate,
        tlsWarning: s.acceptedInvalidCertificate && last.url.scheme == 'https'
            ? 'TLS certificate validation failed. Content was loaded anyway for inspection.'
            : null,
      ),
      source: DataSource.server,
      provenance: Provenance.derived);
}
