import 'package:flutter/foundation.dart';

import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/file_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/text_decoding.dart';

/// "12345" -> "12.345" (the Source header's number style).
int _lines(String text) => '\n'.allMatches(text).length + 1;

String formatThousands(int number) => number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');

/// What the Source tab (and the DOM tree) shows: one document of the store,
/// its state, and honest size/charset labels. Pure data; built by
/// [deriveSourceView].
@immutable
class SourceView {
  /// True for a URL inspection: the user can pick rendered DOM or server HTML.
  final bool canSwitch;

  /// Which document [text] belongs to; null for a document the store does not
  /// hold (legacy fallback content, nothing loaded).
  final DataSource? requested;

  /// The document text, or why there is none (Pending / Failed / Unavailable).
  final Observed<String> text;

  /// "12.345 bytes", "9.000 characters (serialized DOM)"; null without text.
  final String? sizeLabel;

  /// Charset of a server body / file; null for the rendered DOM.
  final String? charsetLabel;

  /// Number of lines in [text]; null without text.
  final int? lineCount;

  /// Content type of the displayed document (server header / browser
  /// document.contentType); null when unknown or for files.
  final String? contentType;

  /// File name when the document is a local file.
  final String? fileName;

  const SourceView({
    required this.canSwitch,
    required this.requested,
    required this.text,
    this.sizeLabel,
    this.charsetLabel,
    this.lineCount,
    this.contentType,
    this.fileName,
  });

  String? get textOrNull {
    final t = text;
    return t is Present<String> ? t.value : null;
  }

  /// "rendered DOM", "server HTML", "file".
  String get label => switch (requested) {
        DataSource.browser => 'rendered DOM',
        DataSource.server => 'server HTML',
        DataSource.file => 'file',
        null => 'loaded document',
      };

  /// Shown while [text] is Pending.
  String get pendingMessage => switch (requested) {
        DataSource.browser => 'Waiting for the rendered DOM…',
        _ => 'Fetching server HTML…',
      };

  @override
  bool operator ==(Object other) =>
      other is SourceView &&
      canSwitch == other.canSwitch &&
      requested == other.requested &&
      _sameText(text, other.text) &&
      sizeLabel == other.sizeLabel &&
      charsetLabel == other.charsetLabel &&
      contentType == other.contentType &&
      fileName == other.fileName;

  @override
  int get hashCode => Object.hash(canSwitch, requested, text.runtimeType,
      textOrNull?.length, sizeLabel, charsetLabel);
}

bool _sameText(Observed<String> a, Observed<String> b) => switch ((a, b)) {
      (Present<String> x, Present<String> y) => x.value == y.value,
      (Pending<String>(), Pending<String>()) => true,
      (Failed<String> x, Failed<String> y) => x.error == y.error,
      (Unavailable<String> x, Unavailable<String> y) =>
        x.reason == y.reason && x.detail == y.detail,
      _ => false,
    };

Observed<String> _asText<T>(Observed<T> o) => switch (o) {
      Pending<T>() => const Pending(),
      Failed<T>(:final error) => Failed(error),
      Unavailable<T>(:final reason, :final detail) =>
        Unavailable(reason, detail),
      Present<T>() => const Unavailable(UnavailableReason.notApplicable),
    };

const _binary = Unavailable<String>(
    UnavailableReason.notApplicable, 'binary content, not shown as text');

String _charsetSourceWord(CharsetSource s) => switch (s) {
      CharsetSource.header => 'HTTP header',
      CharsetSource.bom => 'byte order mark',
      CharsetSource.meta => 'meta tag',
      CharsetSource.fallback => 'assumed',
    };

String _charsetLabel(DecodedText d) {
  if (d.unsupportedCharset) {
    return 'charset ${d.declaredCharset ?? 'unknown'} not supported — '
        'shown as ${d.charset}';
  }
  final malformed = d.hadMalformed ? ', some bytes could not be decoded' : '';
  return 'charset ${d.charset} (${_charsetSourceWord(d.charsetSource)})'
      '$malformed';
}

SourceView _forBrowser(Observed<BrowserSnapshot> b, bool canSwitch) {
  if (b is Present<BrowserSnapshot>) {
    final dom = b.value.renderedDom;
    if (dom is Present<RenderedDom>) {
      return SourceView(
        canSwitch: canSwitch,
        requested: DataSource.browser,
        text: Present(dom.value.text, source: DataSource.browser),
        sizeLabel:
            '${formatThousands(dom.value.domCharCount)} characters (serialized DOM)',
        lineCount: _lines(dom.value.text),
        contentType: switch (b.value.contentType) {
          Present<String>(:final value) => value,
          _ => null,
        },
      );
    }
    return SourceView(
        canSwitch: canSwitch,
        requested: DataSource.browser,
        text: _asText(dom));
  }
  return SourceView(
      canSwitch: canSwitch, requested: DataSource.browser, text: _asText(b));
}

SourceView _forServer(Observed<ServerSnapshot> s, bool canSwitch) {
  if (s is Present<ServerSnapshot>) {
    final body = s.value.body;
    if (body is Present<ServerBody>) {
      final b = body.value;
      if (b.decoded.isBinary) {
        return SourceView(
            canSwitch: canSwitch, requested: DataSource.server, text: _binary);
      }
      final transfer = b.transferLength != b.byteLength
          ? ' (transfer ${formatThousands(b.transferLength)} bytes)'
          : '';
      final cut = b.truncated ? ', cut off at the size limit' : '';
      return SourceView(
        canSwitch: canSwitch,
        requested: DataSource.server,
        text: Present(b.decoded.text, source: DataSource.server),
        sizeLabel: '${formatThousands(b.byteLength)} bytes$transfer$cut',
        charsetLabel: _charsetLabel(b.decoded),
        lineCount: _lines(b.decoded.text),
        contentType: s.value.hops.isEmpty
            ? null
            : s.value.hops.last.header('content-type'),
      );
    }
    return SourceView(
        canSwitch: canSwitch,
        requested: DataSource.server,
        text: _asText(body));
  }
  return SourceView(
      canSwitch: canSwitch, requested: DataSource.server, text: _asText(s));
}

SourceView _forFile(Observed<FileSnapshot> f) {
  if (f is Present<FileSnapshot>) {
    final file = f.value;
    if (file.isBinary) {
      return const SourceView(
          canSwitch: false, requested: DataSource.file, text: _binary);
    }
    return SourceView(
      canSwitch: false,
      requested: DataSource.file,
      text: Present(file.text.text, source: DataSource.file),
      sizeLabel: '${formatThousands(file.byteLength)} bytes',
      charsetLabel: _charsetLabel(file.text),
      lineCount: _lines(file.text.text),
      fileName: file.name,
    );
  }
  return SourceView(
      canSwitch: false, requested: DataSource.file, text: _asText(f));
}

/// Text the store does not hold (a generated error page, a URL file loaded
/// without fetch). No switch: neither core is the source of this text.
SourceView _fallback(String text) => SourceView(
      canSwitch: false,
      requested: null,
      text: Present(text, source: DataSource.file),
      sizeLabel: '${formatThousands(text.length)} characters (loaded document)',
      lineCount: _lines(text),
    );

/// The document the Source tab and DOM tree show for [p].
///
/// URL inspection: the user's choice (rendered DOM / server HTML), else the
/// store's default rule; a chosen source that has no document yet shows its
/// state (Pending / Failed / Unavailable), never another document's text.
/// File: the file. When the store holds no document at all, [fallbackText]
/// (the app's legacy current file, e.g. a generated error page) is shown.
SourceView deriveSourceView(PageInspection p, {String? fallbackText}) {
  final t = p.target;
  if (t is FileTarget) {
    if (p.file is! Present<FileSnapshot> &&
        fallbackText != null &&
        fallbackText.isNotEmpty) {
      return _fallback(fallbackText);
    }
    return _forFile(p.file);
  }
  final canSwitch = t is UrlTarget;
  final requested = p.primaryDocumentPreference ?? p.primaryDocument;
  if (canSwitch && requested != null) {
    return switch (requested) {
      DataSource.browser => _forBrowser(p.browser, true),
      DataSource.server => _forServer(p.server, true),
      DataSource.file => _forFile(p.file),
    };
  }
  if (fallbackText != null && fallbackText.isNotEmpty) {
    return _fallback(fallbackText);
  }
  if (!canSwitch) {
    return const SourceView(
        canSwitch: false,
        requested: null,
        text: Unavailable(UnavailableReason.notApplicable, 'nothing loaded'));
  }
  // Nothing yet: say what we are waiting for.
  final server = p.server, browser = p.browser;
  final waiting =
      server is Pending<ServerSnapshot> || browser is Pending<BrowserSnapshot>;
  if (waiting) {
    return SourceView(
        canSwitch: true,
        requested: server is Pending<ServerSnapshot>
            ? DataSource.server
            : DataSource.browser,
        text: const Pending());
  }
  return _forServer(p.server, true);
}
