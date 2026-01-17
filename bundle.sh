#!/bin/bash
APP_NAME="Hikari"
OUTPUT_DIR=".build/debug"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"
cp "$OUTPUT_DIR/Hikari" "$APP_NAME.app/Contents/MacOS/$APP_NAME"
chmod +x "$APP_NAME.app/Contents/MacOS/$APP_NAME"

# Icon Generation
if [ -f "icon.png" ]; then
    echo "Generating App Icon..."
    # Convert JPEG to true PNG first
    sips -s format png icon.png --out source.png > /dev/null
    
    ICONSET="AppIcon.iconset"
    mkdir -p "$ICONSET"
    sips -z 16 16     source.png --out "$ICONSET/icon_16x16.png" > /dev/null
    sips -z 32 32     source.png --out "$ICONSET/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     source.png --out "$ICONSET/icon_32x32.png" > /dev/null
    sips -z 64 64     source.png --out "$ICONSET/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   source.png --out "$ICONSET/icon_128x128.png" > /dev/null
    sips -z 256 256   source.png --out "$ICONSET/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   source.png --out "$ICONSET/icon_256x256.png" > /dev/null
    sips -z 512 512   source.png --out "$ICONSET/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   source.png --out "$ICONSET/icon_512x512.png" > /dev/null
    sips -z 1024 1024 source.png --out "$ICONSET/icon_512x512@2x.png" > /dev/null
    
    iconutil -c icns "$ICONSET"
    mkdir -p "$APP_NAME.app/Contents/Resources"
    cp AppIcon.icns "$APP_NAME.app/Contents/Resources/"
    rm -rf "$ICONSET"
    rm AppIcon.icns
    rm source.png
fi

cat > "$APP_NAME.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.hikari.Hikari</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "App bundled at $APP_NAME.app"

# Force Finder to refresh the icon
touch "$APP_NAME.app"
mv "$APP_NAME.app" "${APP_NAME}_Temp.app" && mv "${APP_NAME}_Temp.app" "$APP_NAME.app"
