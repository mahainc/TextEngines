#!/usr/bin/env bash
# Builds native/harper-ffi for iOS device + simulator and packages Artifacts/HarperFFI.xcframework.
# Needs rustup and cbindgen; on nix: nix shell nixpkgs#rustup nixpkgs#rust-cbindgen -c scripts/build-harper.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRATE="$ROOT/native/harper-ffi"
TOOLCHAIN="${RUST_TOOLCHAIN:-stable}"
TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim)
OUTPUT="$ROOT/Artifacts/HarperFFI.xcframework"

export IPHONEOS_DEPLOYMENT_TARGET=17.0

rustup toolchain install "$TOOLCHAIN" --profile minimal
rustup target add --toolchain "$TOOLCHAIN" "${TARGETS[@]}"

cd "$CRATE"
for target in "${TARGETS[@]}"; do
    rustup run "$TOOLCHAIN" cargo build --locked --release --target "$target"
done

INCLUDE="$CRATE/target/include"
# A per-module subdirectory keeps this modulemap from colliding with other xcframeworks' in SwiftPM.
HEADERS="$INCLUDE/HarperFFI"
rm -rf "$INCLUDE"
mkdir -p "$HEADERS"
cbindgen --config cbindgen.toml --lang c --output "$HEADERS/harper_ffi.h" "$CRATE"
cat > "$HEADERS/module.modulemap" <<'MODULEMAP'
module HarperFFI {
    header "harper_ffi.h"
    export *
}
MODULEMAP

rm -rf "$OUTPUT"
mkdir -p "$ROOT/Artifacts"
xcodebuild -create-xcframework \
    -library "$CRATE/target/aarch64-apple-ios/release/libharper_ffi.a" -headers "$INCLUDE" \
    -library "$CRATE/target/aarch64-apple-ios-sim/release/libharper_ffi.a" -headers "$INCLUDE" \
    -output "$OUTPUT"

ls -l "$CRATE"/target/aarch64-apple-ios*/release/libharper_ffi.a
du -sh "$OUTPUT"
