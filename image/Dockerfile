# Windows desktop (Wine) in the browser for the pod runtime (appstore.yaml).
# Xvfb + openbox + x11vnc + noVNC; Wine prefix and MATLAB live on the storage
# volume (HOME). MATLAB itself is NOT part of the image (licence): start.sh
# installs it into the prefix on first start with mpm.exe.
FROM docker.io/library/debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      wine wine64 wine32 libwine winbind winetricks cabextract ca-certificates curl procps \
      xvfb x11vnc openbox novnc websockify x11-utils xdotool imagemagick xterm \
      fonts-liberation fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/*

# HOME is the storage volume (mounted by the platform). The platform runs the
# container as UID 1000 with a read-only root filesystem, so everything that
# is written goes to HOME or /tmp.
ENV HOME=/home/wine \
    WINEPREFIX=/home/wine/prefix \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=winemenubuilder.exe=d \
    DISPLAY=:0 \
    MATLAB_RELEASE=R2024b

COPY start.sh /usr/local/bin/start.sh
COPY install-matlab.sh /usr/local/bin/install-matlab.sh
RUN chmod 0755 /usr/local/bin/start.sh /usr/local/bin/install-matlab.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start.sh"]
