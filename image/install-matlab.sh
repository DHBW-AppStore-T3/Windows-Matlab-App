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
VCREDIST="$HOME/vc_redist.x64.exe"
if [ ! -f "$HOME/.vcrun-done" ]; then
  [ -f "$VCREDIST" ] || curl -fsSL -o "$VCREDIST" https://aka.ms/vs/17/release/vc_redist.x64.exe
  wine "$VCREDIST" /install /quiet /norestart || true
  wineserver -w || true
  ls -l "$WINEPREFIX/drive_c/windows/system32/"vcruntime140*.dll "$WINEPREFIX/drive_c/windows/system32/"msvcp140*.dll
  touch "$HOME/.vcrun-done"
fi
# Profile paths as the Windows side expects them (a missing one made winetricks see an empty %AppData%).
mkdir -p "$WINEPREFIX/drive_c/users/wine/AppData/Roaming" "$WINEPREFIX/drive_c/users/wine/AppData/Local"
export APPDATA='C:\users\wine\AppData\Roaming' LOCALAPPDATA='C:\users\wine\AppData\Local' USERPROFILE='C:\users\wine'
WINEDEBUG=+loaddll,+seh,err+all wine "$MPM" --help 2>&1 | grep -E "loaddll|seh:|err:" | grep -v "wineboot" | tail -45 || true
wine "$MPM" install \
  --release "${MATLAB_RELEASE:-R2024b}" \
  --destination 'C:\MATLAB' \
  --products ${MATLAB_PRODUCTS:-MATLAB}

echo "MATLAB installed in $WINEPREFIX/drive_c/MATLAB"
