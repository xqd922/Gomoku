# Compile in Debian 12 so the AOT executable cannot acquire a newer glibc ABI.
FROM debian:bookworm-slim AS compiler
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL --retry 3 https://storage.googleapis.com/dart-archive/channels/stable/release/3.13.1/sdk/dartsdk-linux-x64-release.zip -o /tmp/dart.zip \
    && curl -fsSL --retry 3 https://storage.googleapis.com/dart-archive/channels/stable/release/3.13.1/sdk/dartsdk-linux-x64-release.zip.sha256sum -o /tmp/dart.sha \
    && echo "$(cut -d ' ' -f 1 /tmp/dart.sha)  /tmp/dart.zip" | sha256sum -c - \
    && unzip -q /tmp/dart.zip -d /opt && rm /tmp/dart.zip /tmp/dart.sha
ENV PATH="/opt/dart-sdk/bin:${PATH}"
ENV PUB_HOSTED_URL=https://pub.dev
WORKDIR /workspace
COPY infra/server.pubspec.lock ./pubspec.lock
COPY infra/server-workspace.yaml ./pubspec.yaml
COPY packages/gomoku_core packages/gomoku_core
COPY packages/gomoku_client packages/gomoku_client
COPY apps/server apps/server
RUN dart pub get --enforce-lockfile
WORKDIR /workspace/apps/server
RUN mkdir /output && dart compile exe bin/main.dart -o /output/gomoku-server
FROM scratch AS artifact
COPY --from=compiler /output/gomoku-server /
