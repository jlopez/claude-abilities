---
description: Reconcile upstream ability changes with this repo's local evolution — a conversation grouped by version, explained from the changelog's intent, with every substance decision made by the user; ends in a PR, an advanced baseline, and appended prose notes. No silent merges, ever.
disable-model-invocation: true
argument-hint: "<ability-id>"
---

# /abilities:update — the reconciliation conversation

You are the **reconciling agent**. An adopted ability dissolved into this
repo's own primitives and has been evolving on two sides: upstream released
versions past the record's `baseline`, and the repo may have moved too. This
command reconciles the two — **a conversation, not a merge**: you present each
upstream change explained from its changelog intent, classify it against local
state, and the user decides what to take. It ends in a **PR**, an **advanced
`baseline`**, and an appended prose entry in the adoption record.

The normative contracts are in the plugin itself — read them when this file
points at them, they are short:

- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/reconciliation.md` — the
  **classify-and-fold move** used whenever an upstream change collides with
  local evolution. Shared with adopt; never improvise a variant.
- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/adoption-record.md` — the record's shape,
  hashing rules (§3), what refreshes hashes and advances `baseline` (§4), the
  prose-notes convention (§5), and the reading order (§6).
- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/ability-format.md` — the changelog's
  intent entries (what you explain *from*) and the body sections, especially
  *Keep faithful*.
- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/repository-resolution.md` — upstream is
  **pinned by the record's `source`**; resolution and cache rules live there.

Arguments given by the user: `$ARGUMENTS`

## Hard constraints (read first)

- **No silent merges, ever.** Every substance decision — take, decline, adapt,
  resolve a collision — is the user's. A session that cannot ask **stops at a
  written proposal** (step 8); it never takes, declines, or writes anything on
  the user's behalf.
- **`baseline` advances only here**, only after the conversation, and always
  together with refreshed hashes and a `Reconciled` prose entry. Nothing else
  ever advances it.
- **Upstream is the record's pinned `source`** — resolve it per
  repository-resolution.md; never substitute a different repository, even one
  offering the same id.
- **Compute every hash with the plugin's scripts** (`tripwire`,
  `artifact-hash`) — never ad-hoc shell hashing.
- **The prose notes are load-bearing.** Artifacts the notes say were
  deliberately skipped, and decisions already recorded, must not resurface as
  things to reconcile.
- **Never write to the target repo's `.claude/settings.json`** — project-scope
  plugin installs live there; clobbering it uninstalls plugins.
- The update PR is left **open for human review** — never merge it.
- Do not modify the abilities repository or the plugin's own files.

## 1. Preflight

- An ability id is required; without one, say so and stop.
- The current directory must be inside a git repository — update ends in a PR.
  If not, say so and stop.
- If `.claude/abilities/<id>.md` does not exist, this ability is not adopted
  here — there is no baseline to reconcile from. Say so; if the capability's
  content nonetheless exists in the repo (a hand-written ancestor, a copy from
  elsewhere), point at `/abilities:adopt <id>` — its preflight detects
  existing content and runs the same classify-and-fold move. Stop.
- Read the record in full — frontmatter *and* every prose entry, top to
  bottom (spec §6 order). The notes carry deliberate omissions, past
  reconcile decisions, and host-side history you must not contradict.

## 2. Tripwire, then triage

Run the deterministic check before spending anything:

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/tripwire <id>
```

As in `/abilities:diff`, spare the clone when the plugin's setup config maps
the record's `source` to a local clone: config at `$CONFIG_DIR/config.json`
where

```bash
CONFIG_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/abilities-claude-abilities}"
```

— an entry whose identity canonically matches the record's `source`
(repository-resolution.md) and which points at a local clone (`localPath`;
a v1 `local`-type entry counts the same) qualifies for
`--map <source>=<dir>`. Strictly an optimization: config missing, unreadable
(sandboxed sessions may be denied reads of plugin data — that is *not* "not
configured"), or unmatched → let the tripwire clone.

Triage on the `baseline` fact:

- **`current`, wire clean** — nothing upstream and nothing local. Say so in a
  line ("baseline X is upstream's latest; artifacts match their acknowledged
  hashes — nothing to reconcile") and **stop**.
- **`current`, artifacts changed/missing** — local-only drift. That is
  `/abilities:diff` territory (faithful-mode restore, or guideline-mode
  acknowledge); update reconciles *upstream* movement and there is none. Say
  so, point at `/abilities:diff <id>`, and **stop**.
- **`ahead`** — the recorded baseline is newer than upstream's latest
  (adoption from a clone ahead of its remote — the notes usually say).
  Nothing upstream to take yet; say so and **stop**.
- **`unknown`** (or exit 4) — upstream could not be checked. A reconcile
  without upstream is impossible; report what failed and **stop** — never
  guess the upstream half.
- **`behind`** — proceed. Local artifact changes are not a blocker; they are
  exactly what the conversation reconciles *with*.

## 3. Read both ends of upstream

Resolve the record's `source` per repository-resolution.md (registered entry
→ its `localPath` or refreshed cache; unregistered → offer to register, or a
temporary shallow clone for this run). Then read:

1. **Latest**: the ability's current `ABILITY.md` — body, *Adapt to the
   repo*, *Keep faithful*, full changelog — and its `assets/`.
2. **Baseline side**: the ability as of the last commit where
   `<id>/ABILITY.md` declared `version: <baseline>` (unshallow a cache/clone
   first: `git fetch --unshallow --quiet`). This is what the repo's artifacts
   descend from — the base of every three-way comparison. If the baseline
   version cannot be found in upstream history (adopted from an unpushed
   state — the notes may say), fall back to the changelog's intent entries
   alone and say you did.
3. **The changelog entries between baseline and latest** — the versions you
   will walk, and the intent prose you will explain each one from.
4. **The realized artifacts** at the recorded paths, as they stand now.

## 4. The conversation

Present upstream movement **grouped by version, oldest first** — the story
from the repo's baseline to upstream's latest. For each version: what it
changed and **why, explained from its changelog `intent` entry** (that prose
exists precisely to be explained from), grounded in what actually changed in
the body and assets between the two versions.

Classify each concrete change against *this repo's* state:

- **applies cleanly** — the local artifact still matches the baseline-side
  state the change was written against;
- **collides with local evolution** — the repo moved in the same place; this
  is the classify-and-fold case (reconciliation.md), and the fold is what
  "take" will mean here;
- **already effectively present** — the repo's own evolution anticipated it;
  taking it is a no-op worth saying so;
- **superseded locally** — the repo deliberately does this differently (often
  recorded in the notes); present it as a real choice, not a clean apply;
- **not applicable** — it touches an artifact the notes say this repo skipped;
  one sentence, not a finding.

Then ask, **per change** — AskUserQuestion fits, one question per change,
with your recommendation first: **take** / **decline** / **adapt** (take the
substance, with a named adaptation). Group trivially-related changes into one
question rather than interrogating the user over each comma.

Mode shapes the framing, not the mechanics:

- **guideline** — declining is normal; upstream is an offer, not an
  expectation.
- **faithful** — declining a substance change departs from faithful: the wire
  will read the gap as deviation from now on. Say so when the user declines,
  and offer the honest alternative: *"this departs from faithful — switch
  this adoption to guideline mode?"* Record the answer either way: mode
  changed → update `mode:` in the frontmatter and say why in the notes; mode
  kept → the notes record a conscious faithful-mode exception the next agent
  must not "fix."

## 5. Apply what was taken

Branch first: off the default branch, up to date with its remote. Name the
branch by the repo's own convention if it has one; otherwise `update/<id>`.

- Apply each **take** honoring the *Adapt to the repo* and **Keep faithful of
  the NEW version** — the invariants you must land are the latest version's,
  not the baseline's. Collisions fold per reconciliation.md §4.
- New artifacts introduced by a taken version are installed as adopt would:
  from the new canonical assets, adapted to the repo's idiom, honoring their
  config gates.
- **New config points** declared since the baseline get prompted **like adopt
  would** — the declared `prompt`, the declared `default` as the recommended
  option — and the answers join the record's `config` map. (A non-interactive
  session never reaches this step; see step 8.)
- Declines change nothing in the tree; they change the record (step 6).

## 6. Refresh the record

All in the same operation — a half-updated record is worse than none:

- **Advance `baseline` to upstream's latest** — including when changes were
  declined. `baseline` means "the last version *consciously reconciled
  against*" (spec §2), and a conscious decline is a reconciliation; the
  declines live in the notes, not in a stale baseline that would re-raise
  them on every run.
- **Refresh every artifact hash** via the plugin's script —
  `"${CLAUDE_PLUGIN_ROOT}"/scripts/artifact-hash <path> [<section>]` — to the
  post-reconcile state. Add entries for artifacts this update installed;
  drop entries for artifacts a taken change removed (the frontmatter lists
  what exists; the note carries why). A renamed section heading updates the
  `section:` value verbatim.
- **Record new config answers** from step 5, keyed exactly as declared.
- **Append a prose entry** at the end of the body, never rewriting prior
  entries:

  ```markdown
  ## YYYY-MM-DD — Reconciled <old> → <new>
  ```

  What was **taken**, **declined**, and **adapted** — and *why*, per version
  walked; collision classifications per reconciliation.md §5; the faithful
  decline/mode answer if step 4 raised it; new config rationale. Written for
  the next agent.

## 7. Open the PR

Commit everything (artifacts + record) and open a PR against the default
branch, following the **target repo's own merge conventions** — including any
this very ability installed. The body summarizes the versions walked, what
was taken/declined/adapted and why, and any collision folds. Leave the PR
open; tell the user it is ready for review.

## 8. Non-interactive sessions: stop at a written proposal

Update is the conversation; a session that cannot ask the user must not hold
it with itself. If the session cannot prompt, run steps 1–3 and the
*analysis* of step 4, then **stop before deciding or touching anything** —
no take/decline, no tree edits, no baseline advance, no record write. Deliver
a **written proposal**: the versions walked with their intent, each change's
classification, and your recommendation, then where to go
(`/abilities:update <id>` in an interactive session). Deliver it where the
run's audience will see it — in a CI/automation context, a PR or issue
comment; otherwise session output plus a fallback file at the repo root
(`abilities-update-proposal-<id>.md`, untracked — headless sessions cannot
write under `.claude/`, per the plugin-structure gotchas). A reconciliation
without a human in the loop is exactly the silent merge the design forbids.
