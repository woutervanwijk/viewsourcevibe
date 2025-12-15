import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:htmlviewer/utils/file_utils.dart';
import 'package:htmlviewer/widgets/url_dialog.dart';
import 'package:htmlviewer/screens/settings_screen.dart';

class Toolbar extends StatelessWidget {
  const Toolbar({super.key});

  Future<void> _pickFile(BuildContext context) async {
    final navigatorContext = context;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['html', 'htm', 'css', 'js', 'json', 'xml', 'txt'],
      );

      if (result != null) {
        final file = result.files.single;
        final content = String.fromCharCodes(file.bytes!);
        
        final htmlFile = HtmlFile(
          name: file.name,
          path: file.path ?? '',
          content: content,
          lastModified: DateTime.now(),
          size: file.size,
        );

        Provider.of<HtmlService>(navigatorContext, listen: false).loadFile(htmlFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(navigatorContext).showSnackBar(
        SnackBar(content: Text('Error loading file: $e')),
      );
    }
  }

  Future<void> _loadSampleFile(BuildContext context, String filename) async {
    final navigatorContext = context;
    try {
      final htmlFile = await FileUtils.loadSampleFile(filename);
      Provider.of<HtmlService>(navigatorContext, listen: false).loadFile(htmlFile);
    } catch (e) {
      ScaffoldMessenger.of(navigatorContext).showSnackBar(
        SnackBar(content: Text('Error loading sample file: $e')),
      );
    }
  }

  void _showSettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: 'Open File',
          onPressed: () => _pickFile(context),
        ),
        IconButton(
          icon: const Icon(Icons.language),
          tooltip: 'Open URL',
          onPressed: () => showUrlDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.code),
          tooltip: 'Sample Files',
          onPressed: () => _showSampleFilesMenu(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            // TODO: Implement refresh functionality
          },
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