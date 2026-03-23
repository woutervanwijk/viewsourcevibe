#!/bin/bash
flutter clean

flutter build macos --release
rm -drf  "build/View Source Vibe.app"
mv "build/macos/Build/Products/Release/View Source Vibe.app" "build/View Source Vibe.app"