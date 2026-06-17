#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Dirscope.app"
BUILD_DIR="$ROOT/DerivedData/Build/Products/Debug"
SOURCE_APP="$BUILD_DIR/Dirscope.app"
DEST_APP="/Applications/${APP_NAME}"
OPEN_APP=true
SKIP_ICONS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-open)
      OPEN_APP=false
      shift
      ;;
    --skip-icons)
      SKIP_ICONS=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--no-open] [--skip-icons]" >&2
      exit 1
      ;;
  esac
done

clear_codesign_xattrs() {
  xattr -cr "$ROOT/DerivedData" 2>/dev/null || true
  for path in FolderPreviewApp FolderPreviewExtension Shared FolderPreviewApp.xcodeproj Vendor; do
    xattr -cr "$ROOT/$path" 2>/dev/null || true
  done
}

bundle_7zz_into_app() {
  local app_path="$1"
  local resources="${app_path}/Contents/Resources"
  local vendor_7zz="${ROOT}/Vendor/7zz/7zz"
  mkdir -p "${resources}"

  if [[ ! -x "${vendor_7zz}" ]]; then
    "$ROOT/scripts/fetch-7zz.sh" >/dev/null 2>&1 || true
  fi

  if [[ -x "${vendor_7zz}" ]]; then
    cp "${vendor_7zz}" "${resources}/7zz"
    chmod +x "${resources}/7zz"
    echo "Bundled 7zz into app Resources."
  else
    echo "No 7zz bundled; run ./scripts/fetch-7zz.sh for sandboxed 7z/rar support." >&2
  fi
}

echo "Building Dirscope..."
clear_codesign_xattrs
if ! $SKIP_ICONS; then
  if python3 -c "import PIL" 2>/dev/null; then
    "$ROOT/scripts/generate-icons.sh"
  else
    echo "Skipping icon regeneration (Pillow not installed; using bundled icons)." >&2
    echo "  To regenerate icons: pip install Pillow, then re-run without --skip-icons." >&2
  fi
fi
clear_codesign_xattrs
xcodebuild \
  -project "$ROOT/FolderPreviewApp.xcodeproj" \
  -scheme FolderPreviewApp \
  -derivedDataPath "$ROOT/DerivedData" \
  build

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Build failed: $SOURCE_APP not found" >&2
  exit 1
fi

bundle_7zz_into_app "${SOURCE_APP}"

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

HELPER_BIN="${DEST_APP}/Contents/MacOS/Dirscope"
LAUNCH_AGENT="${HOME}/Library/LaunchAgents/com.folderpreview.app.openhelper.plist"
if [[ -x "${HELPER_BIN}" ]]; then
  echo "Installing background archive-open helper..."
  mkdir -p "${HOME}/Library/LaunchAgents"
  cat > "${LAUNCH_AGENT}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.folderpreview.app.openhelper</string>
  <key>ProgramArguments</key>
  <array>
    <string>${HELPER_BIN}</string>
    <string>-backgroundOpenHelper</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>ProcessType</key>
  <string>Background</string>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$(id -u)/com.folderpreview.app.openhelper" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "${LAUNCH_AGENT}" >/dev/null 2>&1 || true
  "${HELPER_BIN}" -registerLoginItem >/dev/null 2>&1 || true
fi

if $OPEN_APP; then
  echo "Done. Opening Dirscope..."
  open "$DEST_APP"
else
  echo "Done. Installed to ${DEST_APP} (Quick Look extension reloaded)."
fi
