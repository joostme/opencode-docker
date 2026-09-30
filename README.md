# opencode-docker

Run [OpenCode](https://opencode.ai), [code-server](https://github.com/coder/code-server), and a Playwright MCP browser sidecar with a shared filesystem and persistent data.

This setup is meant for people who want a browser-based AI coding agent and VS Code always available on a VPS or home server.

## What you get

- OpenCode web UI served directly by the `opencode` binary and code-server from one container
- Playwright MCP sidecar for browser automation from the agent
- GitHub CLI available in the container for `gh` commands
- Shared `/repos` workspace between both apps
- Persistent OpenCode data, toolchains, and VS Code extensions
- Prewired MCP config for Context7 and Playwright
- Traefik-ready HTTPS routing for separate subdomains
- SSH key mounting for private Git access and inbound SSH login via `authorized_keys`
- Preconfigured safeguards that block OpenCode from reading common secret files

## Before you start

You need:

- Docker and Docker Compose
- At least one LLM provider API key such as `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GEMINI_API_KEY`
- A server or machine where the container can keep running
- Traefik with a `proxy` network if you want the included domain-based routing
- Optional: `GH_TOKEN` or `GITHUB_TOKEN` if you want `gh` pre-authenticated

## Quick start

```bash
git clone <your-repo-url> opencode-docker
cd opencode-docker
cp .env.example .env
mkdir -p repos share agents config/mise config/opencode
docker compose up -d
```

Then edit `.env` and set at least:

- `OPENCODE_SERVER_PASSWORD`
- `ANTHROPIC_API_KEY` or another supported provider key
- `OPENCODE_DOMAIN` and `CODE_SERVER_DOMAIN` if you are using Traefik
- `SSH_KEY_PATH` if your SSH keys are not in `~/.ssh`

The included OpenCode config points to the Playwright MCP sidecar at `http://playwright-mcp:8931/mcp`, so browser automation is available as soon as the stack starts.

After startup:

- OpenCode: `https://<OPENCODE_DOMAIN>`
- code-server: `https://<CODE_SERVER_DOMAIN>`

## Main settings

| Variable | What it does |
|---|---|
| `OPENCODE_SERVER_PASSWORD` | Required password for the OpenCode web UI |
| `OPENCODE_SERVER_USERNAME` | Username for the OpenCode web UI |
| `CODE_SERVER_PASSWORD` | Optional separate password for code-server |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `GEMINI_API_KEY` | LLM provider credentials |
| `PUID` / `PGID` | Match container permissions to your host user |
| `OPENCODE_DOMAIN` | Domain for OpenCode |
| `CODE_SERVER_DOMAIN` | Domain for code-server |
| `CERT_RESOLVER` | Traefik certificate resolver |
| `SSH_KEY_PATH` | Host path to SSH keys; if `authorized_keys` exists there it is used for inbound SSH login |
| `GH_TOKEN` / `GITHUB_TOKEN` | Optional token for GitHub CLI and API access |

See `.env.example` for the full list.

## Persistent data

- `./repos` -> your repositories
- `./config` -> full `~/.config` persistence including OpenCode config, installed skills, and mise config
- `./share` -> full `~/.local/share` persistence including OpenCode data, code-server data, and mise installs
- `./agents` -> compatibility config and skills for tools that use `~/.agents`

GitHub CLI auth also persists under `./config` when you log in with `gh auth login` inside the container.

## Security notes

- This setup is intended for personal use, not multi-tenant hosting
- OpenCode is configured to deny reads for files such as `.env`, SSH keys, `*.pem`, and `*.key`
- SSH keys are mounted read-only and copied into the container at startup with the correct permissions
- If `authorized_keys` exists in the mounted SSH directory, the container uses it for inbound SSH access on port `22`
- SSH password authentication is disabled and root login is disabled
- Playwright MCP runs as a separate internal service and is only exposed on the private Compose network by default
- If both `OPENCODE_SERVER_PASSWORD` and `CODE_SERVER_PASSWORD` are empty, code-server can run without auth

## Browser automation

- The stack includes a `playwright-mcp` service using `mcr.microsoft.com/playwright/mcp`
- OpenCode is preconfigured to connect to it through MCP at `http://playwright-mcp:8931/mcp`
- The container runs headless Chromium with `--no-sandbox`
- If you need a different image tag, set `PLAYWRIGHT_MCP_IMAGE` in `.env`

## Without Traefik

If you do not use Traefik, remove the `labels` and `networks` sections from `docker-compose.yml` and access the mapped ports directly:

```yaml
ports:
  - "4096:4096"
  - "8080:8080"
```

`4096` serves both the OpenCode API and the web UI directly from the `opencode` process.

## Troubleshooting

- Permission errors on mounted folders: set `PUID` and `PGID` to match your host user
- SSH access not working: verify `SSH_KEY_PATH`, confirm an `authorized_keys` file exists there, and make sure the files are readable by that user
- code-server auth issue: set `OPENCODE_SERVER_PASSWORD` even if you leave `CODE_SERVER_PASSWORD` empty
- Browser actions failing unexpectedly: check `docker compose logs playwright-mcp` and confirm the sidecar is healthy
- Toolchains reinstalling or changing: check `config/mise/config.toml` and restart the container
- GitHub CLI not authenticated: set `GH_TOKEN` or `GITHUB_TOKEN`, or run `gh auth login` in the container
- OpenCode page still tries to reach the internet: restart the container so mise upgrades OpenCode to the current release

## Automatic updates on start

The image contains only system packages and mise. OpenCode, GitHub CLI, and code-server are not baked in; mise installs them on container start and keeps them current:

- They are declared as `latest` in the image's system config (`system/mise.toml` -> `/etc/mise/config.toml`)
- Tools in your own `config/mise/config.toml` (Node, Python, ...) are upgraded within their declared version range (e.g. `node = "22"` follows 22.x)
- mise itself is self-updated (at most once per 24h)
- Downloads are cached in `./share`, so restarts without new releases are fast
- The **first start needs network access** and downloads ~300 MB; the container will not start if the initial install fails. Later starts continue with the cached versions if an upgrade fails
- New releases are picked up after mise's 24h release-age delay
- Set `AUTO_UPDATE=false` to skip upgrades and only install missing tools
- Set `GITHUB_TOKEN` to avoid GitHub API rate limits when resolving releases

### Pinning versions or disabling auto-updates

If you do not want the latest releases, pin them in `config/mise/config.toml` (your entry takes precedence over the image default of `latest`):

```toml
[tools]
opencode = "1.18.33"
gh = "2.101.0"
"github:coder/code-server" = "4.139.1"
```

Pinned exact versions are never upgraded. Loose versions like `opencode = "1.18"` follow patch releases only. To stop all upgrades, including mise itself and floating toolchains such as `node = "22"`, set `AUTO_UPDATE=false` in your `.env`. Missing tools are still installed on start.

A plain `docker compose restart opencode` updates everything. You only need to pull a new image for changes to the image itself (system packages, entrypoint).
