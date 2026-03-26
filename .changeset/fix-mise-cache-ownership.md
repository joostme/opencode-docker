---
"my-project": patch
---

Fix `~/.cache` directory ownership after mise self-update.

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
