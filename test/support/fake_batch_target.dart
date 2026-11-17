import 'package:archive/archive.dart';
import 'package:view_source_vibe/services/batch_runner.dart';
import 'package:view_source_vibe/services/derive/inspection_summary.dart';

class FakeBatchTarget implements BatchTarget {
  final calls = <String>[];

  /// Host -> polls it stays pending; -1 = forever.
  final pendingFor = <String, int>{};
  final failOpen = <String>{};
  void Function(Uri url)? onOpen;
  Uri? _current;
  final _polls = <String, int>{};

  @override
  Future<void> open(Uri url) async {
    calls.add('open $url');
    if (failOpen.contains(url.host)) {
      throw StateError('cannot open ${url.host}');
    }
    _current = url;
    onOpen?.call(url);
  }

  @override
  List<String> pending() {
    final host = _current!.host;
    final limit = pendingFor[host] ?? 0;
    final n = _polls[host] = (_polls[host] ?? 0) + 1;
    return limit == -1 || n <= limit ? ['sovereignty'] : [];
  }

  @override
  void collectLate() => calls.add('collectLate');

  @override
  Future<void> clearSiteData(Uri url) async => calls.add('clear $url');

  @override
  Future<void> measureFreshLoad() async => calls.add('fresh');

  @override
  void watchSovereignty(bool watching) =>
      calls.add('watchSovereignty $watching');

  @override
  InspectionSummary summary() => InspectionSummary(
        [],
        {for (final k in summaryFactKeys) k: null}..['url'] =
            _current.toString(),
      );

  @override
  List<int> package() {
    calls.add('package $_current');
    return ZipEncoder()
        .encode(Archive()..addFile(ArchiveFile.string('a', 'b')));
  }
}
