#!/bin/bash
# Installs the Windows build of MATLAB into the Wine prefix with mpm.exe.
# No licence is needed to install; students activate with their MathWorks
# account (campus licence, Shibboleth) when they first start MATLAB.
set -euxo pipefail

MPM_URL="https://www.mathworks.com/mpm/win64/mpm"
MPM="$HOME/mpm.exe"
VCREDIST="$HOME/vc_redist.x64.exe"

# MathWorks' binaries need the real Microsoft VC++ runtime, not Wine's stub.
if [ ! -f "$HOME/.vcrun-done" ]; then
  [ -f "$VCREDIST" ] || curl -fsSL -o "$VCREDIST" https://aka.ms/vs/17/release/vc_redist.x64.exe
  wine "$VCREDIST" /install /quiet /norestart || true
  wineserver -w || true
  touch "$HOME/.vcrun-done"
fi

[ -f "$MPM" ] || curl -fsSL -o "$MPM" "$MPM_URL"

wine "$MPM" install \
  --release "${MATLAB_RELEASE:-R2024b}" \
  --destination 'C:\MATLAB' \
  --products ${MATLAB_PRODUCTS:-MATLAB}

echo "MATLAB installed in $WINEPREFIX/drive_c/MATLAB"
