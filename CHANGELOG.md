# opencode-docker

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
