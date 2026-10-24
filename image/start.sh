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

# A restarted container keeps /tmp: drop the lock and socket the killed X
# server left behind, or Xvfb refuses to start and nothing has a display.
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
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

# Tells the platform how far the setup is: one log line the AppStore reads
# (appstore-progress {json}); it shows a second bar with the remaining time.
# mpm prints "Installing... 42%" while it unpacks; before that there is no
# percentage, so the first estimate is SETUP_ESTIMATE_SECONDS.
report_progress() {  # $1: pid of the installer, $2: its log
  local start now pct elapsed eta
  start=$(date +%s)
  while kill -0 "$1" 2>/dev/null; do
    now=$(date +%s)
    elapsed=$((now - start))
    pct=$(tr '\r' '\n' <"$2" 2>/dev/null | grep -o '[0-9]\{1,3\}%' | tail -1 | tr -d '%') || true
    pct=${pct:-0}
    if [ "$pct" -ge 3 ]; then
      eta=$((elapsed * (100 - pct) / pct))
    else
      eta=$((${SETUP_ESTIMATE_SECONDS:-2400} - elapsed))
      [ "$eta" -lt 60 ] && eta=60
    fi
    printf 'appstore-progress {"percent":%s,"step":"%s","etaSeconds":%s}\n' "$pct" "MATLAB wird installiert (nur beim ersten Start)" "$eta"
    sleep 10
  done
}

# MathWorks' secret store (it keeps the sign-in) accepts a folder only when
# just the Windows user, Local System and Administrators have access. Wine turns
# Unix permissions into those entries, so everything the user's profile and
# ProgramData hold must be closed to group and others.
harden_profile() {
  local u
  chmod go-rwx "$WINEPREFIX" "$WINEPREFIX/drive_c" "$WINEPREFIX/drive_c/users" 2>/dev/null || true
  chmod -R go-rwx "$WINEPREFIX/drive_c/users" "$WINEPREFIX/drive_c/ProgramData" 2>/dev/null || true
  for u in "$WINEPREFIX"/drive_c/users/*/AppData/Local/Temp; do
    [ -d "$u" ] || continue
    rm -rf "$u/.mathworks"
    mkdir -m 700 "$u/.mathworks"
  done
}

# Under Wine the embedded browser of MathWorks' sign-in dialog shows typed text
# only after a redraw (wmredraw.exe) and takes none in an empty field (wm-login
# daemon types it into the page). The daemon needs a DevTools port, which
# wmwrap.exe opens for that one dialog by standing in for MATLABWindow.exe. It
# is only needed until the sign-in is saved; afterwards the original runs.
login_helpers() {
  local bin="$WINEPREFIX/drive_c/MATLAB/bin/win64" store
  [ -f "$bin/MATLABWindow.exe" ] || return 0
  store=$(ls "$WINEPREFIX"/drive_c/users/*/AppData/Roaming/MathWorks/credentials/default_store.xml 2>/dev/null | head -1 || true)
  if [ -z "$store" ] || ! grep -q RESTPersonalAccessToken "$store" 2>/dev/null; then
    [ -f "$bin/MATLABWindow-real.exe" ] || mv "$bin/MATLABWindow.exe" "$bin/MATLABWindow-real.exe"
    cp /opt/wine-helpers/wmwrap.exe "$bin/MATLABWindow.exe"
    wm-login daemon >"$HOME/wm-login.log" 2>&1 &
  elif [ -f "$bin/MATLABWindow-real.exe" ]; then
    cp "$bin/MATLABWindow-real.exe" "$bin/MATLABWindow.exe"
  fi
}

start_matlab() {
  harden_profile
  wine /opt/wine-helpers/wmredraw.exe &
  login_helpers
  wine 'C:\MATLAB\bin\matlab.exe' -desktop
}

# Everything Wine-related runs in the background so the web page is up at once.
(
  umask 077
  [ -f "$WINEPREFIX/system.reg" ] || wineboot --init || true
  wineserver -w || true
  if [ ! -f "$HOME/.matlab-installed" ] && [ "${SKIP_MATLAB_INSTALL:-0}" != "1" ]; then
    xterm -geometry 120x30+20+20 -e "tail -F $HOME/matlab-install.log" &
    install-matlab.sh >"$HOME/matlab-install.log" 2>&1 &
    installer=$!
    report_progress "$installer" "$HOME/matlab-install.log" &
    if wait "$installer"; then
      touch "$HOME/.matlab-installed"
      printf 'appstore-progress {"percent":100,"step":"MATLAB ist installiert","etaSeconds":0}\n'
      start_matlab
    fi
  elif [ -f "$HOME/.matlab-installed" ]; then
    start_matlab
  fi
) &

# The root filesystem is read-only: serve noVNC from /tmp with an index that connects at once.
mkdir -p /tmp/web
cp -rs /usr/share/novnc/. /tmp/web/ 2>/dev/null || true
printf '%s\n' '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=scale">' >/tmp/web/index.html

# Listen on all families: the cluster is IPv6-primary.
exec websockify --web /tmp/web "[::]:8080" localhost:5900
