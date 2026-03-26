---
"opencode-docker": patch
---

Skip recursive ownership changes on the read-only `.ssh-keys` mount during container startup. This prevents startup errors when SSH keys are mounted with `:ro` and still copies them into the writable `~/.ssh` directory for use inside the container.
