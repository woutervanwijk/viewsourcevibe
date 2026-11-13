import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';
import 'package:universal_io/io.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About View Source Vibe'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Icon and Title
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.code,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'View Source Vibe',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Web Page Explorer',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.3.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (Platform.isIOS || Platform.isAndroid) ...[
                          ElevatedButton.icon(
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
                            icon: const Icon(Icons.share),
                            label: const Text('Share App'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        OutlinedButton.icon(
                          onPressed: () async {
                            await InAppBrowser.openWithSystemBrowser(
                              url: WebUri(
                                  'https://github.com/woutervanwijk/viewsourcevibe'),
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('GitHub'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // About Section (Updated)
              const Text(
                'About',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Viewing the source of a webpage is sooooo early 2026!! Just use View Source Vibe to easily see what's in the page, without looking at the source. Of course we included a source code viewer and a DOM Tree, but you probably don't need them for most quick glances, because of our easy to use exploring tools",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'It was created as an experiment in Vibe coding (using Mistral Vibe), proving that AI-assisted development can produce high-quality, usable software.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Key Features Section (Updated)
              const Text(
                'Key Features',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureItem(
                          '🌐 Built-in Browser with "Surf & View Source"'),
                      _buildFeatureItem(
                          '📱 Source viewer: HTML, CSS, JS, XML, JSON with syntax highlighting, search, word wrap and beautify'),
                      _buildFeatureItem('🌳 DOM Tree explorer'),
                      _buildFeatureItem('📖 Reader Mode and RSS/Atom feeds'),
                      _buildFeatureItem(
                          'ℹ️ Metadata: meta tags and OpenGraph/Twitter share previews'),
                      _buildFeatureItem(
                          '🛠️ Services: CMS, frameworks and third parties, with the evidence behind each detection'),
                      _buildFeatureItem('🖼️ Media: images, videos and fonts'),
                      _buildFeatureItem(
                          '⚖️ Page size: transfer and decoded weight of the page and its resources'),
                      _buildFeatureItem(
                          '🛡️ Privacy: which trackers and services see your visit'),
                      _buildFeatureItem(
                          '🌍 Sovereignty: where the page and its services are hosted, and under which law'),
                      _buildFeatureItem(
                          '📡 Network: request timeline, headers, cookies, probe and security (incl. TLS)'),
                      _buildFeatureItem(
                          '📂 Open local files, share URLs/files/text into the app, URL history'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Disclaimer Section (New)
              const Text(
                'Disclaimer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Indication only: detection of services, tech stacks, trackers, cookies and hosting is heuristic and may be incomplete or wrong.',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Copyright Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Collaboration',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '© 2026 Wouter van Wijk & Mistral Vibe & Gemini & Claude',
                        style: TextStyle(
                            fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Released under the MIT License. The name and icon of '
                        'View Source Vibe are not covered by that license.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'View Source Vibe',
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Open source licenses'),
                ),
              ),

              const SizedBox(height: 16),

              // Close Button
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
