# opencode-docker

## 2.3.5

### Patch Changes

- 9968fbb: chore(deps): update opencode to v1.14.50
- a79f2dd: chore(deps): update code-server to v4.118.0
- 9f6de0f: chore(deps): update github cli to v2.92.0

## 2.3.4

### Patch Changes

- 3b08fbc: chore(deps): update code-server to v4.116.0
- ecf668c: chore(deps): update opencode to v1.14.18
- 25e6940: chore(deps): update github cli to v2.90.0

## 2.3.3

### Patch Changes

- 711146b: Update the bundled OpenCode binary in the Docker image to v1.4.6.

## 2.3.2

### Patch Changes

- 9f1c623: Update the Docker image to include the latest Dockerfile changes, including the added build-essential package.
- 2f6cb81: Update the bundled code-server in the Docker image to v4.115.0.
- fd31763: Update the bundled GitHub CLI in the Docker image to v2.89.0.
- 87186da: Update the bundled OpenCode binary in the Docker image to v1.4.0.

## 2.3.1

### Patch Changes

- 0e71d22: Fix SSH login failing with "account is locked" by setting the opencode user's password field to `*` instead of the default `!` that `useradd` sets.

## 2.3.0

### Minor Changes

- ae87f30: Add inbound SSH server support to the container.

  This change installs and starts `sshd`, exposes port `22`, uses the existing mounted SSH directory for `authorized_keys`, disables password authentication, and disables root login.

## 2.2.6

### Patch Changes

- 8ab97f2: Skip recursive ownership changes on the read-only `.ssh-keys` mount during startup to avoid `chown` failures while still copying SSH keys into the writable `~/.ssh` directory.

## 2.2.5

### Patch Changes

- 4c7f354: Remove the local OpenCode web UI patch and switch to the upstream precompiled binary.

  Recent OpenCode releases already include embedded web UI support in the published
  Linux binaries, so this repo no longer needs to carry a custom patch or rebuild
  OpenCode from source in Docker. This keeps Renovate upgrade PRs mergeable again,
  reduces image build complexity, and avoids build failures when local compile-time
  customizations drift from upstream.

## 2.2.4

### Patch Changes

- c04f74a: Skip recursive ownership changes on the read-only `.ssh-keys` mount during container startup. This prevents startup errors when SSH keys are mounted with `:ro` and still copies them into the writable `~/.ssh` directory for use inside the container.

## 2.2.3

### Patch Changes

- 382c390: Fix `~/.cache` directory ownership after mise self-update.

  The `mise self-update` command runs as root (since the binary lives in
  `/usr/local/bin`) and creates `~/.cache` owned by root. Subsequent operations
  running as the unprivileged user (PUID/PGID) would fail because they couldn't
  write to the root-owned cache directory, causing a container crash loop.

  The entrypoint now:

  - Recursively fixes ownership of `~/.cache` immediately after `mise self-update`.
  - Simplifies `fix_ownership()` to chown everything under `$HOME` instead of
    enumerating individual dotfiles, so new directories like `.cache` are
    automatically covered. The `.config` directory remains excluded (only the
    directory entries are chowned, not contents) since users may mount config
    files with specific ownership.

## 2.2.2

### Patch Changes

- 067646f: Auto-update mise to the latest version on container startup.

  The entrypoint now runs `mise self-update --yes` before installing user-defined
  toolchains, so the container always picks up the latest mise release without
  needing an image rebuild. A 24-hour staleness check (via a timestamp file in
  `/tmp`) avoids redundant network calls on container restarts. If the update
  fails (e.g. no internet), the container logs a warning and continues with the
  version baked into the image.

- 619bdce: Update the bundled OpenCode dependency from v1.3.0 to v1.3.2.

## 2.2.1

### Patch Changes

- 15c98e6: Refresh the bundled tooling in the Docker image for the next release.

  - Update Bun to `1.3.11`
  - Update code-server to `4.112.0`
  - Update OpenCode to `1.3.0`
  - Refresh the embedded web UI patch so the local OpenCode UI build stays compatible with OpenCode `1.3.0`

## 2.2.0

### Minor Changes

- 7c81304: Build OpenCode from source with the web UI embedded directly into the binary.

  The Dockerfile now includes a multi-stage build that patches OpenCode to compile
  the upstream web UI assets into the binary at build time. This removes the
  runtime dependency on `app.opencode.ai` for serving the web interface, so the
  container works fully offline and without an external CDN proxy.

  Additional improvements:

  - **Multi-platform build support**: The opencode binary selection now uses
    Docker's `TARGETARCH` instead of a hardcoded `linux-x64` path, fixing arm64
    image builds.
  - **Renovate auto-updates for all pinned versions**: Added renovate comment
    prefixes for `OPENCODE_VERSION` and `BUN_VERSION`, and registered matching
    custom managers and package rules so the bot can open PRs when new releases
    are published.
  - **Removed unused ARG**: Cleaned up a redundant `ARG OPENCODE_VERSION`
    re-declaration in the final build stage.

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
