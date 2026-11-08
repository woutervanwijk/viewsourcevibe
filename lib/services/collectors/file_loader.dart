import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
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

  /// Whether we run on Android; replaceable in tests.
  @visibleForTesting
  static bool Function() isAndroid = () => !kIsWeb && Platform.isAndroid;

  /// Android user-visible shared storage, readable for shared (not deep
  /// link) paths because the share intent hands the user's own file over.
  static const _androidSharedRoots = ['/storage/emulated/', '/sdcard/'];

  static Future<String?> _resolveSharedStorage(String raw) async {
    if (!isAndroid()) return null;
    var normalized = normalizeExternalFilePath(raw);
    if (normalized == null) return null;
    bool inRoots(String x) => _androidSharedRoots.any(x.startsWith);
    if (!inRoots(normalized)) return null;
    try {
      // Resolve symlinks so a link inside shared storage cannot escape it.
      if (await File(normalized).exists()) {
        normalized = await File(normalized).resolveSymbolicLinks();
        if (!inRoots(normalized)) return null;
      }
    } catch (_) {
      return null;
    }
    return normalized;
  }

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
      var allowed = await resolveWithinAppDirectories(path);
      if (allowed == null && origin == FileOrigin.share) {
        allowed = await _resolveSharedStorage(path);
      }
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

  /// Loads a deep-link file. A refused or missing file becomes a visible
  /// error snapshot (isError) instead of a silent failure.
  static Future<FileSnapshot> fromDeepLinkPath(String path) async {
    try {
      return await fromPath(path, origin: FileOrigin.deepLink);
    } on FileLoadException catch (e) {
      final name = p.basename(path);
      final message = e.outsideSandbox
          ? "File outside the app's folders was not opened: $name"
          : e.notFound
              ? 'File not found: $name'
              : 'Could not open file: $name';
      return fromText(message,
          origin: FileOrigin.deepLink,
          name: 'File Error',
          path: path,
          isError: true);
    }
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
