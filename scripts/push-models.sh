#!/usr/bin/env bash
# Side-loads Models/* into the dev app's Documents/models/ on a device (app must be installed).
set -euo pipefail
DEVICE="${1:?usage: push-models.sh <device-udid> <bundle-id>}"
BUNDLE="${2:?usage: push-models.sh <device-udid> <bundle-id>}"
cd "$(dirname "$0")/.."
for f in Models/bergamot-enes/* Models/qwen/*.gguf; do
  dest="Documents/models/$(basename "$(dirname "$f")")/$(basename "$f")"
  echo "push $f -> $dest"
  xcrun devicectl device copy to --device "$DEVICE" --domain-type appDataContainer \
    --domain-identifier "$BUNDLE" --source "$f" --destination "$dest" >/dev/null
done
