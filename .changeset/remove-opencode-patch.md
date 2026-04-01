---
"opencode-docker": patch
---

Remove the local OpenCode web UI patch and rely on upstream embedded UI support.

OpenCode `1.3.9` already includes its own embedded web UI build path, so this repo
no longer needs to carry a custom patch that rewrites the upstream server and build
files. This keeps Renovate upgrade PRs mergeable again and avoids Docker build
failures when the patch drifts from upstream.
