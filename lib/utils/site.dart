import 'package:view_source_vibe/utils/public_suffix.g.dart';

final _ipv4 = RegExp(r'^\d+(\.\d+){3}$');

/// The registrable domain of [host] (public suffix plus one label), per the
/// Public Suffix List algorithm. The host is lower-cased and a trailing dot
/// ignored. An IP address, a single label, an empty string or a host that is
/// itself a public suffix is returned unchanged (lower-cased).
String registrableDomain(String host) {
  var h = host.toLowerCase();
  if (h.endsWith('.')) h = h.substring(0, h.length - 1);
  if (h.isEmpty || h.contains(':') || h.startsWith('[') || _ipv4.hasMatch(h)) {
    return h;
  }
  final labels = h.split('.');
  if (labels.length < 2 || labels.any((l) => l.isEmpty)) return h;

  String suffixFrom(int i) => labels.sublist(i).join('.');

  // An exception rule beats everything: the suffix is the rule minus its
  // first label.
  var suffixLabels = 0;
  for (var i = 0; i < labels.length; i++) {
    if (publicSuffixExceptions.contains(suffixFrom(i))) {
      suffixLabels = labels.length - i - 1;
      break;
    }
  }
  if (suffixLabels == 0) {
    // Longest matching rule wins; the default rule `*` is the last label.
    suffixLabels = 1;
    for (var i = 0; i < labels.length; i++) {
      final n = labels.length - i;
      if (n <= suffixLabels) break;
      if (publicSuffixRules.contains(suffixFrom(i)) ||
          (i + 1 < labels.length &&
              publicSuffixWildcards.contains(suffixFrom(i + 1)))) {
        suffixLabels = n;
        break;
      }
    }
  }
  if (labels.length <= suffixLabels) return h;
  return labels.sublist(labels.length - suffixLabels - 1).join('.');
}

/// True when both hosts share a registrable domain. Hosts that are not
/// domains (empty, IP, single label) are the same site only when equal and
/// non-empty.
bool sameSite(String hostA, String hostB) {
  final a = registrableDomain(hostA);
  final b = registrableDomain(hostB);
  return a.isNotEmpty && a == b;
}
