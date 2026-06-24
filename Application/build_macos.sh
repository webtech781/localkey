#!/usr/bin/env bash
# =============================================================================
# LocalKey macOS Build Script
# Produces: LocalKey-macOS-arm64.dmg  (or x86_64)
# Requires: Xcode Command Line Tools, create-dmg (brew install create-dmg)
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

echo "=============================="
echo " LocalKey macOS Build Script"
echo "=============================="

ARCH="$(uname -m)"   # arm64 or x86_64
VERSION="${LOCALKEY_VERSION:-1.0.0}"

# --- 1. Setup virtual environment ---
if [ ! -d ".venv" ]; then
    echo "[1/6] Creating virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate
echo "[1/6] Virtual environment ready."

# --- 2. Install dependencies ---
echo "[2/6] Installing dependencies..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
pip install pyinstaller pillow --quiet

# --- 3. Build with PyInstaller ---
echo "[3/6] Building with PyInstaller..."
pyinstaller localkey.spec --clean --noconfirm

echo "[3/6] PyInstaller build complete. App bundle: dist/LocalKey.app"

# --- 4. Copy native host into .app ---
echo "[4/6] Packaging native host... (handled by PyInstaller spec file)"

# --- 5. Code sign (optional, for distribution outside MAS) ---
echo "[5/6] Skipping code sign (add APPLE_IDENTITY env var to enable)..."
if [ -n "${APPLE_IDENTITY:-}" ]; then
    codesign --force --deep --sign "$APPLE_IDENTITY" dist/LocalKey.app
    echo "[5/6] Code signed with identity: $APPLE_IDENTITY"
fi

# --- 6. Create DMG ---
echo "[6/6] Creating DMG..."
DMG_NAME="LocalKey-${VERSION}-macOS-${ARCH}.dmg"

if command -v create-dmg &>/dev/null; then
    create-dmg \
      --volname "LocalKey" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "LocalKey.app" 175 190 \
      --hide-extension "LocalKey.app" \
      --app-drop-link 425 190 \
      "$DMG_NAME" \
      "dist/LocalKey.app"
else
    # Fallback: simple hdiutil DMG
    hdiutil create -volname "LocalKey" -srcfolder "dist/LocalKey.app" \
        -ov -format UDZO "$DMG_NAME"
fi

echo ""
echo "=============================="
echo " Build complete!"
echo " Output: ${DMG_NAME}"
echo "=============================="
echo ""
echo "To install: Open ${DMG_NAME} and drag LocalKey.app to Applications."
