---
"opencode-docker": minor
---

Support OpenCode 2. Since mise 2026.10.9, `opencode = "latest"` installs OpenCode 2 from npm (`@opencode/cli`) instead of OpenCode 1 from GitHub releases, so existing containers switch to OpenCode 2 on their next restart. OpenCode 2 migrates sessions, credentials, and `opencode.json` from OpenCode 1 automatically. To stay on OpenCode 1, set `opencode = "1"` in your mise config.

- The system mise config installs Node LTS, which mise needs to install OpenCode 2 from npm. A `node` entry in your own mise config takes precedence.
- `OPENCODE_SERVER_PASSWORD` is now enforced: the container exits with an error without it. OpenCode 2 always requires auth and would otherwise use a random password that only shows up in the logs.
- `OPENCODE_SERVER_USERNAME` is removed. OpenCode 2 always uses the username `opencode`.
- The healthcheck uses `/api/info`, the readiness endpoint of OpenCode 2, and falls back to `/health` only if `/api/info` does not exist (installs pinned to OpenCode 1). The old check was always healthy on OpenCode 2, whose `/health` just serves the web UI.
- The `server` block is removed from the bundled `opencode.json`; OpenCode 2 ignores it, and port and hostname are passed on the command line.
- The README explains how to attach the terminal UI to the running server (`opencode --server http://localhost:4096`).
