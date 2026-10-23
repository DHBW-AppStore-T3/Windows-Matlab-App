# Windows desktop (Wine) in the browser for the pod runtime (appstore.yaml).
# Xvfb + openbox + x11vnc + noVNC; Wine prefix and MATLAB live on the storage
# volume (HOME). MATLAB itself is NOT part of the image (licence): start.sh
# installs it into the prefix on first start with mpm.exe.
FROM docker.io/library/debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# Debian's Wine 8.0 mishandles the C++ exceptions of MathWorks' installer, so
# use the WineHQ stable branch.
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && mkdir -pm755 /etc/apt/keyrings \
 && curl -fsSL -o /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
 && curl -fsSL -o /etc/apt/sources.list.d/winehq-bookworm.sources https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources \
 && apt-get update \
 && apt-get install -y --no-install-recommends winehq-stable winbind cabextract unzip procps \
      xvfb x11vnc openbox novnc websockify x11-utils xdotool imagemagick xterm \
      fonts-liberation fonts-dejavu-core \
 && wine --version \
 && rm -rf /var/lib/apt/lists/*

# winetricks is in Debian contrib, so take the pinned upstream script.
RUN curl -fsSL -o /usr/local/bin/winetricks \
      https://raw.githubusercontent.com/Winetricks/winetricks/20240105/src/winetricks \
 && chmod 0755 /usr/local/bin/winetricks

# HOME is the storage volume (mounted by the platform). The platform runs the
# container as UID 1000 with a read-only root filesystem, so everything that
# is written goes to HOME or /tmp.
ENV HOME=/home/wine \
    WINEPREFIX=/home/wine/prefix \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml,winemenubuilder.exe=" \
    DISPLAY=:0 \
    MATLAB_RELEASE=R2024b

COPY start.sh /usr/local/bin/start.sh
COPY install-matlab.sh /usr/local/bin/install-matlab.sh
RUN chmod 0755 /usr/local/bin/start.sh /usr/local/bin/install-matlab.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start.sh"]
