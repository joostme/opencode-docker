---
"opencode-docker": major
---

Rebuild the image without any bundled binaries. OpenCode, GitHub CLI, and code-server are now installed by mise on first container start and upgraded on every start (together with mise itself and user toolchains). The first start requires network access.

Breaking changes:

- The image no longer pins or bundles OpenCode, GitHub CLI, or code-server; the pinned-version Dockerfile args, the dependency-refresh workflow, and the related Renovate rules are removed, so image releases no longer track upstream versions.

Pinning and opting out:

- To pin versions, add them to `config/mise/config.toml`, e.g. `opencode = "1.18.33"`, `gh = "2.101.0"`, `"github:coder/code-server" = "4.139.1"`. Entries there override the image default of `latest`.
- To disable all upgrades (including mise itself and floating toolchains), set `AUTO_UPDATE=false`. Missing tools are still installed on start.
