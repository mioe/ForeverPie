#!/bin/sh
# Packs the addon into ForeverPie-v<version>.zip, with the version taken from the .toc file.
# Usage: ./pack.sh
set -eu

cd "$(dirname "$0")"

ADDON="ForeverPie"
TOC="$ADDON/$ADDON.toc"

VERSION=$(sed -n 's/^## Version:[[:space:]]*//p' "$TOC" | tr -d '\r' | head -n 1)
if [ -z "$VERSION" ]; then
	echo "No \"## Version:\" line in $TOC" >&2
	exit 1
fi

ARCHIVE="$ADDON-v$VERSION.zip"
rm -f "$ARCHIVE"
# -X and the exclude keep macOS service files out of the archive.
zip -r -X -q "$ARCHIVE" "$ADDON" -x "*.DS_Store"

echo "Created $ARCHIVE:"
unzip -l "$ARCHIVE"
