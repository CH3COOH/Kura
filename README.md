# Kura 🔐

[日本語版 README はこちら](README.ja.md)

**Kura** (蔵) is a pure-Swift CLI tool (`kura-generator`) that obfuscates secrets from `.env` files and generates type-safe Swift code — no Ruby required.

It is built for iOS / macOS app developers who want to embed secrets such as API keys and access tokens in their app without hardcoding them in source code. Designed to work seamlessly with **Xcode Cloud** out of the box.

> [!NOTE]
> What Kura performs is XOR + salt **obfuscation**, not cryptographically secure **encryption**. The generated `KuraKeys.swift` embeds both the encoded byte arrays and the salt used to decode them, so anyone with access to your source code or binary can easily recover the values. The goal is simply to keep plaintext secrets from showing up when someone runs `strings` on your binary — do not rely on this mechanism alone to protect truly sensitive values (e.g. server-side private keys).

Table of Contents
-----------------

- [Quick start](#quick-start)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
    - [Local development](#local-development)
    - [Xcode Cloud](#xcode-cloud)
- [Generated code](#generated-code)
- [Options](#options)
- [FAQ](#faq)

Quick start
-----------

Getting set up takes four steps. Follow the links for the details of each step.

1. Create `BuildTools/Package.swift` and add Kura to it (→ [Installation](#installation))
2. Create `.kura.yml` at your project root (→ [Configuration](#configuration))
3. Put a `.env` file at your project root (→ [Local development](#local-development))
4. Run the generator, then add the generated `KuraKeys/` to your app as a local package

```bash
$ swift run --package-path BuildTools kura-generator
```

Your app can now access the secrets type-safely, e.g. `KuraKeys.Global.apiKey` (→ [Generated code](#generated-code)).

Features
--------

- ✅ No Ruby, no external runtimes — pure Swift
- ✅ Plain SwiftPM executable (`kura-generator`) — no Xcode project entanglement, no plugin sandbox surprises
- ✅ Works with **Xcode Cloud** via `ci_post_clone.sh`
- ✅ XOR + salt obfuscation (secrets are never stored in plaintext)
- ✅ Global secrets and per-environment secrets
- ✅ Supports migration from `.arkana.yml` (a subset of Arkana's options)

Installation
------------

**Recommended:** Don't add Kura to your app's Xcode project. Instead, create a dedicated `BuildTools/Package.swift` and confine Kura to it. This keeps Kura's internal dependencies such as `Yams` out of your app's dependency graph (`Package.resolved`) — the same approach commonly used to isolate build tools like `SwiftFormat` in `BuildTools/`.

```swift
// BuildTools/Package.swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/CH3COOH/Kura.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "BuildTools",
            dependencies: [
                .product(name: "kura-generator", package: "Kura"),
            ],
            path: ""
        ),
    ]
)
```

Put one empty file (e.g. `Empty.swift`) in `BuildTools/` for the target.

If your project is already a pure SwiftPM package (no `.xcodeproj`), you can skip `BuildTools` and add Kura directly to your own `Package.swift` `dependencies`. In that case just run `swift run kura-generator` at the package root (when using `BuildTools`, pass `--package-path BuildTools` as shown below).

Configuration
-------------

Create `.kura.yml` at your project root.

```yaml
import_name: KuraKeys      # Name of the generated Swift module
result_path: .             # Directory to place KuraKeys/ in
swift_declaration: public  # public / internal (default: public)
                           # The generated code is a standalone package, so public is required
                           # when you import it from your app. Use internal only when you copy
                           # the generated .swift file directly into your app target.
preserve_key_case: false  # If true, use the key name as-is for the property name instead of
                           # converting it to camelCase (default: false; see "Key name conversion"
                           # under "Generated code" below).

global_secrets:
  - API_KEY
  - ANALYTICS_TOKEN

environments:
  debug:
    - DEBUG_ENDPOINT
  release:
    - RELEASE_ENDPOINT
```

Kura can also read `.arkana.yml` as a config file, but only the options Kura supports are honored (it does not cover Arkana's full option set).

Usage
-----

### Local development

Put a `.env` file at your project root (add it to `.gitignore`).

```
API_KEY=your_api_key_here
ANALYTICS_TOKEN=your_token
DEBUG_ENDPOINT=https://dev.example.com
RELEASE_ENDPOINT=https://example.com
```

Run the generator (from the same directory as `.kura.yml` / `.env`, i.e. the project root).

```bash
$ swift run --package-path BuildTools kura-generator
```

`swift run --package-path` builds using the specified package (`BuildTools`), but the resulting executable runs in **the current directory of the invocation**. The relative default paths for `.kura.yml` / `.env` therefore resolve as-is, and no options need to be passed explicitly.

Add the generated `KuraKeys/` to your project as a local package.

```swift
// Your app's Package.swift, or Xcode's Package Dependencies
.package(name: "KuraKeys", path: "KuraKeys")
```

### Xcode Cloud

No `.env` needed. Register each key as an **Environment Variable** in your workflow settings, and add the following to `ci_post_clone.sh`.

```sh
#!/bin/sh
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH/path/to/project"  # cd to where .kura.yml lives
swift run --package-path BuildTools kura-generator
```

Generated code
--------------

`global_secrets` are nested under `Global` inside the outer enum. Per-environment secrets are nested under their environment name (in PascalCase) in the same outer enum.

```swift
// KuraKeys/Sources/KuraKeys/KuraKeys.swift
// AUTO-GENERATED by Kura (https://github.com/CH3COOH/Kura) — DO NOT EDIT

private func _kuraDecrypt(_ encoded: [UInt8], salt: [UInt8]) -> String { ... }

public enum KuraKeys {
    public enum Global {
        public static var apiKey: String {
            let encoded: [UInt8] = [0x3F, 0x1A, ...]
            let salt: [UInt8]    = [0xAB, 0xCD, ...]
            return _kuraDecrypt(encoded, salt: salt)
        }
        public static var analyticsToken: String { ... }
    }
    public enum Debug {
        public static var debugEndpoint: String { ... }
    }
    public enum Release {
        public static var releaseEndpoint: String { ... }
    }
}
```

Use it from your app as usual.

```swift
import KuraKeys

let key = KuraKeys.Global.apiKey
let endpoint = KuraKeys.Release.releaseEndpoint
```

**Key name conversion:**

| Key in `.kura.yml` | Generated property name |
|---|---|
| `API_KEY` (underscore-separated) | `apiKey` |
| `APIKEY` (no separator) | `apikey` (lowercased) |

Set `preserve_key_case: true` to skip this conversion and use the key name as-is for the property name (`APIKEY` → `APIKEY`, `API_KEY` → `API_KEY`). Use this when migrating to Kura while keeping existing generated property names unchanged.

Options
-------

```bash
$ swift run --package-path BuildTools kura-generator \
    --config path/to/.kura.yml \   # default: .kura.yml → .kura.yaml → .arkana.yml
    --dotenv path/to/.env \        # default: .env
    --output path/to/output        # default: result_path from .kura.yml
```

`--help` (`-h`) shows the usage, and `--version` prints the version. When `--dotenv` is passed explicitly, the file must exist (a missing file is an error); the default `.env` may be absent (e.g. on CI, where secrets come from environment variables).

FAQ
---

### Why not cocoapods-keys?

CocoaPods has announced it will become read-only in December 2026, which means its libraries will no longer be updated. Since it became hard to keep using CocoaPods actively in our projects, we moved to a setup that does not depend on it. Kura runs on pure SwiftPM, so no CocoaPods installation is required.

### Why not Arkana?

Arkana is an excellent tool, and Kura borrows a lot from it, including the structure of its config file. However, Arkana is written in Ruby and needs to resolve its gem dependencies via RubyGems at build time, and connections from Xcode Cloud to the RubyGems servers can fail. Every time that happened our builds stopped and development stalled, so we built Kura as a pure-Swift CLI that needs no external runtime and no over-the-network dependency resolution.
