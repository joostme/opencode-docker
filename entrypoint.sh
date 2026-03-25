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
CONFIG_DIR="${HOME_DIR}/.config"
ZSH_CONFIG_DIR="${CONFIG_DIR}/zsh"
OH_MY_ZSH_DIR="${CONFIG_DIR}/oh-my-zsh"
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
        usermod -u "${PUID}" -g "${PGID}" -s /bin/zsh opencode
    else
        useradd ${useradd_args} -u "${PUID}" -g "${PGID}" -d "${HOME_DIR}" -s /bin/zsh opencode
    fi

    if id opencode > /dev/null 2>&1; then
        usermod -s /bin/zsh opencode
    fi
}

chown_tree_if_exists() {
    for path in "$@"; do
        if [ -e "${path}" ]; then
            chown -R "${PUID}:${PGID}" "${path}"
        fi
    done
}

chown_path_if_dir() {
    for path in "$@"; do
        if [ -d "${path}" ]; then
            chown "${PUID}:${PGID}" "${path}"
        fi
    done
}

append_file_block_if_missing() {
    local file="$1"
    local marker="$2"
    local block="$3"

    touch "${file}"

    if ! grep -Fq "${marker}" "${file}"; then
        printf '\n%s\n' "${block}" >> "${file}"
    fi
}

# ---------------------------------------------------------------------------
# File ownership
# ---------------------------------------------------------------------------
fix_ownership() {
    chown "${PUID}:${PGID}" "${HOME_DIR}"
    chown_tree_if_exists \
        "${HOME_DIR}/.bash_profile" \
        "${HOME_DIR}/.bashrc" \
        "${HOME_DIR}/.profile" \
        "${HOME_DIR}/.zshenv" \
        "${HOME_DIR}/.zprofile" \
        "${HOME_DIR}/.zshrc" \
        "${HOME_DIR}/.agents" \
        "${HOME_DIR}/.ssh" \
        "${HOME_DIR}/.local"
    chown_tree_if_exists /repos

    # Own config directories themselves without touching mounted files.
    chown_path_if_dir \
        "${CONFIG_DIR}" \
        "${CONFIG_DIR}/opencode" \
        "${CONFIG_DIR}/mise" \
        "${ZSH_CONFIG_DIR}" \
        "${OH_MY_ZSH_DIR}"
}

# ---------------------------------------------------------------------------
# SSH keys & config
# ---------------------------------------------------------------------------
setup_ssh() {
    mkdir -p "${HOME_DIR}/.ssh"

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
    if ! gosu "${RUN_AS}" git config --global --get-all safe.directory | grep -Fxq '*'; then
        gosu "${RUN_AS}" git config --global --add safe.directory '*'
    fi
}

# ---------------------------------------------------------------------------
# Mise toolchain
# ---------------------------------------------------------------------------
setup_mise() {
    export HOME="${HOME_DIR}"

    # Self-update mise to latest version (skip if updated within the last 24h)
    local stamp="/tmp/.mise-last-update"
    local now
    now=$(date +%s)
    local stale=true

    if [ -f "${stamp}" ]; then
        local last
        last=$(cat "${stamp}" 2>/dev/null || echo 0)
        if [ $((now - last)) -lt 86400 ]; then
            stale=false
        fi
    fi

    # Update the mise binary itself (runs as root because mise lives in /usr/local/bin)
    if [ "${stale}" = true ]; then
        echo "Checking for mise updates..."
        if mise self-update --yes 2>&1; then
            echo "${now}" > "${stamp}"
            echo "mise is up to date: $(mise --version)"
        else
            echo "Warning: mise self-update failed, continuing with installed version."
        fi
    fi

    # Install user-defined toolchains (Node, Python, etc.) from mise config
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
# Shell environment
# ---------------------------------------------------------------------------
setup_shell_env() {
    local marker="# opencode-docker mise setup"
    local zsh_env_marker="# opencode-docker zsh env"
    local zsh_marker="# opencode-docker zsh setup"
    local profile_block
    local bashrc_block
    local bash_profile_block
    local zshenv_block
    local zprofile_block
    local zshrc_block

    mkdir -p "${ZSH_CONFIG_DIR}"

    profile_block=$(cat <<'EOF'
# opencode-docker mise setup
eval "$(mise activate bash --shims)"
EOF
)

    bashrc_block=$(cat <<'EOF'
# opencode-docker mise setup
eval "$(mise activate bash)"
EOF
)

    bash_profile_block=$(cat <<'EOF'
# opencode-docker mise setup
if [ -f "/home/opencode/.profile" ]; then
    . "/home/opencode/.profile"
fi
if [ -f "/home/opencode/.bashrc" ]; then
    . "/home/opencode/.bashrc"
fi
EOF
)

    zshenv_block=$(cat <<'EOF'
# opencode-docker zsh env
export ZDOTDIR="$HOME/.config/zsh"
export ZSH="$HOME/.config/oh-my-zsh"
EOF
)

    zprofile_block=$(cat <<'EOF'
# opencode-docker mise setup
if [ -f "/home/opencode/.profile" ]; then
    . "/home/opencode/.profile"
fi
EOF
)

    zshrc_block=$(cat <<'EOF'
# opencode-docker zsh setup
export ZSH="$HOME/.config/oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
DISABLE_AUTO_UPDATE="true"
source "$ZSH/oh-my-zsh.sh"
eval "$(mise activate zsh)"
EOF
)

    append_file_block_if_missing "${HOME_DIR}/.profile" "${marker}" "${profile_block}"
    append_file_block_if_missing "${HOME_DIR}/.bashrc" "${marker}" "${bashrc_block}"
    append_file_block_if_missing "${HOME_DIR}/.bash_profile" "${marker}" "${bash_profile_block}"
    append_file_block_if_missing "${HOME_DIR}/.zshenv" "${zsh_env_marker}" "${zshenv_block}"
    append_file_block_if_missing "${ZSH_CONFIG_DIR}/.zprofile" "${marker}" "${zprofile_block}"
    append_file_block_if_missing "${ZSH_CONFIG_DIR}/.zshrc" "${zsh_marker}" "${zshrc_block}"
}

# ---------------------------------------------------------------------------
# Oh My Zsh
# ---------------------------------------------------------------------------
setup_oh_my_zsh() {
    mkdir -p "${OH_MY_ZSH_DIR}"

    if [ ! -d "${OH_MY_ZSH_DIR}/.git" ]; then
        echo "Installing Oh My Zsh into ${OH_MY_ZSH_DIR}..."
        rm -rf "${OH_MY_ZSH_DIR}"
        gosu "${RUN_AS}" env \
            HOME="${HOME_DIR}" \
            ZSH="${OH_MY_ZSH_DIR}" \
            CHSH=no \
            RUNZSH=no \
            KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        echo "Oh My Zsh installed."
    fi
}

# ---------------------------------------------------------------------------
# code-server settings
# ---------------------------------------------------------------------------
setup_code_server_settings() {
    local settings_dir="${HOME_DIR}/.local/share/code-server/User"
    local settings_file="${settings_dir}/settings.json"
    local tmp_file

    mkdir -p "${settings_dir}"

    if [ ! -f "${settings_file}" ]; then
        printf '{}\n' > "${settings_file}"
    fi

    tmp_file=$(mktemp)
    jq '
        .["terminal.integrated.profiles.linux"].zsh = {
            "path": "/bin/zsh"
        }
        | .["terminal.integrated.defaultProfile.linux"] = "zsh"
    ' "${settings_file}" > "${tmp_file}"
    mv "${tmp_file}" "${settings_file}"
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
        ZDOTDIR="${ZSH_CONFIG_DIR}" \
        ZSH="${OH_MY_ZSH_DIR}" \
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
    echo "Starting opencode serve on port ${OPENCODE_PORT}..."
    gosu "${RUN_AS}" env \
        HOME="${HOME_DIR}" \
        PATH="${PATH}" \
        SHELL="/bin/zsh" \
        ZDOTDIR="${ZSH_CONFIG_DIR}" \
        ZSH="${OH_MY_ZSH_DIR}" \
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
mkdir -p /repos
setup_ssh
setup_shell_env
setup_code_server_settings
fix_ownership
setup_oh_my_zsh
setup_git
setup_mise

trap cleanup SIGTERM SIGINT

start_code_server
start_opencode

# Wait for either process to exit; if one dies, stop the other
wait -n
echo "A process exited, shutting down..."
cleanup
