#!/bin/sh
set -eu
cd "$(dirname "$0")"
app="build/ScreenFollow.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun clang -mmacosx-version-min=13.0 -fobjc-arc -Os -Wall -Wextra \
    -framework AppKit -framework CoreGraphics ScreenFollow.m -o "$app/Contents/MacOS/ScreenFollow"
cp Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
touch "$app"
printf 'Built %s\n' "$app"
