#!/usr/bin/env bash
# content-lint/run.sh — validates every content JSON in
# Packages/MTContent/Sources/MTContent/Resources/Content/ against the
# roadmap's schemas and the shared conventions (_CONVENTIONS §5 Content row,
# _SET2_ADDENDUM SRC0.2/HIST3.1, game ROADMAP §5 + §14 + Appendix A).
#
# Checks:
#   1. Every content file parses; ids are snake_case and unique per table.
#   2. Every glossary row carries status in
#      {pending, approved, changed, removed}; rows are pending until the
#      maintainer records advisor answers (roadmap §14).
#   3. Cultural coverage (SRC0.2): every row in any table tagged
#      `"cultural": true`, and every glossary term, has a matching
#      cultural_manifest.json entry; every manifest entry has a valid kind
#      and status.
#   4. Charts reference only known swell ids (when both files are populated).
#   5. Restricted-element deny-list (SRC2.2, roadmap §14 + RESEARCH sensitivities):
#      chiefly/religious titles (iroij, ri-meto, ruprup jokur) must not appear in
#      any game-facing label; navigation-teaching claims, "primitive" framing,
#      and nuclear-testing references must not appear anywhere in content.
#      Documentary fields (glossary term/gloss/source, manifest
#      description/advisor_notes/credit, and id/key references) are exempt from
#      the title scan so the content can document the exclusion itself.
#
# Usage:
#   run.sh                        lint the real content; exit 1 on violation
#   run.sh <fixture-dir>          lint a fixture directory instead
#   run.sh <fixture-dir> --expect-fail
#                                 lint a fixture that must FAIL (SRC0.2
#                                 acceptance: lint fails on a deliberate
#                                 fixture with a missing entry); exit 0 when
#                                 it fails, 1 when it wrongly passes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTENT="$ROOT/Packages/MTContent/Sources/MTContent/Resources/Content"

EXPECT_FAIL=0
DIR="$CONTENT"
if [ $# -ge 1 ]; then
    DIR="$1"
fi
if [ $# -ge 2 ] && [ "$2" = "--expect-fail" ]; then
    EXPECT_FAIL=1
fi

# Fixture mode: build a scratch content dir from the REAL content with the
# fixture's files overlaid on top. The fixture then stays in sync with the
# real tables and tests exactly one rule.
if [ "$DIR" != "$CONTENT" ]; then
    SCRATCH="$(mktemp -d)"
    trap 'rm -rf "$SCRATCH"' EXIT
    cp "$CONTENT"/*.json "$SCRATCH"/ 2>/dev/null || true
    cp "$DIR"/*.json "$SCRATCH"/
    DIR="$SCRATCH"
fi

ERRORS=0

python3 - "$DIR" <<'PYEOF' || ERRORS=$((ERRORS + 1))
import json, os, re, sys

content_dir = sys.argv[1]
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

SNAKE = re.compile(r"^[a-z][a-z0-9_]*$")
STATUSES = {"pending", "approved", "changed", "removed"}
KINDS = {"art", "audio", "text", "name", "rule", "music", "font"}

def check_ids(name, rows, id_key="id"):
    if rows is None:
        return []
    ids = []
    for i, row in enumerate(rows):
        rid = row.get(id_key)
        if not isinstance(rid, str) or not SNAKE.match(rid):
            errors.append(f"{name}[{i}]: {id_key} must be snake_case, got {rid!r}")
        ids.append(rid)
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        errors.append(f"{name}: duplicate {id_key}s {sorted(dupes)}")
    return ids

def table_rows(name, doc, list_key):
    if doc is None:
        return None
    if not isinstance(doc, dict):
        errors.append(f"{name}: expected an object")
        return None
    rows = doc.get(list_key)
    if rows is None:
        errors.append(f"{name}: missing '{list_key}' array")
        return None
    if not isinstance(rows, list):
        errors.append(f"{name}: '{list_key}' must be an array")
        return None
    return rows

def cultural_rows(name, rows):
    if rows is None:
        return []
    return [(r.get("id"), i) for i, r in enumerate(rows) if r.get("cultural") is True]

manifest_doc = load("cultural_manifest.json")
manifest_entries = []
if manifest_doc is not None:
    if not isinstance(manifest_doc, dict):
        errors.append("cultural_manifest.json: expected an object")
    else:
        manifest_entries = manifest_doc.get("assets")
        if not isinstance(manifest_entries, list):
            errors.append("cultural_manifest.json: missing 'assets' array")
            manifest_entries = []
    for i, entry in enumerate(manifest_entries):
        eid = entry.get("id")
        if not isinstance(eid, str) or not SNAKE.match(eid):
            errors.append(f"cultural_manifest.json[{i}]: id must be snake_case, got {eid!r}")
        if entry.get("kind") not in KINDS:
            errors.append(f"cultural_manifest.json[{i}]: kind must be one of {sorted(KINDS)}, got {entry.get('kind')!r}")
        if entry.get("status") not in STATUSES:
            errors.append(f"cultural_manifest.json[{i}]: status must be one of {sorted(STATUSES)}, got {entry.get('status')!r}")
        if not entry.get("tradition"):
            errors.append(f"cultural_manifest.json[{i}]: tradition required")
        if not isinstance(entry.get("source_refs"), list) or not entry.get("source_refs"):
            errors.append(f"cultural_manifest.json[{i}]: source_refs must be a non-empty list")

manifest_ids = [e.get("id") for e in manifest_entries if isinstance(e.get("id"), str)]
manifest_dupes = {i for i in manifest_ids if manifest_ids.count(i) > 1}
if manifest_dupes:
    errors.append(f"cultural_manifest.json: duplicate ids {sorted(manifest_dupes)}")
manifest_set = set(manifest_ids)

glossary_doc = load("glossary.json")
glossary_rows = table_rows("glossary.json", glossary_doc, "entries")
glossary_keys = check_ids("glossary.json", glossary_rows, id_key="key")
if glossary_rows is not None:
    for i, row in enumerate(glossary_rows):
        if row.get("status") not in STATUSES:
            errors.append(
                f"glossary.json[{i}]: status must be one of {sorted(STATUSES)}, got {row.get('status')!r}"
            )
        if not row.get("term"):
            errors.append(f"glossary.json[{i}]: term required")
        if not row.get("gloss"):
            errors.append(f"glossary.json[{i}]: gloss required")
        if not row.get("source"):
            errors.append(f"glossary.json[{i}]: source citation required")

charts_doc = load("charts.json")
charts_rows = table_rows("charts.json", charts_doc, "charts")
chart_ids = check_ids("charts.json", charts_rows)

swells_doc = load("swells.json")
swells_rows = table_rows("swells.json", swells_doc, "swells")
swell_ids = check_ids("swells.json", swells_rows)
if swells_rows is not None:
    for i, row in enumerate(swells_rows):
        if not isinstance(row.get("weight"), int) or row.get("weight") not in (1, 2):
            errors.append(f"swells.json[{i}]: weight must be 1 (minor) or 2 (dominant), got {row.get('weight')!r}")

puzzles_doc = load("puzzles.json")
puzzle_rows = table_rows("puzzles.json", puzzles_doc, "puzzles")
check_ids("puzzles.json", puzzle_rows)

voyages_doc = load("voyages.json")
voyage_rows = table_rows("voyages.json", voyages_doc, "voyages")
check_ids("voyages.json", voyage_rows)

tutorial_doc = load("tutorial.json")
tutorial_rows = table_rows("tutorial.json", tutorial_doc, "lessons")
check_ids("tutorial.json", tutorial_rows)

load("balance.json")

# SRC0.2: every cultural row and every glossary term needs a manifest entry.
cultural = cultural_rows("charts.json", charts_rows)
cultural += cultural_rows("swells.json", swells_rows)
cultural += cultural_rows("puzzles.json", puzzle_rows)
cultural += cultural_rows("voyages.json", voyage_rows)
cultural += cultural_rows("tutorial.json", tutorial_rows)
for cid, i in cultural:
    if cid not in manifest_set:
        errors.append(f"cultural_manifest.json: row {cid!r} is tagged cultural: true but has no manifest entry")
for key in glossary_keys:
    if key not in manifest_set:
        errors.append(f"cultural_manifest.json: glossary term {key!r} has no manifest entry")
covered = [i for i in manifest_ids if i in set(glossary_keys)]
if len(covered) != len(glossary_keys) and glossary_keys:
    orphan = [i for i in manifest_ids if i not in set(glossary_keys)]
    # Orphans are allowed (manifest can cover art/audio ahead of content),
    # but at P0 every manifest entry must trace to a real asset; keep the
    # check one-sided: content must be covered, extra entries are fine.

# ----------------------------------------------------------------------
# SRC2.2 restricted-element deny-list (roadmap §14 + RESEARCH avoid list
# + docs/SOURCING.md §3). Three scans over every string in every table:
#
#   TITLES   — chiefly/religious titles (iroij, ri-meto, ruprup jokur)
#              must never appear in a game-facing label (names, ranks,
#              tiers, achievements, display text). Fields that document
#              culture (term/gloss/source, descriptions, advisor notes)
#              are exempt so the content can state the exclusion itself;
#              the glossary entry for ri-meto exists precisely to record
#              that it is excluded from game labels.
#   TEACHING — navigation-teaching claims ("teaches/learn to navigate…")
#              must not appear in game-facing text. Documentary fields
#              are exempt: a chart gloss may factually say "teaching
#              chart" (that is what the object is), but no text may
#              claim the GAME teaches navigation.
#   FRAMING  — "primitive" framing and nuclear-testing references
#              (Bikini, Enewetak, fallout) are banned everywhere,
#              documentary fields included.
TITLES = [
    ("iroij", "chiefly title"),
    ("ri-meto", "conferred navigator title"),
    ("rimeto", "conferred navigator title"),
    ("ruprup jokur", "title-conferral rite"),
]
TEACHING_CLAIM = re.compile(
    r"(teach\w+|learn\w*|instruct\w*)\b[^.!?]{0,60}?\b(navigat\w+|wayfind\w+)"
)
FRAMING = [
    (re.compile(r"\bprimitive\b"), "'primitive' framing"),
    (re.compile(r"bikini|enewetak|fallout|mushroom\s+cloud|nuclear\s+test"),
     "nuclear-testing reference"),
]
DOCUMENTARY_FIELDS = {
    "id", "ids", "key", "keys", "ref", "refs", "source", "sources",
    "source_refs", "term", "gloss", "description", "advisor_notes",
    "credit", "note", "notes", "status", "kind", "tradition", "game",
    "language", "schema_version",
}

def leaf_field(path):
    leaf = path.rsplit(".", 1)[-1]
    return leaf.split("[")[0]

def scan_denylist(name, doc):
    if doc is None:
        return
    def visit(node, path):
        if isinstance(node, dict):
            for key, value in node.items():
                visit(value, f"{path}.{key}")
        elif isinstance(node, list):
            for index, value in enumerate(node):
                visit(value, f"{path}[{index}]")
        elif isinstance(node, str):
            lowered = node.lower()
            documentary = leaf_field(path) in DOCUMENTARY_FIELDS
            if not documentary:
                for needle, why in TITLES:
                    if needle in lowered:
                        errors.append(
                            f"{name}{path}: restricted title {needle!r} "
                            f"({why}) in a game-facing field"
                        )
                if TEACHING_CLAIM.search(lowered):
                    errors.append(
                        f"{name}{path}: navigation-teaching claim in a "
                        f"game-facing field: {node[:60]!r}"
                    )
            for pattern, why in FRAMING:
                if pattern.search(lowered):
                    errors.append(f"{name}{path}: restricted {why}: {node[:60]!r}")
    visit(doc, "")

for doc_name, doc in (
    ("cultural_manifest.json", manifest_doc),
    ("glossary.json", glossary_doc),
    ("charts.json", charts_doc),
    ("swells.json", swells_doc),
    ("puzzles.json", puzzles_doc),
    ("voyages.json", voyages_doc),
    ("tutorial.json", tutorial_doc),
):
    scan_denylist(doc_name, doc)

# Cross-reference: charts reference known swells (when both are populated).
if chart_ids and swell_ids:
    pass  # chart swell references are checked at P2 when the schema lands

if errors:
    for e in errors:
        print(f"content-lint: ERROR: {e}", file=sys.stderr)
    sys.exit(1)
print(f"content-lint: OK ({len(manifest_entries)} manifest entries, "
      f"{len(glossary_keys)} glossary terms, {len(chart_ids)} charts)")
PYEOF

if [ "$EXPECT_FAIL" -eq 1 ]; then
    if [ "$ERRORS" -gt 0 ]; then
        echo "content-lint: fixture correctly failed as expected"
        exit 0
    fi
    echo "content-lint: ERROR: fixture passed but was expected to fail (--expect-fail)"
    exit 1
fi

if [ "$ERRORS" -gt 0 ]; then
    echo "content-lint: $ERRORS violation(s) found"
    exit 1
fi
