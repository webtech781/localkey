@echo off
REM =============================================================================
REM VaultMate Windows Build Script
REM Produces: dist\VaultMate-windows-x64.zip
REM Run from within the Application\ directory with Python in PATH
REM =============================================================================

echo ==============================
echo  VaultMate Windows Build Script
echo ==============================

cd /d "%~dp0"

REM --- 1. Setup virtual environment ---
if not exist ".venv\" (
    echo [1/5] Creating virtual environment...
    python -m venv .venv
)

call .venv\Scripts\activate.bat
echo [1/5] Virtual environment ready.

REM --- 2. Install dependencies ---
echo [2/5] Installing dependencies...
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
pip install pyinstaller pillow --quiet

REM --- 3. Build with PyInstaller ---
echo [3/5] Building with PyInstaller...
pyinstaller vaultmate.spec --clean --noconfirm

echo [3/5] PyInstaller build complete.

REM --- 4. Copy native host alongside GUI ---
echo [4/5] Packaging native host...
copy native_host.py dist\VaultMate\
copy native_host_windows.bat dist\VaultMate\ 2>nul || echo (no windows batch wrapper found)

REM --- 5. Create ZIP archive ---
echo [5/5] Creating ZIP archive...
set VERSION=1.0.0
if defined VAULTMATE_VERSION set VERSION=%VAULTMATE_VERSION%

powershell -Command "Compress-Archive -Path 'dist\VaultMate\*' -DestinationPath 'VaultMate-%VERSION%-windows-x64.zip' -Force"

echo.
echo ==============================
echo  Build complete!
echo  Output: VaultMate-%VERSION%-windows-x64.zip
echo ==============================
echo.
echo To run: Unzip and double-click VaultMate.exe
