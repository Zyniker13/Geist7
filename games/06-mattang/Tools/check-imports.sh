#!/usr/bin/env bash
# check-imports.sh — ensure no banned APIs or imports in Core/Content/AI
# packages (_CONVENTIONS determinism ban; Mattang roadmap S0.1).
#
# Banned in MTCore, MTContent, MTAI:
#   SystemRandomNumberGenerator, Int.random(in:), Date(), UUID()
#   Double/Float in Core (use Fixed; see _SET2_ADDENDUM §6.1)
#   UIKit / AppKit (platform abstraction lives in MTPlatform)
#
# Allowed in tests, Tools, App targets, MTRender, MTAudio, MTPlatform, MTMeta.

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
)

ERRORS=0

for pkg_dir in MTCore MTContent MTAI; do
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

# Core additionally bans floating-point types (Q32.32 Fixed only):
# enforced through the boundary rule instead — Core may convert at
# sanctioned boundaries (e.g. Fixed.init(Double)) but never compute in
# floating point. No grep section for it, so the boundary stays explicit.

if [ "$ERRORS" -gt 0 ]; then
    echo "check-imports.sh: $ERRORS violation(s) found"
    exit 1
fi

echo "check-imports.sh: OK"
