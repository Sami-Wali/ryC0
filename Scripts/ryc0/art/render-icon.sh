#!/usr/bin/env bash
# Renders ryC0's icon from AppIcon.svg into every PNG the app uses, so the
# SVG stays the only source. Run it after changing the SVG, then commit the PNGs:
#
#   Scripts/ryc0/art/render-icon.sh
#
# Writes:
# - Resources/Assets.xcassets/AppIcon.appiconset: the icon, its dark variant (the
#   same art) and its tinted variant (white tiles on black, which iOS tints).
#   The Linux build resizes the first one into the loose AppIcon PNGs.
# - Resources/Assets.xcassets/AppIconGrey.appiconset and Resources/AppIconGrey*.png:
#   the grey icon LiveContainer gives a second copy of the app, in grey.
# - Resources/AppIcons/AppIcon<Name><size>.png: the icons Settings > Home Screen
#   offers instead, the grid on other colors.
# - Scripts/ryc0/art/icon-preview.png: the icon masked the way iOS shows it, for review.
#
# Needs rsvg-convert (librsvg) and ImageMagick.
set -euo pipefail
ART="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ART/../../.." && pwd)"
SVG="$ART/AppIcon.svg"
ICONS="$REPO/Resources/Assets.xcassets/AppIcon.appiconset"
GREY="$REPO/Resources/Assets.xcassets/AppIconGrey.appiconset"
MAGICK="$(command -v magick || command -v convert)"
command -v rsvg-convert >/dev/null || { echo "error: rsvg-convert is not on PATH" >&2; exit 1; }

# The gradient's two stops, which the tinted and grey icons recolor; the tiles
# stay white.
LIGHT='#E64BAE'
DARK='#A3156F'
BACKGROUND='#161616'

# render <size> <output> [sed expression]: the SVG, recolored by the expression,
# as an opaque RGB PNG (an app icon has no alpha channel).
render() {
    local size=$1 out=$2 recolor=${3:-}
    sed -e "${recolor:-s/^//}" "$SVG" | rsvg-convert -w "$size" -h "$size" |
        "$MAGICK" png:- -background "$BACKGROUND" -alpha remove -alpha off -strip "PNG24:$out"
}

TINTED="s/$LIGHT/#000000/g; s/$DARK/#000000/g"
GREYED="s/$LIGHT/#8E8E93/g; s/$DARK/#5A5A5E/g"

render 1024 "$ICONS/AppIcon1024.png"
render 1024 "$ICONS/AppIconDark1024.png"
render 1024 "$ICONS/AppIconDark1024 1.png" "$TINTED"
render 1024 "$GREY/AppIconGrey1024.png" "$GREYED"
render 1024 "$GREY/AppIconGreyDark1024.png" "$GREYED"
render 1024 "$GREY/AppIconGreyDark1024 1.png" "$TINTED"
render 120 "$REPO/Resources/AppIconGrey60x60@2x.png" "$GREYED"
render 152 "$REPO/Resources/AppIconGrey76x76@2x~ipad.png" "$GREYED"

# The icons Settings > Home Screen offers instead, at the sizes iOS asks for, in
# Resources/AppIcons, which the Linux build copies into the app and lists in
# Info.plist's CFBundleAlternateIcons by name. Keep the names in step with
# AppIconChoice.
ALTERNATES="$REPO/Resources/AppIcons"
mkdir -p "$ALTERNATES"
rm -f "$ALTERNATES"/*.png

# alternate <name> <svg> [sed expression]: one icon at iPhone 2x and 3x and iPad
# and iPad Pro 2x.
alternate() {
    local name=$1 svg=$2 recolor=${3:-}
    for size in 60x60@2x:120 60x60@3x:180 76x76@2x:152 83.5x83.5@2x:167; do
        sed -e "${recolor:-s/^//}" "$svg" | rsvg-convert -w "${size#*:}" -h "${size#*:}" |
            "$MAGICK" png:- -background "$BACKGROUND" -alpha remove -alpha off -strip "PNG24:$ALTERNATES/AppIcon$name${size%:*}.png"
    done
}

# The tiles are recolored first, so Light's white gradient doesn't turn pink too.
while read -r name light dark tiles; do
    alternate "$name" "$SVG" "s/#FFFFFF/$tiles/g; s/$LIGHT/$light/g; s/$DARK/$dark/g"
done <<'ICONS'
Purple #A855F7 #6D28D9 #FFFFFF
Blue   #60A5FA #1D4ED8 #FFFFFF
Teal   #2DD4BF #0F766E #FFFFFF
Green  #4ADE80 #15803D #FFFFFF
Orange #FDBA74 #EA580C #FFFFFF
Red    #F87171 #B91C1C #FFFFFF
Gold   #FCD34D #D97706 #FFFFFF
Mono   #48484A #0C0C0D #FFFFFF
Light  #FFFFFF #E9E9EE #DB2C99
ICONS

# The preview: the icon inside the shape iOS masks it to (continuous corners).
MASK='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><path fill="#fff" d="M281.3 0 L742.7 0 C823.7 0 864.2 0 907.8 13.8 C955.4 31.1 992.9 68.6 1010.2 116.2 C1024 159.8 1024 200.3 1024 281.3 L1024 742.7 C1024 823.7 1024 864.2 1010.2 907.8 C992.9 955.4 955.4 992.9 907.8 1010.2 C864.2 1024 823.7 1024 742.7 1024 L281.3 1024 C200.3 1024 159.8 1024 116.2 1010.2 C68.6 992.9 31.1 955.4 13.8 907.8 C0 864.2 0 823.7 0 742.7 L0 281.3 C0 200.3 0 159.8 13.8 116.2 C31.1 68.6 68.6 31.1 116.2 13.8 C159.8 0 200.3 0 281.3 0 Z"/></svg>'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
rsvg-convert -w 1024 -h 1024 "$SVG" -o "$tmp/icon.png"
printf '%s' "$MASK" | rsvg-convert -w 1024 -h 1024 -o "$tmp/mask.png"
"$MAGICK" "$tmp/icon.png" \( "$tmp/mask.png" -alpha extract \) -alpha off -compose CopyOpacity -composite -strip \
    "$ART/icon-preview.png"
echo "Rendered the icon from $SVG"
