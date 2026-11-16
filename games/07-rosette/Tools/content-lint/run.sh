#!/usr/bin/env bash
# content-lint/run.sh — skeleton for content validation.
#
# Checks:
#   1. No human-readable strings in Sources/ (all UI strings go through localization).
#   2. All .png/.jpg/.webp assets have a corresponding .json metadata file.
#   3. No copyrighted text in Resources/Content.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ERRORS=0

# Check 1: no hardcoded UI strings in Sources (allow comments and doc comments)
echo "Checking for hardcoded UI strings in Sources..."
# TODO: implement full check when P1 content is added
echo "  (skeleton — no violations yet)"

# Check 2: asset metadata
echo "Checking asset metadata..."
# TODO: implement when assets are added

# Check 3: no copyrighted content
echo "Checking for copyrighted content..."
# TODO: implement when content is added

if [ "$ERRORS" -gt 0 ]; then
    echo "content-lint: $ERRORS violation(s) found"
    exit 1
fi

echo "content-lint: OK"
