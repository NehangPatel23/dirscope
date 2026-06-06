#!/bin/bash
# Debounced rebuild/install. Returns immediately; runs install-app.sh in the background.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQUEST_FILE="$ROOT/DerivedData/.rebuild-requested"
WORKER_PID_FILE="$ROOT/DerivedData/.rebuild-worker.pid"
INSTALL_LOG="$ROOT/DerivedData/install.log"
DEBOUNCE_SECONDS=3
NO_OPEN=false
FILE_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-open)
      NO_OPEN=true
      shift
      ;;
    --debounce)
      DEBOUNCE_SECONDS="${2:-3}"
      shift 2
      ;;
    --file)
      FILE_PATH="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

should_rebuild_for_path() {
  local path="$1"
  case "$path" in
    */FolderPreviewApp/*|*/FolderPreviewExtension/*|*/Shared/*|*/scripts/*|*/FolderPreviewApp.xcodeproj/*)
      case "$path" in
        *.swift|*.plist|*.entitlements|*.pbxproj|*.xcassets/*|*/install-app.sh|*/generate-icons.sh|*/rebuild-and-install.sh|*/watch-and-install.sh)
          return 0
          ;;
      esac
      ;;
  esac
  return 1
}

if [[ -n "$FILE_PATH" ]] && ! should_rebuild_for_path "$FILE_PATH"; then
  exit 0
fi

mkdir -p "$ROOT/DerivedData"
date +%s >"$REQUEST_FILE"

if [[ -f "$WORKER_PID_FILE" ]]; then
  worker_pid="$(cat "$WORKER_PID_FILE")"
  if kill -0 "$worker_pid" 2>/dev/null; then
    exit 0
  fi
fi

(
  while [[ -f "$REQUEST_FILE" ]]; do
    sleep 1
    requested_at="$(cat "$REQUEST_FILE")"
    now="$(date +%s)"
    if (( now - requested_at >= DEBOUNCE_SECONDS )); then
      rm -f "$REQUEST_FILE"
      install_args=(--skip-icons)
      if $NO_OPEN; then
        install_args+=(--no-open)
      fi
      {
        echo "----- $(date '+%Y-%m-%d %H:%M:%S') rebuild started -----"
        "$ROOT/install-app.sh" "${install_args[@]}"
        echo "----- $(date '+%Y-%m-%d %H:%M:%S') rebuild finished -----"
      } >>"$INSTALL_LOG" 2>&1
      break
    fi
  done
  rm -f "$WORKER_PID_FILE"
) &

echo $! >"$WORKER_PID_FILE"
exit 0
