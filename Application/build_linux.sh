#!/usr/bin/env bash
# =============================================================================
# VaultMate Linux Build Script
# Produces: dist/VaultMate-linux-x86_64.tar.gz  and  VaultMate.AppImage
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

echo "=============================="
echo " VaultMate Linux Build Script"
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
pyinstaller vaultmate.spec --clean --noconfirm

echo "[3/5] PyInstaller build complete."

# --- 4. Package the native host alongside the GUI ---
echo "[4/5] Packaging native host..."
cp native_host.py dist/VaultMate/
# Create a bundled native_host wrapper that uses the bundled Python
cat > dist/VaultMate/native_host.sh << 'NHEOF'
#!/bin/bash
# VaultMate bundled native host launcher
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f /.flatpak-info ]; then
    exec flatpak-spawn --host "$DIR/native_host.py" "$@"
else
    exec "$DIR/_internal/python3" "$DIR/native_host.py" "$@" 2>/dev/null || \
    exec python3 "$DIR/native_host.py" "$@"
fi
NHEOF
chmod +x dist/VaultMate/native_host.sh

# --- 5. Create tar.gz archive ---
echo "[5/5] Creating archive..."
VERSION="${VAULTMATE_VERSION:-1.0.0}"
ARCH="$(uname -m)"
ARCHIVE="VaultMate-${VERSION}-linux-${ARCH}.tar.gz"

cd dist
tar -czf "../${ARCHIVE}" VaultMate/
cd ..

echo ""
echo "=============================="
echo " Build complete!"
echo " Output: ${ARCHIVE}"
echo "=============================="
echo ""
echo "To install:"
echo "  tar -xzf ${ARCHIVE}"
echo "  cd VaultMate && ./VaultMate"
