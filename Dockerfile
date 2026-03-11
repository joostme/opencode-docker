FROM debian:bookworm-slim

# ---------------------------------------------------------------------------
# 1. System packages (rarely changes — cached aggressively)
# ---------------------------------------------------------------------------

# Core runtime tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gosu \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# CLI utilities commonly used by agents and developers
RUN apt-get update && apt-get install -y --no-install-recommends \
    gzip \
    jq \
    ripgrep \
    tar \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. mise (changes rarely — only on mise version bumps)
# ---------------------------------------------------------------------------
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# ---------------------------------------------------------------------------
# 3. code-server (own layer — version changes independently)
# ---------------------------------------------------------------------------
ARG CODE_SERVER_VERSION=latest
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "${CODE_SERVER_VERSION}" = "latest" ]; then \
        CS_VERSION=$(curl -fsSL https://api.github.com/repos/coder/code-server/releases/latest \
            | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/'); \
    else \
        CS_VERSION="${CODE_SERVER_VERSION#v}"; \
    fi && \
    URL="https://github.com/coder/code-server/releases/download/v${CS_VERSION}/code-server_${CS_VERSION}_${ARCH}.deb" && \
    echo "Downloading code-server v${CS_VERSION} from ${URL}" && \
    curl -fsSL -o /tmp/code-server.deb "${URL}" && \
    dpkg -i /tmp/code-server.deb && \
    rm /tmp/code-server.deb && \
    code-server --version

# ---------------------------------------------------------------------------
# 4. opencode (own layer — most likely to change across rebuilds)
# ---------------------------------------------------------------------------
ARG OPENCODE_VERSION=latest
RUN ARCH=$(dpkg --print-architecture) && \
    case "${ARCH}" in \
        amd64) OC_ARCH="x64" ;; \
        arm64) OC_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    if [ "${OPENCODE_VERSION}" = "latest" ]; then \
        URL="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-${OC_ARCH}.tar.gz"; \
    else \
        URL="https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}/opencode-linux-${OC_ARCH}.tar.gz"; \
    fi && \
    echo "Downloading opencode from ${URL}" && \
    curl -fsSL "${URL}" | tar xz -C /usr/local/bin opencode && \
    chmod +x /usr/local/bin/opencode && \
    opencode --version

# ---------------------------------------------------------------------------
# 5. Environment defaults (directories are created by entrypoint.sh)
# ---------------------------------------------------------------------------
ENV PUID=1000 \
    PGID=1000 \
    OPENCODE_PORT=4096 \
    CODE_SERVER_PORT=8080

# ---------------------------------------------------------------------------
# 6. Entrypoint (changes most often during development)
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ---------------------------------------------------------------------------
# 7. Metadata
# ---------------------------------------------------------------------------
EXPOSE 4096 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:${OPENCODE_PORT:-4096}/health || exit 1

WORKDIR /repos

ENTRYPOINT ["/entrypoint.sh"]
