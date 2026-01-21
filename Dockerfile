FROM eclipse-temurin:25.0.1_8-jre-jammy

ARG DEBIAN_FRONTEND=noninteractive
ARG HYTALE_DOWNLOADER_ZIP_URL="https://downloader.hytale.com/hytale-downloader.zip"

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip bash tini \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 42420 -s /bin/bash hytale

RUN mkdir -p /opt/hytale/downloader \
  && curl -fsSL "${HYTALE_DOWNLOADER_ZIP_URL}" -o /opt/hytale/downloader/hytale-downloader.zip \
  && unzip -q /opt/hytale/downloader/hytale-downloader.zip -d /opt/hytale/downloader \
  && chmod -R a+rX /opt/hytale/downloader

COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER hytale
WORKDIR /data

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
