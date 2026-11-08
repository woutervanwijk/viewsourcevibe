import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';

void main() {
  test('Present defaults to measured provenance and exposes fields', () {
    const o = Present<int>(5, source: DataSource.server);
    expect(o.value, 5);
    expect(o.source, DataSource.server);
    expect(o.provenance, Provenance.measured);
  });

  test('sealed switch is exhaustive over all four states', () {
    String describe(Observed<int> o) => switch (o) {
          Present<int>() => 'present',
          Unavailable<int>() => 'unavailable',
          Pending<int>() => 'pending',
          Failed<int>() => 'failed',
        };
    expect(describe(const Present(1, source: DataSource.file)), 'present');
    expect(describe(const Unavailable(UnavailableReason.notApplicable, '')),
        'unavailable');
    expect(describe(const Pending()), 'pending');
    expect(describe(const Failed('boom')), 'failed');
  });

  test('every UnavailableReason has a non-empty English message', () {
    for (final r in UnavailableReason.values) {
      expect(unavailableMessage(r, 'x').trim(), isNotEmpty);
    }
  });
}
