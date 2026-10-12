---
"opencode-docker": patch
---

Put the mise shims of the `opencode` user on the image `PATH`, so `docker exec -u opencode opencode gh ...` finds OpenCode, GitHub CLI, and code-server again. Since 3.0.0-beta.0 they were only on the `PATH` of login and interactive shells, and `docker exec` failed with `executable file not found in $PATH`.
