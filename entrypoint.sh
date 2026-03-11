#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
PUID=${PUID:-1000}
PGID=${PGID:-1000}
OPENCODE_PORT=${OPENCODE_PORT:-4096}
CODE_SERVER_PORT=${CODE_SERVER_PORT:-8080}
HOME_DIR="/home/opencode"
RUN_AS="${PUID}:${PGID}"

# ---------------------------------------------------------------------------
# User & group setup
# ---------------------------------------------------------------------------
setup_user() {
    local groupadd_args=""
    local useradd_args=""

    if [ "${PGID}" -lt 1000 ]; then
        groupadd_args="--system"
    fi

    if [ "${PUID}" -lt 1000 ]; then
        useradd_args="--system"
    fi

    if getent group "${PGID}" > /dev/null 2>&1; then
        echo "Using existing group with GID ${PGID}"
    elif getent group opencode > /dev/null 2>&1; then
        groupmod -g "${PGID}" opencode
    else
        groupadd ${groupadd_args} -g "${PGID}" opencode
    fi

    if id -u "${PUID}" > /dev/null 2>&1; then
        echo "Using existing user with UID ${PUID}"
    elif id opencode > /dev/null 2>&1; then
        usermod -u "${PUID}" -g "${PGID}" opencode
    else
        useradd ${useradd_args} -u "${PUID}" -g "${PGID}" -d "${HOME_DIR}" -s /bin/bash opencode
    fi
}

# ---------------------------------------------------------------------------
# Directory structure
# ---------------------------------------------------------------------------
create_directories() {
    mkdir -p \
        "${HOME_DIR}/.config/opencode/skills" \
        "${HOME_DIR}/.config/mise" \
        "${HOME_DIR}/.ssh" \
        "${HOME_DIR}/.local/share/opencode" \
        "${HOME_DIR}/.local/share/mise" \
        "${HOME_DIR}/.local/share/code-server" \
        "${HOME_DIR}/.local/state/opencode" \
        "${HOME_DIR}/.local/state/mise" \
        /repos
}

# ---------------------------------------------------------------------------
# File ownership
# ---------------------------------------------------------------------------
fix_ownership() {
    chown "${PUID}:${PGID}" "${HOME_DIR}"
    chown -R "${PUID}:${PGID}" \
        "${HOME_DIR}/.ssh" \
        "${HOME_DIR}/.local"
    chown -R "${PUID}:${PGID}" /repos

    # Config dirs — own the dirs themselves, skip read-only mounted files
    chown "${PUID}:${PGID}" \
        "${HOME_DIR}/.config" \
        "${HOME_DIR}/.config/opencode" \
        "${HOME_DIR}/.config/mise"
}

# ---------------------------------------------------------------------------
# SSH keys & config
# ---------------------------------------------------------------------------
setup_ssh() {
    # Copy keys from read-only mount into writable .ssh directory
    if [ -d "${HOME_DIR}/.ssh-keys" ]; then
        cp -a "${HOME_DIR}/.ssh-keys/." "${HOME_DIR}/.ssh/" 2>/dev/null || true
    fi

    # Write default SSH config (won't overwrite if user mounted one)
    if [ ! -f "${HOME_DIR}/.ssh/config" ]; then
        cat > "${HOME_DIR}/.ssh/config" <<'SSHEOF'
Host github.com
    StrictHostKeyChecking accept-new
    IdentitiesOnly yes

Host *
    StrictHostKeyChecking accept-new
SSHEOF
    fi

    # Fix permissions
    chmod 700 "${HOME_DIR}/.ssh"
    chmod 600 "${HOME_DIR}/.ssh/config"     2>/dev/null || true
    chmod 600 "${HOME_DIR}/.ssh/id_"*       2>/dev/null || true
    chmod 644 "${HOME_DIR}/.ssh/"*.pub      2>/dev/null || true
    chmod 644 "${HOME_DIR}/.ssh/known_hosts" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Git configuration
# ---------------------------------------------------------------------------
setup_git() {
    # Trust all directories (single-purpose container; all code is under /repos)
    gosu "${RUN_AS}" git config --global --add safe.directory '*'
}

# ---------------------------------------------------------------------------
# Mise toolchain
# ---------------------------------------------------------------------------
setup_mise() {
    export HOME="${HOME_DIR}"

    if [ -f "${HOME_DIR}/.config/mise/config.toml" ]; then
        echo "Installing mise tools from config..."
        gosu "${RUN_AS}" mise install --yes 2>&1
        echo "Mise tools installed."
    fi

    # Add mise shims to PATH so opencode's bash tool can find installed runtimes
    MISE_SHIMS="${HOME_DIR}/.local/share/mise/shims"
    export PATH="${MISE_SHIMS}:${PATH}"
}

# ---------------------------------------------------------------------------
# Start code-server
# ---------------------------------------------------------------------------
start_code_server() {
    # Resolve password: reuse OpenCode password if not set separately
    local cs_password="${CODE_SERVER_PASSWORD:-${OPENCODE_SERVER_PASSWORD:-}}"
    local cs_auth="none"
    [ -n "${cs_password}" ] && cs_auth="password"

    echo "Starting code-server on port ${CODE_SERVER_PORT} (auth=${cs_auth})..."
    gosu "${RUN_AS}" env \
        HOME="${HOME_DIR}" \
        PATH="${PATH}" \
        PASSWORD="${cs_password}" \
        code-server \
        --bind-addr "0.0.0.0:${CODE_SERVER_PORT}" \
        --user-data-dir "${HOME_DIR}/.local/share/code-server" \
        --auth "${cs_auth}" \
        --disable-telemetry \
        --disable-update-check \
        /repos &
    CODE_SERVER_PID=$!
}

# ---------------------------------------------------------------------------
# Start opencode
# ---------------------------------------------------------------------------
start_opencode() {
    # Using "serve" instead of "web" to avoid xdg-open browser attempt in a container.
    echo "Starting opencode serve on port ${OPENCODE_PORT}..."
    gosu "${RUN_AS}" env \
        HOME="${HOME_DIR}" \
        PATH="${PATH}" \
        opencode serve \
        --port "${OPENCODE_PORT}" \
        --hostname 0.0.0.0 &
    OPENCODE_PID=$!
}

# ---------------------------------------------------------------------------
# Graceful shutdown
# ---------------------------------------------------------------------------
cleanup() {
    echo "Shutting down..."
    kill "$CODE_SERVER_PID" 2>/dev/null
    kill "$OPENCODE_PID" 2>/dev/null
    wait
}

# ===========================================================================
# Main
# ===========================================================================
echo "Starting opencode-docker"
echo "  PUID=${PUID} PGID=${PGID}"
echo "  OpenCode port=${OPENCODE_PORT}"
echo "  code-server port=${CODE_SERVER_PORT}"

setup_user
create_directories
setup_ssh
fix_ownership
setup_git
setup_mise

trap cleanup SIGTERM SIGINT

start_code_server
start_opencode

# Wait for either process to exit; if one dies, stop the other
wait -n
echo "A process exited, shutting down..."
cleanup
