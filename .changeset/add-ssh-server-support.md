---
"opencode-docker": minor
---

Add inbound SSH server support to the container.

This change installs and starts `sshd`, exposes port `22`, uses the existing mounted SSH directory for `authorized_keys`, disables password authentication, and disables root login.
