# Jean headless server for Railway.
# Upstream: https://github.com/coollabsio/jean (Apache-2.0), release v1.0.16.
# The jean-server binary (web UI embedded) and gh come from the official image,
# pinned by version and digest. They run on a pinned Node.js LTS base because
# Jean installs several agent CLIs with npm and checks for node/npm on start.
FROM ghcr.io/coollabsio/jean-server:v1.0.16@sha256:52df17e2623c14aa075015421efea6ac42f9cb0dcaf5fa5667e722f3199651a3 AS jean

FROM node:24.22.3-bookworm-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git libatomic1 openssh-client procps ripgrep tini util-linux \
 && rm -rf /var/lib/apt/lists/* \
 # Upstream runs as "jean" (UID/GID 1000) with HOME=/home/jean; the node image's
 # UID 1000 user is renamed so file ownership matches upstream volumes.
 && groupmod -n jean node \
 && usermod -l jean -d /home/jean -m node \
 # Keep git inside a 0.5 GB service when cloning or repacking large repositories.
 && git config --system pack.threads 1 \
 && git config --system pack.windowMemory 64m \
 && git config --system pack.deltaCacheSize 32m \
 && git config --system core.packedGitLimit 128m \
 && git config --system core.packedGitWindowSize 32m \
 && git config --system core.bigFileThreshold 16m

# Agent CLIs, pinned. Installed in the image because Jean's in-app installer
# loads the whole ~370 MB Claude Code binary into memory and is OOM-killed on a
# 0.5 GB service. Jean picks these up automatically (CLI source "System PATH").
ARG CLAUDE_CODE_VERSION=2.1.331
ARG CODEX_VERSION=0.172.0
ARG OPENCODE_VERSION=1.19.6
RUN npm install -g --prefix /opt/agents --no-audit --no-fund --loglevel=error \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
      "@openai/codex@${CODEX_VERSION}" \
      "opencode-ai@${OPENCODE_VERSION}" \
 && npm cache clean --force \
 && /opt/agents/bin/claude --version \
 && /opt/agents/bin/codex --version \
 && /opt/agents/bin/opencode --version

COPY --from=jean /usr/local/bin/jean-server /usr/local/bin/jean-server
COPY --from=jean /usr/bin/gh /usr/bin/gh
COPY start.sh /usr/local/bin/jean-railway-start
RUN chmod 0755 /usr/local/bin/jean-railway-start /usr/local/bin/jean-server /usr/bin/gh \
 && jean-server --version

ENV HOME=/home/jean \
    PATH=/home/jean/.local/bin:/opt/agents/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    NPM_CONFIG_PREFIX=/home/jean/.local \
    DISABLE_AUTOUPDATER=1 \
    OPENCODE_DISABLE_AUTOUPDATE=1 \
    OPENCODE_DISABLE_MODELS_FETCH=1 \
    PORT=3456

EXPOSE 3456
# /home/jean must be a Railway volume (projects, worktrees, agent logins, settings).
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/usr/local/bin/jean-railway-start"]
