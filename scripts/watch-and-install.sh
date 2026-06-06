#!/bin/bash
# Watches source files and rebuilds/reinstalls Dirscope after changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WATCH_PATHS=(
  "$ROOT/FolderPreviewApp"
  "$ROOT/FolderPreviewExtension"
  "$ROOT/Shared"
  "$ROOT/scripts"
  "$ROOT/FolderPreviewApp.xcodeproj"
)

echo "Dirscope auto-rebuild is active."
echo "Watching for changes... (logs: DerivedData/install.log)"
echo "Press Ctrl+C to stop."

snapshot_source_state() {
  find "${WATCH_PATHS[@]}" \
    \( -name '*.swift' -o -name '*.plist' -o -name '*.entitlements' -o -name 'project.pbxproj' -o -name '*.sh' \) \
    -type f -print0 2>/dev/null \
    | xargs -0 stat -f '%m %N' 2>/dev/null \
    | shasum -a 256 \
    | awk '{print $1}'
}

last_state="$(snapshot_source_state)"

while true; do
  sleep 2
  current_state="$(snapshot_source_state)"
  if [[ "$current_state" != "$last_state" ]]; then
    last_state="$current_state"
    "$ROOT/scripts/rebuild-and-install.sh" --no-open
  fi
done
