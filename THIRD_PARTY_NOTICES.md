# Third-party notices

The released xcframeworks contain the following third-party software. Each is used under its own
license; the full texts are in the upstream repositories named below.

## BergamotFFI.xcframework

| Component | License | Source |
|---|---|---|
| bergamot-translator | MPL-2.0 | [mozilla/translations](https://github.com/mozilla/translations) `inference/`, commit `69455acaecbe8650cdba988dbcf7c10ca20e7c48`, with the patches in `native/bergamot-ffi/patches` |
| Marian (marian-fork) | MIT | `inference/marian-fork` in the same repository |
| ruy | Apache-2.0 | `marian-fork/src/3rd_party/ruy` |
| SentencePiece | Apache-2.0 | `marian-fork/src/3rd_party/sentencepiece` |
| ssplit-cpp | Apache-2.0 | `inference/3rd_party/ssplit-cpp` |
| PCRE2 10.39 | BSD-3-Clause (with PCRE2 exception) | [PhilipHazel/pcre2](https://github.com/PhilipHazel/pcre2) |

The MPL-2.0 source for this build is the upstream commit above plus the patches in this repository.

## HarperFFI.xcframework

| Component | License | Source |
|---|---|---|
| harper-core 3.2.0 and its Rust dependencies | Apache-2.0 (harper-core); see `native/harper-ffi/Cargo.lock` for each dependency | [Automattic/harper](https://github.com/Automattic/harper) |
