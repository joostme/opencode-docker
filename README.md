# opencode-docker

Run [OpenCode](https://opencode.ai) and [code-server](https://github.com/coder/code-server) in one Docker container, with a shared filesystem and persistent data.

This setup is meant for people who want a browser-based AI coding agent and VS Code always available on a VPS or home server.

## What you get

- OpenCode web UI and code-server from one container
- Shared `/repos` workspace between both apps
- Persistent OpenCode data, toolchains, and VS Code extensions
- Traefik-ready HTTPS routing for separate subdomains
- SSH key mounting for private Git access
- Preconfigured safeguards that block OpenCode from reading common secret files

## Before you start

You need:

- Docker and Docker Compose
- At least one LLM provider API key such as `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GEMINI_API_KEY`
- A server or machine where the container can keep running
- Traefik with a `proxy` network if you want the included domain-based routing

## Quick start

```bash
git clone <your-repo-url> opencode-docker
cd opencode-docker
cp .env.example .env
mkdir -p repos data skills
docker compose up -d
```

Then edit `.env` and set at least:

- `OPENCODE_SERVER_PASSWORD`
- `ANTHROPIC_API_KEY` or another supported provider key
- `OPENCODE_DOMAIN` and `CODE_SERVER_DOMAIN` if you are using Traefik
- `SSH_KEY_PATH` if your SSH keys are not in `~/.ssh`

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

See `.env.example` for the full list.

## Persistent data

- `./repos` -> your repositories
- `./data` -> OpenCode conversations and app data
- `./skills` -> OpenCode skills
- `mise-data` -> installed toolchains
- `code-server-data` -> VS Code extensions and settings

## Security notes

- This setup is intended for personal use, not multi-tenant hosting
- OpenCode is configured to deny reads for files such as `.env`, SSH keys, `*.pem`, and `*.key`
- SSH keys are mounted read-only and copied into the container at startup with the correct permissions
- If both `OPENCODE_SERVER_PASSWORD` and `CODE_SERVER_PASSWORD` are empty, code-server can run without auth

## Without Traefik

If you do not use Traefik, remove the `labels` and `networks` sections from `docker-compose.yml` and access the mapped ports directly:

```yaml
ports:
  - "4096:4096"
  - "8080:8080"
```

## Troubleshooting

- Permission errors on mounted folders: set `PUID` and `PGID` to match your host user
- SSH access not working: verify `SSH_KEY_PATH` and confirm the files are readable by that user
- code-server auth issue: set `OPENCODE_SERVER_PASSWORD` even if you leave `CODE_SERVER_PASSWORD` empty
- Toolchains reinstalling or changing: check `config/mise.toml` and restart the container
