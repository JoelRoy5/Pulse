#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
for cfg in Debug Release; do
  [ -f "Config/$cfg.xcconfig" ] || cp "Config/$cfg.xcconfig.template" "Config/$cfg.xcconfig"
done
command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; }
xcodegen generate
