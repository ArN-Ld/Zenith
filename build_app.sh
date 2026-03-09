#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────
# build_app.sh — Build self-contained Zenith.app
# ──────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Zenith"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
PYTHON_BUNDLE="$RESOURCES/python"
VPN_TOOLS_SRC="${VPN_TOOLS_SRC:-$HOME/Documents/GitHub/vpn-tools}"

echo "==> Building $APP_NAME.app"

# 1. Swift build
echo "  [1/5] Compiling Swift (release)..."
cd "$SCRIPT_DIR"
swift build -c release -q

# 2. Create .app structure
echo "  [2/5] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES" "$PYTHON_BUNDLE"

# 3. Copy binary
cp .build/release/Zenith "$MACOS_DIR/$APP_NAME"

# 4. Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Zenith</string>
    <key>CFBundleIdentifier</key>
    <string>com.arn-ld.zenith</string>
    <key>CFBundleName</key>
    <string>Zenith</string>
    <key>CFBundleDisplayName</key>
    <string>Zenith</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>Zenith</string>
</dict>
</plist>
EOF

# Copy app icon
if [ -f "$SCRIPT_DIR/Resources/Zenith.icns" ]; then
    cp "$SCRIPT_DIR/Resources/Zenith.icns" "$RESOURCES/Zenith.icns"
fi

# 5. Bundle Python source code
echo "  [3/5] Bundling Python source..."
if [ ! -d "$VPN_TOOLS_SRC/src/vpn_tools" ]; then
    echo "ERROR: vpn-tools source not found at $VPN_TOOLS_SRC"
    echo "Set VPN_TOOLS_SRC=/path/to/vpn-tools and retry."
    exit 1
fi
cp -R "$VPN_TOOLS_SRC/src/vpn_tools" "$PYTHON_BUNDLE/vpn_tools"

# 6. Bundle Python dependencies
echo "  [4/5] Installing Python dependencies..."
PYTHON3="$(command -v python3)"
"$PYTHON3" -m pip install --target "$PYTHON_BUNDLE/vendor" \
    speedtest-cli geopy colorama \
    --quiet --no-cache-dir --disable-pip-version-check 2>/dev/null

# 7. Bundle requirements info
cp "$VPN_TOOLS_SRC/requirements.txt" "$RESOURCES/requirements.txt" 2>/dev/null || true

echo "  [5/5] Done!"
echo ""
echo "  $APP_BUNDLE"
echo "  Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
echo "  Install: cp -R '$APP_BUNDLE' /Applications/"
echo "  Run:     open '/Applications/$APP_NAME.app'"
