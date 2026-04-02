---
"opencode-docker": patch
---

Fix SSH login failing with "account is locked" by setting the opencode user's password field to `*` instead of the default `!` that `useradd` sets.