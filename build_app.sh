#!/bin/bash

APP_NAME="Winamp"
BUILD_PATH=".build/release/$APP_NAME"

# 1. Compile
swift build -c release

# 2. Setup Bundle Structure
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# 3. Handle Icon (The "Vibecoding" One-Liner)
# This converts your PNG directly to the Apple Icon format inside the bundle
if [ -f "icon.png" ]; then
    sips -s format icns icon.png --out "$APP_NAME.app/Contents/Resources/AppIcon.icns"
    echo "🎨 Icon generated successfully!"
else
    echo "⚠️ icon.png not found in root, skipping icon step."
fi

# 4. Copy Binary
cp "$BUILD_PATH" "$APP_NAME.app/Contents/MacOS/"

# 5. Copy Info.plist
cp Info.plist "$APP_NAME.app/Contents/Info.plist"

# 6. Refresh System Cache (The "Don't Make Me Reboot" step)
# This forces macOS to realize the Icon and Open Recent menu are new
touch "$APP_NAME.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_NAME.app"

echo "✅ $APP_NAME.app built successfully!"