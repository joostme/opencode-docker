FROM debian:bookworm-slim

# ---------------------------------------------------------------------------
# 1. System packages (rarely changes — cached aggressively)
# ---------------------------------------------------------------------------

# Core runtime tools + CLI utilities commonly used by agents and developers
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    git \
    gosu \
    gzip \
    jq \
    openssh-client \
    openssh-server \
    ripgrep \
    tar \
    unzip \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. mise (changes rarely — only on mise version bumps)
# ---------------------------------------------------------------------------
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# ---------------------------------------------------------------------------
# 3. System mise config: opencode, gh and code-server are installed and
#    kept up to date by mise on container start (nothing is baked in)
# ---------------------------------------------------------------------------
COPY system/mise.toml /etc/mise/config.toml

# ---------------------------------------------------------------------------
# 4. Environment defaults (directories are created by entrypoint.sh)
# ---------------------------------------------------------------------------
ENV PUID=1000 \
    PGID=1000 \
    OPENCODE_PORT=4096 \
    CODE_SERVER_PORT=8080 \
    AUTO_UPDATE=true

# mise shims of the opencode user, so `docker exec -u opencode` finds
# opencode, gh and code-server without a login shell
ENV PATH="/home/opencode/.local/share/mise/shims:${PATH}"

# ---------------------------------------------------------------------------
# 5. Entrypoint (changes most often during development)
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ---------------------------------------------------------------------------
# 6. Metadata
# ---------------------------------------------------------------------------
EXPOSE 22 4096 8080

# OpenCode 2 reports readiness on /api/info (basic auth, user is always
# "opencode"). Its /health only serves the web UI and is always 200, so it is
# asked only when /api/info does not exist (installs pinned to OpenCode 1).
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=3 \
    CMD auth="opencode:${OPENCODE_PASSWORD:-${OPENCODE_SERVER_PASSWORD}}"; \
        url="http://localhost:${OPENCODE_PORT:-4096}"; \
        code=$(curl -s -o /dev/null -w '%{http_code}' -u "${auth}" "${url}/api/info"); \
        [ "${code}" = 200 ] \
            || { [ "${code}" = 404 ] && curl -sf -o /dev/null -u "${auth}" "${url}/health"; } \
            || exit 1

WORKDIR /repos

ENTRYPOINT ["/entrypoint.sh"]
