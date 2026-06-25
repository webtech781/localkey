# -*- mode: python ; coding: utf-8 -*-
# LocalKey PyInstaller Spec File
# Builds a single-file executable distribution on all platforms.
# Run: pyinstaller localkey.spec

import sys
import os

block_cipher = None

# Collect all customtkinter theme/image assets
from PyInstaller.utils.hooks import collect_data_files

customtkinter_datas = collect_data_files('customtkinter')

a = Analysis(
    ['main.py'],
    pathex=['.'],
    binaries=[],
    datas=[
        # Application icons & images
        ('icon16.png',  '.'),
        ('icon32.png',  '.'),
        ('icon48.png',  '.'),
        ('icon128.png', '.'),
        ('icon256.png', '.'),
        ('icon_app.png', '.'),
        ('localkey.ico', '.'),
        # CustomTkinter theme assets
        *customtkinter_datas,
    ],
    hiddenimports=[
        'customtkinter',
        'PIL',
        'PIL.Image',
        'PIL.ImageTk',
        'cryptography',
        'cryptography.fernet',
        'cryptography.hazmat.primitives.kdf.pbkdf2',
        'cryptography.hazmat.primitives.hashes',
        'bcrypt',
        'keyring',
        'keyring.backends',
        'keyring.backends.SecretService',
        'keyring.backends.Windows',
        'keyring.backends.macOS',
        'keyring.backends.fail',
        'fido2',
        'fido2.cose',
        'fido2.webauthn',
        'fido2.cbor',
        'cbor2',
        'dotenv',
        'sqlite3',
        'json',
        'database',
        'crypto_utils',
        'extension_installer',
        'browser_profiles',
        'native_host',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'test_fido', 'test_fido2', 'test_native', 'test_native2', 'test_passkey',
        'matplotlib', 'numpy', 'pandas', 'scipy', 'IPython',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='LocalKey',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,          # No terminal window on Windows/macOS
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    # Windows: embed the icon into the .exe
    icon='localkey.ico' if sys.platform == 'win32' else (
        'icon256.png' if sys.platform != 'darwin' else 'icon256.png'
    ),
)

# macOS: wrap everything in a .app bundle
if sys.platform == 'darwin':
    app = BUNDLE(
        exe,
        name='LocalKey.app',
        icon='icon256.png',
        bundle_identifier='com.localkey.app',
        info_plist={
            'CFBundleName': 'LocalKey',
            'CFBundleDisplayName': 'LocalKey',
            'CFBundleShortVersionString': '1.0.0',
            'CFBundleVersion': '1.0.0',
            'NSHighResolutionCapable': True,
            'NSRequiresAquaSystemAppearance': False,  # Enable dark mode
        },
    )
