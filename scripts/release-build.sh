#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Dirscope.app"
BUILD_DIR="${ROOT}/DerivedData/Build/Products/Release"
SOURCE_APP="${BUILD_DIR}/${APP_NAME}"
DIST_DIR="${ROOT}/dist"
VERSION="${DIRSCOPE_VERSION:-1.0.0}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SKIP_NOTARIZE=false

usage() {
  cat <<EOF
Usage: $0 [--skip-notarize] [--version VERSION]

Build a Release Dirscope.app, optionally notarize it, and write artifacts to dist/.

Environment:
  DEVELOPMENT_TEAM   Apple Developer Team ID (required for Developer ID signing)
  NOTARY_PROFILE     Keychain notarytool profile name (required for notarization)
  DIRSCOPE_VERSION   Marketing version tag (default: 1.0.0)

Examples:
  DEVELOPMENT_TEAM=ABCDE12345 NOTARY_PROFILE=dirscope-notary $0
  $0 --skip-notarize
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-notarize)
      SKIP_NOTARIZE=true
      shift
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

clear_codesign_xattrs() {
  xattr -cr "${ROOT}/DerivedData" 2>/dev/null || true
  for path in FolderPreviewApp FolderPreviewExtension Shared FolderPreviewApp.xcodeproj Vendor; do
    xattr -cr "${ROOT}/${path}" 2>/dev/null || true
  done
}

bundle_7zz_into_app() {
  local app_path="$1"
  local resources="${app_path}/Contents/Resources"
  local vendor_7zz="${ROOT}/Vendor/7zz/7zz"
  mkdir -p "${resources}"

  if [[ ! -x "${vendor_7zz}" ]]; then
    "${ROOT}/scripts/fetch-7zz.sh" >/dev/null 2>&1 || true
  fi

  if [[ -x "${vendor_7zz}" ]]; then
    cp "${vendor_7zz}" "${resources}/7zz"
    chmod +x "${resources}/7zz"
    echo "Bundled 7zz into app Resources."
  else
    echo "Warning: no 7zz bundled; 7z/rar may require Homebrew at runtime." >&2
  fi
}

sign_nested_tools() {
  local app_path="$1"
  local sign_identity="$2"
  local seven_zip="${app_path}/Contents/Resources/7zz"
  if [[ -f "${seven_zip}" ]]; then
    codesign --force --options runtime --sign "${sign_identity}" "${seven_zip}"
  fi
}

mkdir -p "${DIST_DIR}"
clear_codesign_xattrs

BUILD_ARGS=(
  -project "${ROOT}/FolderPreviewApp.xcodeproj"
  -scheme FolderPreviewApp
  -derivedDataPath "${ROOT}/DerivedData"
  -configuration Release
  MARKETING_VERSION="${VERSION}"
  CURRENT_PROJECT_VERSION="${VERSION}"
  ENABLE_HARDENED_RUNTIME=YES
)

if [[ -n "${DEVELOPMENT_TEAM}" ]]; then
  BUILD_ARGS+=(
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}"
    CODE_SIGN_IDENTITY="Developer ID Application"
  )
  SIGN_IDENTITY="Developer ID Application"
else
  BUILD_ARGS+=(CODE_SIGN_IDENTITY="-")
  SIGN_IDENTITY="-"
  echo "DEVELOPMENT_TEAM not set; building with ad-hoc signing." >&2
fi

echo "Building Release Dirscope ${VERSION}..."
xcodebuild build "${BUILD_ARGS[@]}"

if [[ ! -d "${SOURCE_APP}" ]]; then
  echo "Release build failed: ${SOURCE_APP} not found" >&2
  exit 1
fi

xattr -cr "${SOURCE_APP}" 2>/dev/null || true

bundle_7zz_into_app "${SOURCE_APP}"
xattr -cr "${SOURCE_APP}" 2>/dev/null || true

if [[ "${SIGN_IDENTITY}" != "-" ]]; then
  echo "Re-signing nested tools..."
  sign_nested_tools "${SOURCE_APP}" "${SIGN_IDENTITY}"
  codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${SOURCE_APP}"
fi

ZIP_PATH="${DIST_DIR}/Dirscope-${VERSION}.zip"
DMG_PATH="${DIST_DIR}/Dirscope-${VERSION}.dmg"
STAGED_APP="${DIST_DIR}/stage/${APP_NAME}"

rm -rf "${DIST_DIR}/stage"
mkdir -p "${DIST_DIR}/stage"
ditto "${SOURCE_APP}" "${STAGED_APP}"

(
  cd "${DIST_DIR}/stage"
  zip -r "${ZIP_PATH}" "${APP_NAME}" >/dev/null
)

if command -v hdiutil >/dev/null; then
  rm -f "${DMG_PATH}"
  hdiutil create -volname "Dirscope" -srcfolder "${STAGED_APP}" -ov -format UDZO "${DMG_PATH}" >/dev/null
fi

if ! $SKIP_NOTARIZE; then
  if [[ -z "${DEVELOPMENT_TEAM}" || -z "${NOTARY_PROFILE}" ]]; then
    echo "Skipping notarization (set DEVELOPMENT_TEAM and NOTARY_PROFILE, or pass --skip-notarize)." >&2
  else
    echo "Submitting ${ZIP_PATH} for notarization..."
    xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
    xcrun stapler staple "${STAGED_APP}"
    (
      cd "${DIST_DIR}/stage"
      rm -f "${ZIP_PATH}"
      zip -r "${ZIP_PATH}" "${APP_NAME}" >/dev/null
    )
    if [[ -f "${DMG_PATH}" ]]; then
      rm -f "${DMG_PATH}"
      hdiutil create -volname "Dirscope" -srcfolder "${STAGED_APP}" -ov -format UDZO "${DMG_PATH}" >/dev/null
      xcrun stapler staple "${DMG_PATH}" || true
    fi
    echo "Notarization complete."
  fi
fi

cat > "${DIST_DIR}/RELEASE-${VERSION}.md" <<EOF
# Dirscope ${VERSION}

## Install

1. Download \`Dirscope-${VERSION}.zip\` (or the DMG if provided).
2. Move \`Dirscope.app\` to \`/Applications\`.
3. Open Dirscope once, then enable the Quick Look extension in **System Settings → General → Login Items & Extensions → Quick Look**.
4. In Finder, select a folder and press **Space** or **⌘Y**.

## Archive support

- Zip and tar (including \`.tar.gz\` and \`.tar.xz\`) use in-process parsing where possible.
- \`.7z\` and \`.rar\` use a bundled \`7zz\` binary when present.
- Opening files from inside archives uses the background helper installed on first launch.

## Background helper

After installing, \`install-app.sh\` or the first app launch registers \`com.folderpreview.app.openhelper\`. Check **Behaviors** in Dirscope settings if archive open stops working.
EOF

echo "Artifacts written to ${DIST_DIR}:"
ls -1 "${DIST_DIR}"
