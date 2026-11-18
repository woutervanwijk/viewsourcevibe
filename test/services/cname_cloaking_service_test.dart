import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/cname_cloaking_service.dart';

void main() {
  test('a first-party host that is an alias for a tracker is found', () async {
    final r = await findCloakedTrackers([
      'metrics.shop.test',
      'cdn.shop.test',
      'www.shop.test',
      'ads.other.test'
    ],
        pageHost: 'www.shop.test',
        lookup: (h) async => switch (h) {
              'metrics.shop.test' => ['shop.sc.omtrdc.net'],
              'cdn.shop.test' => ['d111.cloudfront.net'],
              _ => const <String>[],
            });
    expect(r.checked, ['metrics.shop.test', 'cdn.shop.test']);
    expect(r.notChecked, isEmpty);
    expect(r.aliases.single.host, 'metrics.shop.test');
    expect(r.aliases.single.target, 'shop.sc.omtrdc.net');
    expect(r.aliases.single.tracker, 'Adobe Analytics');
  });

  test('an alias for a hosting domain in a marketing entity is no finding',
      () async {
    final r = await findCloakedTrackers(['help.shop.test'],
        pageHost: 'www.shop.test',
        lookup: (h) async => ['shop.my.force.com']);
    expect(r.checked, ['help.shop.test']);
    expect(r.aliases, isEmpty);
  });

  test('a failed lookup is listed as not checked, the rest still runs',
      () async {
    final r = await findCloakedTrackers(['a.shop.test', 'b.shop.test'],
        pageHost: 'www.shop.test',
        lookup: (h) async => h == 'a.shop.test' ? null : ['x.omtrdc.net']);
    expect(r.notChecked, ['a.shop.test']);
    expect(r.checked, ['b.shop.test']);
    expect(r.aliases.single.host, 'b.shop.test');
  });

  test('a lookup that throws is also not checked, not fatal', () async {
    final r = await findCloakedTrackers(['a.shop.test', 'b.shop.test'],
        pageHost: 'www.shop.test',
        lookup: (h) async =>
            h == 'a.shop.test' ? throw Exception('boom') : ['x.omtrdc.net']);
    expect(r.notChecked, ['a.shop.test']);
    expect(r.aliases.single.host, 'b.shop.test');
  });

  test('a lookup that hangs does not stop the others', () async {
    final r = await findCloakedTrackers(['a.shop.test', 'b.shop.test'],
        pageHost: 'www.shop.test',
        lookupTimeout: const Duration(milliseconds: 20),
        lookup: (h) => h == 'a.shop.test'
            ? Future.delayed(const Duration(seconds: 5), () => <String>[])
            : Future.value(['x.omtrdc.net']));
    expect(r.notChecked, ['a.shop.test']);
    expect(r.aliases.single.host, 'b.shop.test');
  });

  test('an alias to the same site or to an unknown host is not reported',
      () async {
    final r = await findCloakedTrackers(['a.shop.test', 'b.shop.test'],
        pageHost: 'www.shop.test',
        lookup: (h) async =>
            h == 'a.shop.test' ? ['edge.shop.test'] : ['x.unknown-cdn.test']);
    expect(r.aliases, isEmpty);
    expect(r.checked, hasLength(2));
  });

  test('at most 20 hosts are looked up, each once', () async {
    final looked = <String>[];
    final hosts = [
      for (var i = 0; i < 30; i++) 'h$i.shop.test',
      'h0.shop.test',
    ];
    final r = await findCloakedTrackers(hosts, pageHost: 'www.shop.test',
        lookup: (h) async {
      looked.add(h);
      return const <String>[];
    });
    expect(r.checked, hasLength(20));
    expect(looked, hasLength(20));
    expect(looked.toSet(), hasLength(20));
  });
}
