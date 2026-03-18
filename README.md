# opencode-docker

Run [OpenCode](https://opencode.ai), [code-server](https://github.com/coder/code-server), and a Playwright MCP browser sidecar with a shared filesystem and persistent data.

This setup is meant for people who want a browser-based AI coding agent and VS Code always available on a VPS or home server.

## What you get

- OpenCode web UI served directly by the bundled `opencode` binary and code-server from one container
- Playwright MCP sidecar for browser automation from the agent
- GitHub CLI available in the container for `gh` commands
- Shared `/repos` workspace between both apps
- Persistent OpenCode data, toolchains, and VS Code extensions
- Prewired MCP config for Context7 and Playwright
- Traefik-ready HTTPS routing for separate subdomains
- SSH key mounting for private Git access
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

The included OpenCode config already points to the Playwright MCP sidecar at `http://playwright-mcp:8931/mcp`, so browser automation is available as soon as the stack starts.

The image now patches and builds OpenCode from source so the `opencode` binary embeds the upstream web UI bundle at compile time. That removes the runtime dependency on `app.opencode.ai` for the main web UI without needing a separate reverse proxy in the container.

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
| `SSH_KEY_PATH` | Host path to SSH keys |
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
- Playwright MCP runs as a separate internal service and is only exposed on the private Compose network by default
- If both `OPENCODE_SERVER_PASSWORD` and `CODE_SERVER_PASSWORD` are empty, code-server can run without auth

## Browser automation

- The stack now includes a `playwright-mcp` service using `mcr.microsoft.com/playwright/mcp`
- OpenCode is preconfigured to connect to it through MCP at `http://playwright-mcp:8931/mcp`
- The current container setup uses headless Chromium with `--no-sandbox`, matching the documented Docker usage for Playwright MCP
- If you need a different image tag, set `PLAYWRIGHT_MCP_IMAGE` in `.env`

## Without Traefik

If you do not use Traefik, remove the `labels` and `networks` sections from `docker-compose.yml` and access the mapped ports directly:

```yaml
ports:
  - "4096:4096"
  - "8080:8080"
```

`4096` serves both the OpenCode API and the locally embedded web UI directly from the `opencode` process.

## Troubleshooting

- Permission errors on mounted folders: set `PUID` and `PGID` to match your host user
- SSH access not working: verify `SSH_KEY_PATH` and confirm the files are readable by that user
- code-server auth issue: set `OPENCODE_SERVER_PASSWORD` even if you leave `CODE_SERVER_PASSWORD` empty
- Browser actions failing unexpectedly: check `docker compose logs playwright-mcp` and confirm the sidecar is healthy
- Toolchains reinstalling or changing: check `config/mise/config.toml` and restart the container
- GitHub CLI not authenticated: set `GH_TOKEN` or `GITHUB_TOKEN`, or run `gh auth login` in the container
- OpenCode page still tries to reach the internet: rebuild the image so the patched OpenCode binary with embedded web assets is actually installed

## Upstream updates

- `Dockerfile` pins `GH_VERSION`, `CODE_SERVER_VERSION`, and `OPENCODE_VERSION`, so image builds stay reproducible instead of silently pulling `latest`
- `renovate.json` teaches Renovate to watch `cli/cli`, `coder/code-server`, and `anomalyco/opencode` releases and open PRs when any pinned version can be bumped
- Enable the Renovate app or runner for this repository to start receiving update PRs automatically
