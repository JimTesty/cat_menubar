#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

SOURCE="${1:-Resources/AppIcon.png}"
OUTPUT="${2:-Resources/AppIcon.icns}"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cat-menubar-icon.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

ICONSET="$TEMP_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"

# Keep the source artwork as PNG, but package three standard macOS ICNS
# representations. These are enough for the app while avoiding the duplicate
# 1x/2x and legacy entries Finder stores in a pasted folder icon.
for size in 128 256 512; do
    sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
done

# An ICNS file is a header followed by typed length-prefixed image resources.
# ic07, ic08, and ic09 are the 128, 256, and 512 pixel PNG representations.
LC_ALL=C /usr/bin/perl -e '
    my @types = qw(ic07 ic08 ic09);
    my $output = pop @ARGV;
    my $body = "";

    for my $index (0 .. $#types) {
        open my $input, "<:raw", $ARGV[$index] or die "$ARGV[$index]: $!\n";
        local $/;
        my $png = <$input>;
        $body .= pack("a4N", $types[$index], 8 + length($png)) . $png;
    }

    open my $out, ">:raw", $output or die "$output: $!\n";
    print {$out} pack("a4N", "icns", 8 + length($body)), $body;
' \
    "$ICONSET/icon_128x128.png" \
    "$ICONSET/icon_256x256.png" \
    "$ICONSET/icon_512x512.png" \
    "$OUTPUT"

file "$OUTPUT"
