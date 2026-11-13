#!/bin/bash
# Renders every app icon from the SVG masters in assets/.
# Needs rsvg-convert and cwebp (brew install librsvg webp).
set -e
cd "$(dirname "$0")"

render() { rsvg-convert -w "$2" -h "$2" "$1" -o "$3"; }

echo "Rendering masters..."
render assets/icon.svg 1024 assets/icon.png
render assets/icon.svg 512 assets/icon512.png
cwebp -quiet -lossless assets/icon.png -o assets/icon.webp
render assets/icon_foreground.svg 1024 assets/icon_foreground.png
render assets/icon_desktop.svg 1024 assets/icon_desktop.png

echo "Generating platform icons..."
dart run flutter_launcher_icons

# flutter_launcher_icons scales one image for every macOS size; the small
# sizes get the simplified three-row glyph instead.
MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64; do render assets/icon_desktop_small.svg "$s" "$MAC/app_icon_$s.png"; done

# iOS launch screen: the icon at 120pt, centered on white.
LAUNCH=ios/Runner/Assets.xcassets/LaunchImage.imageset
render assets/icon_desktop.svg 120 "$LAUNCH/icon.png"
render assets/icon_desktop.svg 240 "$LAUNCH/icon 1.png"
render assets/icon_desktop.svg 360 "$LAUNCH/icon 2.png"

echo "Done."
