#!/bin/bash
# Starts the virtual desktop and serves it through noVNC on :8080. The Wine
# prefix is created on first start; MATLAB is installed in the background.
set -euo pipefail

# The volume mount itself belongs to root (only its group is ours) and Wine
# refuses such a HOME, so work in a directory below it that we own.
mkdir -p /home/wine/user
export HOME=/home/wine/user WINEPREFIX=/home/wine/user/prefix
mkdir -p /tmp/.X11-unix
export XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

Xvfb :0 -screen 0 "${SCREEN:-1600x900x24}" -nolisten tcp &
for _ in $(seq 1 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
# Right-click on the desktop opens this menu (MATLAB, Windows tools).
mkdir -p "$HOME/.config/openbox"
cat >"$HOME/.config/openbox/menu.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Windows">
    <item label="MATLAB"><action name="Execute"><command>wine C:\\MATLAB\\bin\\matlab.exe -desktop</command></action></item>
    <item label="Install log"><action name="Execute"><command>xterm -e "tail -f $HOME/matlab-install.log"</command></action></item>
    <item label="Windows Explorer"><action name="Execute"><command>wine explorer</command></action></item>
    <item label="Windows Command Prompt"><action name="Execute"><command>wine cmd</command></action></item>
  </menu>
</openbox_menu>
XML
openbox &

# The VNC server is local only; websockify is the one exposed port. Password
# protection of the page is the platform's job (ingress), not VNC's.
# The password is the app's generated one (env VNC_PASSWORD); VNC uses its first 8 characters.
if [ -n "${VNC_PASSWORD:-}" ]; then
  x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpass >/dev/null 2>&1
  VNC_AUTH=(-rfbauth /tmp/vncpass)
else
  VNC_AUTH=(-nopw)
fi
x11vnc -display :0 -forever -shared "${VNC_AUTH[@]}" -localhost -rfbport 5900 -quiet &

# Everything Wine-related runs in the background so the web page is up at once.
(
  [ -f "$WINEPREFIX/system.reg" ] || wineboot --init || true
  wineserver -w || true
  if [ ! -f "$HOME/.matlab-installed" ] && [ "${SKIP_MATLAB_INSTALL:-0}" != "1" ]; then
    xterm -geometry 120x30+20+20 -e "tail -F $HOME/matlab-install.log" &
    if install-matlab.sh >"$HOME/matlab-install.log" 2>&1; then
      touch "$HOME/.matlab-installed"
      wine 'C:\MATLAB\bin\matlab.exe' -desktop
    fi
  elif [ -f "$HOME/.matlab-installed" ]; then
    wine 'C:\MATLAB\bin\matlab.exe' -desktop
  fi
) &

# The root filesystem is read-only: serve noVNC from /tmp with an index that connects at once.
mkdir -p /tmp/web
cp -rs /usr/share/novnc/. /tmp/web/ 2>/dev/null || true
printf '%s\n' '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=scale">' >/tmp/web/index.html

# Listen on all families: the cluster is IPv6-primary.
exec websockify --web /tmp/web "[::]:8080" localhost:5900
