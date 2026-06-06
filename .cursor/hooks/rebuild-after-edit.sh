#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
input="$(cat)"

file_path="$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
    print(data.get("file_path") or data.get("path") or "")
except Exception:
    print("")' 2>/dev/null || true)"

exec "$ROOT/scripts/rebuild-and-install.sh" --no-open ${file_path:+--file "$file_path"}
