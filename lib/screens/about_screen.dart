import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';
import 'package:view_source_vibe/widgets/section_box.dart';
import 'package:universal_io/io.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Features with the icon of the tab that shows them.
  static const _features = <(IconData, String)>[
    (Icons.language, 'Built-in browser with "Surf & View Source"'),
    (
      Icons.code,
      'Source viewer: HTML, CSS, JS, XML, JSON with syntax highlighting, search, word wrap and beautify'
    ),
    (Icons.account_tree_outlined, 'DOM Tree explorer'),
    (Icons.chrome_reader_mode, 'Reader mode and RSS/Atom feeds'),
    (
      Icons.info_outline,
      'Metadata: meta tags and OpenGraph/Twitter share previews'
    ),
    (
      Icons.layers_outlined,
      'Services: CMS, frameworks and third parties, with the evidence behind each detection'
    ),
    (Icons.perm_media_outlined, 'Media: images, videos and fonts'),
    (
      Icons.scale_outlined,
      'Size: transfer and decoded weight of the page and its resources'
    ),
    (
      Icons.privacy_tip_outlined,
      'Privacy: which trackers and services see your visit'
    ),
    (
      Icons.public,
      'Sovereignty: where the page and its services are hosted, and under which law'
    ),
    (
      Icons.timeline,
      'Network: request timeline, headers, cookies, probe and security (incl. TLS)'
    ),
    (
      Icons.folder_open,
      'Open local files, share URLs/files/text into the app, URL history'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const bodyStyle = TextStyle(fontSize: 15, height: 1.45);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App icon and name
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/icon.webp',
                          width: 88, height: 88),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'View Source Vibe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Web page explorer · Version 2.0.0',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (Platform.isIOS || Platform.isAndroid)
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await UnifiedSharingService.shareText(
                                  'Check out View Source Vibe! 🚀 An easy-to-use web page explorer. See the source, tech stack, trackers and hosting of any page.\n\nGet it here: https://github.com/woutervanwijk/viewsourcevibe');
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error sharing: $e')),
                              );
                            }
                          },
                          icon: Icon(Platform.isIOS
                              ? CupertinoIcons.share
                              : Icons.share_outlined),
                          label: const Text('Share app'),
                          style: ButtonStyle(shape: kUiButtonShape),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await InAppBrowser.openWithSystemBrowser(
                            url: WebUri(
                                'https://github.com/woutervanwijk/viewsourcevibe'),
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('GitHub'),
                        style: ButtonStyle(shape: kUiButtonShape),
                      ),
                    ],
                  ),

                  const SectionLabel('About'),
                  const SectionBox(children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Viewing the source of a webpage is sooooo early 2026!! Just use View Source Vibe to easily see what's in the page, without looking at the source. Of course we included a source code viewer and a DOM Tree, but you probably don't need them for most quick glances, because of our easy to use exploring tools",
                            style: bodyStyle,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'It was created as an experiment in Vibe coding (using Mistral Vibe), proving that AI-assisted development can produce high-quality, usable software.',
                            style: bodyStyle,
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SectionLabel('Key features'),
                  SectionBox(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          for (final (icon, text) in _features)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(icon, size: 20, color: scheme.primary),
                                  const SizedBox(width: 14),
                                  Expanded(child: Text(text, style: bodyStyle)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),

                  const SectionLabel('Disclaimer'),
                  SectionBox(
                    color: scheme.surfaceContainerHighest,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: scheme.tertiary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Indication only: detection of services, tech stacks, trackers, cookies and hosting is heuristic and may be incomplete or wrong.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SectionLabel('Collaboration'),
                  SectionBox(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '© 2026 Wouter van Wijk & Mistral Vibe & Gemini & Claude',
                            style: bodyStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Released under the MIT License. The name and icon of '
                            'View Source Vibe are not covered by that license.',
                            style: TextStyle(
                                fontSize: 14, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.description_outlined,
                          color: scheme.primary),
                      title: const Text('Open source licenses'),
                      trailing: Icon(Icons.chevron_right,
                          color: scheme.onSurfaceVariant),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'View Source Vibe',
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ButtonStyle(shape: kUiButtonShape),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
