#!/bin/bash
# Regenerates AppIcon (opaque, full-bleed for macOS) and AppMark (transparent for in-app UI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/../.cursor/projects/Users-nehangpatel-Desktop-Folder-Preview-App/assets/image-229508e0-1f30-4951-82c2-95a9ee9d5ec9.png}"

if [[ ! -f "$SRC" ]]; then
  SRC="/Users/nehangpatel/.cursor/projects/Users-nehangpatel-Desktop-Folder-Preview-App/assets/image-229508e0-1f30-4951-82c2-95a9ee9d5ec9.png"
fi

ICONSET="$ROOT/FolderPreviewApp/Assets.xcassets/AppIcon.appiconset"
MARKSET="$ROOT/FolderPreviewApp/Assets.xcassets/AppMark.imageset"

python3 << PY
from PIL import Image, ImageDraw
import os

src = "$SRC"
iconset = "$ICONSET"
markset = "$MARKSET"

img = Image.open(src).convert("RGBA")
w, h = img.size
side = h
left = (w - side) // 2
icon = img.crop((left, 0, left + side, side))

def squircle_mask(size, radius_ratio=0.2237):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    r = int(size * radius_ratio)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=r, fill=255)
    return mask

# macOS AppIcon: opaque full-bleed square — macOS applies its own squircle mask at display time.
icon_opaque = icon.resize((1024, 1024), Image.Resampling.LANCZOS).convert("RGBA")

# AppMark: transparent outside squircle for in-app heroes on gradient backgrounds.
icon_mark = Image.new("RGBA", icon.size, (0, 0, 0, 0))
icon_mark.paste(icon, (0, 0), squircle_mask(icon.size[0]))

sizes = {
    "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
}
for name, px in sizes.items():
    icon_opaque.resize((px, px), Image.Resampling.LANCZOS).save(os.path.join(iconset, name))

icon_mark.resize((256, 256), Image.Resampling.LANCZOS).save(os.path.join(markset, "app-mark@1x.png"))
icon_mark.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(markset, "app-mark@2x.png"))
print("Generated opaque AppIcon + transparent AppMark from", src)
PY
