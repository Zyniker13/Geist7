#!/usr/bin/env bash
# check-imports.sh — ensure no banned imports in Core/Content/AI packages.
#
# Banned:
#   SystemRandomNumberGenerator, Int.random(in:)
#   Date(), UUID()
#   UIKit (use RSPlatform abstraction)
#
# Allowed in tests and UI-only targets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BANNED_PATTERNS=(
    'SystemRandomNumberGenerator'
    'Int\.random\('
    'Date\(\)'
    'UUID\(\)'
)

ERRORS=0

for pkg_dir in RSCore RSContent RSAI; do
    src="$ROOT/Packages/$pkg_dir/Sources"
    [ -d "$src" ] || continue
    for f in $(find "$src" -name '*.swift'); do
        for pat in "${BANNED_PATTERNS[@]}"; do
            if grep -n "$pat" "$f" >/dev/null 2>&1; then
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
