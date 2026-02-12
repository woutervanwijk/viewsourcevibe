import 'package:flutter/material.dart';

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
                      'Cross-Platform Source Code Viewer',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
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
                        'View Source Vibe is a powerful tool to view source code, inspect web pages, and analyze web technologies. Built with Flutter, it offers a desktop-class inspection experience on your mobile device.',
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
                      _buildFeatureItem('📱 View Source & Inspect web pages'),
                      _buildFeatureItem('🌳 DOM Tree Inspector'),
                      _buildFeatureItem(
                          '📖 Reader Mode for distraction-free reading'),
                      _buildFeatureItem('📡 RSS/Atom Feed Support'),
                      _buildFeatureItem(
                          '🔍 Deep Analysis: Metadata, headers, security'),
                      _buildFeatureItem('🛠️ Tech Stack & CMS Detection'),
                      _buildFeatureItem(
                          '🌐 Built-in Browser with "Surf & View Source"'),
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
                          'Please note: The detection of services, tech stacks, and cookies is currently in beta and may not be 100% reliable yet.',
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
                        '© 2025 Wouter van Wijk & Mistral Vibe',
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
