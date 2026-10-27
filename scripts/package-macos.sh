#!/bin/bash
set -euo pipefail
arch="${1:-arm64}"
case "$arch" in arm64) label=arm64;; x86_64) label=x64;; *) exit 2;; esac
swift build --build-system native -c release --arch "$arch"
bin="$(swift build --build-system native -c release --arch "$arch" --show-bin-path)"
root="release/$label"
app="$root/Vigil Lookout.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Lookout" "$app/Contents/MacOS/Lookout"
cp assets/vigiltech/fonts/*.ttf assets/Lookout.png assets/Lookout.icns "$app/Contents/Resources/"
cp LICENSE NOTICE.md "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Lookout</string><key>CFBundleIdentifier</key><string>com.artemissoftworks.lookout</string><key>CFBundleName</key><string>Vigil Lookout</string><key>CFBundleDisplayName</key><string>Vigil Lookout</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.1.2</string><key>CFBundleVersion</key><string>3</string><key>CFBundleIconFile</key><string>Lookout</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHighResolutionCapable</key><true/><key>NSPrincipalClass</key><string>NSApplication</string><key>NSCameraUsageDescription</key><string>Websites can request your camera for calls or recording. Choose whether to allow each request.</string><key>NSMicrophoneUsageDescription</key><string>Websites can request your microphone for calls or recording. Choose whether to allow each request.</string><key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoadsInWebContent</key><true/></dict><key>NSHumanReadableCopyright</key><string>Copyright © 2026 VigilTech. GPL-3.0-only.</string></dict></plist>
PLIST
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
ln -sfn /Applications "$root/Applications"
mkdir -p artifacts
hdiutil create -volname "Vigil Lookout" -srcfolder "$root" -ov -format UDZO "artifacts/ArtemisLookout-mac-$label.dmg"
hdiutil verify "artifacts/ArtemisLookout-mac-$label.dmg"
mount=$(mktemp -d)
hdiutil attach -readonly -nobrowse -mountpoint "$mount" "artifacts/ArtemisLookout-mac-$label.dmg"
trap 'hdiutil detach "$mount"; rmdir "$mount"' EXIT
codesign --verify --deep --strict --verbose=2 "$mount/Vigil Lookout.app"
shasum -a 256 "artifacts/ArtemisLookout-mac-$label.dmg" > "artifacts/ArtemisLookout-mac-$label.dmg.sha256"
