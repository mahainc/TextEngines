#!/usr/bin/env bash
# Downloads side-loaded engine models into Models/ (gitignored). Each engine owns one section.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODELS="$ROOT/Models"

fetch() {
  local url="$1" dest="$2"
  [[ -f "$dest" ]] && return 0
  mkdir -p "$(dirname "$dest")"
  curl -fL --retry 3 -C - -o "$dest.part" "$url"
  mv "$dest.part" "$dest"
}

# ---- Qwen (LlamaKit): Qwen2.5 Instruct GGUF q4_k_m, Apache-2.0 ----
QWEN_BASE="https://huggingface.co/Qwen"
fetch "$QWEN_BASE/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf" \
      "$MODELS/qwen/qwen2.5-0.5b-instruct-q4_k_m.gguf"
fetch "$QWEN_BASE/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf" \
      "$MODELS/qwen/qwen2.5-1.5b-instruct-q4_k_m.gguf"
# ---- end Qwen ----

# ---- Bergamot (BergamotKit): Firefox Translations en->es, MPL-2.0 ----
# Mozilla's registry (storage.googleapis.com/moz-fx-translations-data--303e-prod-translations-data/db/models.json),
# entry en-es "Release", base-memory. The firefox-translations-models repo no longer carries new models.
BERGAMOT_BASE="https://storage.googleapis.com/moz-fx-translations-data--303e-prod-translations-data/models/en-es/retrain_hr_fix_names_CUAEXUHoQum_cFqh-ZAryw/exported"
BERGAMOT_MODEL_SHA256=3b1c399511c01c84c36fae5c0524df44096288efdc8236e182b5c97d7ad2244c
fetch_gunzipped() {
  local url="$1" dest="$2"
  [[ -f "$dest" ]] && return 0
  mkdir -p "$(dirname "$dest")"
  curl -fsSL --retry 3 "$url" | gunzip > "$dest.part"
  mv "$dest.part" "$dest"
}
for file in model.enes.intgemm.alphas.bin lex.50.50.enes.s2t.bin vocab.enes.spm; do
  fetch_gunzipped "$BERGAMOT_BASE/$file.gz" "$MODELS/bergamot-enes/$file"
done
actual=$(shasum -a 256 "$MODELS/bergamot-enes/model.enes.intgemm.alphas.bin" | cut -d' ' -f1)
[[ "$actual" == "$BERGAMOT_MODEL_SHA256" ]] || { echo "bergamot-enes model checksum mismatch: $actual" >&2; exit 1; }
# ---- end Bergamot ----
