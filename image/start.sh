#!/bin/bash
# Starts the virtual desktop and serves it through noVNC on :8080. The Wine
# prefix is created on first start; MATLAB is installed in the background.
set -euo pipefail

mkdir -p "$HOME" /tmp/.X11-unix
export XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

Xvfb :0 -screen 0 "${SCREEN:-1600x900x24}" -nolisten tcp &
for _ in $(seq 1 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
openbox &

# The VNC server is local only; websockify is the one exposed port. Password
# protection of the page is the platform's job (ingress), not VNC's.
x11vnc -display :0 -forever -shared -nopw -localhost -rfbport 5900 -quiet &

if [ ! -f "$WINEPREFIX/system.reg" ]; then
  wineboot --init || true
fi

# Install MATLAB once; /tmp/matlab-install.log shows progress in the desktop terminal.
if [ ! -f "$HOME/.matlab-installed" ] && [ "${SKIP_MATLAB_INSTALL:-0}" != "1" ]; then
  (install-matlab.sh >"$HOME/matlab-install.log" 2>&1 && touch "$HOME/.matlab-installed") &
  xterm -geometry 120x30+20+20 -e "tail -f $HOME/matlab-install.log" &
fi

# Listen on all families: the cluster is IPv6-primary.
exec websockify --web /usr/share/novnc "[::]:8080" localhost:5900
