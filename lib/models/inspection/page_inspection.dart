import 'browser_snapshot.dart';
import 'file_snapshot.dart';
import 'observed.dart';
import 'server_snapshot.dart';

/// What is being inspected.
sealed class InspectionTarget {
  const InspectionTarget();
}

class NoTarget extends InspectionTarget {
  const NoTarget();
}

class UrlTarget extends InspectionTarget {
  final Uri url;
  const UrlTarget(this.url);
}

class FileTarget extends InspectionTarget {
  final FileSnapshot file;
  const FileTarget(this.file);
}

/// Immutable state of the current inspection: three cores (server, browser,
/// file) plus the generation of the navigation they belong to.
///
/// Robots are not kept separately: they live in `ServerSnapshot.robots`.
class PageInspection {
  final int generation;
  final InspectionTarget target;
  final Observed<ServerSnapshot> server;
  final Observed<BrowserSnapshot> browser;
  final Observed<FileSnapshot> file;

  /// The user's choice for the Source tab; null = default rule.
  final DataSource? primaryDocumentPreference;

  const PageInspection({
    required this.generation,
    required this.target,
    required this.server,
    required this.browser,
    required this.file,
    this.primaryDocumentPreference,
  });

  const PageInspection.empty()
      : generation = 0,
        target = const NoTarget(),
        server = const Unavailable(
            UnavailableReason.notApplicable, 'nothing loaded'),
        browser = const Unavailable(
            UnavailableReason.notApplicable, 'nothing loaded'),
        file = const Unavailable(
            UnavailableReason.notApplicable, 'nothing loaded'),
        primaryDocumentPreference = null;

  PageInspection copyWith({
    Observed<ServerSnapshot>? server,
    Observed<BrowserSnapshot>? browser,
    Observed<FileSnapshot>? file,
    Object? primaryDocumentPreference = _keep,
  }) =>
      PageInspection(
        generation: generation,
        target: target,
        server: server ?? this.server,
        browser: browser ?? this.browser,
        file: file ?? this.file,
        primaryDocumentPreference: identical(primaryDocumentPreference, _keep)
            ? this.primaryDocumentPreference
            : primaryDocumentPreference as DataSource?,
      );

  bool _has(DataSource s) => switch (s) {
        DataSource.browser => switch (browser) {
            Present<BrowserSnapshot>(value: final b) =>
              b.renderedDom is Present<RenderedDom>,
            _ => false,
          },
        DataSource.server => switch (server) {
            Present<ServerSnapshot>(value: final s) =>
              s.body is Present<ServerBody>,
            _ => false,
          },
        DataSource.file => file is Present<FileSnapshot>,
      };

  /// The document the Source/DOM/Metadata views use: the explicit preference
  /// when that source has a document, else rendered DOM, else server body,
  /// else file. Null when there is no document at all.
  DataSource? get primaryDocument {
    final pref = primaryDocumentPreference;
    if (pref != null && _has(pref)) return pref;
    for (final s in const [
      DataSource.browser,
      DataSource.server,
      DataSource.file
    ]) {
      if (_has(s)) return s;
    }
    return null;
  }
}

const Object _keep = Object();
