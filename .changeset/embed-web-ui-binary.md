---
"opencode-docker": minor
---

Build OpenCode from source with the web UI embedded directly into the binary.

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
