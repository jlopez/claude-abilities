#!/bin/sh
# Unit tests for artifact-hash (adoption record spec §3 hashing rules).
# Run: sh scripts/artifact-hash.test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
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

sha_of() { # hash of the argument's exact value, no trailing newline added
    printf '%s' "$1" | if command -v sha256sum >/dev/null 2>&1; then
        sha256sum
    else
        shasum -a 256
    fi | cut -d' ' -f1
}

sha_of_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum <"$1"
    else
        shasum -a 256 <"$1"
    fi | cut -d' ' -f1
}

fixture=$tmp/doc.md
cat >"$fixture" <<'EOF'
# Title

intro text

## Merging to main

Body line 1.

### Sub

sub text

## Other

#include <stdio.h> is not a heading

other text

EOF

# 1. Whole-file artifact: SHA-256 of exact bytes.
check "whole-file hash" \
    "sha256:$(sha_of_file "$fixture")" \
    "$("$AH" "$fixture")"

# 2. Middle section: includes its deeper subsection, stops before the next
#    same-depth heading, trailing blank line stripped.
expected='## Merging to main

Body line 1.

### Sub

sub text'
check "middle section with deeper subsection" \
    "sha256:$(sha_of "$expected")" \
    "$("$AH" "$fixture" "## Merging to main")"

# 3. Last section: runs to EOF; a 1..depth run of '#' not followed by
#    space/tab/EOL (e.g. "#include") is NOT a boundary; trailing blank lines
#    stripped.
expected='## Other

#include <stdio.h> is not a heading

other text'
check "last section to EOF, #include not a boundary" \
    "sha256:$(sha_of "$expected")" \
    "$("$AH" "$fixture" "## Other")"

# 4. Depth-1 section: no shallower-or-equal heading follows, so it spans to
#    EOF (deeper "##" headings are content, not boundaries).
expected=$(cat "$fixture")
check "depth-1 section spans deeper headings to EOF" \
    "sha256:$(sha_of "$expected")" \
    "$("$AH" "$fixture" "# Title")"

# 5. Heading match is exact — near-miss finds nothing.
out=$("$AH" "$fixture" "##  Merging to main")
check "near-miss heading -> missing" "missing/3" "$out/$?"

# 6. Missing file.
out=$("$AH" "$tmp/nope.md")
check "missing file -> missing" "missing/3" "$out/$?"

# 7. Missing file, section form.
out=$("$AH" "$tmp/nope.md" "## Anything")
check "missing file (section) -> missing" "missing/3" "$out/$?"

# 8. Boundary at equal depth cuts even when the section is first.
f2=$tmp/two.md
printf '## A\ntext a\n## B\ntext b\n' >"$f2"
expected='## A
text a'
check "adjacent same-depth boundary" \
    "sha256:$(sha_of "$expected")" \
    "$("$AH" "$f2" "## A")"

# 9. A bare "#" line (run of # followed by EOL) is a boundary.
f3=$tmp/bare.md
printf '## A\ntext a\n#\ntail\n' >"$f3"
expected='## A
text a'
check "bare # line is a boundary" \
    "sha256:$(sha_of "$expected")" \
    "$("$AH" "$f3" "## A")"

# 10. Section that is only its heading line.
f4=$tmp/only.md
printf '## Empty\n\n\n## Next\nx\n' >"$f4"
check "heading-only section" \
    "sha256:$(sha_of '## Empty')" \
    "$("$AH" "$f4" "## Empty")"

# 11. Usage errors exit 2.
"$AH" >/dev/null 2>&1
check "no args -> exit 2" "2" "$?"
"$AH" "$fixture" "not a heading" >/dev/null 2>&1
check "non-heading section arg -> exit 2" "2" "$?"

# 12. Whitespace-only trailing lines are stripped as blank.
f5=$tmp/ws.md
printf '## A\ntext a\n   \n\t\n## B\nx\n' >"$f5"
expected='## A
text a'
check "whitespace-only trailing lines stripped" \
    "sha256:$(sha_of "$expected")" \
    "$("$AH" "$f5" "## A")"

echo "----"
echo "pass: $pass  fail: $fail"
[ "$fail" -eq 0 ]
