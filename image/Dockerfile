# Windows desktop (Wine) in the browser for the pod runtime (appstore.yaml).
# Xvfb + openbox + x11vnc + noVNC; Wine prefix and MATLAB live on the storage
# volume. MATLAB itself is NOT part of the image (licence): start.sh installs
# it into the prefix on first start with MathWorks' own mpm.exe.
#
# Wine is built here with one patch (patches/): upstream Wine 11.0 stubs
# GetProcessGroupAffinity, and MathWorks' installer and MATLAB abort when it
# fails ("ddux_loggingapi.dll failed to initialize").

FROM docker.io/library/debian:bookworm-slim AS wine-build
ARG WINE_VERSION=11.0
ARG WINE_SHA256=c07a6857933c1fc60dff5448d79f39c92481c1e9db5aa628db9d0358446e0701
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils patch build-essential flex bison pkg-config perl \
      gcc-mingw-w64-x86-64 gcc-mingw-w64-i686 \
      libx11-dev libxext-dev libxrender-dev libxrandr-dev libxi-dev libxcursor-dev \
      libxinerama-dev libxcomposite-dev libxfixes-dev libxxf86vm-dev \
      libfreetype-dev libfontconfig-dev libgnutls28-dev libgl-dev libglu1-mesa-dev libosmesa6-dev \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN curl -fsSL -o wine.tar.xz "https://dl.winehq.org/wine/source/${WINE_VERSION}/wine-${WINE_VERSION}.tar.xz" \
 && echo "${WINE_SHA256}  wine.tar.xz" | sha256sum -c - \
 && tar -xJf wine.tar.xz && rm wine.tar.xz
COPY patches/ /patches/
RUN for p in /patches/*.patch; do patch -d "wine-${WINE_VERSION}" -p1 < "$p"; done
WORKDIR /build/obj
RUN ../wine-${WINE_VERSION}/configure --prefix=/opt/wine --enable-archs=i386,x86_64 --disable-tests \
 && make -j"$(nproc)" \
 && make install

FROM docker.io/library/debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl winbind cabextract unzip procps \
      libx11-6 libxext6 libxrender1 libxrandr2 libxi6 libxcursor1 libxinerama1 libxcomposite1 \
      libxfixes3 libxxf86vm1 libfreetype6 libfontconfig1 libgnutls30 libgl1 libgl1-mesa-dri libglu1-mesa libosmesa6 \
      xvfb x11vnc openbox novnc websockify x11-utils xdotool imagemagick xterm \
      fonts-liberation fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/*
COPY --from=wine-build /opt/wine /opt/wine

# MATLAB's libmx.dll needs std::get_new_handler, which Wine's builtin msvcp140
# lacks; the Microsoft runtime that install-matlab.sh installs must win (n,b).
# HOME is on the storage volume (mounted by the platform). The platform runs
# the container as UID 1000 with a read-only root filesystem, so everything
# that is written goes to the volume or /tmp.
ENV PATH=/opt/wine/bin:$PATH \
    HOME=/home/wine \
    WINEPREFIX=/home/wine/prefix \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml,winemenubuilder.exe=;msvcp140=n,b;msvcp140_1=n,b;msvcp140_2=n,b;msvcp140_atomic_wait=n,b;msvcp140_codecvt_ids=n,b;vcruntime140=n,b;vcruntime140_1=n,b;concrt140=n,b" \
    DISPLAY=:0 \
    MATLAB_RELEASE=R2024b

COPY start.sh /usr/local/bin/start.sh
COPY install-matlab.sh /usr/local/bin/install-matlab.sh
RUN chmod 0755 /usr/local/bin/start.sh /usr/local/bin/install-matlab.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start.sh"]
