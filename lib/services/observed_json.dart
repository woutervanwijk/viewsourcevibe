import '../models/inspection/observed.dart';

/// An [Observed] as the export writes it, so the file carries the same truth
/// as the UI:
/// `{status: present|unavailable|pending|failed, value?, reason?, detail?,
///   source, provenance}`.
///
/// [source] / [provenance] describe where the value would come from; a
/// Present value brings its own.
Map<String, Object?> observedJson<T>(
  Observed<T> o,
  Object? Function(T) encode, {
  required DataSource source,
  Provenance provenance = Provenance.measured,
}) =>
    switch (o) {
      Present<T>(:final value, source: final s, provenance: final p) => {
          'status': 'present',
          'value': encode(value),
          'source': s.name,
          'provenance': p.name,
        },
      Unavailable<T>(:final reason, :final detail) => {
          'status': 'unavailable',
          'reason': reason.name,
          if (detail.isNotEmpty) 'detail': detail,
          'source': source.name,
          'provenance': provenance.name,
        },
      Pending<T>() => {
          'status': 'pending',
          'source': source.name,
          'provenance': provenance.name,
        },
      Failed<T>(:final error) => {
          'status': 'failed',
          'detail': error,
          'source': source.name,
          'provenance': provenance.name,
        },
    };

/// Shorthand for values that need no encoding (numbers, strings, bools).
Map<String, Object?> observedPlain<T extends Object>(
  Observed<T> o, {
  required DataSource source,
}) =>
    observedJson<T>(o, (v) => v, source: source);
