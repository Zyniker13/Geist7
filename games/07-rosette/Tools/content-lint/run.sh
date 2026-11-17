#!/usr/bin/env bash
# content-lint/run.sh — validates every content JSON against the roadmap's
# schemas and the shared conventions (_CONVENTIONS §5 Content row,
# _SET2_ADDENDUM HIST3.1, game ROADMAP §5 + Appendix A).
#
# Checks:
#   1. Every content file parses and every row carries a history `label`
#      (HIST3.1) whose value is attested | reconstructed | invented.
#   2. Content ids are snake_case (§4.1) and unique per table.
#   3. Referential integrity: tavern→ruleset, tavern→opponent,
#      opponent→omens, ruleset→dice, circuit→taverns, fortune→ruleset/deck,
#      tutorial→ruleset; no dangling ids anywhere.
#   4. Counts meet the roadmap §5 counts table (G3 column minimums).
#   5. Dice weights sum to the model's denominator (R-17); omen costs in
#      the §6 5–40 band; circuit is 3 regions × 4 taverns (R-13).
#   6. docs/HISTORY.md agrees with rulesets.json labels (Appendix A.7).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTENT="$ROOT/Packages/RSContent/Sources/RSContent/Resources/Content"

ERRORS=0

python3 - "$CONTENT" "$ROOT" <<'PYEOF' || ERRORS=$((ERRORS + 1))
import json, os, re, sys

content_dir = sys.argv[1]
root = sys.argv[2]
errors = []

def load(name):
    path = os.path.join(content_dir, name)
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        errors.append(f"missing content file: {name}")
        return None
    except json.JSONDecodeError as e:
        errors.append(f"{name}: invalid JSON: {e}")
        return None

LABELS = {"attested", "reconstructed", "invented"}
SNAKE = re.compile(r"^[a-z][a-z0-9_]*$")

def check_rows(name, rows, id_required=True):
    if rows is None:
        return []
    ids = []
    for i, row in enumerate(rows):
        label = row.get("label")
        if label not in LABELS:
            errors.append(f"{name}[{i}]: label must be one of {sorted(LABELS)} (HIST3.1), got {label!r}")
        if id_required:
            rid = row.get("id")
            if not isinstance(rid, str) or not SNAKE.match(rid):
                errors.append(f"{name}[{i}]: id must be snake_case, got {rid!r}")
            ids.append(rid)
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        errors.append(f"{name}: duplicate ids {sorted(dupes)}")
    return ids

dice = load("dice.json")
rulesets = load("rulesets.json")
circuit = load("circuit.json")
taverns = load("taverns.json")
opponents = load("opponents.json")
omens = load("omens.json")
fortunes = load("fortunes.json")
tutorial = load("tutorial.json")
balance = load("balance.json")

dice_ids = check_rows("dice.json", dice)
ruleset_rows = check_rows("rulesets.json", rulesets)
tavern_rows = check_rows("taverns.json", taverns)
opponent_rows = check_rows("opponents.json", opponents)
omen_rows = check_rows("omens.json", omens)
check_rows("fortunes.json", fortunes, id_required=False)
check_rows("tutorial.json", tutorial)

if circuit is not None:
    if "startPurse" not in circuit or "finalCrawford" not in circuit:
        errors.append("circuit.json: needs startPurse and finalCrawford")
    regions = circuit.get("regions", [])
    if len(regions) != 3:
        errors.append(f"circuit.json: exactly 3 regions required (R-13), got {len(regions)}")
    listed = []
    region_ids = set()
    for region in regions:
        rid = region.get("id")
        if not isinstance(rid, str) or not SNAKE.match(rid):
            errors.append(f"circuit.json region id must be snake_case, got {rid!r}")
        if rid in region_ids:
            errors.append(f"circuit.json: duplicate region {rid!r}")
        region_ids.add(rid)
        tavern_list = region.get("taverns", [])
        if len(tavern_list) != 4:
            errors.append(f"region {rid!r}: must list exactly 4 taverns (R-13), got {len(tavern_list)}")
        listed.extend(tavern_list)
    if tavern_rows and set(listed) != set(tavern_rows):
        errors.append("circuit.json must list every tavern exactly once")

ruleset_ids = set(ruleset_rows or [])
tavern_ids = set(tavern_rows or [])
opponent_ids = set(opponent_rows or [])
omen_ids = set(omen_rows or [])
dice_ids = set(dice_ids or [])

if dice:
    for model in dice:
        total = sum(o.get("weight", 0) for o in model.get("outcomes", []))
        if total != model.get("denominator"):
            errors.append(
                f"dice.json {model.get('id')}: weights sum to {total}, denominator is {model.get('denominator')} (R-17)"
            )

if rulesets:
    for r in rulesets:
        if not r.get("source"):
            errors.append(f"rulesets.json {r.get('id')}: source citation required")
        if r.get("dice") not in dice_ids:
            errors.append(f"rulesets.json {r.get('id')}: unknown dice model {r.get('dice')!r}")

if taverns:
    for t in taverns:
        if t.get("ruleset") not in ruleset_ids:
            errors.append(f"taverns.json {t.get('id')}: unknown ruleset {t.get('ruleset')!r}")
        if t.get("opponent") not in opponent_ids:
            errors.append(f"taverns.json {t.get('id')}: unknown opponent {t.get('opponent')!r}")
        if t.get("minStake", 0) <= 0 or t.get("buyIn", 0) <= 0:
            errors.append(f"taverns.json {t.get('id')}: minStake and buyIn must be positive")

if opponents:
    for o in opponents:
        for omen_id in o.get("omens", []):
            if omen_id not in omen_ids:
                errors.append(f"opponents.json {o.get('id')}: unknown omen {omen_id!r}")

if omens:
    for om in omens:
        cost = om.get("cost", 0)
        if cost < 5 or cost > 40:
            errors.append(f"omens.json {om.get('id')}: cost {cost} outside the 5-40 band (§6)")
        effect = om.get("effect", {})
        if effect.get("kind") not in {"reroll", "unsafeRosettes", "split"}:
            errors.append(f"omens.json {om.get('id')}: effect kind not in the closed set (R-12)")

if fortunes:
    valid_decks = {"fortune_good", "fortune_bad"}
    for f in fortunes:
        if f.get("ruleset") not in ruleset_ids:
            errors.append(f"fortunes.json: unknown ruleset {f.get('ruleset')!r}")
        if f.get("omenDeck") not in valid_decks:
            errors.append(f"fortunes.json: unknown omenDeck {f.get('omenDeck')!r}")

if tutorial:
    for lesson in tutorial:
        if lesson.get("rulesetId") not in ruleset_ids:
            errors.append(f"tutorial.json {lesson.get('id')}: unknown ruleset {lesson.get('rulesetId')!r}")

# Counts table (roadmap §5, G3 column).
minimums = {"rulesets.json": (rulesets, 3), "taverns.json": (taverns, 6),
            "opponents.json": (opponents, 6), "omens.json": (omens, 6)}
for name, (rows, minimum) in minimums.items():
    if rows is not None and len(rows) < minimum:
        errors.append(f"{name}: {len(rows)} rows, needs at least {minimum} at G3")
if tutorial is not None and len(tutorial) < 3:
    errors.append(f"tutorial.json: {len(tutorial)} lessons, needs 3 (RS-P3.2)")

if balance is not None and not (8 <= balance.get("cubeMax", 0) <= 64):
    errors.append("balance.json: cubeMax must be in the 8-64 range (§6)")

# Appendix A.7: docs/HISTORY.md must agree with rulesets.json labels.
if rulesets:
    history_path = os.path.join(root, "docs", "HISTORY.md")
    try:
        with open(history_path) as f:
            history = f.read()
        for r in rulesets:
            marker = f"ruleset:{r['id']}"
            if marker not in history:
                errors.append(f"HISTORY.md: missing ruleset marker {marker}")
            else:
                line_start = history.index(marker)
                line = history[line_start:history.find("\n", line_start)]
                if str(r["label"]) not in line:
                    errors.append(
                        f"HISTORY.md: ruleset:{r['id']} line must state its label ({r['label']})"
                    )
    except FileNotFoundError:
        errors.append("docs/HISTORY.md missing (HIST0.1)")

if errors:
    for e in errors:
        print(f"content-lint: ERROR: {e}", file=sys.stderr)
    sys.exit(1)
print(f"content-lint: OK ({len(rulesets or [])} rulesets, {len(taverns or [])} taverns, "
      f"{len(opponents or [])} opponents, {len(omens or [])} omens, "
      f"{len(fortunes or [])} fortunes, {len(tutorial or [])} lessons)")
PYEOF

if [ "$ERRORS" -gt 0 ]; then
    echo "content-lint: $ERRORS violation(s) found"
    exit 1
fi
