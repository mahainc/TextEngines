# TextEngines

Native text engines for the app761 live-translate feature, wrapped as Swift packages.

| Kit | Native engine | Build script | Published | Model (side-loaded, never bundled) |
|---|---|---|---|---|
| `BergamotKit` | bergamot-translator (Marian, ruy on arm64) | `scripts/build-bergamot.sh` | yes | Firefox `enes` |
| `HarperKit` | harper-core 3.2.0 (Rust FFI) | `scripts/build-harper.sh` | yes | none |
| `LlamaKit` | llama.cpp release xcframework | `scripts/build-llama.sh` | no, local only | Qwen2.5 0.5B / 1.5B Instruct GGUF q4_k_m |

## Using it

```swift
.package(url: "https://github.com/mahainc/TextEngines.git", exact: "0.1.0"),
```

A consumer gets `BergamotKit` and `HarperKit`; their xcframeworks download from the GitHub release
(`.binaryTarget(url:checksum:)`).

## Working on an engine

Build it with its script into `Artifacts/<Binary>.xcframework` (gitignored). A local build wins over
the release, so an engine can be changed and tested without publishing; `LlamaKit` exists only then.
Each Kit's tests read their models from `Models/` (gitignored, fetched by `scripts/fetch-models.sh`).

## Releasing

1. Build the engine, then zip it: `ditto -c -k --sequesterRsrc --keepParent Artifacts/X.xcframework X.xcframework.zip`.
2. `swift package compute-checksum X.xcframework.zip`, and put the version and checksum in `Package.swift`.
3. Commit, tag the version, and attach the zips to a GitHub release of that tag.

Third-party licenses: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
