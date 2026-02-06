import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/screens/settings_screen.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class Toolbar extends StatelessWidget {
  const Toolbar({super.key});

  Future<void> _pickFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Web Development
          'html', 'htm', 'xhtml', 'css', 'js', 'javascript', 'mjs', 'cjs',
          'ts', 'typescript', 'jsx', 'tsx', 'json', 'json5', 'xml', 'xsd',
          'xsl', 'svg', 'yaml', 'yml', 'vue', 'svelte',

          // Markup & Documentation
          'md', 'markdown', 'txt', 'text', 'adoc', 'asciidoc',

          // Programming Languages
          'dart', 'py', 'python', 'java', 'kt', 'kts', 'swift', 'go',
          'rs', 'rust', 'php', 'rb', 'ruby', 'cpp', 'cc', 'cxx', 'c++',
          'h', 'hpp', 'hxx', 'c', 'cs', 'scala', 'hs', 'haskell', 'lua',
          'pl', 'perl', 'r', 'sh', 'bash', 'zsh', 'fish', 'ps1', 'psm1',

          // Configuration & Data
          'ini', 'conf', 'config', 'properties', 'toml', 'sql', 'graphql',
          'gql', 'dockerfile', 'makefile', 'mk', 'cmake',

          // Styling & Preprocessors
          'scss', 'sass', 'less', 'styl', 'stylus',

          // Other Common Formats
          'diff', 'patch', 'gitignore', 'ignore', 'editorconfig',

          // Additional common text formats
          'log', 'env', 'gradle',
        ],
      );

      if (result != null && context.mounted) {
        final file = result.files.single;

        // Try to get content from bytes first, then fall back to reading from file path
        String content = '';
        int fileSize = file.size;

        if (file.bytes != null && file.bytes!.isNotEmpty) {
          // Use bytes if available
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null && file.path!.isNotEmpty) {
          // Try to read from file path if bytes are not available
          try {
            final fileObject = File(file.path!);
            if (await fileObject.exists()) {
              content = await fileObject.readAsString();
              fileSize = await fileObject.length();
            }
          } catch (e) {
            debugPrint('Error reading file from path: $e');
            // Fall back to empty content if file reading fails
            content = '';
            fileSize = 0;
          }
        }

        // If we still have no content, try to get it from file identifier
        if (content.isEmpty && file.identifier != null) {
          try {
            // Some file pickers provide content through identifier
            // This is a fallback attempt for special cases
            content = 'File content could not be loaded: ${file.name}';
          } catch (e) {
            debugPrint('Error getting file content: $e');
          }
        }

        final htmlFile = HtmlFile(
          name: file.name.isNotEmpty ? file.name : '',
          path: file.path ?? '',
          content: content,
          lastModified: DateTime.now(),
          size: fileSize,
          isUrl: false,
        );

        if (context.mounted) {
          await Provider.of<HtmlService>(context, listen: false)
              .loadFile(htmlFile);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading file: $e')),
        );
      }
    }
  }

  void _showSettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _shareCurrentFile(BuildContext context) async {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    final currentFile = htmlService.currentFile;

    if (currentFile == null) return;

    final String? choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Share Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (currentFile.isUrl)
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Share URL'),
                subtitle: Text(currentFile.path,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, 'url'),
              ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Share as File'),
              subtitle: Text(currentFile.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Share as Text'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    try {
      if (choice == 'url') {
        await UnifiedSharingService.shareUrl(currentFile.path);
      } else if (choice == 'file') {
        if (currentFile.content.isEmpty && !htmlService.isMedia) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No content to share')),
            );
          }
          return;
        }
        await UnifiedSharingService.shareHtml(currentFile.content,
            filename: currentFile.name);
      } else if (choice == 'text') {
        if (currentFile.content.isEmpty && !htmlService.isMedia) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No content to share')),
            );
          }
          return;
        }
        await UnifiedSharingService.shareText(currentFile.content);
      }
    } catch (e) {
      if (context.mounted) {
        // Fallback for text sharing if platform fails
        if (choice == 'text') {
          await Clipboard.setData(ClipboardData(text: currentFile.content));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Content copied to clipboard')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sharing: $e')),
          );
        }
      }
      debugPrint('Share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(
      builder: (context, htmlService, child) {
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 24),
              tooltip: 'Back',
              onPressed:
                  htmlService.canGoBack ? () => htmlService.goBack() : null,
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Open File',
              onPressed: () => _pickFile(context),
            ),
            IconButton(
              icon: Icon(
                Platform.isIOS ? CupertinoIcons.share : Icons.share,
                size: 24,
              ),
              tooltip: 'Share',
              onPressed: () => _shareCurrentFile(context),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => _showSettingsScreen(context),
            ),
          ],
        );
      },
    );
  }
}
