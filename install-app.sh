#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Dirscope.app"
BUILD_DIR="$ROOT/DerivedData/Build/Products/Debug"
SOURCE_APP="$BUILD_DIR/Dirscope.app"
DEST_APP="/Applications/${APP_NAME}"

echo "Building Dirscope..."
xattr -cr "$ROOT" 2>/dev/null || true
"$ROOT/scripts/generate-icons.sh"
xcodebuild \
  -project "$ROOT/FolderPreviewApp.xcodeproj" \
  -scheme FolderPreviewApp \
  -derivedDataPath "$ROOT/DerivedData" \
  build

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Build failed: $SOURCE_APP not found" >&2
  exit 1
fi

echo "Installing to ${DEST_APP}..."
rm -rf "$DEST_APP"
ditto "$SOURCE_APP" "$DEST_APP"
xattr -cr "$DEST_APP" 2>/dev/null || true

CONTAINER_PREFS="${HOME}/Library/Containers/com.folderpreview.app.preview/Data/Library/Application Support/Dirscope/Preferences.plist"
LEGACY_PREFS="${HOME}/Library/Application Support/Dirscope/Preferences.plist"
if [[ -f "${LEGACY_PREFS}" ]]; then
  mkdir -p "$(dirname "${CONTAINER_PREFS}")"
  cp "${LEGACY_PREFS}" "${CONTAINER_PREFS}"
  echo "Synced preferences to Quick Look extension container."
fi

/usr/bin/qlmanage -r >/dev/null 2>&1 || true

echo "Done. Opening Dirscope..."
open "$DEST_APP"
