---
"opencode-docker": patch
---

Set `SHELL=/bin/zsh` when starting the OpenCode web server so server-run shell commands follow the container user's configured zsh shell instead of falling back to bash.
