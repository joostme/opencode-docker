# opencode-docker

Docker setup that runs [OpenCode](https://opencode.ai) (AI coding agent with web UI) and [code-server](https://github.com/coder/code-server) (VS Code in the browser) in a single container. Designed for a personal VPS behind Traefik, so you always have an agent and editor running — even when your PC is off.

## Features

- **OpenCode Web** on one subdomain, **VS Code** on another — same container, shared filesystem
- **Traefik integration** with automatic TLS via Let's Encrypt
- **Mise** for dev toolchains (Node.js, Go, Python, Rust) — prebuilt binaries, no compilation
- **Mountable** SSH keys, OpenCode config, skills, and repos
- **Persistent** conversations (SQLite), mise tools, and VS Code extensions across restarts
- **Configurable** PUID/PGID to match host user permissions
- **Security**: OpenCode permission rules deny reading `.env`, `.ssh/*`, `.pem`, `.key` files

## Quick Start

```bash
# 1. Clone the repo
git clone <your-repo-url> opencode-docker
cd opencode-docker

# 2. Create your .env from the template
cp .env.example .env

# 3. Edit .env — at minimum set:
#    - OPENCODE_SERVER_PASSWORD (required)
#    - ANTHROPIC_API_KEY (or another LLM provider key)
#    - OPENCODE_DOMAIN / CODE_SERVER_DOMAIN (your actual domains)
#    - SSH_KEY_PATH (path to your SSH keys on the host)

# 4. Create the required directories
mkdir -p repos data skills

# 5. Build and start
docker compose up -d --build

# 6. Check logs
docker compose logs -f
```

## Architecture

```
┌─────────────────────────────────────────────┐
│  Container: opencode                        │
│                                             │
│  ┌─────────────────┐  ┌──────────────────┐  │
│  │  OpenCode Web   │  │  code-server     │  │
│  │  :4096          │  │  :8080           │  │
│  └────────┬────────┘  └────────┬─────────┘  │
│           │   Shared filesystem │            │
│           ├─── /repos (your code)            │
│           ├─── /home/opencode/.ssh           │
│           ├─── mise shims (node, go, ...)    │
│           └─── git, ripgrep, curl, ...       │
└─────────────────────────────────────────────┘
            │                    │
     Traefik reverse proxy (external)
            │                    │
   opencode.example.com   code.example.com
```

Both processes run as the `opencode` user with the same PATH, tools, and SSH keys. A terminal opened in code-server has the same environment OpenCode uses.

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | Yes | — | Password for OpenCode web UI (HTTP basic auth) |
| `OPENCODE_SERVER_USERNAME` | No | `opencode` | Username for OpenCode web UI |
| `CODE_SERVER_PASSWORD` | No | (falls back to `OPENCODE_SERVER_PASSWORD`) | Separate password for code-server |
| `ANTHROPIC_API_KEY` | — | — | Anthropic API key (or use `OPENAI_API_KEY`, `GEMINI_API_KEY`) |
| `PUID` / `PGID` | No | `1000` | UID/GID for the container user (match your host user with `id`) |
| `OPENCODE_DOMAIN` | No | `opencode.example.com` | Domain for the OpenCode web UI |
| `CODE_SERVER_DOMAIN` | No | `code.example.com` | Domain for code-server |
| `CERT_RESOLVER` | No | `letsencrypt` | Traefik certificate resolver name |
| `SSH_KEY_PATH` | No | `~/.ssh` | Path to SSH keys on the host |

### Volumes

| Host Path | Container Path | Description |
|---|---|---|
| `./repos` | `/repos` | Your code repositories |
| `./data` | `/home/opencode/.local/share/opencode` | OpenCode data (SQLite DB, conversations) |
| `./config/opencode.json` | `/home/opencode/.config/opencode/opencode.json` | OpenCode config (read-only) |
| `./config/mise.toml` | `/home/opencode/.config/mise/config.toml` | Mise tool definitions (read-only) |
| `./skills` | `/home/opencode/.config/opencode/skills` | OpenCode skills directory (read-only) |
| `$SSH_KEY_PATH` | `/home/opencode/.ssh-keys` | SSH keys (mounted read-only, copied at startup) |
| `mise-data` (named) | `/home/opencode/.local/share/mise` | Mise tool cache (persisted) |
| `code-server-data` (named) | `/home/opencode/.local/share/code-server` | VS Code extensions & settings (persisted) |

### Mise Toolchains

Edit `config/mise.toml` to add, remove, or change tool versions:

```toml
[tools]
node = "22"
go = "1.24"
python = "3.13"
rust = "1.85"
```

Changes take effect on container restart. Tools are cached in a named volume so they don't reinstall every time. See [mise docs](https://mise.jdx.dev) for all available tools.

### OpenCode Config

Edit `config/opencode.json` to configure OpenCode behavior, permissions, and MCP servers. The default config includes:

- Permission rules denying reads of sensitive files (`.env`, `.ssh/*`, `.pem`, `.key`)
- `external_directory: deny` to prevent access outside the container
- [Context7](https://context7.com) MCP server for documentation lookups
- Autoupdate disabled (managed by Docker image version instead)

### Security

This is designed for **personal use** on a VPS. The security model relies on:

1. **HTTP basic auth** on OpenCode (built-in `OPENCODE_SERVER_PASSWORD`)
2. **Password auth** on code-server
3. **TLS** via Traefik + Let's Encrypt
4. **OpenCode permission rules** preventing the agent from reading secrets
5. **Read-only mounts** for config files and SSH keys (keys are copied to a writable dir at startup with correct permissions)

No full sandbox/seccomp profiles are configured — if you need multi-tenant isolation, this isn't the right setup.

## Traefik Setup

This assumes you have Traefik already running with:

- An external Docker network named `proxy`
- An HTTPS entrypoint named `websecure`
- A certificate resolver (default: `letsencrypt`)

The compose file creates two Traefik routers — one for each subdomain — both pointing to the same container on different ports.

If you're not using Traefik, remove the `labels` and `networks` sections from `docker-compose.yml` and add port mappings instead:

```yaml
ports:
  - "4096:4096"
  - "8080:8080"
```

## Pinning Versions

Both OpenCode and code-server versions can be pinned at build time:

```bash
docker compose build \
  --build-arg OPENCODE_VERSION=v0.5.0 \
  --build-arg CODE_SERVER_VERSION=v4.110.1
```

By default, both pull the latest release.

## Releases

This repo uses [Changesets](https://github.com/changesets/changesets) for release management.

The intended flow is:

1. Add a changeset for each user-visible change with `npm run changeset`
2. Merge your work into `main`
3. The release workflow opens or updates a release PR with version bumps and changelog updates
4. Review and merge that release PR when you're ready to ship
5. Merging the release PR creates the GitHub Release and publishes the matching Docker image to GHCR

## Troubleshooting

**Mise tools compiling from source?** You're likely on Alpine or a musl-based image. This setup uses `debian:bookworm-slim` specifically to get prebuilt glibc binaries. If you've changed the base image, switch back.

**Permission errors on mounted volumes?** Set `PUID` and `PGID` in `.env` to match your host user. Run `id` on the host to find your UID/GID.

**code-server has no auth?** If both `CODE_SERVER_PASSWORD` and `OPENCODE_SERVER_PASSWORD` are empty, code-server runs with `--auth none`. Always set at least `OPENCODE_SERVER_PASSWORD`.

**SSH keys not working?** Keys are mounted read-only at `/home/opencode/.ssh-keys` and copied to `/home/opencode/.ssh` at startup. Check container logs for permission errors. The host SSH key files need to be readable by the `PUID` user.
