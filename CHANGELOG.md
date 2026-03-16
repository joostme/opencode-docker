# opencode-docker

## 2.1.2

### Patch Changes

- 800b555: Update the bundled OpenCode dependency to the latest patch release.

## 2.1.1

### Patch Changes

- d6f5dbc: Set `SHELL=/bin/zsh` when starting the OpenCode web server so server-run shell commands follow the container user's configured zsh shell instead of falling back to bash.

## 2.1.0

### Minor Changes

- c559b7c: Switch the internal terminals to `zsh`, bootstrap Oh My Zsh automatically, and persist zsh/Oh My Zsh configuration under the mounted `./config` directory so custom plugins and themes survive container rebuilds and reruns.
- bfd9c12: Add the GitHub CLI to the Docker image so `gh` commands are available in the terminal and to agents, and document optional `GH_TOKEN` / `GITHUB_TOKEN` authentication for container startup.
- b328ac6: Add a bundled Playwright MCP sidecar and prewire OpenCode to connect to it for browser automation out of the box.

  Relax the bundled OpenCode permissions so todo tools, Context7 usage, subagents, and GitHub CLI commands can run without repeated approval prompts.

## 2.0.0

### Major Changes

- 3c8a661: Rework the container's persisted directory layout to mount full `~/.config`, `~/.local/share`, and `~/.agents` paths, which simplifies configuration but requires existing installs to migrate their mounted data and config files.

  Pin OpenCode and code-server versions in the `Dockerfile`, add Renovate tracking for those upstream releases, and refresh the README to match the new setup and upgrade flow.

## 1.0.3

### Patch Changes

- 30a25e5: Fix user/group ids below 1000. Fix healthcheck with password

## 1.0.2

### Patch Changes

- 8e35ce2: Remove unnecessary dev depcs in docker image. Fix UID/GID handling with existing groups

## 1.0.1

### Patch Changes

- 4853bcf: Add arm64 & amd64

## 1.0.0

### Major Changes

- 6448799: Initial release
