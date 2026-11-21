#!/usr/bin/env bash
# Builds Artifacts/BergamotFFI.xcframework (iOS device arm64 + iOS simulator arm64, iOS 17.0):
# the bergamot_ffi C shim over Mozilla's Bergamot engine, merged with every static dependency.
#
# Usage: scripts/build-bergamot.sh          (needs cmake + ninja, e.g. nix shell nixpkgs#cmake nixpkgs#ninja)
set -euo pipefail

# bergamot-translator now lives in mozilla/translations (inference/); browsermt/bergamot-translator
# stopped in 2024-05. This commit postdates browsermt 9271618 (ARM via ruy) and matches the patches.
ENGINE_REPO=https://github.com/mozilla/translations.git
ENGINE_COMMIT=69455acaecbe8650cdba988dbcf7c10ca20e7c48

PCRE2=pcre2-10.39
PCRE2_SHA256=0781bd2536ef5279b1943471fdcdbd9961a2845e1d2c9ad849b9bd98ba1a9bd4

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FFI="$ROOT/native/bergamot-ffi"
WORK="$ROOT/build/bergamot"
ENGINE="$WORK/engine"
OUTPUT="$ROOT/Artifacts/BergamotFFI.xcframework"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

# CMake 4 refuses cpuinfo's bundled clog (cmake_minimum_required < 3.5); the env var reaches
# ExternalProjects too.
export CMAKE_POLICY_VERSION_MINIMUM=3.5

fetch_engine() {
  if [[ ! -d "$ENGINE/.git" ]]; then
    git clone --quiet --filter=blob:none --no-checkout "$ENGINE_REPO" "$ENGINE"
  fi
  git -C "$ENGINE" sparse-checkout set inference
  git -C "$ENGINE" checkout --quiet "$ENGINE_COMMIT"
  git -C "$ENGINE" submodule update --init --depth 1 \
    inference/3rd_party/ssplit-cpp \
    inference/marian-fork/src/3rd_party/sentencepiece \
    inference/marian-fork/src/3rd_party/intgemm \
    inference/marian-fork/src/3rd_party/ruy \
    inference/marian-fork/src/3rd_party/simd_utils
  git -C "$ENGINE/inference/marian-fork/src/3rd_party/ruy" \
    submodule update --init --depth 1 third_party/cpuinfo

  apply_patch "$ENGINE" marian-TargetArch-arm64.patch
  apply_patch "$ENGINE" marian-ExceptionWithCallStack-vla.patch
  apply_patch "$ENGINE" marian-zlib-TARGET_OS_MAC.patch
  apply_patch "$ENGINE" marian-bergamot-Logger-process-wide.patch
  apply_patch "$ENGINE/inference/3rd_party/ssplit-cpp" ssplit-pcre2-nojit-ios.patch
  apply_patch "$ENGINE/inference/marian-fork/src/3rd_party/sentencepiece" sentencepiece-clang20-kAnyType.patch

  local pcre_dir="$ENGINE/inference/3rd_party/ssplit-cpp/src/3rd-party"
  if [[ ! -f "$pcre_dir/$PCRE2/configure" ]]; then
    mkdir -p "$pcre_dir"
    curl -sSfL -o "$pcre_dir/$PCRE2.tar.gz" \
      "https://github.com/PhilipHazel/pcre2/releases/download/$PCRE2/$PCRE2.tar.gz"
    local actual
    actual=$(shasum -a 256 "$pcre_dir/$PCRE2.tar.gz" | cut -d' ' -f1)
    [[ "$actual" == "$PCRE2_SHA256" ]] || { echo "PCRE2 checksum mismatch: $actual" >&2; exit 1; }
    tar -xzf "$pcre_dir/$PCRE2.tar.gz" -C "$pcre_dir"
    rm "$pcre_dir/$PCRE2.tar.gz"
  fi
}

apply_patch() {
  local dir="$1" patch="$FFI/patches/$2"
  if git -C "$dir" apply --reverse --check "$patch" 2>/dev/null; then
    echo "already applied: $2"
  else
    git -C "$dir" apply "$patch"
    echo "applied: $2"
  fi
}

# build_slice <iphoneos|iphonesimulator>: prints the merged static library path.
build_slice() {
  local sdk="$1" build="$WORK/build-$1"
  export IOS_SDK="$sdk"
  local flags=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_TOOLCHAIN_FILE="$FFI/ios.toolchain.cmake"
    -DENGINE_DIR="$ENGINE/inference"
    -DBUILD_ARCH=armv8-a
    -DSSPLIT_USE_INTERNAL_PCRE2=ON
    -DGIT_SUBMODULE=OFF
    -DCOMPILE_CPU=ON -DCOMPILE_CUDA=OFF -DCOMPILE_WASM=OFF
    -DUSE_STATIC_LIBS=ON
    -DUSE_FBGEMM=OFF -DUSE_MKL=OFF -DUSE_NCCL=OFF -DUSE_DOXYGEN=OFF
    -DUSE_RUY=ON -DUSE_RUY_SGEMM=ON -DUSE_APPLE_ACCELERATE=OFF
  )
  cmake -S "$FFI" -B "$build" "${flags[@]}" >&2

  # Marian sets its compile definitions only inside marian-fork/; Bergamot's sources would
  # otherwise see Marian's headers with the ARM (NEON/SSE-emulation) paths switched off.
  local defs
  defs=$(awk '
    /^build [^:]*marian-fork\/src\/CMakeFiles\/marian\.dir\/common\/utils\.cpp\.o:/ { f = 1 }
    f && /^  DEFINES = / { sub(/^  DEFINES = /, ""); print; exit }
  ' "$build/build.ninja")
  [[ -n "$defs" ]] || { echo "could not read Marian's DEFINES from build.ninja" >&2; exit 1; }
  cmake -S "$FFI" -B "$build" "${flags[@]}" -DCMAKE_CXX_FLAGS="$defs" >&2
  cmake --build "$build" --target bergamot_ffi bergamot-translator-source -- -j "$JOBS" >&2

  local libs=()
  while IFS= read -r lib; do libs+=("$lib"); done < <(find "$build" -name '*.a' \
    ! -name 'libpcre2-posix*' ! -name 'libgtest*' ! -name 'libgmock*' ! -path '*/pcre2-build/*' | sort)
  local merged="$WORK/out-$sdk/libBergamotFFI.a"
  mkdir -p "$(dirname "$merged")"
  rm -f "$merged"
  libtool -static -no_warning_for_no_symbols -o "$merged" "${libs[@]}" 2>&1 \
    | grep -v 'same member name' >&2 || true
  printf '%s\n' "${libs[@]}" | sed "s|^$build/|  merged: |" >&2
  echo "$merged"
}

mkdir -p "$WORK"
fetch_engine
device_lib=$(build_slice iphoneos)
simulator_lib=$(build_slice iphonesimulator)

headers="$WORK/headers"
rm -rf "$headers" && mkdir -p "$headers/BergamotFFI"
cp "$FFI/bergamot_ffi.h" "$FFI/module.modulemap" "$headers/BergamotFFI/"

rm -rf "$OUTPUT"
xcodebuild -create-xcframework \
  -library "$device_lib" -headers "$headers" \
  -library "$simulator_lib" -headers "$headers" \
  -output "$OUTPUT"
echo "engine: $ENGINE_REPO@$ENGINE_COMMIT"
du -sh "$OUTPUT"/*/libBergamotFFI.a
