#!/bin/sh
# Builds "Tasks.app" into ./build (release build, ad-hoc signed). Requires macOS 26 and Xcode 26 or later.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Tasks.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TasksForMac "$APP/Contents/MacOS/Tasks"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Tasks</string>
  <key>CFBundleDisplayName</key><string>Tasks</string>
  <key>CFBundleIdentifier</key><string>com.example.tasks-for-mac</string>
  <key>CFBundleExecutable</key><string>Tasks</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP — open it with: open $APP"
