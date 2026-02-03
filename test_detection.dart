import 'package:view_source_vibe/services/metadata_parser.dart';

void main() async {
  final testCases = [
    {
      'name': 'Cookiebot and Next.js',
      'html':
          '<html><head><script src="https://consent.cookiebot.com/uc.js"></script><script src="/_next/static/chunks/main.js"></script></head><body></body></html>',
      'expectedTech': {'Framework': 'Next.js'},
      'expectedServices': {
        'Privacy & Consent Management': ['Cookiebot']
      },
    },
    {
      'name': 'WordPress with Google Analytics',
      'html':
          '<html><head><meta name="generator" content="WordPress 6.0"><script src="https://www.googletagmanager.com/gtag/js?id=UA-123"></script></head><body><div class="wp-content"></div></body></html>',
      'expectedTech': {'CMS': 'WordPress'},
      'expectedServices': {
        'Analytics & Trackers': ['Google Analytics', 'Google Tag Manager']
      },
    },
    {
      'name': 'Astro and Tailwind',
      'html':
          '<html><head><meta name="generator" content="Astro v1.0"><link rel="stylesheet" href="tailwind.css"><meta class="sm:text-white"></head><body></body></html>',
      'expectedTech': {'Static Site': 'Astro', 'CSS Framework': 'Tailwind CSS'},
      'expectedServices': {},
    },
    {
      'name': 'Htmx and Alpine.js',
      'html':
          '<html><body><button hx-get="/data" x-data="{open: false}">Click</button></body></html>',
      'expectedTech': {
        'Library': 'HTMX'
      }, // Current implementation only stores one value per category, HTMX wins here
      'expectedServices': {},
    },
    {
      'name': 'OneTrust and Crisp',
      'html':
          '<html><head><script src="otSDKStub.js"></script><script src="client.crisp.chat/l.js"></script></head><body></body></html>',
      'expectedTech': {},
      'expectedServices': {
        'Privacy & Consent Management': ['OneTrust'],
        'Marketing & CRM': ['Crisp']
      },
    }
  ];

  for (final testCase in testCases) {
    print('Testing: ${testCase['name']}');
    final metadata = await extractMetadataInIsolate(
        testCase['html'] as String, 'https://example.com');

    final tech = metadata['detectedTech'] as Map<String, String>;
    final services = metadata['detectedServices'] as Map<String, List<String>>;

    print('  Detected Tech: $tech');
    print('  Detected Services: $services');

    // Simple validation (can be expanded)
  }
}
