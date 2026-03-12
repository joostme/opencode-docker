---
"opencode-docker": major
---

Rework the container's persisted directory layout to mount full `~/.config`, `~/.local/share`, and `~/.agents` paths, which simplifies configuration but requires existing installs to migrate their mounted data and config files.

Pin OpenCode and code-server versions in the `Dockerfile`, add Renovate tracking for those upstream releases, and refresh the README to match the new setup and upgrade flow.
