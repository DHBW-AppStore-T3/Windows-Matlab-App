#!/bin/bash
# Installs the Windows build of MATLAB into the Wine prefix with mpm.exe.
# No licence is needed to install; students activate with their MathWorks
# account (campus licence, Shibboleth) when they first start MATLAB.
set -euo pipefail

MPM_URL="https://www.mathworks.com/mpm/win64/mpm"
MPM="$HOME/mpm.exe"

[ -f "$MPM" ] || curl -fsSL -o "$MPM" "$MPM_URL"

wine "$MPM" install \
  --release "${MATLAB_RELEASE:-R2024b}" \
  --destination 'C:\MATLAB' \
  --products ${MATLAB_PRODUCTS:-MATLAB}

echo "MATLAB installed in $WINEPREFIX/drive_c/MATLAB"
