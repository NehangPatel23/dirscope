#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="${ROOT}/Vendor/7zz"
DEST="${VENDOR_DIR}/7zz"
ARCH="$(uname -m)"

mkdir -p "${VENDOR_DIR}"

if [[ -x "${DEST}" ]]; then
  echo "7zz already present at ${DEST}"
  exit 0
fi

copy_from_path() {
  local source="$1"
  if [[ -x "${source}" ]]; then
    cp "${source}" "${DEST}"
    chmod +x "${DEST}"
    echo "Copied 7zz from ${source}"
    exit 0
  fi
}

for candidate in \
  /opt/homebrew/bin/7zz \
  /opt/homebrew/bin/7z \
  /usr/local/bin/7zz \
  /usr/local/bin/7z; do
  copy_from_path "${candidate}"
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
ARCHIVE_PATH="${TMP_DIR}/7z-mac.tar.xz"
ARCHIVE_URLS=(
  "https://www.7-zip.org/a/7z2601-mac.tar.xz"
  "https://www.7-zip.org/a/7z2500-mac.tar.xz"
  "https://www.7-zip.org/a/7z2409-mac.tar.xz"
  "https://www.7-zip.org/a/7z2301-mac.tar.xz"
)

downloaded=false
for ARCHIVE_URL in "${ARCHIVE_URLS[@]}"; do
  echo "Trying ${ARCHIVE_URL}..."
  if curl -fsSL "${ARCHIVE_URL}" -o "${ARCHIVE_PATH}"; then
    downloaded=true
    break
  fi
done

if ! $downloaded; then
  echo "Could not download 7-Zip macOS archive from official mirrors." >&2
  exit 1
fi
tar -xJf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

FOUND="$(find "${TMP_DIR}" -type f \( -name 7zz -o -name 7z \) -perm +111 | head -n 1 || true)"
if [[ -z "${FOUND}" ]]; then
  echo "Could not locate 7zz in downloaded archive." >&2
  exit 1
fi

cp "${FOUND}" "${DEST}"
chmod +x "${DEST}"
echo "Installed 7zz to ${DEST} (host arch: ${ARCH})"
