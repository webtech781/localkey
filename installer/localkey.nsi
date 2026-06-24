; =============================================================================
; LocalKey NSIS Installer Script
; Produces: LocalKey-Setup-{VERSION}-windows.exe
; Requires: NSIS 3.x + NsExec / INetC plugins
;
; WHAT THIS INSTALLER DOES:
;   1. Checks if Python 3.10+ is installed (downloads & installs if missing)
;   2. Downloads the LocalKey source from GitHub to C:\LocalKey (or chosen dir)
;   3. Runs build_windows.bat silently in the background (builds the .exe)
;   4. Creates Start Menu shortcut (always)
;   5. Creates Desktop shortcut (optional — user checkbox)
; =============================================================================

!define APP_NAME        "LocalKey"
!define APP_VERSION     "$%LOCALKEY_VERSION%"
!define APP_PUBLISHER   "webtech781"
!define APP_URL         "https://github.com/webtech781/localkey"
!define GITHUB_ZIP_URL  "https://github.com/webtech781/localkey/archive/refs/heads/main.zip"
!define APP_EXE         "LocalKey.exe"
!define DEFAULT_DIR     "C:\LocalKey"
!define PYTHON_URL      "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
!define REG_ROOT        "HKCU"
!define REG_KEY         "Software\LocalKey"

; ── Plugins ──────────────────────────────────────────────────────────────────
; INetC is needed for in-installer downloads. The CI step installs it via:
;   choco install nsis-inetc  -or-  copy INetC.dll to NSIS\Plugins\x86-unicode\
; NsExec is built into NSIS 3.x.
; ─────────────────────────────────────────────────────────────────────────────

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "..\LocalKey-Setup-${APP_VERSION}-windows.exe"
InstallDir "${DEFAULT_DIR}"
InstallDirRegKey ${REG_ROOT} "${REG_KEY}" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

; ── Custom property for Desktop Shortcut ─────────────────────────────────────
Var DesktopShortcut   ; 1 = create, 0 = skip

; ── MUI Configuration ────────────────────────────────────────────────────────
!define MUI_ABORTWARNING
!define MUI_ICON                    "..\Application\localkey.ico"
!define MUI_UNICON                  "..\Application\localkey.ico"
!define MUI_WELCOMEPAGE_TITLE       "Welcome to LocalKey Setup"
!define MUI_WELCOMEPAGE_TEXT        "LocalKey is an offline password manager and passkey authenticator.$\n$\nThis installer will:$\n  • Download LocalKey source from GitHub$\n  • Build the application on your computer$\n  • Create Start Menu (and optionally Desktop) shortcuts$\n$\nClick Next to continue."
!define MUI_FINISHPAGE_RUN          "$INSTDIR\dist\LocalKey\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT     "Launch LocalKey now"
!define MUI_FINISHPAGE_LINK         "Visit LocalKey on GitHub"
!define MUI_FINISHPAGE_LINK_LOCATION "${APP_URL}"
!define MUI_COMPONENTSPAGE_SMALLDESC

; ── Pages ─────────────────────────────────────────────────────────────────────
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE       "..\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
Page custom DesktopShortcutPage DesktopShortcutPageLeave   ; custom checkbox page
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; =============================================================================
; Custom page: Desktop Shortcut checkbox
; =============================================================================
!define MUI_BGCOLOR "FFFFFF"

Function DesktopShortcutPage
    !insertmacro MUI_HEADER_TEXT "Additional Options" "Choose optional components."

    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
        Abort
    ${EndIf}

    ; Checkbox label
    ${NSD_CreateCheckbox} 10u 30u 280u 14u "&Create Desktop Shortcut"
    Pop $1
    ; Default: checked
    ${NSD_SetState} $1 ${BST_CHECKED}
    GetFunctionAddress $2 OnDesktopCheckbox
    nsDialogs::OnClick $1 $2

    nsDialogs::Show
FunctionEnd

Function OnDesktopCheckbox
    Pop $0
    ${NSD_GetState} $0 $DesktopShortcut
FunctionEnd

Function DesktopShortcutPageLeave
    ; If DesktopShortcut is still unset, default to checked
    ${If} $DesktopShortcut == ""
        StrCpy $DesktopShortcut ${BST_CHECKED}
    ${EndIf}
FunctionEnd

; =============================================================================
; Helper: Check if Python 3.10+ is available in PATH
; =============================================================================
Function CheckPython
    ; Try to run python --version, capture to temp file
    nsExec::ExecToStack 'cmd.exe /C python --version 2>&1'
    Pop $0   ; exit code
    Pop $1   ; stdout text
    ; If exit code != 0, Python not found
    ${If} $0 != 0
        Call InstallPython
    ${EndIf}
FunctionEnd

Function InstallPython
    DetailPrint "Python not found. Downloading Python 3.11..."
    inetc::get "${PYTHON_URL}" "$TEMP\python_installer.exe" /END
    Pop $0
    ${If} $0 != "OK"
        MessageBox MB_ICONSTOP "Failed to download Python installer. Please install Python 3.11+ manually from python.org, then re-run this installer."
        Abort
    ${EndIf}
    DetailPrint "Installing Python 3.11 (silent)..."
    ; /quiet InstallAllUsers=1 PrependPath=1 are standard Python installer switches
    nsExec::ExecToLog '"$TEMP\python_installer.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Python installation failed (code $0). Please install Python 3.11+ manually, then re-run this installer."
        Abort
    ${EndIf}
    DetailPrint "Python installed successfully."
    Delete "$TEMP\python_installer.exe"
FunctionEnd

; =============================================================================
; Helper: Download & extract LocalKey source from GitHub
; =============================================================================
Function DownloadSource
    DetailPrint "Downloading LocalKey source from GitHub..."
    inetc::get /CAPTION "Downloading LocalKey" /BANNER "Please wait while we download LocalKey from GitHub..." \
        "${GITHUB_ZIP_URL}" "$TEMP\localkey-source.zip" /END
    Pop $0
    ${If} $0 != "OK"
        MessageBox MB_ICONSTOP "Download failed: $0$\n$\nCheck your internet connection and try again."
        Abort
    ${EndIf}
    DetailPrint "Download complete. Extracting..."
FunctionEnd

Function ExtractSource
    ; Use PowerShell to expand the ZIP into $INSTDIR
    DetailPrint "Extracting LocalKey source to $INSTDIR..."
    nsExec::ExecToLog 'powershell.exe -NoProfile -NonInteractive -Command \
        "Expand-Archive -Path \"$TEMP\localkey-source.zip\" -DestinationPath \"$TEMP\localkey-extract\" -Force"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Extraction failed. Please try again."
        Abort
    ${EndIf}

    ; Move the inner folder (localkey-main) content to INSTDIR
    ; GitHub ZIP always produces: localkey-main\ (or localkey-<branch>\)
    nsExec::ExecToLog 'powershell.exe -NoProfile -NonInteractive -Command \
        "$src = (Get-ChildItem \"$TEMP\localkey-extract\" | Select-Object -First 1).FullName; \
         if (Test-Path \"$INSTDIR\") { Remove-Item \"$INSTDIR\" -Recurse -Force }; \
         Move-Item -Path $src -Destination \"$INSTDIR\" -Force"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Failed to place LocalKey files into $INSTDIR. Try running as Administrator."
        Abort
    ${EndIf}

    Delete "$TEMP\localkey-source.zip"
    RMDir /r "$TEMP\localkey-extract"
    DetailPrint "Source extracted to $INSTDIR"
FunctionEnd

; =============================================================================
; Helper: Run build_windows.bat
; =============================================================================
Function BuildLocalKey
    DetailPrint "Building LocalKey (this may take 3-5 minutes)..."
    DetailPrint "Running build_windows.bat in $INSTDIR\Application..."

    ; Run synchronously so installer waits for completion
    ; /V1 gives us live output in the detail pane via nsExec::ExecToLog
    nsExec::ExecToLog 'cmd.exe /C ""$INSTDIR\Application\build_windows.bat""'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Build failed (code $0).$\n$\nCheck that Python is installed and internet is available, then try again."
        Abort
    ${EndIf}
    DetailPrint "Build completed successfully!"
FunctionEnd

; =============================================================================
; INSTALL SECTION
; =============================================================================
Section "LocalKey (required)" SecMain
    SectionIn RO

    SetOutPath "$INSTDIR"

    ; Step 1 – Verify / install Python
    Call CheckPython

    ; Step 2 – Download source from GitHub
    Call DownloadSource

    ; Step 3 – Extract source
    Call ExtractSource

    ; Step 4 – Build from source
    Call BuildLocalKey

    ; Step 5 – Write install dir to registry
    WriteRegStr ${REG_ROOT} "${REG_KEY}" "InstallDir" "$INSTDIR"

    ; Step 6 – Start Menu shortcut (always created)
    CreateDirectory "$SMPROGRAMS\LocalKey"
    CreateShortcut "$SMPROGRAMS\LocalKey\LocalKey.lnk" \
        "$INSTDIR\Application\dist\${APP_EXE}" "" \
        "$INSTDIR\Application\dist\${APP_EXE}" 0 \
        SW_SHOWNORMAL "" "LocalKey Password Manager"
    CreateShortcut "$SMPROGRAMS\LocalKey\Uninstall LocalKey.lnk" \
        "$INSTDIR\Uninstall.exe" "" "$INSTDIR\Uninstall.exe" 0

    ; Step 7 – Desktop shortcut (optional)
    ${If} $DesktopShortcut == ${BST_CHECKED}
        CreateShortcut "$DESKTOP\LocalKey.lnk" \
            "$INSTDIR\Application\dist\${APP_EXE}" "" \
            "$INSTDIR\Application\dist\${APP_EXE}" 0 \
            SW_SHOWNORMAL "" "LocalKey Password Manager"
    ${EndIf}

    ; Step 8 – Write uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Step 9 – Register in Add/Remove Programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "DisplayName"     "${APP_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "DisplayIcon"     "$INSTDIR\Application\dist\${APP_EXE}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "Publisher"       "${APP_PUBLISHER}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "URLInfoAbout"    "${APP_URL}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "DisplayVersion"  "${APP_VERSION}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey" \
        "NoRepair"  1

SectionEnd

; =============================================================================
; UNINSTALL SECTION
; =============================================================================
Section "Uninstall"
    ; Remove shortcuts
    Delete "$SMPROGRAMS\LocalKey\LocalKey.lnk"
    Delete "$SMPROGRAMS\LocalKey\Uninstall LocalKey.lnk"
    RMDir  "$SMPROGRAMS\LocalKey"
    Delete "$DESKTOP\LocalKey.lnk"

    ; Remove installed folder
    RMDir /r "$INSTDIR"

    ; Clean registry
    DeleteRegKey ${REG_ROOT} "${REG_KEY}"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalKey"
SectionEnd
