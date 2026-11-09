import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';

/// How long to keep collecting a page's resources after it loaded: poll
/// every [interval]; stop once nothing changed for [quiet] or after [max]
/// (Lighthouse waits for a quiet network the same way).
class NetworkQuietPolicy {
  final Duration interval;
  final Duration quiet;
  final Duration max;

  const NetworkQuietPolicy(
      {required this.interval, required this.quiet, required this.max});

  /// The live browser: 2 s polls, 5 s quiet, at most 30 s.
  static const live = NetworkQuietPolicy(
      interval: Duration(seconds: 2),
      quiet: Duration(seconds: 5),
      max: Duration(seconds: 30));

  /// The fresh load: Lighthouse's 45 s maximum.
  static const fresh = NetworkQuietPolicy(
      interval: Duration(seconds: 2),
      quiet: Duration(seconds: 5),
      max: Duration(seconds: 45));

  /// No polling at all (tests).
  static const off = NetworkQuietPolicy(
      interval: Duration.zero, quiet: Duration.zero, max: Duration.zero);

  bool get enabled => max > Duration.zero;

  /// Stop polling: quiet for [quiet] since the last change, or [max] reached.
  bool done({required Duration elapsed, required Duration sinceLastChange}) =>
      elapsed >= max || sinceLastChange >= quiet;
}

/// Changes when a resource is added or reports a larger size; used to tell
/// whether the page is still loading.
int resourceSignature(Observed<List<ResourceEntry>> resources) {
  if (resources is! Present<List<ResourceEntry>>) return -1;
  var sizes = 0;
  for (final r in resources.value) {
    final tx = r.transfer;
    if (tx is Present<int>) sizes += tx.value;
  }
  return Object.hash(resources.value.length, sizes);
}
