#!/usr/bin/env bash
# Regenerate all app/favicon raster assets from the book artwork.
# Source of truth for the artwork is web/favicon.svg (transparent book).
# The orange-background icons (maskable + apple-touch + Android legacy +
# iOS/macOS app icons) compose that book, scaled to the maskable safe zone,
# over a solid #D98324 background. The Android adaptive-icon foreground
# (master-adaptive-fg.html) scales the book to 0.58 so its bounding-box
# diagonal stays inside the 66/108dp adaptive safe-zone circle; the
# background layer is the flat color in values/ic_launcher_background.xml.
#
# Requires: Google Chrome (headless render) + macOS `sips` + python3.
set -euo pipefail
cd "$(dirname "$0")/../.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
GEN=tool/icon-gen

render() { # html out [extra-flag]
  # Newer Chrome rejects an empty '' argument as a second target URL, so
  # only pass $3 when set.
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    ${3:+"$3"} --window-size=1024,1024 --screenshot="$2" "file://$PWD/$1" 2>/dev/null
}
render "$GEN/master-transparent.html" "$GEN/master-transparent.png" "--default-background-color=00000000"
render "$GEN/master-orange.html"      "$GEN/master-orange.png"      ""
render "$GEN/master-adaptive-fg.html" "$GEN/master-adaptive-fg.png" "--default-background-color=00000000"

T=$GEN/master-transparent.png; O=$GEN/master-orange.png
sips -z 512 512 "$T" --out web/icons/Icon-512.png            >/dev/null
sips -z 192 192 "$T" --out web/icons/Icon-192.png            >/dev/null
sips -z 32  32  "$T" --out web/favicon-32x32.png             >/dev/null
sips -z 16  16  "$T" --out web/favicon-16x16.png             >/dev/null
sips -z 512 512 "$O" --out web/icons/Icon-maskable-512.png   >/dev/null
sips -z 192 192 "$O" --out web/icons/Icon-maskable-192.png   >/dev/null
sips -z 180 180 "$O" --out web/apple-touch-icon.png          >/dev/null

# Android launcher: legacy full-bleed icon (< API 26, 48dp basis) and the
# adaptive-icon foreground layer (API 26+, 108dp basis). The adaptive icon
# itself is res/mipmap-anydpi-v26/ic_launcher.xml (background color +
# this foreground), which Android prefers over the legacy pngs.
AND=android/app/src/main/res
F=$GEN/master-adaptive-fg.png
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  sips -z "${d#*:}" "${d#*:}" "$O" --out "$AND/mipmap-${d%%:*}/ic_launcher.png" >/dev/null
done
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  sips -z "${d#*:}" "${d#*:}" "$F" --out "$AND/mipmap-${d%%:*}/ic_launcher_foreground.png" >/dev/null
done

# iOS app icon set (filenames fixed by AppIcon.appiconset/Contents.json).
IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
for s in 20x20@1x:20 20x20@2x:40 20x20@3x:60 29x29@1x:29 29x29@2x:58 \
         29x29@3x:87 40x40@1x:40 40x40@2x:80 40x40@3x:120 60x60@2x:120 \
         60x60@3x:180 76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167 \
         1024x1024@1x:1024; do
  sips -z "${s#*:}" "${s#*:}" "$O" --out "$IOS/Icon-App-${s%%:*}.png" >/dev/null
done

# macOS app icon set.
MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset
for px in 16 32 64 128 256 512 1024; do
  sips -z "$px" "$px" "$O" --out "$MAC/app_icon_$px.png" >/dev/null
done

python3 - <<'PY'
import struct
png = open("web/favicon-32x32.png","rb").read()
hdr   = struct.pack("<HHH", 0, 1, 1)
entry = struct.pack("<BBBBHHII", 32, 32, 0, 0, 1, 32, len(png), 6+16)
open("web/favicon.ico","wb").write(hdr+entry+png)
PY
echo "Regenerated web/, Android, iOS, and macOS icons from $GEN masters."
