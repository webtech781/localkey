#!/usr/bin/env bash
# =============================================================================
# LocalKey Linux Build Script
# Produces: dist/LocalKey-linux-x86_64.tar.gz  and  LocalKey.AppImage
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

echo "=============================="
echo " LocalKey Linux Build Script"
echo "=============================="

# --- 1. Setup virtual environment ---
if [ ! -d ".venv" ]; then
    echo "[1/5] Creating virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate
echo "[1/5] Virtual environment ready."

# --- 2. Install dependencies ---
echo "[2/5] Installing dependencies..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
pip install pyinstaller pillow --quiet

# --- 3. Build with PyInstaller ---
echo "[3/5] Building with PyInstaller..."
pyinstaller localkey.spec --clean --noconfirm

echo "[3/5] PyInstaller build complete."

# --- 4. Package the native host alongside the GUI ---
echo "[4/5] Packaging native host... (handled by PyInstaller spec file)"

# --- 5. Create tar.gz archive ---
echo "[5/5] Creating archive..."
VERSION="${LOCALKEY_VERSION:-1.0.0}"
ARCH="$(uname -m)"
ARCHIVE="LocalKey-${VERSION}-linux-${ARCH}.tar.gz"

cd dist
tar -czf "../${ARCHIVE}" LocalKey/
cd ..

echo ""
echo "=============================="
echo " Build complete!"
echo " Output: ${ARCHIVE}"
echo "=============================="
echo ""
echo "To install:"
echo "  tar -xzf ${ARCHIVE}"
echo "  cd LocalKey && ./LocalKey"
