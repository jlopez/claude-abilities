# Adoption record — normative spec

> Status: normative as of 2026-07-23 (roadmap item 1). This finalizes
> [design §4](../design.md#4-adoption-record-the-manifest). If this spec and
> the design doc disagree, this spec wins for the record's shape; the design
> doc wins for intent.

The adoption record is the per-repo record of one adopted ability. It solves
the identity problem: an adopted ability dissolves into the repo's native
primitives, and without a record every later operation starts with
archaeology. It is an **adoption record, not a lockfile** — its readers are,
in order of frequency:

1. the **tripwire script** (cheap, mechanical: "did anything move on either
   side?"),
2. a **future agent** running `/abilities.diff`, `update`, `remove`, or
   `publish`,
3. a human skimming the repo's relationship with the ability.

Everything in this spec serves those three readers. Structured facts go in
frontmatter (reader 1 parses it); judgment, history, and reasons go in the
prose body (readers 2–3 read it).

## 1. Location and naming

One file per adopted ability in the **target repo**:

```
.claude/abilities/<id>.md
```

- `<id>` is the ability id exactly as declared in the ability's `ABILITY.md`
  frontmatter.
- The file is markdown with a YAML frontmatter block.
- The file is committed and travels with the repo — collaborators get the
  record without having the plugin installed. It is inert content; nothing at
  runtime reads it except `/abilities.*` operations.

## 2. Frontmatter schema

```yaml
---
id: squash-merge-policy
source: jlopez/claude-abilities-repository
baseline: 1.3.0
mode: faithful
adopted: 2026-05-14
config:
  enforce_hook: true
artifacts:
  - path: CLAUDE.md
    section: "## Merging to main"
    hash: sha256:9f3c…
    description: judgment half — curated squash-merge messages
  - path: .githooks/pre-push
    hash: sha256:41d7…
    description: constraint half — blocks merge commits from reaching main
---
```

### Field reference

| Field | Required | Type | Meaning |
|---|---|---|---|
| `id` | yes | string | Ability id, as declared upstream. Must equal the filename stem. |
| `source` | yes | string | The abilities repository this ability was adopted from, as `owner/repo` (or a full git URL for non-GitHub hosts). Disambiguates once multiple repositories exist; tells `diff`/`update` where upstream is without consulting plugin config. |
| `baseline` | yes | string | The last upstream **version consciously reconciled against** — merge-base semantics ([design §5](../design.md#5-tracking-modes-faithful-vs-guideline)). Advances only on adopt and on a conscious reconcile (`/abilities.update`), never merely because upstream released. |
| `mode` | yes | `faithful` \| `guideline` | Tracking mode chosen at adoption ([design §5](../design.md#5-tracking-modes-faithful-vs-guideline)). The ability recommends one; the record stores what was actually chosen. |
| `adopted` | yes | date (`YYYY-MM-DD`) | Date of initial adoption. Never changes afterward. |
| `config` | yes | map | The answers given to the ability's declared config points, keyed by the **config ids exactly as the ability declares them**. Record every answer, including ones where the user accepted the default — a future agent must not need upstream's historical defaults to know what this repo chose. May be `{}` for a config-less ability. |
| `artifacts` | yes | list | The realized artifact inventory: what the adoption actually produced **in this repo**, at the paths where it actually lives. See §3. |

Unknown extra fields are permitted (forward compatibility) but tools must not
require them.

Deliberately **not** in frontmatter: artifacts the ability offered but this
repo skipped. The frontmatter lists what exists; the reasons something
doesn't exist are judgment, and belong in the prose notes (§5). `remove`
removes what is listed; `diff`'s LLM pass learns about deliberate omissions
from the notes.

## 3. Artifact entries

Each entry describes one realized artifact:

| Field | Required | Meaning |
|---|---|---|
| `path` | yes | Repo-root-relative path, as it exists in **this** repo (not the path suggested upstream). |
| `section` | no | A markdown heading line, verbatim (e.g. `"## Merging to main"`). Present when the artifact is a **section of a shared file** rather than a whole file the ability owns. |
| `hash` | yes | `sha256:` + 64 lowercase hex chars. The tripwire hash of the artifact's **last acknowledged state** (§4). |
| `description` | recommended | One line telling a future agent what this artifact is for. Load-bearing for `remove` and `diff` when the path alone is opaque. |

### Hashing rules

- **Whole-file artifact** (no `section`): SHA-256 of the file's exact bytes.
- **Section artifact**: extract the block starting at the first line exactly
  equal to the recorded heading, ending just before the next heading of the
  same or shallower depth (a line starting with the same number of `#` or
  fewer), or end of file. Strip trailing blank lines. Hash the UTF-8 bytes of
  the remaining lines joined with `\n`, no trailing newline.
- If the file is missing, or a section artifact's heading is not found
  (renamed, deleted, merged into another section), the artifact is
  **missing** for tripwire purposes — the LLM pass sorts out whether it
  moved, was renamed, or is gone.

Section scoping exists so an ability's slice of a shared file (`CLAUDE.md`
being the canonical case) doesn't trip the wire every time an unrelated
section changes.

## 4. Tripwire semantics

The tripwire is a cheap plugin script, no LLM. It answers exactly one
question: **has anything moved on either side since this repo last looked?**

It compares:

1. **Local**: for each artifact entry, recompute the hash per §3 →
   `clean` / `changed` / `missing`.
2. **Upstream**: the record's `baseline` against the latest version declared
   in the source repository's `ABILITY.md` → `current` / `behind`.

The wire is **tripped** if any artifact is `changed`/`missing` or the
baseline is `behind`. A tripped wire is *not* a drift verdict — it is the
signal that spending an LLM pass is worthwhile. Interpretation is mode-aware
and belongs to the LLM: in faithful mode local change is candidate deviation;
in guideline mode it is candidate evolution ([design §5](../design.md#5-tracking-modes-faithful-vs-guideline)).

**Hashes record the last acknowledged state, not upstream's canonical
state.** They are refreshed only by conscious operations:

- **adopt** — hashes of the artifacts as initially realized;
- **update/reconcile** — hashes of the artifacts as they stand after
  reconciliation (alongside the advanced `baseline`);
- **acknowledge** — in guideline mode, `/abilities.diff` may offer to record
  deliberate local evolution as the new acknowledged state: refresh the
  hashes, append a note (§5), do **not** advance `baseline`.

The tripwire itself never writes. Without the acknowledge operation, any
legitimate local evolution would leave the wire permanently tripped and
train users to ignore it.

## 5. Prose notes body

The body below the frontmatter is the **per-repo LLM changelog**: this
repo's relationship with the ability, written by the adopting/reconciling
agent **for the next agent**. It is the record's second half, not an
afterthought — frontmatter says *what is*, the notes say *why*.

### Structure

The body is a sequence of dated entries in **chronological order, appended
at the end** — the file reads top-down as a story. No preamble is needed;
the adoption entry is the orientation.

Entry heading format:

```markdown
## YYYY-MM-DD — <operation>
```

Canonical operations (free-form variants are allowed, but prefer these):

- `Adopted at <version>`
- `Reconciled <old> → <new>` (an `/abilities.update` that advanced the baseline)
- `Acknowledged local changes` (guideline-mode hash refresh, baseline unchanged)

### Content guidance

Write what the next agent cannot recover from the artifacts themselves:

- decisions and their **reasons** ("skipped the CI check — this repo has no
  CI"; "user rejected the pre-push hook as too aggressive");
- adaptations to repo idiom, and which upstream substance they preserve;
- config rationale where the answer alone doesn't explain itself;
- **host-side suggestions** the ability made ("suggest, don't do" actions —
  e.g. disabling merge commits in repository settings): whether the user took
  them. Nothing local exists to hash, so these notes are the only trace a
  future `diff`/`remove` has;
- on reconcile: which upstream changes were taken, which were declined, and
  why.

Do not restate the diff or duplicate the frontmatter. A good entry is a
paragraph or three, not a report.

### Appending

Operations append a new `##` entry at the end of the body and never rewrite
prior entries. Prior entries are history; if an old decision is reversed,
the new entry says so.

## 6. What a fresh agent reads first

An agent starting any `/abilities.*` operation on an adopted ability reads,
in order:

1. **Frontmatter** — what is adopted, from where, at what baseline, in what
   mode, realized where.
2. **Body notes, top to bottom** — the history of decisions; this is where
   "why is there no CI artifact?" gets answered before it becomes a false
   drift finding.
3. **The realized artifacts** at the listed paths — the current ground truth.
4. **Upstream `ABILITY.md`** (via `source`), including its changelog — only
   when the operation compares against upstream (`diff`, `update`,
   `publish` against a base ability).

## 7. Interface contract with the ability format

The ability format (roadmap item 2) **declares**; the adoption record
**stores the realized values**. Names must line up across the boundary:

| Ability declares (`ABILITY.md`) | Record stores (`.claude/abilities/<id>.md`) |
|---|---|
| `id` | `id` (same value; also the record's filename stem) |
| `version` (latest, plus changelog) | `baseline` (some version consciously reconciled against — usually older than upstream latest) |
| `config` — points with prompt/type/default | `config` — answers, keyed by the same config ids |
| `mode` — recommendation | `mode` — the choice actually made |
| `artifacts` — loose inventory ("a CLAUDE.md section about merging") | `artifacts` — realized paths in this repo, plus hashes |
| — | `source` — which abilities repository declared all of the above |

The pressure this contract put on item 2 — the loose inventory hinting when
an artifact is expected to be a section of a shared file, so the adopting
agent knows to record it with `section` scoping — is resolved: the ability
format's `artifacts` rules require it.

## 8. Worked example

A complete example instance — `squash-merge-policy` adopted into a fictional
repo — lives at [`examples/squash-merge-policy.md`](examples/squash-merge-policy.md),
verbatim as it would appear at `.claude/abilities/squash-merge-policy.md` in
the adopting repo. Examples are what future agents pattern-match on; keep it
current when this spec changes.
