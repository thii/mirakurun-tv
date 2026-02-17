#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV="$ROOT_DIR/.local/apple-tv.env"
DERIVED_DATA_PATH="$ROOT_DIR/.build/DerivedData"
PROJECT_PATH="$ROOT_DIR/JapanTV.xcodeproj"
SCHEME="JapanTV"

if [[ ! -f "$LOCAL_ENV" ]]; then
  echo "Missing $LOCAL_ENV"
  echo "Run scripts/configure-local-signing.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "$LOCAL_ENV"

if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "APPLE_TEAM_ID is missing in $LOCAL_ENV"
  exit 1
fi

if [[ -z "${APPLE_TV_DEVICE:-}" ]]; then
  echo "APPLE_TV_DEVICE is missing in $LOCAL_ENV"
  echo "Set it to your Apple TV name or UDID (devicectl --device accepts both)."
  exit 1
fi

APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.example.japantv}"

cd "$ROOT_DIR"

if [[ ! -d "$ROOT_DIR/Vendor/TVVLCKit.xcframework" ]]; then
  echo "Missing TVVLCKit dependency. Running fetch..."
  "$ROOT_DIR/scripts/fetch-tvvlckit.sh"
fi

echo "Generating project..."
xcodegen generate

echo "Building for Apple TV device '$APPLE_TV_DEVICE' with team '$APPLE_TEAM_ID'..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$APPLE_TV_DEVICE" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-appletvos/JapanTV.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found at: $APP_PATH"
  exit 1
fi

echo "Installing app on Apple TV..."
xcrun devicectl device install app --device "$APPLE_TV_DEVICE" "$APP_PATH"

echo "Launching app ($APP_BUNDLE_ID)..."
xcrun devicectl device process launch --device "$APPLE_TV_DEVICE" "$APP_BUNDLE_ID" --activate

echo "Install and launch complete."
