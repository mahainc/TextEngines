# Bergamot engine patches

Copied verbatim from `ostpnk/translate-engine` (MIT) at commit
`de7e275`, written against `mozilla/translations` at the commit pinned in
`scripts/build-bergamot.sh`. `marian-*` patches apply to the `mozilla/translations`
checkout; the others to the submodule they name.

| Patch | Why |
|---|---|
| `marian-TargetArch-arm64.patch` | Marian's arch probe rejects `CMAKE_OSX_ARCHITECTURES=arm64`; reports it as `armv8`. |
| `marian-ExceptionWithCallStack-vla.patch` | Two VLAs fail Apple clang `-Wvla-cxx-extension` under `-Werror`. |
| `marian-zlib-TARGET_OS_MAC.patch` | Bundled zlib 1.2.11 defines `fdopen` to `NULL` on every Apple OS. |
| `marian-bergamot-Logger-process-wide.patch` | A second service failed with "logger with name 'general' already exists". |
| `ssplit-pcre2-nojit-ios.patch` | PCRE2 JIT is forbidden on iOS (and does not link: `___clear_cache`). |
| `sentencepiece-clang20-kAnyType.patch` | Newer clang rejects an out-of-range `constexpr` enum constant. |
