# Reconciliation — the classify-and-fold move

> Status: normative as of 2026-07-23 (roadmap item 6). This is the **shared
> procedure** behind every place two versions of an ability's content meet:
> `/abilities:update` runs it per upstream change, and `/abilities:adopt` runs
> it when it finds existing content at a target location (adopt-over-existing
> is update with no record — PR #13's learning). One procedure, documented
> once, referenced from both skills; the skills add their own conversation
> and record-keeping around it but must not fork the move itself.

The situation: an artifact location holds **local text** (existing content at
adoption, or the repo's evolved artifact at update) and the ability offers
**canonical text** (the asset, at the version being adopted or reconciled
toward). Merging them mechanically is exactly the silent three-way merge the
design forbids ([design §5](../design.md#5-tracking-modes-faithful-vs-guideline));
ignoring either side loses content. The move: scope, diff, **classify each
delta**, decide, fold, record.

## 1. Scope: the ability's concern

First establish which slice of the local content belongs to the ability's
concern — for a section-scoped artifact, the section; for a whole-file
artifact, the file. Two consequences, both from the same fact — **section
scope is hash scope** ([adoption-record.md §3](adoption-record.md#3-artifact-entries)):

- **Fold in only content that belongs to the ability's concern.** Adjacent
  repo content that merely mentions the same topic stays where it is; pulling
  it under the artifact puts it under the artifact's hash and trips the wire
  on unrelated edits.
- **Local content inside the artifact that does not belong to the concern**
  (build-order orientation inside a merge-policy section, say) is moved
  *outside* the artifact — relocated, never deleted — and the notes say so.

## 2. Diff and classify

Diff the local text against the canonical text **by substance, not lines** —
the anchor for what counts as substance is the ability's *Keep faithful*
section and its assets. Classify **every** delta:

| Class | Shape | Default resolution |
|---|---|---|
| **Equivalent rewording** | Same substance, different form | Keep the local form — form belongs to the repo ([design §5](../design.md#5-tracking-modes-faithful-vs-guideline)). Not worth a decision; one line in the notes at most. |
| **Local extra to preserve** | Present locally, no canonical counterpart, belongs to the concern | Preserve it, woven into the folded result (repo-specifics are the point of adaptation). |
| **Canonical text to take** | Canonical substance with no local counterpart | Take it, adapted per the ability's *Adapt to the repo* section. |
| **Substance deviation to decide on** | Both sides address the same point, differently, and the difference is substance | **A human decision — never resolved silently.** See §3. |

The first three classes have safe defaults precisely because they are not
conflicts: nothing is lost and no substance question is being answered on the
user's behalf. The fourth is the conflict, and it is the reason this
procedure exists.

## 3. Decide

For each substance deviation, present both texts, what each does, and a
recommendation — framed through the **tracking mode** (at adoption, the mode
being chosen; at update, the record's):

- **faithful** — the canonical substance is the expected end-state; keeping
  the local side is a departure from faithful and deserves the mode-change
  nudge (see the update skill).
- **guideline** — the local side is legitimate evolution; keeping it is
  normal, not a departure.

**Non-interactive sessions**: with no substance deviations, the safe defaults
above may proceed (the notes must say the run was non-interactive). With any
substance deviation, **stop at a written proposal** — the classification
table, both texts per deviation, and a recommendation — delivered per the
calling skill's fallback convention. A reconciliation without a human in the
loop is exactly the silent merge the design forbids.

## 4. Fold

Produce the merged artifact: canonical substance taken (adapted to the
repo's form), local extras preserved, deviations resolved as decided.
The *Keep faithful* invariants of the version being folded toward win over
any adaptation; if a decision the user made breaks one in faithful mode,
stop and say so rather than folding a broken artifact.

## 5. Record

The classification is part of the operation's prose-notes entry
([adoption-record.md §5](adoption-record.md#5-prose-notes-body)) — the
adoption entry, or the `Reconciled <old> → <new>` entry: what was preserved,
taken, relocated, and decided, **and why**, per delta of substance. Written
for the next agent, who will run this same move against the folded result.
The worked example's reconcile entry
([examples/squash-merge-policy.md](examples/squash-merge-policy.md)) and this
plugin repo's own adoption record show the shape.
