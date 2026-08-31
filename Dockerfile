# renovate: datasource=github-releases depName=anomalyco/opencode
ARG OPENCODE_VERSION=1.18.25

FROM debian:bookworm-slim

ARG OPENCODE_VERSION

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
# 3. GitHub CLI (own layer — version changes independently)
# ---------------------------------------------------------------------------
# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=2.98.0
RUN ARCH=$(dpkg --print-architecture) && \
    URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" && \
    echo "Downloading GitHub CLI v${GH_VERSION} from ${URL}" && \
    curl -fsSL -o /tmp/gh.deb "${URL}" && \
    dpkg -i /tmp/gh.deb && \
    rm /tmp/gh.deb && \
    gh --version

# ---------------------------------------------------------------------------
# 4. code-server (own layer — version changes independently)
# ---------------------------------------------------------------------------
# renovate: datasource=github-releases depName=coder/code-server
ARG CODE_SERVER_VERSION=4.135.0
RUN ARCH=$(dpkg --print-architecture) && \
    URL="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_${ARCH}.deb" && \
    echo "Downloading code-server v${CODE_SERVER_VERSION} from ${URL}" && \
    curl -fsSL -o /tmp/code-server.deb "${URL}" && \
    dpkg -i /tmp/code-server.deb && \
    rm /tmp/code-server.deb && \
    code-server --version

# ---------------------------------------------------------------------------
# 5. opencode (precompiled upstream release binary)
# ---------------------------------------------------------------------------
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x64") && \
    URL="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${ARCH}.tar.gz" && \
    echo "Downloading OpenCode v${OPENCODE_VERSION} from ${URL}" && \
    curl -fsSL -o /tmp/opencode.tar.gz "${URL}" && \
    tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin opencode && \
    rm /tmp/opencode.tar.gz && \
    chmod +x /usr/local/bin/opencode && opencode --version

# ---------------------------------------------------------------------------
# 6. Environment defaults (directories are created by entrypoint.sh)
# ---------------------------------------------------------------------------
ENV PUID=1000 \
    PGID=1000 \
    OPENCODE_PORT=4096 \
    CODE_SERVER_PORT=8080

# ---------------------------------------------------------------------------
# 7. Entrypoint (changes most often during development)
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ---------------------------------------------------------------------------
# 8. Metadata
# ---------------------------------------------------------------------------
EXPOSE 22 4096 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD if [ -n "${OPENCODE_SERVER_PASSWORD}" ]; then \
            curl -sf -u "${OPENCODE_SERVER_USERNAME:-opencode}:${OPENCODE_SERVER_PASSWORD}" \
                http://localhost:${OPENCODE_PORT:-4096}/health; \
        else \
            curl -sf http://localhost:${OPENCODE_PORT:-4096}/health; \
        fi || exit 1

WORKDIR /repos

ENTRYPOINT ["/entrypoint.sh"]
