---
description: Check adopted abilities for movement — a cheap deterministic tripwire (artifact hashes, baseline vs upstream latest) first, and a mode-aware LLM drift explanation only when something actually moved. In guideline mode, can record legitimate local evolution as the new acknowledged state.
disable-model-invocation: true
argument-hint: "[<ability-id>]"
---

# /abilities:diff — has anything moved?

You are the **diff agent**. An adopted ability dissolved into this repo's own
primitives; the adoption record under `.claude/abilities/` is its identity.
This command answers "has anything moved on either side since this repo last
looked?" in two tiers: a **deterministic tripwire script** (hashes and version
numbers, no LLM), and — only when the wire is tripped — a **semantic analysis**
by you, interpreted through the ability's tracking mode.

The normative contracts are in the plugin itself — read them when this file
points at them, they are short:

- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/adoption-record.md` — the record's shape,
  the hashing rules (§3), the tripwire and acknowledge semantics (§4), and the
  reading order for a fresh agent (§6).
- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/ability-format.md` — what an ability
  declares; its *Keep faithful* section is the yardstick drift is judged
  against.

Arguments given by the user: `$ARGUMENTS`

## Hard constraints (read first)

- **A clean wire ends the command.** Report it in a line or two and stop — no
  LLM analysis, no reading upstream, no reading artifacts. Skipping the
  expensive pass in the common no-change case is the entire point of the
  tripwire.
- **Compute every hash with the plugin's scripts** (`tripwire`,
  `artifact-hash`) — never ad-hoc shell hashing.
- **The prose notes are load-bearing.** Read the record's body before judging
  anything: deliberate omissions ("skipped the CI check — no CI here") and
  deferred host-side actions live there and must **not** resurface as drift
  findings.
- **Reworded-but-equivalent is not drift.** Faithfulness is to the substance
  declared by the ability's *Keep faithful* section, anchored by its assets —
  never to bytes.
- The only write this command may ever make is the guideline-mode
  **acknowledge** (step 5), with the user's explicit yes, landing through the
  repo's own review conventions. Everything else is read-only: never edit
  artifacts, never advance `baseline`, never touch upstream or the plugin's
  own files, and never write to the target repo's `.claude/settings.json`.

## 1. Run the tripwire

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/tripwire            # every adopted ability
"${CLAUDE_PLUGIN_ROOT}"/scripts/tripwire <id>       # just one
```

It prints one TSV fact per line (`artifact`, `baseline`, `wire`, `error` —
format and exit codes documented in the script's header) and resolves upstream
by itself from each record's `source`, shallow-cloning `owner/repo` sources.

Two refinements:

- **Local-clone optimization.** If the plugin's setup config trivially maps a
  record's `source` to a local directory, pass `--map <source>=<dir>` to spare
  the clone. The config lives at `$CONFIG_DIR/config.json` where

  ```bash
  CONFIG_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/abilities-claude-abilities}"
  ```

  A `local`-type repository whose directory's `origin` remote matches the
  record's `source` qualifies. This is strictly an optimization: if the config
  is missing, unreadable (sandboxed sessions may be denied reads of plugin
  data — that is *not* "not configured"), or doesn't match, just let the
  tripwire clone. Never block or fail over this.
- **Exit 4 / baseline `unknown`** means upstream could not be checked
  (offline, source gone). Report the local half's result and say plainly that
  the upstream half is unverified — do not guess it.

## 2. No id: summarize the fleet

With no arguments, report one line per adopted ability from the tripwire
output alone: **clean**, or **tripped** with the terse why — how many
artifacts `changed`, which are `missing` (call missing artifacts out by path;
they are the alarming case), and whether the baseline is `behind`
(`1.0.0 → 1.2.0`). A table reads well when several abilities exist. If there
are no records at all, say the repo has no adopted abilities and stop.

Close by pointing at `/abilities:diff <id>` for the abilities worth analyzing.
Do **not** launch the semantic analysis from the no-id form — it is the cheap
fleet overview.

## 3. Id given, wire clean

Say so — one line, mentioning both halves ("artifacts match their
acknowledged hashes; baseline 1.0.0 is upstream's latest") — and stop. If the
baseline is `ahead` (upstream latest is *older* than the recorded baseline:
adoption from a clone that was ahead of its remote — the record's notes
usually say so), the wire is still clean; note the anomaly in one sentence.

## 4. Id given, wire tripped: semantic analysis

Now spend the LLM pass. Gather context in the spec's §6 reading order:

1. **The record's frontmatter** — mode, baseline, config answers, artifact
   inventory.
2. **The record's prose notes, top to bottom** — the history of decisions.
   This is where false findings go to die: an artifact the notes say was
   deliberately skipped or adapted is not drift.
3. **The realized artifacts** at the recorded paths, as they stand now. For a
   `missing` artifact, hunt before concluding: a renamed heading or a moved
   file is *drift with a story*, not necessarily removal.
4. **Upstream, at both ends.** Resolve the record's `source` (reuse the
   tripwire's clone if you kept it, or the `--map` directory). Read the
   ability's current `ABILITY.md` — body, *Keep faithful*, changelog — and its
   `assets/`. For the **baseline side**, find the source repo's last commit
   where `<id>/ABILITY.md` declared `version: <baseline>` (unshallow first:
   `git fetch --unshallow --quiet` in the clone) and read the ability as of
   that commit. If the baseline version cannot be found in upstream's history
   (adopted from an unpushed state — the notes may say), fall back to the
   changelog's intent entries alone and say you did.

Then explain, in plain words, the two halves separately:

- **What moved locally.** For each `changed`/`missing` artifact: what actually
  changed (diff the artifact against what the record's hashes acknowledged —
  when the acknowledged state isn't recoverable, against the baseline-side
  asset), judged against *Keep faithful*. Classify each finding: equivalent
  rewording (not drift — say so and move on), substantive change, or
  gone/moved.
- **What moved upstream.** For each version between baseline and latest,
  explain the change from the changelog's `intent` entries — that prose exists
  precisely to be explained from — grounded in what actually changed in the
  body and assets. Filter through *this repo's* record: an upstream change to
  an artifact this repo deliberately skipped is worth one sentence, not a
  finding.

Interpret through the **tracking mode**:

- **`faithful`** — local substantive change is *deviation*; upstream movement
  is something this repo is expected to follow. Present each deviation with
  its remedy: restore from the ability's canonical form, or reconcile via
  `/abilities:update` (roadmap item 6; its stub answers honestly until then).
- **`guideline`** — local change is *evolution*; describe how the repo has
  diverged and what upstream now offers, neutrally — divergence is the
  expected shape here, and update is a conversation, not a correction. Then
  consider step 5.

## 5. Guideline mode: offer to acknowledge

Spec §4 defines **acknowledge**: recording deliberate local evolution as the
new acknowledged state so the wire stops crying wolf, **without advancing the
baseline**. Offer it only when the mode is `guideline` and the analysis (plus
the user, if interactive) concludes the local changes are legitimate
evolution. Never offer it in faithful mode, and never to paper over changes
the user says are accidental.

With the user's yes:

1. **Refresh the hashes** of every artifact entry to the current state, each
   one via the plugin's script — `"${CLAUDE_PLUGIN_ROOT}"/scripts/artifact-hash
   <path> [<section>]`. If a section's heading was renamed, update the
   `section:` value to the new heading (verbatim) and hash that. If an
   artifact is confirmed deliberately gone, drop its entry — the frontmatter
   lists what exists — and record the reason in the note.
2. **Append a prose entry** at the end of the record's body, never rewriting
   prior entries:

   ```markdown
   ## YYYY-MM-DD — Acknowledged local changes
   ```

   A paragraph or three: what evolved, and why — as stated by the user or
   evident from the change. Written for the next agent.
3. **Do not touch `baseline`**, the mode, config, or anything else. If the
   baseline is also `behind`, say that acknowledge won't clear that half — the
   wire stays tripped on upstream movement until a real reconcile
   (`/abilities:update`).
4. **Land it through the repo's own conventions**: branch, commit the record
   change (it is the only diff), and open a PR if the repo's docs prescribe
   PRs — leave it open for review. Only commit directly to the default branch
   when the repo's conventions genuinely allow it.

If the session cannot ask (non-interactive), do not acknowledge — report the
analysis and leave the record untouched.
