---
"opencode-docker": patch
---

Skip recursive ownership changes on the read-only `.ssh-keys` mount during startup to avoid `chown` failures while still copying SSH keys into the writable `~/.ssh` directory.
