#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
for cfg in Debug Release; do
  [ -f "Config/$cfg.xcconfig" ] || cp "Config/$cfg.xcconfig.template" "Config/$cfg.xcconfig"
done
xcodegen generate
