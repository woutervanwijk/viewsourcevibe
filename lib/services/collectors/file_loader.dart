import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import '../../models/inspection/file_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../utils/text_decoding.dart';
import '../file_system_service.dart';

/// A file could not be loaded; [message] is user-presentable.
class FileLoadException implements Exception {
  final String message;

  /// The path is outside the app directories (blocked by the sandbox check).
  final bool outsideSandbox;
  final bool notFound;

  const FileLoadException(this.message,
      {this.outsideSandbox = false, this.notFound = false});

  @override
  String toString() => message;
}

/// The one place where local, shared and deep-linked files become a
/// [FileSnapshot].
class FileLoader {
  const FileLoader._();

  /// Reads [path] as bytes and decodes it by charset.
  ///
  /// With [enforceSandbox] (default) the path must be inside the app
  /// directories: use this for untrusted sources (deep links, share intents).
  /// Pass false only for the app's own saved state (restore/reload).
  static Future<FileSnapshot> fromPath(
    String path, {
    required FileOrigin origin,
    bool enforceSandbox = true,
  }) async {
    var resolved = path;
    if (enforceSandbox) {
      final allowed = await resolveWithinAppDirectories(path);
      if (allowed == null) {
        throw const FileLoadException(
            'File is outside the app directories and cannot be opened',
            outsideSandbox: true);
      }
      resolved = allowed;
    }
    final file = File(resolved);
    if (!await file.exists()) {
      throw FileLoadException('File does not exist: $resolved', notFound: true);
    }
    final bytes = await file.readAsBytes();
    final modified = (await file.stat()).modified;
    return _build(
      name: p.basename(resolved),
      path: resolved,
      origin: origin,
      bytes: bytes,
      lastModified: Present(modified, source: DataSource.file),
    );
  }

  /// Bytes delivered by the OS (file picker, share extension). The platform
  /// reports no modification time, so lastModified is Unavailable.
  static FileSnapshot fromBytes(
    List<int> bytes, {
    required String name,
    required FileOrigin origin,
    String path = '',
  }) {
    return _build(
      name: name,
      path: path,
      origin: origin,
      bytes: bytes,
      lastModified: const Unavailable(UnavailableReason.notReportedByPlatform,
          'not provided by picker/share'),
    );
  }

  /// Text that was shared or typed (kept verbatim, never treated as binary).
  static FileSnapshot fromText(
    String text, {
    required FileOrigin origin,
    String name = 'Shared text',
    String path = 'shared://text',
    bool isError = false,
  }) {
    final bytes = utf8.encode(text);
    return FileSnapshot(
      name: name,
      path: path,
      origin: origin,
      bytes: bytes,
      text: DecodedText(
        text: text,
        charset: 'utf-8',
        charsetSource: CharsetSource.fallback,
        byteLength: bytes.length,
      ),
      lastModified: const Unavailable(UnavailableReason.notReportedByPlatform,
          'not provided by picker/share'),
      isError: isError,
    );
  }

  static FileSnapshot _build({
    required String name,
    required String path,
    required FileOrigin origin,
    required List<int> bytes,
    required Observed<DateTime> lastModified,
  }) {
    return FileSnapshot(
      name: name,
      path: path,
      origin: origin,
      bytes: bytes,
      text: decodeText(bytes),
      lastModified: lastModified,
    );
  }
}
