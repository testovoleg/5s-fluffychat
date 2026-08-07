# SPDX-FileCopyrightText: 2019-Present Christian Kußowski
# SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Cirrus images lag patch versions; .tool_versions.yaml may be newer (e.g. 3.44.8).
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS builder

RUN sudo apt-get update \
  && sudo apt-get install -y --no-install-recommends curl wget jq build-essential \
  && sudo rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN wget -q https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64.tar.gz \
  && tar -xzf ./yq_linux_amd64.tar.gz \
  && sudo mv yq_linux_amd64 /usr/bin/yq \
  && rm -f ./yq_linux_amd64.tar.gz

COPY . /app
WORKDIR /app

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
RUN ./scripts/prepare-web.sh
RUN flutter pub get

# Optional: --build-arg BASE_HREF=/chat/ for subpath Ingress deployments
ARG BASE_HREF=/
RUN flutter build web \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/ \
  --release \
  --source-maps \
  --pwa-strategy=offline-first \
  --base-href="${BASE_HREF}"

# Serve runtime config next to the web assets when present in the build context
RUN if [ -f /app/config.json ]; then cp /app/config.json /app/build/web/config.json; fi

FROM docker.io/nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/build/web /app

EXPOSE 80
STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
