---
"opencode-docker": patch
---

Add a scheduled GitHub Actions workflow that refreshes pinned upstream versions.

The repo now checks for new OpenCode, code-server, and GitHub CLI releases on a daily schedule, opens a dependency bump PR with matching changesets, and lets the existing release workflow publish a fresh image after merge.
