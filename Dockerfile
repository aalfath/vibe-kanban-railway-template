# Vibe Kanban on Railway: BloopAI/vibe-kanban v0.1.46.1794744340 (local server).
#
# Upstream publishes no container image. Its release ships a prebuilt static
# Linux binary (the one `npx vibe-kanban` downloads), with a SHA-256 in the
# release manifest. This Dockerfile downloads that exact asset and checks the
# hash, so the build is fast and reproducible. Coding agents (Claude Code,
# Codex, Gemini CLI...) are started by Vibe Kanban through `npx`, so the base
# image is the official Node LTS image, pinned by digest.
#
# To update: change VK_TAG and VK_SHA256 (from the release's manifest.json,
# platform linux-x64, binary vibe-kanban) and add a CHANGELOG entry.

FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM node:24.22.3-bookworm-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54 AS download
ARG VK_TAG=v0.1.46.1794744340
ARG VK_SHA256=519823fb29b28290b9d98e41a3c09f649654357a042785951bda62206f1ee5f2
ARG GH_VERSION=2.105.0
ARG GH_SHA256=79e7ab5db738c48777b696e374f8b428f0647debfb424f44d2f426370407fe2f
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /dl
RUN curl -fsSL -o vk.zip "https://github.com/BloopAI/vibe-kanban/releases/download/${VK_TAG}/linux-x64-vibe-kanban.zip" \
    && echo "${VK_SHA256}  vk.zip" | sha256sum -c - \
    && unzip -q vk.zip && install -m 755 vibe-kanban /usr/local/bin/vibe-kanban \
    && curl -fsSL -o gh.tgz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
    && echo "${GH_SHA256}  gh.tgz" | sha256sum -c - \
    && tar -xzf gh.tgz && install -m 755 "gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh

FROM node:24.22.3-bookworm-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54
LABEL org.opencontainers.image.title="Vibe Kanban (Railway template)" \
      org.opencontainers.image.version="0.1.46.1794744340" \
      org.opencontainers.image.source="https://github.com/aalfath/vibe-kanban-railway-template" \
      org.opencontainers.image.licenses="Apache-2.0"
# git + ssh for repos, procps for the agents' process handling.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git openssh-client procps less \
    && rm -rf /var/lib/apt/lists/*
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=download /usr/local/bin/vibe-kanban /usr/local/bin/vibe-kanban
COPY --from=download /usr/local/bin/gh /usr/local/bin/gh
# Lean npx: installs each pinned agent once on the volume and runs it without a
# resident `npm exec` parent (see npx-shim.sh).
# (/usr/local/bin/npx is a symlink to npm's npx-cli.js: remove it first so COPY
# doesn't overwrite npm's own file through the link.)
RUN rm /usr/local/bin/npx
COPY npx-shim.sh /usr/local/bin/npx
RUN chmod 755 /usr/local/bin/npx && npx --version >/dev/null
COPY Caddyfile /etc/vibe-kanban/Caddyfile
COPY start.sh /usr/local/bin/vibe-kanban-start
RUN chmod 755 /usr/local/bin/vibe-kanban-start
ENV PORT=8080
EXPOSE 8080
# Starts as root only to hand the Railway volume to the `node` user, then drops privileges.
ENTRYPOINT ["/usr/local/bin/vibe-kanban-start"]
