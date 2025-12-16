import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'dart:io';

void main() {
  group('SVG Icon Tests', () {
    test('HTML Viewer SVG icons exist', () {
      // Check that SVG files exist
      final iconPath = 'assets/icon.html_viewer.svg';
      final iconMinimalPath = 'assets/icon.html_viewer_minimal.svg';
      
      final iconFile = File(iconPath);
      final iconMinimalFile = File(iconMinimalPath);
      
      expect(iconFile.existsSync(), true, reason: 'HTML Viewer SVG icon should exist');
      expect(iconMinimalFile.existsSync(), true, reason: 'HTML Viewer minimal SVG icon should exist');
    });

    test('SVG icons have valid content', () {
      final iconPath = 'assets/icon.html_viewer.svg';
      final iconMinimalPath = 'assets/icon.html_viewer_minimal.svg';
      
      final iconContent = File(iconPath).readAsStringSync();
      final iconMinimalContent = File(iconMinimalPath).readAsStringSync();
      
      // Check that files contain valid SVG content
      expect(iconContent.contains('<svg'), true, reason: 'Should contain SVG tag');
      expect(iconContent.contains('xmlns="http://www.w3.org/2000/svg"'), true, reason: 'Should contain SVG namespace');
      expect(iconContent.contains('</svg>'), true, reason: 'Should contain closing SVG tag');
      
      expect(iconMinimalContent.contains('<svg'), true, reason: 'Should contain SVG tag');
      expect(iconMinimalContent.contains('xmlns="http://www.w3.org/2000/svg"'), true, reason: 'Should contain SVG namespace');
      expect(iconMinimalContent.contains('</svg>'), true, reason: 'Should contain closing SVG tag');
    });

    test('SVG icons have appropriate dimensions', () {
      final iconPath = 'assets/icon.html_viewer.svg';
      final iconMinimalPath = 'assets/icon.html_viewer_minimal.svg';
      
      final iconContent = File(iconPath).readAsStringSync();
      final iconMinimalContent = File(iconMinimalPath).readAsStringSync();
      
      // Check that icons have 512x512 dimensions (standard for app icons)
      expect(iconContent.contains('width="512"'), true, reason: 'Should have 512px width');
      expect(iconContent.contains('height="512"'), true, reason: 'Should have 512px height');
      
      expect(iconMinimalContent.contains('width="512"'), true, reason: 'Should have 512px width');
      expect(iconMinimalContent.contains('height="512"'), true, reason: 'Should have 512px height');
    });

    test('SVG icons contain HTML viewing symbols', () {
      final iconContent = File('assets/icon.html_viewer.svg').readAsStringSync();
      final iconMinimalContent = File('assets/icon.html_viewer_minimal.svg').readAsStringSync();
      
      // Check for HTML/Code related elements
      expect(iconContent.contains('HTML') || iconContent.contains('code') || iconContent.contains('bracket'), 
          true, reason: 'Should contain HTML/code related symbols');
      
      expect(iconMinimalContent.contains('HTML') || iconMinimalContent.contains('code') || iconMinimalContent.contains('bracket'),
          true, reason: 'Should contain HTML/code related symbols');
    });

    test('SVG icons use appropriate color scheme', () {
      final iconContent = File('assets/icon.html_viewer.svg').readAsStringSync();
      final iconMinimalContent = File('assets/icon.html_viewer_minimal.svg').readAsStringSync();
      
      // Check for blue color scheme (HTML viewer theme)
      expect(iconContent.contains('#1E88E5') || iconContent.contains('#2196F3') || iconContent.contains('blue'),
          true, reason: 'Should use blue color scheme');
      
      expect(iconMinimalContent.contains('#1E88E5') || iconMinimalContent.contains('#2196F3') || iconMinimalContent.contains('blue'),
          true, reason: 'Should use blue color scheme');
    });
  });
}