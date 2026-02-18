#!/bin/bash
set -e

APP_ICON_SET="/Users/wouter/code/viewsourcevibe/macos/Runner/Assets.xcassets/AppIcon.appiconset"
SOURCE_ICON="/Users/wouter/.gemini/antigravity/brain/c5b9b46d-bc67-447b-8f38-08977bb65a98/macos_icon_square_1771427271790.png"

echo "Resizing icons..."

sips -z 16 16 "$SOURCE_ICON" --out "$APP_ICON_SET/app_icon_16.png"
sips -z 32 32 "$SOURCE_ICON" --out "$APP_ICON_SET/app_icon_32.png"
sips -z 64 64 "$SOURCE_ICON" --out "$APP_ICON_SET/app_icon_64.png"
sips -z 128 128 "$SOURCE_ICON" --out "$APP_ICON_SET/app_icon_128.png"
sips -z 256 256 "$SOURCE_ICON" --out "$APP_ICON_SET/app_icon_256.png"
sips -z 512 512 "$SOURCE_ICON" --out "$APP_ICON_SET/app_icon_512.png"
sips -z 1024 1024 "$SOURCE_ICON" --out "$APP_ICON_SET/app_icon_1024.png"

echo "Done."
