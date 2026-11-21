#!/usr/bin/env bash
# Builds llama.cpp from source into Artifacts/llama.xcframework (ios-arm64 + ios simulator slices).
# The release xcframework has no simulator slice, hence the source build.
set -euo pipefail

LLAMA_TAG="b12527"
LLAMA_COMMIT="78e05298f0d68abff41d08d79fa7469264b2aff0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/llama-src/llama.cpp"
DEST="$ROOT/Artifacts/llama.xcframework"

if [[ ! -d "$SRC/.git" ]]; then
  mkdir -p "$(dirname "$SRC")"
  git clone --depth 1 --branch "$LLAMA_TAG" https://github.com/ggml-org/llama.cpp.git "$SRC"
fi
ACTUAL="$(git -C "$SRC" rev-parse HEAD)"
[[ "$ACTUAL" == "$LLAMA_COMMIT" ]] || { echo "commit mismatch: $ACTUAL != $LLAMA_COMMIT" >&2; exit 1; }

CMAKE_RUN=()
command -v cmake >/dev/null || CMAKE_RUN=(nix shell nixpkgs#cmake nixpkgs#ninja -c)
(cd "$SRC" && "${CMAKE_RUN[@]}" ./build-xcframework.sh ios-sim ios-device)

mkdir -p "$ROOT/Artifacts"
rm -rf "$DEST"
cp -R "$SRC/build-apple/llama.xcframework" "$DEST"
printf '%s %s\n' "$LLAMA_TAG" "$LLAMA_COMMIT" > "$ROOT/Artifacts/llama.tag"
echo "Built llama.cpp $LLAMA_TAG ($LLAMA_COMMIT) -> $DEST"
