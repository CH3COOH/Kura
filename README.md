# Kura 🔐

**Kura** (蔵) is a pure-Swift CLI tool (`kura-generator`) that encrypts secrets from `.env` files and generates type-safe Swift code — no Ruby required.

Designed to work seamlessly with **Xcode Cloud** out of the box.

---

## Features

- ✅ No Ruby, no external runtimes — pure Swift
- ✅ Plain SwiftPM executable (`kura-generator`) — no Xcode project entanglement, no plugin sandbox surprises
- ✅ Works with **Xcode Cloud** via `ci_post_clone.sh`
- ✅ XOR + salt encryption (secrets are never stored in plaintext)
- ✅ Global secrets and per-environment secrets
- ✅ Backward compatible with `.arkana.yml`


