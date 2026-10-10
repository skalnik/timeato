#!/bin/sh
# Generates the Xcode project, builds the Release app, and prints its path.
# Put more xcodebuild arguments in the XCODEBUILD_ARGS environment variable.
set -eu

cd "$(dirname "$0")/.."

DERIVED_DATA="build/DerivedData"

xcodegen generate
# shellcheck disable=SC2086
xcodebuild \
  -scheme Timeato \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  ${XCODEBUILD_ARGS:-} \
  build

echo "Built app: $(pwd)/$DERIVED_DATA/Build/Products/Release/Timeato.app"
