#!/usr/bin/env bash
# check-imports.sh — ensure no banned APIs or imports in Core packages
# (_CONVENTIONS determinism ban; Dry Garden roadmap S0.1, DG-P0.1).
#
# Banned in DGCore (and DGContent/DGAI when they arrive):
#   SystemRandomNumberGenerator, Int.random(in:), Date(), UUID()
#   Float/Double computation in Core (Fixed Q32.32 only; sanctioned
#   conversions at boundaries keep the boundary explicit)
#   UIKit / AppKit / SwiftUI / SpriteKit / GameKit (platform and UI
#   frameworks live in the App layer and later packages)
#
# Allowed in tests, Tools, App targets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BANNED_PATTERNS=(
    'SystemRandomNumberGenerator'
    'Int.random('
    'Date()'
    'UUID()'
    'import UIKit'
    'import AppKit'
    'import SwiftUI'
    'import SpriteKit'
    'import GameKit'
)

ERRORS=0

for pkg_dir in DGCore DGContent DGAI; do
    src="$ROOT/Packages/$pkg_dir/Sources"
    [ -d "$src" ] || continue
    for f in $(find "$src" -name '*.swift'); do
        for pat in "${BANNED_PATTERNS[@]}"; do
            # -F: fixed strings — the patterns contain parentheses.
            if grep -nF "$pat" "$f" >/dev/null 2>&1; then
                echo "ERROR: $f: banned pattern '$pat' found"
                ERRORS=$((ERRORS + 1))
            fi
        done
    done
done

if [ "$ERRORS" -gt 0 ]; then
    echo "check-imports.sh: $ERRORS violation(s) found"
    exit 1
fi

echo "check-imports.sh: OK"
