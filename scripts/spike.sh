#!/bin/bash
# PoC: does a Windows desktop on Wine run in the platform's security context,
# and does the Windows build of MATLAB install and start on it? Results go to
# $GITHUB_STEP_SUMMARY (or stdout). Takes the image reference as $1.
set -uo pipefail

IMAGE="${1:?image reference}"
OUT="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
VOL="$(mktemp -d)"
chmod 0777 "$VOL"

report() { echo "$1" >>"$OUT"; }
step() { echo "::group::$1"; }
endstep() { echo "::endgroup::"; }

# Same context the platform sets: UID 1000, read-only root, no capabilities.
docker run -d --name wm --user 1000:1000 --read-only --cap-drop ALL \
  --security-opt no-new-privileges --network host \
  --tmpfs /tmp:exec --tmpfs /run --mount type=bind,src="$VOL",dst=/home/wine \
  -e SKIP_MATLAB_INSTALL=1 "$IMAGE" >/dev/null

report "## Wine / MATLAB spike"

step "noVNC reachable"
ok=0
for _ in $(seq 1 60); do
  curl -fs -o /dev/null http://127.0.0.1:8080/vnc.html && ok=1 && break
  sleep 2
done
report "- noVNC on :8080 under platform security context: $([ $ok = 1 ] && echo OK || echo FAIL)"
endstep

step "wine prefix"
for _ in $(seq 1 60); do docker exec wm test -f /home/wine/prefix/system.reg && break; sleep 2; done
ver="$(docker exec wm wine cmd /c ver 2>&1 | tr -d '\r' | tail -1)"
report "- Windows version reported by Wine: \`${ver:-none}\`"
endstep

step "mpm install MATLAB"
start=$(date +%s)
docker exec -e MATLAB_PRODUCTS=MATLAB wm install-matlab.sh >"$VOL/install.log" 2>&1
rc=$?
report "- MATLAB install via mpm.exe: exit $rc after $(( $(date +%s) - start )) s"
report '```'; tail -15 "$VOL/install.log" >>"$OUT"; report '```'
endstep

if [ "$rc" = 0 ]; then
  step "start MATLAB"
  docker exec wm timeout 300 wine 'C:\MATLAB\bin\matlab.exe' -batch "disp(version)" >"$VOL/run.log" 2>&1
  report "- \`matlab -batch\` exit $? (licence error expected without activation)"
  report '```'; tail -15 "$VOL/run.log" >>"$OUT"; report '```'
  endstep
  step "screenshot of the desktop"
  docker exec wm bash -c 'import -window root /tmp/shot.png' && docker cp wm:/tmp/shot.png "$VOL/shot.png" || true
  endstep
fi

docker logs wm >"$VOL/container.log" 2>&1 || true
mkdir -p spike-out && cp -r "$VOL"/*.log "$VOL"/*.png spike-out/ 2>/dev/null || true
docker rm -f wm >/dev/null
