import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../detection/engine.dart';

/// Which sources a scan could look at, and which it could not.
class CheckedSources {
  /// Sources that were read ("server HTML and headers", "browser requests").
  final List<String> checked;

  /// Sources that were not available, each with its reason.
  final List<String> notChecked;

  /// A source is still loading: the findings may be incomplete.
  final bool waiting;

  const CheckedSources(this.checked, this.notChecked, this.waiting);

  bool get anythingChecked => checked.isNotEmpty;

  /// "Checked: server HTML and headers; browser requests not available for
  /// local files". Says which sources were read and which were not.
  String get line {
    if (checked.isEmpty && notChecked.isEmpty) return '';
    final parts = [
      if (checked.isNotEmpty) 'Checked: ${checked.join(', ')}',
      if (checked.isEmpty && notChecked.isNotEmpty) 'Nothing could be checked',
      ...notChecked,
    ];
    return parts.join('; ');
  }
}

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// What a detection scan of [p] could read. [browserReachable] says whether a
/// browser will report for this page; without one a Pending browser result
/// is a source that was never read, not one that is about to arrive.
CheckedSources describeCheckedSources(PageInspection p,
    {bool browserReachable = true}) {
  final checked = <String>[];
  final not = <String>[];
  var waiting = false;
  final isFile = p.target is FileTarget;

  switch (p.server) {
    case Present<ServerSnapshot>(value: final s):
      final body = s.body;
      checked.add(body is Present<ServerBody> && !body.value.decoded.isBinary
          ? 'server HTML and headers'
          : 'server headers');
    case Pending<ServerSnapshot>():
      waiting = true;
    case Failed<ServerSnapshot>(:final error):
      not.add('server response failed ($error)');
    case Unavailable<ServerSnapshot>(:final reason, :final detail):
      if (isFile) {
        not.add('server headers not available for local files');
      } else if (p.target is! NoTarget) {
        not.add(
            'server response ${_lower(unavailableMessage(reason, detail))}');
      }
  }

  switch (p.browser) {
    case Present<BrowserSnapshot>(value: final b):
      if (b.renderedDom is Present) {
        checked.add('browser DOM');
      } else {
        not.add('browser DOM ${_note(b.renderedDom)}');
      }
      if (b.resources is Present) {
        checked.add('browser requests');
      } else {
        not.add('browser requests ${_note(b.resources)}');
      }
      if (b.cookies is Present) {
        checked.add('browser cookies');
      } else {
        not.add('browser cookies ${_note(b.cookies)}');
      }
    case Pending<BrowserSnapshot>():
      if (browserReachable) {
        waiting = true;
      } else {
        not.add('browser data not collected (no browser is active)');
      }
    case Failed<BrowserSnapshot>(:final error):
      not.add('browser data failed ($error)');
    case Unavailable<BrowserSnapshot>(:final reason, :final detail):
      if (isFile) {
        not.add('browser requests not available for local files');
      } else if (p.target is! NoTarget) {
        not.add('browser data ${_lower(unavailableMessage(reason, detail))}');
      }
  }

  if (p.file is Present) checked.add('file source');
  return CheckedSources(checked, not, waiting);
}

String _note<T>(Observed<T> o) => switch (o) {
      Unavailable<T>(reason: final r, detail: final d) =>
        _lower(unavailableMessage(r, d)),
      Failed<T>(error: final e) => 'failed ($e)',
      Pending<T>() => 'still loading',
      Present<T>() => '',
    };

/// The Services, Privacy and Technology views' data: the findings and how
/// far to trust "nothing found".
class DetectionsView {
  final List<Detection> detections;

  /// The source scan runs, or a source is still loading.
  final bool scanning;

  /// The source scan failed: only request and cookie findings are shown.
  final String? failure;
  final CheckedSources sources;

  const DetectionsView({
    required this.detections,
    required this.scanning,
    required this.failure,
    required this.sources,
  });

  /// True when an empty list means "none found": the scan finished, did not
  /// fail and had something to read.
  bool get complete => !scanning && failure == null && sources.anythingChecked;
}
