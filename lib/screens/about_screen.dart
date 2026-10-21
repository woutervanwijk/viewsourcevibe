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
                      'Version 1.1.4',
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
                            onPressed: () {
                              UnifiedSharingService.shareText(
                                  'Check out View Source Vibe! 🚀 An easy-to-use web page explorer. See the source, tech stack, trackers and hosting of any page.\n\nGet it here: https://github.com/woutervanwijk/viewsourcevibe');
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
                        'View Source Vibe is an easy-to-use web page explorer. Read the source, walk the DOM, and see what a page is built with, which trackers and services it uses, and where it is hosted. Built with Flutter, it offers a desktop-class experience on your phone, tablet and desktop.',
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
                          '📱 Source viewer with syntax highlighting'),
                      _buildFeatureItem('🌳 DOM Tree explorer'),
                      _buildFeatureItem(
                          '🛠️ Services: CMS, frameworks and third parties'),
                      _buildFeatureItem(
                          '🛡️ Privacy: which trackers see your visit'),
                      _buildFeatureItem(
                          '🌍 Sovereignty: where a page is hosted'),
                      _buildFeatureItem('🖼️ Media: images, videos and fonts'),
                      _buildFeatureItem(
                          '📡 Network: timeline, headers, cookies, security'),
                      _buildFeatureItem(
                          '🌐 Built-in Browser with "Surf & View Source"'),
                      _buildFeatureItem('📖 Reader Mode and RSS/Atom feeds'),
                      _buildFeatureItem('📦 Bundle management for bookmarks'),
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
                        '© 2025 Wouter van Wijk & Mistral Vibe & Gemini & Claude',
                        style: TextStyle(
                            fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Released under the MIT License.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

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
