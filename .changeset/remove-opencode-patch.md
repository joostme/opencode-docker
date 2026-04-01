---
"opencode-docker": patch
---

Remove the local OpenCode web UI patch and switch to the upstream precompiled binary.

Recent OpenCode releases already include embedded web UI support in the published
Linux binaries, so this repo no longer needs to carry a custom patch or rebuild
OpenCode from source in Docker. This keeps Renovate upgrade PRs mergeable again,
reduces image build complexity, and avoids build failures when local compile-time
customizations drift from upstream.
