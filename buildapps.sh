#!/bin/bash
flutter clean
flutter build ipa --release
rm -f "build/ViewSourceVibe.xcarchive"
mv build/ios/archive/Runner.xcarchive "build/ViewSourceVibe.xcarchive"

flutter build appbundle --release
rm -f "build/ViewSourceVibe.aab"
mv build/app/outputs/bundle/release/app-release.aab "build/ViewSourceVibe.aab"
