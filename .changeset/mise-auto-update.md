---
"opencode-docker": patch
---

Auto-update mise to the latest version on container startup.

The entrypoint now runs `mise self-update --yes` before installing user-defined
toolchains, so the container always picks up the latest mise release without
needing an image rebuild. A 24-hour staleness check (via a timestamp file in
`/tmp`) avoids redundant network calls on container restarts. If the update
fails (e.g. no internet), the container logs a warning and continues with the
version baked into the image.
