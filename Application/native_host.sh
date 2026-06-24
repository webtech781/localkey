#!/bin/bash
# LocalKey Native Host Wrapper - uses venv Python with all required packages
VENV_PYTHON="/home/datapro/.localkey/Application/.venv/bin/python3"
NATIVE_HOST="/home/datapro/.localkey/Application/native_host.py"
if [ -f /.flatpak-info ]; then
    exec flatpak-spawn --host "$VENV_PYTHON" "$NATIVE_HOST" "$@"
else
    exec "$VENV_PYTHON" "$NATIVE_HOST" "$@"
fi
