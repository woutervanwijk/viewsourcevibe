import 'package:material_ui/material_ui.dart';

/// Asks before an inspection package leaves the app. True only on `Share`.
Future<bool> confirmSharePackage(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Share inspection package?'),
      content: const Text(
          'The package contains the page source as the browser showed it and '
          'every request URL. If you were signed in, that can include personal '
          'data. Cookie and storage values are not included.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Share'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
