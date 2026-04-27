#!/usr/bin/env bash
# Builds Claude Chime as a self-contained .app bundle.
set -euo pipefail

APP_NAME="ClaudeChime"
APP_BUNDLE="${APP_NAME}.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect host arch and build a universal binary if both toolchains are available.
ARCH_FLAGS=("--arch" "arm64" "--arch" "x86_64")

echo "==> Compiling (release, universal)"
if ! swift build -c release "${ARCH_FLAGS[@]}" 2>/dev/null; then
    echo "    universal build unavailable, falling back to host arch"
    swift build -c release
    BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
else
    BIN_PATH=".build/apple/Products/Release/${APP_NAME}"
fi

if [[ ! -f "$BIN_PATH" ]]; then
    echo "error: built binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "$BIN_PATH" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# Optional icon — drop AppIcon.icns next to this script and it will be bundled.
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true
fi

# Ad-hoc sign so Gatekeeper doesn't immediately quarantine the unsigned binary
# on first launch. Users can still need to right-click → Open the first time.
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo
echo "✓ Built ${APP_BUNDLE}"
echo
echo "Run it:"
echo "    open ${APP_BUNDLE}"
echo
echo "Install to /Applications:"
echo "    mv ${APP_BUNDLE} /Applications/"
echo "    open /Applications/${APP_BUNDLE}"
