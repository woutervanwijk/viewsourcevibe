import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/utils/file_utils.dart';
import 'package:view_source_vibe/screens/settings_screen.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class Toolbar extends StatelessWidget {
  const Toolbar({super.key});

  Future<void> _pickFile(BuildContext context) async {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    
    // Check if we have unsaved changes in edit mode
    if (htmlService.editMode && htmlService.hasUnsavedChanges) {
      final shouldContinue = await _showUnsavedChangesDialog(context);
      if (!shouldContinue) {
        return; // User cancelled the operation
      }
    }
    
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

  Future<bool> _showUnsavedChangesDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to discard them and load a new file?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Discard Changes'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _loadSampleFile(BuildContext context, String filename) async {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    
    // Check if we have unsaved changes in edit mode
    if (htmlService.editMode && htmlService.hasUnsavedChanges) {
      final shouldContinue = await _showUnsavedChangesDialog(context);
      if (!shouldContinue) {
        return; // User cancelled the operation
      }
    }
    
    try {
      final htmlFile = await FileUtils.loadSampleFile(filename);
      if (context.mounted) {
        await Provider.of<HtmlService>(context, listen: false)
            .loadFile(htmlFile);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sample file: $e')),
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

  void _toggleWordWrap(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final newValue = !settings.wrapText;
    settings.wrapText = newValue;
  }

  Future<void> _shareCurrentFile(BuildContext context) async {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    final currentFile = htmlService.currentFile;

    if (currentFile == null || currentFile.content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No content to share')),
      );
      return;
    }

    try {
      // Try to share using the platform sharing method
      // If that fails, fall back to copying to clipboard
      try {
        await UnifiedSharingService.shareHtml(currentFile.content,
            filename: currentFile.name);
      } catch (e) {
        debugPrint('Platform sharing failed, falling back to clipboard: $e');
        // Fall back to copying to clipboard
        await Clipboard.setData(ClipboardData(text: currentFile.content));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Content copied to clipboard')),
          );
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
      debugPrint('Share error: $e');
    }
  }

  void _showSampleFilesMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.html, color: Colors.blue),
            title: const Text('Sample HTML'),
            onTap: () {
              Navigator.pop(context);
              _loadSampleFile(context, 'sample.html');
            },
          ),
          ListTile(
            leading: const Icon(Icons.css, color: Colors.purple),
            title: const Text('Sample CSS'),
            onTap: () {
              Navigator.pop(context);
              _loadSampleFile(context, 'sample.css');
            },
          ),
          ListTile(
            leading: const Icon(Icons.code, color: Colors.green),
            title: const Text('Sample Dart'),
            onTap: () {
              Navigator.pop(context);
              _loadSampleFile(context, 'sample.dart');
            },
          ),
          ListTile(
            leading: const Icon(Icons.data_object, color: Colors.amber),
            title: const Text('Sample YAML'),
            onTap: () {
              Navigator.pop(context);
              _loadSampleFile(context, 'sample.yaml');
            },
          ),
          ListTile(
            leading: const Icon(Icons.code, color: Colors.blue),
            title: const Text('Sample Python'),
            onTap: () {
              Navigator.pop(context);
              _loadSampleFile(context, 'sample.py');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final currentFile = htmlService.currentFile;
    
    return Row(
      children: [
        // Edit/Save button - first position as requested
        if (currentFile != null)
          Consumer<HtmlService>(
            builder: (context, htmlService, child) {
              return IconButton(
                icon: Icon(
                  htmlService.editMode ? Icons.save : Icons.edit,
                  color: htmlService.editMode ? Colors.green : null,
                ),
                tooltip: htmlService.editMode ? 'Save Changes' : 'Edit File',
                onPressed: () async {
                  if (htmlService.editMode) {
                    // If in edit mode, save changes (with option to save to file)
                    await htmlService.saveChanges(context: context, saveToFile: true);
                  } else {
                    // If not in edit mode, enter edit mode
                    htmlService.toggleEditMode();
                  }
                },
              );
            },
          ),
        
        // Cancel button - shown when in edit mode (smaller, less prominent)
        if (currentFile != null && htmlService.editMode)
          Consumer<HtmlService>(
            builder: (context, htmlService, child) {
              return IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                tooltip: 'Cancel Edits',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await htmlService.discardChanges(context: context);
                },
              );
            },
          ),
        
        IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: 'Open File',
          onPressed: () => _pickFile(context),
        ),
        if (kDebugMode)
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Sample Files',
            onPressed: () => _showSampleFilesMenu(context),
          ),
        Consumer<AppSettings>(
          builder: (context, settings, child) {
            return Container(
              decoration: BoxDecoration(
                color: settings.wrapText
                    ? Theme.of(context).highlightColor
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  settings.wrapText
                      ? Icons.wrap_text
                      : Icons.wrap_text_outlined,
                ),
                tooltip:
                    'Toggle Word Wrap (${settings.wrapText ? 'ON' : 'OFF'})',
                onPressed: () => _toggleWordWrap(context),
              ),
            );
          },
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
  }
}
