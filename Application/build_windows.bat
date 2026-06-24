@echo off
REM =============================================================================
REM LocalKey Windows Build Script
REM Produces: dist\LocalKey-windows-x64.zip
REM Run from within the Application\ directory with Python in PATH
REM =============================================================================

echo ==============================
echo  LocalKey Windows Build Script
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
pyinstaller localkey.spec --clean --noconfirm

echo [3/5] PyInstaller build complete.

REM --- 4. Copy native host alongside GUI ---
echo [4/5] Packaging native host... (handled by PyInstaller spec file)

REM --- 5. Create ZIP archive ---
echo [5/5] Creating ZIP archive...
set VERSION=1.0.0
if defined LOCALKEY_VERSION set VERSION=%LOCALKEY_VERSION%

powershell -Command "Compress-Archive -Path 'dist\LocalKey\*' -DestinationPath 'LocalKey-%VERSION%-windows-x64.zip' -Force"

echo.
echo ==============================
echo  Build complete!
echo  Output: LocalKey-%VERSION%-windows-x64.zip
echo ==============================
echo.
echo To run: Unzip and double-click LocalKey.exe
