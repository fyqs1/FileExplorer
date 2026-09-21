#!/bin/bash
# Build FileExplorer and pack a TrollStore-friendly IPA (ldid entitlements).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED="$ROOT/build"
ARCHIVE_DIR="$DERIVED/Build/Products"
CONFIG="Release"
SDK="iphoneos"
ENTITLEMENTS="$ROOT/FileExplorer/FileExplorer.entitlements"
LDID_BIN="$(command -v ldid || command -v ldid2 || true)"

echo "[1/5] Generate Xcode project (xcodegen)"
xcodegen generate

echo "[2/5] Clean derived data folder"
rm -rf "$DERIVED"
mkdir -p "$DERIVED"

echo "[3/5] xcodebuild ($CONFIG / $SDK), Apple signing disabled"
xcodebuild \
  -project FileExplorer.xcodeproj \
  -scheme FileExplorer \
  -configuration "$CONFIG" \
  -sdk "$SDK" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ONLY_ACTIVE_ARCH=NO \
  build

APP="$ARCHIVE_DIR/$CONFIG-$SDK/FileExplorer.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: app not found at $APP" >&2
  exit 1
fi

echo "[4/5] Embed entitlements with ldid"
if [[ -z "$LDID_BIN" ]]; then
  echo "ERROR: ldid/ldid2 not found. brew install ldid" >&2
  exit 1
fi
if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "ERROR: missing $ENTITLEMENTS" >&2
  exit 1
fi
cp "$ENTITLEMENTS" "$APP/FileExplorer.entitlements"
"$LDID_BIN" -S"$ENTITLEMENTS" "$APP/FileExplorer"
"$LDID_BIN" -S"$ENTITLEMENTS" "$APP"

echo "[5/5] Package IPA"
STAGE="$DERIVED/ipa_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
(
  cd "$STAGE"
  rm -f "$ROOT/FileExplorer.ipa"
  zip -qr "$ROOT/FileExplorer.ipa" Payload
)

echo "OK: $ROOT/FileExplorer.ipa"
ls -lh "$ROOT/FileExplorer.ipa"
echo "Entitlements check:"
"$LDID_BIN" -e "$APP/FileExplorer" | head -40
