---
"opencode-docker": patch
---

Fix the first container start failing with "Permission denied" while installing OpenCode, GitHub CLI, and code-server. `mise self-update` ran as root with the user's home and left root-owned directories under `~/.local/share/mise`; it now runs with `HOME=/root`, and root-owned leftovers in persisted volumes are handed back to the user before installing.
