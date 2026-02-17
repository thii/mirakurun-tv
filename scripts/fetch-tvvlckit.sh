#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
VERSION="${1:-3.7.2}"

case "$VERSION" in
  3.7.2)
    ARCHIVE_URL="https://download.videolan.org/cocoapods/prod/TVVLCKit-3.7.2-3e42ae47-79128878.tar.xz"
    ;;
  3.7.0)
    ARCHIVE_URL="https://download.videolan.org/cocoapods/prod/TVVLCKit-3.7.0-591b8996-f9020c4d.tar.xz"
    ;;
  *)
    echo "Unsupported version: $VERSION"
    echo "Update this script with the URL from VideoLAN Packaging/TVVLCKit.json."
    exit 1
    ;;
esac

TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="$TMP_DIR/TVVLCKit.tar.xz"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Downloading TVVLCKit $VERSION..."
curl -L --fail --retry 3 -o "$ARCHIVE_PATH" "$ARCHIVE_URL"

echo "Extracting package..."
tar -xJf "$ARCHIVE_PATH" -C "$TMP_DIR"

SOURCE_DIR="$TMP_DIR/TVVLCKit-binary"
if [[ ! -d "$SOURCE_DIR/TVVLCKit.xcframework" ]]; then
  echo "TVVLCKit.xcframework not found in archive"
  exit 1
fi

mkdir -p "$VENDOR_DIR"
rm -rf "$VENDOR_DIR/TVVLCKit.xcframework"
cp -R "$SOURCE_DIR/TVVLCKit.xcframework" "$VENDOR_DIR/TVVLCKit.xcframework"
cp "$SOURCE_DIR/COPYING.txt" "$VENDOR_DIR/TVVLCKit-COPYING.txt"
cp "$SOURCE_DIR/NEWS.txt" "$VENDOR_DIR/TVVLCKit-NEWS.txt"

echo "TVVLCKit installed at: $VENDOR_DIR/TVVLCKit.xcframework"
