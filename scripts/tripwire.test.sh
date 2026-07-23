#!/bin/sh
# Unit tests for tripwire (adoption record spec §4 tripwire semantics).
# Hermetic: upstream is a local directory reached via --map / path sources —
# no network, no real clones. Run: sh scripts/tripwire.test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
TW=$here/tripwire
AH=$here/artifact-hash
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

check() { # desc expected actual
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
    fi
}

# One-shot runner: prints "<exit>|<output with newlines as ;>".
run() {
    out=$("$@" 2>/dev/null)
    printf '%s|%s' "$?" "$(printf '%s' "$out" | tr '\n' ';')"
}

# Extract "<status>" of a given kind/detail from tripwire output.
field() { # kind [detail] <<< output ... use: printf '%s\n' "$out" | field kind
    awk -F'\t' -v k="$1" '$2 == k { print $3; exit }'
}

# --- fixture: upstream ability + adopting repo ------------------------------
up=$tmp/upstream
mkdir -p "$up/test-ability"
cat >"$up/test-ability/ABILITY.md" <<'EOF'
---
id: test-ability
name: Test ability
description: fixture
version: 1.2.0
mode: guideline
config: {}
artifacts:
  - A "Policy" section in NOTES.md
  - A script at any path
changelog:
  - version: 1.2.0
    date: 2026-07-01
    intent: fixture
---
body
EOF

repo=$tmp/repo
mkdir -p "$repo/.claude/abilities" "$repo/scripts"
cat >"$repo/NOTES.md" <<'EOF'
# Notes

## Policy

Policy body.

## Unrelated

Other text.
EOF
printf '#!/bin/sh\necho hi\n' >"$repo/scripts/hook"

h_section=$("$AH" "$repo/NOTES.md" "## Policy")
h_file=$("$AH" "$repo/scripts/hook")

record() { # $1 = baseline; writes the record fresh
    cat >"$repo/.claude/abilities/test-ability.md" <<EOF
---
id: test-ability
source: example/abilities
baseline: $1
mode: guideline
adopted: 2026-07-01
config: {}
artifacts:
  - path: NOTES.md
    section: "## Policy"
    hash: $h_section
    description: section artifact
  - path: scripts/hook
    hash: $h_file
    description: whole-file artifact
---

## 2026-07-01 — Adopted at $1

Fixture adoption.
EOF
}

MAP="--map example/abilities=$up"

# 1. Everything clean, baseline current.
record 1.2.0
out=$("$TW" -C "$repo" $MAP); st=$?
check "clean: exit 0" "0" "$st"
check "clean: wire" "clean" "$(printf '%s\n' "$out" | field wire)"
check "clean: baseline current" "current" "$(printf '%s\n' "$out" | field baseline)"
check "clean: both artifacts clean" "2" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "artifact" && $3 == "clean"' | wc -l | tr -d ' ')"

# 2. Unrelated edit in the shared file does not trip the section artifact.
printf '\nMore unrelated text.\n' >>"$repo/NOTES.md"
out=$("$TW" -C "$repo" $MAP); st=$?
check "unrelated edit: still exit 0" "0" "$st"

# 3. Edit inside the section -> changed, wire tripped, exit 1.
perl -pi -e 's/Policy body\./Policy body, evolved./' "$repo/NOTES.md" 2>/dev/null \
    || sed -i.bak 's/Policy body\./Policy body, evolved./' "$repo/NOTES.md"
out=$("$TW" -C "$repo" $MAP); st=$?
check "section edit: exit 1" "1" "$st"
check "section edit: wire tripped" "tripped" "$(printf '%s\n' "$out" | field wire)"
check "section edit: artifact changed" "changed" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "artifact" && $4 == "NOTES.md" { print $3; exit }')"
check "section edit: other artifact clean" "clean" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "artifact" && $4 == "scripts/hook" { print $3; exit }')"

# 4. Heading renamed -> missing.
record 1.2.0 # refresh hashes against current NOTES.md
h_section=$("$AH" "$repo/NOTES.md" "## Policy")
record 1.2.0
sed -i.bak 's/^## Policy$/## Our policy/' "$repo/NOTES.md"
out=$("$TW" -C "$repo" $MAP); st=$?
check "renamed heading: exit 1" "1" "$st"
check "renamed heading: missing" "missing" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "artifact" && $4 == "NOTES.md" { print $3; exit }')"
sed -i.bak 's/^## Our policy$/## Policy/' "$repo/NOTES.md"
rm -f "$repo/NOTES.md.bak"

# 5. Whole-file artifact deleted -> missing, tripped.
mv "$repo/scripts/hook" "$repo/scripts/hook.save"
out=$("$TW" -C "$repo" $MAP); st=$?
check "deleted file: exit 1" "1" "$st"
check "deleted file: missing" "missing" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "artifact" && $4 == "scripts/hook" { print $3; exit }')"
mv "$repo/scripts/hook.save" "$repo/scripts/hook"

# 6. Baseline behind -> tripped even with clean artifacts.
record 1.1.0
out=$("$TW" -C "$repo" $MAP); st=$?
check "behind: exit 1" "1" "$st"
check "behind: baseline status" "behind" "$(printf '%s\n' "$out" | field baseline)"
check "behind: latest reported" "1.1.0" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "baseline" { print $4; exit }')"

# 7. Baseline ahead (adopted from a clone ahead of its remote) -> not tripped.
record 1.3.0
out=$("$TW" -C "$repo" $MAP); st=$?
check "ahead: exit 0" "0" "$st"
check "ahead: baseline status" "ahead" "$(printf '%s\n' "$out" | field baseline)"

# 8. --local skips the upstream half.
record 1.0.0 # far behind, but --local must not care
out=$("$TW" -C "$repo" --local); st=$?
check "--local: exit 0 despite behind baseline" "0" "$st"
check "--local: baseline skipped" "skipped" "$(printf '%s\n' "$out" | field baseline)"

# 9. Named id with no record -> error line, exit 3.
out=$("$TW" -C "$repo" $MAP no-such-ability); st=$?
check "no record: exit 3" "3" "$st"
check "no record: error line" "no-such-ability" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "error" { print $1; exit }')"

# 10. No records at all -> exit 3, no stdout facts.
empty=$tmp/empty
mkdir -p "$empty"
out=$("$TW" -C "$empty" 2>/dev/null); st=$?
check "no records: exit 3" "3" "$st"
check "no records: empty stdout" "" "$out"

# 11. Unresolvable upstream (path source that does not exist) -> unknown, exit 4.
record 1.2.0
sed -i.bak "s|source: example/abilities|source: $tmp/nowhere|" \
    "$repo/.claude/abilities/test-ability.md"
out=$("$TW" -C "$repo"); st=$?
check "unresolvable upstream: exit 4" "4" "$st"
check "unresolvable upstream: baseline unknown" "unknown" \
    "$(printf '%s\n' "$out" | field baseline)"
check "unresolvable upstream: wire unknown" "unknown" \
    "$(printf '%s\n' "$out" | field wire)"

# 12. Path-type source works without --map.
sed -i.bak "s|source: $tmp/nowhere|source: $up|" \
    "$repo/.claude/abilities/test-ability.md"
out=$("$TW" -C "$repo"); st=$?
check "path source: exit 0" "0" "$st"
rm -f "$repo/.claude/abilities/test-ability.md.bak"

# 13. Two records: one clean, one tripped -> exit 1, per-ability wires.
record 1.2.0
up2=$tmp/upstream2
mkdir -p "$up2/other-ability"
cat >"$up2/other-ability/ABILITY.md" <<'EOF'
---
id: other-ability
version: 2.0.0
---
EOF
printf 'content\n' >"$repo/owned.txt"
cat >"$repo/.claude/abilities/other-ability.md" <<EOF
---
id: other-ability
source: $up2
baseline: 2.0.0
mode: faithful
adopted: 2026-07-01
config: {}
artifacts:
  - path: owned.txt
    hash: $("$AH" "$repo/owned.txt")
---
EOF
printf 'edited\n' >"$repo/owned.txt"
out=$("$TW" -C "$repo" $MAP); st=$?
check "two records: exit 1" "1" "$st"
check "two records: test-ability clean" "clean" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "test-ability" && $2 == "wire" { print $3 }')"
check "two records: other-ability tripped" "tripped" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "other-ability" && $2 == "wire" { print $3 }')"

# 14. Record id mismatching its filename -> error, tripped.
sed -i.bak 's/^id: other-ability$/id: wrong-id/' "$repo/.claude/abilities/other-ability.md"
printf 'content\n' >"$repo/owned.txt" # artifacts back to clean
out=$("$TW" -C "$repo" $MAP other-ability); st=$?
check "id mismatch: exit 1" "1" "$st"
check "id mismatch: error line present" "1" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "error" && $3 ~ /does not match/' | wc -l | tr -d ' ')"
rm -f "$repo/.claude/abilities/other-ability.md" "$repo/.claude/abilities/other-ability.md.bak"

# 15. Named-id selection: only the named ability is checked.
out=$("$TW" -C "$repo" $MAP test-ability); st=$?
check "named id: exit 0" "0" "$st"
check "named id: single wire line" "1" \
    "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "wire"' | wc -l | tr -d ' ')"

echo "----"
echo "pass: $pass  fail: $fail"
[ "$fail" -eq 0 ]
