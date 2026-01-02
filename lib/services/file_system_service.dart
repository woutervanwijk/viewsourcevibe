import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:path/path.dart' as path;

/// Comprehensive File System Service for handling app data, cache, and documents
class FileSystemService {
  /// Singleton instance
  static final FileSystemService _instance = FileSystemService._internal();
  
  factory FileSystemService() => _instance;
  
  FileSystemService._internal();

  /// Application directories
  Directory? _appDocumentsDirectory;
  Directory? _appCacheDirectory;
  Directory? _appSupportDirectory;
  Directory? _tempDirectory;

  /// Initialize the file system service
  Future<void> initialize() async {
    try {
      // Get all application directories
      _appDocumentsDirectory = await getApplicationDocumentsDirectory();
      _appCacheDirectory = await getTemporaryDirectory();
      
      if (Platform.isIOS || Platform.isMacOS) {
        _appSupportDirectory = await getApplicationSupportDirectory();
      }
      
      _tempDirectory = await getTemporaryDirectory();
      
      debugPrint('📁 File System Service Initialized');
      debugPrint('   Documents: ${_appDocumentsDirectory?.path}');
      debugPrint('   Cache: ${_appCacheDirectory?.path}');
      debugPrint('   Support: ${_appSupportDirectory?.path}');
      debugPrint('   Temp: ${_tempDirectory?.path}');
      
      // Create necessary directories
      await _ensureDirectoriesExist();
      
    } catch (e) {
      debugPrint('❌ Error initializing FileSystemService: $e');
      rethrow;
    }
  }

  /// Ensure all necessary directories exist
  Future<void> _ensureDirectoriesExist() async {
    try {
      // Create app-specific directories
      final dataDir = Directory(path.join(_appDocumentsDirectory!.path, 'data'));
      final cacheDir = Directory(path.join(_appCacheDirectory!.path, 'cache'));
      final downloadsDir = Directory(path.join(_appDocumentsDirectory!.path, 'downloads'));
      
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
        debugPrint('📂 Created data directory: ${dataDir.path}');
      }
      
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
        debugPrint('📂 Created cache directory: ${cacheDir.path}');
      }
      
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
        debugPrint('📂 Created downloads directory: ${downloadsDir.path}');
      }
      
    } catch (e) {
      debugPrint('⚠️  Warning: Could not create all directories: $e');
    }
  }

  /// Get the application documents directory
  Future<Directory> getDocumentsDirectory() async {
    if (_appDocumentsDirectory == null) {
      await initialize();
    }
    return _appDocumentsDirectory!;
  }

  /// Get the application cache directory
  Future<Directory> getCacheDirectory() async {
    if (_appCacheDirectory == null) {
      await initialize();
    }
    return _appCacheDirectory!;
  }

  /// Get the application support directory (iOS/macOS only)
  Future<Directory?> getSupportDirectory() async {
    if (Platform.isIOS || Platform.isMacOS) {
      if (_appSupportDirectory == null) {
        await initialize();
      }
      return _appSupportDirectory;
    }
    return null;
  }

  /// Get the temporary directory
  Future<Directory> getTempDirectory() async {
    if (_tempDirectory == null) {
      await initialize();
    }
    return _tempDirectory!;
  }

  /// Get the data directory (documents/data/)
  Future<Directory> getDataDirectory() async {
    final docsDir = await getDocumentsDirectory();
    final dataDir = Directory(path.join(docsDir.path, 'data'));
    
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    
    return dataDir;
  }

  /// Get the downloads directory (documents/downloads/)
  Future<Directory> getDownloadsDirectory() async {
    final docsDir = await getDocumentsDirectory();
    final downloadsDir = Directory(path.join(docsDir.path, 'downloads'));
    
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    
    return downloadsDir;
  }

  /// Get the cache directory for the app (cache/cache/)
  Future<Directory> getAppCacheDirectory() async {
    final cacheDir = await getCacheDirectory();
    final appCacheDir = Directory(path.join(cacheDir.path, 'cache'));
    
    if (!await appCacheDir.exists()) {
      await appCacheDir.create(recursive: true);
    }
    
    return appCacheDir;
  }

  /// Save content to a file in the data directory
  Future<File> saveToDataDirectory({
    required String filename,
    required String content,
    String subDirectory = '',
  }) async {
    final dataDir = await getDataDirectory();
    
    // Create subdirectory if specified
    final targetDir = subDirectory.isNotEmpty
        ? Directory(path.join(dataDir.path, subDirectory))
        : dataDir;
    
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    
    final file = File(path.join(targetDir.path, filename));
    await file.writeAsString(content);
    
    debugPrint('💾 Saved file to data directory: ${file.path}');
    return file;
  }

  /// Save binary data to a file in the data directory
  Future<File> saveBinaryToDataDirectory({
    required String filename,
    required List<int> bytes,
    String subDirectory = '',
  }) async {
    final dataDir = await getDataDirectory();
    
    // Create subdirectory if specified
    final targetDir = subDirectory.isNotEmpty
        ? Directory(path.join(dataDir.path, subDirectory))
        : dataDir;
    
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    
    final file = File(path.join(targetDir.path, filename));
    await file.writeAsBytes(bytes);
    
    debugPrint('💾 Saved binary file to data directory: ${file.path} (${bytes.length} bytes)');
    return file;
  }

  /// Save content to a file in the downloads directory
  Future<File> saveToDownloadsDirectory({
    required String filename,
    required String content,
    String subDirectory = '',
  }) async {
    final downloadsDir = await getDownloadsDirectory();
    
    // Create subdirectory if specified
    final targetDir = subDirectory.isNotEmpty
        ? Directory(path.join(downloadsDir.path, subDirectory))
        : downloadsDir;
    
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    
    final file = File(path.join(targetDir.path, filename));
    await file.writeAsString(content);
    
    debugPrint('📥 Saved file to downloads directory: ${file.path}');
    return file;
  }

  /// Save binary data to a file in the downloads directory
  Future<File> saveBinaryToDownloadsDirectory({
    required String filename,
    required List<int> bytes,
    String subDirectory = '',
  }) async {
    final downloadsDir = await getDownloadsDirectory();
    
    // Create subdirectory if specified
    final targetDir = subDirectory.isNotEmpty
        ? Directory(path.join(downloadsDir.path, subDirectory))
        : downloadsDir;
    
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    
    final file = File(path.join(targetDir.path, filename));
    await file.writeAsBytes(bytes);
    
    debugPrint('📥 Saved binary file to downloads directory: ${file.path} (${bytes.length} bytes)');
    return file;
  }

  /// Save content to a temporary file
  Future<File> saveToTempFile({
    required String filename,
    required String content,
  }) async {
    final tempDir = await getTempDirectory();
    final file = File(path.join(tempDir.path, filename));
    await file.writeAsString(content);
    
    debugPrint('⏳ Saved temporary file: ${file.path}');
    return file;
  }

  /// Save binary data to a temporary file
  Future<File> saveBinaryToTempFile({
    required String filename,
    required List<int> bytes,
  }) async {
    final tempDir = await getTempDirectory();
    final file = File(path.join(tempDir.path, filename));
    await file.writeAsBytes(bytes);
    
    debugPrint('⏳ Saved temporary binary file: ${file.path} (${bytes.length} bytes)');
    return file;
  }

  /// Read content from a file
  Future<String> readFileContent(File file) async {
    try {
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        throw Exception('File does not exist: ${file.path}');
      }
    } catch (e) {
      debugPrint('❌ Error reading file: ${file.path} - $e');
      rethrow;
    }
  }

  /// Read binary content from a file
  Future<List<int>> readFileBytes(File file) async {
    try {
      if (await file.exists()) {
        return await file.readAsBytes();
      } else {
        throw Exception('File does not exist: ${file.path}');
      }
    } catch (e) {
      debugPrint('❌ Error reading file bytes: ${file.path} - $e');
      rethrow;
    }
  }

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Delete a file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️  Deleted file: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting file: $filePath - $e');
      return false;
    }
  }

  /// Clear the app cache directory
  Future<void> clearAppCache() async {
    try {
      final cacheDir = await getAppCacheDirectory();
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
        debugPrint('🧹 Cleared app cache directory');
      }
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
      rethrow;
    }
  }

  /// Get file info
  Future<Map<String, dynamic>> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      
      return {
        'path': filePath,
        'exists': await file.exists(),
        'size': stat.size,
        'modified': stat.modified,
        'type': await _getFileType(filePath),
        'readable': true,
        'writable': true,
      };
    } catch (e) {
      debugPrint('❌ Error getting file info: $filePath - $e');
      return {
        'path': filePath,
        'exists': false,
        'error': e.toString(),
      };
    }
  }

  /// Get file type based on extension
  Future<String> _getFileType(String filePath) async {
    final extension = path.extension(filePath).toLowerCase();
    
    // Common file type mappings
    const fileTypes = {
      '.html': 'HTML',
      '.htm': 'HTML',
      '.css': 'CSS',
      '.js': 'JavaScript',
      '.json': 'JSON',
      '.xml': 'XML',
      '.yaml': 'YAML',
      '.yml': 'YAML',
      '.dart': 'Dart',
      '.py': 'Python',
      '.java': 'Java',
      '.kt': 'Kotlin',
      '.swift': 'Swift',
      '.go': 'Go',
      '.rs': 'Rust',
      '.php': 'PHP',
      '.rb': 'Ruby',
      '.cpp': 'C++',
      '.c': 'C',
      '.cs': 'C#',
      '.ts': 'TypeScript',
      '.txt': 'Text',
      '.md': 'Markdown',
      '.pdf': 'PDF',
      '.png': 'Image',
      '.jpg': 'Image',
      '.jpeg': 'Image',
      '.gif': 'Image',
      '.svg': 'Image',
    };
    
    return fileTypes[extension] ?? 'Unknown';
  }

  /// List files in a directory
  Future<List<Map<String, dynamic>>> listFilesInDirectory({
    required String directoryPath,
    bool recursive = false,
    List<String> extensions = const [],
  }) async {
    try {
      final dir = Directory(directoryPath);
      final files = <Map<String, dynamic>>[];
      
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: recursive)) {
          if (entity is File) {
            // Filter by extension if specified
            if (extensions.isEmpty || extensions.contains(path.extension(entity.path).toLowerCase())) {
              final stat = await entity.stat();
              files.add({
                'name': path.basename(entity.path),
                'path': entity.path,
                'size': stat.size,
                'modified': stat.modified,
                'type': path.extension(entity.path).toLowerCase(),
              });
            }
          }
        }
      }
      
      return files;
    } catch (e) {
      debugPrint('❌ Error listing files: $directoryPath - $e');
      return [];
    }
  }

  /// Get available storage space
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final docsDir = await getDocumentsDirectory();
      final cacheDir = await getCacheDirectory();
      
      final docsStat = await docsDir.stat();
      final cacheStat = await cacheDir.stat();
      
      // Calculate used space (approximate)
      final docsUsed = await _calculateDirectorySize(docsDir);
      final cacheUsed = await _calculateDirectorySize(cacheDir);
      
      return {
        'documents': {
          'path': docsDir.path,
          'used': docsUsed,
          'created': docsStat.modified,
        },
        'cache': {
          'path': cacheDir.path,
          'used': cacheUsed,
          'created': cacheStat.modified,
        },
      };
    } catch (e) {
      debugPrint('❌ Error getting storage info: $e');
      return {'error': e.toString()};
    }
  }

  /// Calculate directory size
  Future<int> _calculateDirectorySize(Directory directory) async {
    try {
      if (!await directory.exists()) return 0;
      
      int totalSize = 0;
      
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('⚠️  Warning: Could not calculate directory size: ${directory.path} - $e');
      return 0;
    }
  }

  /// Get platform-specific storage permissions status
  Future<Map<String, dynamic>> getStoragePermissions() async {
    try {
      // Check if we have access to documents directory
      final docsDir = await getDocumentsDirectory();
      final docsAccess = await docsDir.exists() && await _canWriteToDirectory(docsDir);
      
      // Check if we have access to cache directory
      final cacheDir = await getCacheDirectory();
      final cacheAccess = await cacheDir.exists() && await _canWriteToDirectory(cacheDir);
      
      return {
        'documents': docsAccess,
        'cache': cacheAccess,
        'platform': Platform.operatingSystem,
        'allGranted': docsAccess && cacheAccess,
      };
    } catch (e) {
      debugPrint('❌ Error checking storage permissions: $e');
      return {
        'error': e.toString(),
        'platform': Platform.operatingSystem,
      };
    }
  }

  /// Check if we can write to a directory
  Future<bool> _canWriteToDirectory(Directory directory) async {
    try {
      final testFile = File(path.join(directory.path, '.write_test_${DateTime.now().millisecondsSinceEpoch}'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Format file size for display
  String formatFileSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(2)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(2)} KB';
    } else {
      return '$bytes bytes';
    }
  }

  /// Get a unique filename to avoid conflicts
  String getUniqueFilename(String baseFilename) {
    final extension = path.extension(baseFilename);
    final nameWithoutExt = path.basenameWithoutExtension(baseFilename);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    return '${nameWithoutExt}_$timestamp$extension';
  }

  /// Clean up old temporary files
  Future<void> cleanupTempFiles({Duration olderThan = const Duration(days: 7)}) async {
    try {
      final tempDir = await getTempDirectory();
      final now = DateTime.now();
      
      await for (final entity in tempDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          
          if (age > olderThan) {
            try {
              await entity.delete();
              debugPrint('🧹 Cleaned up old temp file: ${entity.path} (${age.inDays} days old)');
            } catch (e) {
              debugPrint('⚠️  Could not delete temp file: ${entity.path} - $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up temp files: $e');
    }
  }
}