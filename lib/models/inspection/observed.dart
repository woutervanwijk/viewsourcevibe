/// Where a value came from.
enum DataSource { browser, server, file }

/// How a value was obtained.
enum Provenance { measured, derived, estimated }

/// Why a value cannot be shown. Unknown is never rendered as 0 or ''.
enum UnavailableReason {
  notApplicable,
  blockedByPlatform,
  blockedBySite,
  notExposedToPage,
  notReportedByServer,
  notReportedByPlatform,
  servedFromCache,
  exceedsLimit,
  unsupportedPlatform,
}

/// A displayed value: present, explicitly unavailable, still loading, or failed.
sealed class Observed<T> {
  const Observed();
}

class Present<T> extends Observed<T> {
  final T value;
  final DataSource source;
  final Provenance provenance;
  const Present(this.value,
      {required this.source, this.provenance = Provenance.measured});
}

class Unavailable<T> extends Observed<T> {
  final UnavailableReason reason;
  final String detail;
  const Unavailable(this.reason, [this.detail = '']);
}

class Pending<T> extends Observed<T> {
  const Pending();
}

class Failed<T> extends Observed<T> {
  final String error;
  const Failed(this.error);
}

/// User-facing text for an [Unavailable] value.
String unavailableMessage(UnavailableReason r, String detail) {
  final label = switch (r) {
    UnavailableReason.notApplicable => 'Not applicable',
    UnavailableReason.blockedByPlatform => 'Not visible',
    UnavailableReason.blockedBySite => 'Not visible (blocked by the site)',
    UnavailableReason.notExposedToPage =>
      'Not visible (not exposed to the page)',
    UnavailableReason.notReportedByServer => 'Not reported by the server',
    UnavailableReason.notReportedByPlatform => 'Not reported by the platform',
    UnavailableReason.servedFromCache => 'Not available (served from cache)',
    UnavailableReason.exceedsLimit => 'Not available (exceeds limit)',
    UnavailableReason.unsupportedPlatform => 'Not supported on this platform',
  };
  return detail.isEmpty ? label : '$label: $detail';
}
