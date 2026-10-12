---
"opencode-docker": patch
---

Commands that OpenCode runs now get the `[env]` variables from your mise config. They run in a non-interactive shell (`zsh -c`), which never loaded them before, so variables like API keys or project settings were missing for agent commands. The container now evaluates `mise env` on every shell start (`~/.config/zsh/.zshenv`, `~/.zshenv`, and `BASH_ENV` for `bash -c`). Changes to the mise config apply without a restart, and the mise config of the current project is honoured.
