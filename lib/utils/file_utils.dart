import 'package:flutter/services.dart';
import 'package:htmlviewer/models/html_file.dart';

class FileUtils {
  static Future<HtmlFile> loadSampleFile(String filename) async {
    try {
      final content = await rootBundle.loadString('assets/$filename');
      return HtmlFile.fromContent(filename, content);
    } catch (e) {
      throw Exception('Failed to load sample file: $e');
    }
  }

  static Future<List<HtmlFile>> getAvailableSampleFiles() async {
    // In a real app, you might scan the assets directory
    // For now, we'll return a hardcoded list
    return [
      HtmlFile.fromContent('sample.html', ''),
      HtmlFile.fromContent('sample.css', ''),
    ];
  }
}