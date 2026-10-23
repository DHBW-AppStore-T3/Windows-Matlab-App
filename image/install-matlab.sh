#!/bin/bash
# Installs the Windows build of MATLAB into the Wine prefix with mpm.exe.
# No licence is needed to install; students activate with their MathWorks
# account (campus licence, Shibboleth) when they first start MATLAB.
set -euxo pipefail
export WINEDEBUG=err+all

MPM_URL="https://www.mathworks.com/mpm/win64/mpm"
MPM="$HOME/mpm.exe"

[ -f "$MPM" ] || curl -fsSL -o "$MPM" "$MPM_URL"

# mpm.exe and MATLAB need the real Microsoft VC++ runtime; Wine's builtin one
# is only a partial stub (ddux_loggingapi.dll fails to initialise without it).
[ -f "$HOME/.vcrun-done" ] || { winetricks -q vcrun2019 corefonts && touch "$HOME/.vcrun-done"; }
wineserver -w || true
wine "$MPM" --help 2>&1 | head -20 || true
wine "$MPM" install \
  --release "${MATLAB_RELEASE:-R2024b}" \
  --destination 'C:\MATLAB' \
  --products ${MATLAB_PRODUCTS:-MATLAB}

echo "MATLAB installed in $WINEPREFIX/drive_c/MATLAB"
