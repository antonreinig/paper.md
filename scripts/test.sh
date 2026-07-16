#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT/Editor"
npm test
npm run build

cd "$ROOT"
if [ ! -d PaperMD.xcodeproj ]; then
  ./scripts/bootstrap.sh
fi
xcodebuild test \
  -project PaperMD.xcodeproj \
  -scheme PaperMD \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO
