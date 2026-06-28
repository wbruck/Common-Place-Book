#!/usr/bin/env bash
# Regenerate all app/favicon raster assets from the book artwork.
# Source of truth for the artwork is web/favicon.svg (transparent book).
# The orange-background icons (maskable + apple-touch) compose that book,
# scaled to the maskable safe zone, over a solid #D98324 background.
#
# Requires: Google Chrome (headless render) + macOS `sips` + python3.
set -euo pipefail
cd "$(dirname "$0")/../.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
GEN=tool/icon-gen

render() { # html out
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    "$3" --window-size=1024,1024 --screenshot="$2" "file://$PWD/$1" 2>/dev/null
}
render "$GEN/master-transparent.html" "$GEN/master-transparent.png" "--default-background-color=00000000"
render "$GEN/master-orange.html"      "$GEN/master-orange.png"      ""

T=$GEN/master-transparent.png; O=$GEN/master-orange.png
sips -z 512 512 "$T" --out web/icons/Icon-512.png            >/dev/null
sips -z 192 192 "$T" --out web/icons/Icon-192.png            >/dev/null
sips -z 32  32  "$T" --out web/favicon-32x32.png             >/dev/null
sips -z 16  16  "$T" --out web/favicon-16x16.png             >/dev/null
sips -z 512 512 "$O" --out web/icons/Icon-maskable-512.png   >/dev/null
sips -z 192 192 "$O" --out web/icons/Icon-maskable-192.png   >/dev/null
sips -z 180 180 "$O" --out web/apple-touch-icon.png          >/dev/null

python3 - <<'PY'
import struct
png = open("web/favicon-32x32.png","rb").read()
hdr   = struct.pack("<HHH", 0, 1, 1)
entry = struct.pack("<BBBBHHII", 32, 32, 0, 0, 1, 32, len(png), 6+16)
open("web/favicon.ico","wb").write(hdr+entry+png)
PY
echo "Regenerated web/ icons from $GEN masters."
