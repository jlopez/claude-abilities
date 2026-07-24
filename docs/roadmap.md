# Roadmap

Build order. Each item lands via PR. Get 1–2 right and the commands are
straightforward views over them; get them wrong and no command polish saves the
project.

> **Status: items 1–8 done**: the substrate contract (items 1–2), the
> installable plugin skeleton with `/abilities:setup` (item 3),
> `/abilities:adopt` (item 4), `/abilities:diff` + `/abilities:remove` with
> the tripwire script (item 5), `/abilities:update` with the shared
> reconciliation move (item 6), `/abilities:publish` (item 7), and the
> browser UI as the `catalog-page` ability (item 8). Next up: **item 9**,
> gated on item 6 proving trustworthy in real use. Check items off here, in
> the PR that completes them.

## 1. Adoption record schema ✅

The identity substrate ([design §4](design.md#4-adoption-record-the-manifest)).
Finalize and document: file location (`.claude/abilities/<id>.md`), frontmatter
fields (id, baseline version, mode, config answers, artifact inventory, tripwire
hashes), and the prose-notes convention (the per-repo LLM changelog).

**Done** — normative spec in [spec/adoption-record.md](spec/adoption-record.md),
worked example in [spec/examples/squash-merge-policy.md](spec/examples/squash-merge-policy.md).

## 2. Ability format ✅

**Done.** Spec: [spec/ability-format.md](spec/ability-format.md). Reference
instance: [squash-merge-policy](https://github.com/jlopez/claude-abilities-repository/tree/main/squash-merge-policy)
in the (now-created) `jlopez/claude-abilities-repository`, exercising both the
hook-constraint and CLAUDE.md-judgment paths plus the `enforce_hook` config
point. Designed together, as planned ([design §3](design.md#3-ability-format-skill-shaped-directory)).

## 3. Plugin skeleton + `/abilities.setup` ✅

Claude Code plugin scaffolding for the `/abilities.*` commands; `setup` config
pointing at an abilities repository. Verify current plugin/skill/hook manifest
formats against docs (claude-code-guide agent) before committing to structure.

**Done.** Verified facts + decisions (command surface is `/abilities:<cmd>` —
the harness forces colon namespacing; setup config lives in
`${CLAUDE_PLUGIN_DATA}/config.json`) are recorded in
[spec/plugin-structure.md](spec/plugin-structure.md).

*Follow-up (#10):* config schema remodeled to v2 — a repository's identity is
its remote (`source`), a local clone is an optional `localPath` overlay — and
multi-repo semantics (`--repo`, grouped browse, record-pinned resolution for
`diff`/`update`/`publish`) defined in
[spec/repository-resolution.md](spec/repository-resolution.md).

## 4. `/abilities.adopt` ✅

The forward transpile: read ability → prompt config → adapt to repo → write
adoption record → PR. Test end-to-end by adopting squash-merge-policy into a
real project.

**Done** — `skills/adopt/SKILL.md` (browse mode + full adopt flow), plus the
shared spec-conformant hashing utility `scripts/artifact-hash` (unit tests in
`scripts/artifact-hash.test.sh`; item 5's tripwire reuses it). Tested
end-to-end by adopting `squash-merge-policy` into
`jlopez/claude-abilities-repository` (its first dogfooding adoption PR).

## 5. `/abilities.diff` + `/abilities.remove` ✅

Tripwire script (hash + version check, no LLM) → LLM semantic drift explanation,
mode-aware. Remove as record-guided reversal via PR.

**Done** — `scripts/tripwire` (deterministic, reuses `scripts/artifact-hash`,
CI-ready exit codes; unit tests in `scripts/tripwire.test.sh`),
`skills/diff/SKILL.md` (fleet summary, mode-aware analysis, guideline-mode
acknowledge per spec §4), `skills/remove/SKILL.md` (record-guided reversal).
Tested end-to-end in a scratch repo — adopt, diff (clean; tripped in both
modes), acknowledge, remove — plus a clean-wire diff against the live
adoption in `jlopez/claude-abilities-repository`.

## 6. `/abilities.update` ✅

The reconciliation conversation; advances the baseline, appends prose notes.
Hardest command; last of the core lifecycle. No silent merges — propose,
explain, human decides.

**Done** — `skills/update/SKILL.md` (tripwire triage, upstream walked
baseline→latest explained from changelog intent, per-change take/decline/
adapt with the faithful-mode nudge, baseline advance + `Reconciled` notes,
non-interactive stop at a written proposal), plus the shared
**classify-and-fold move** in [spec/reconciliation.md](spec/reconciliation.md)
— one procedure behind update's collision handling *and* adopt's
existing-content preflight (PR #13's blind spot, fixed in the same PR).
Tested end-to-end in scratch repos against a staged `squash-merge-policy`
v1.1.0: take-all, mixed take/decline in both modes,
collision-with-local-evolution, the non-interactive stop, and
adopt-over-existing-content.

## 7. `/abilities.publish` ✅

The inverse transpile. Parameter: PR to base ability vs. new ability. Agent
proposes config points while generalizing.

**Done** — `skills/publish/SKILL.md`: evolve mode (gather record + notes +
tripwire, classify the publishable delta — adaptation vs. improvement vs.
new-config-dimension — generalize, author the version bump with a
changelog-intent entry, PR against the record's pinned `source`) and
new-ability-from-scratch mode (interview, generalization pass, full
directory, PR to the default or named repository). Publish writes nothing to
the adopting repo — the post-merge "behind its own contribution" state is
`/abilities:update`'s to reconcile. Proven end-to-end by publishing
squash-merge-policy v1.0.1 (the worktree wording clarification discovered in
this repo's own dogfood adoption, PR #13 learning 4) to
`jlopez/claude-abilities-repository`.

## 8. Browser UI ✅

Copy-the-`/adopt`-line as the primary path; anything richer (Artifact with
mediated install) is v2.

**Done** — implemented **as an ability**, not plugin code:
[`catalog-page` 1.0.0](https://github.com/jlopez/claude-abilities-repository/tree/main/catalog-page)
in the abilities repository, adopted *by* that repository through the normal
`/abilities:adopt` flow (its PRs #4 and #5) — an abilities repository is a
repo like any other, and its catalog is a capability it can adopt. A static
GitHub Pages page generated from each ability's `ABILITY.md` frontmatter
(name, description, version, recommended mode, config-point count, latest
changelog intent); each card's primary action is a copy-to-clipboard
`/abilities:adopt <id>` line; no install-state marking (that is adopt browse
mode's local concern). Deliberately dependency-light per this item's
guidance: POSIX sh + awk generator plus the official Pages actions — no
package manager, no build ecosystem. Pages enablement is a host-side
suggest-don't-do step surfaced to the repo admin, never executed by the
adopting agent.

## 9. Self-updating CI

"Dependabot for behaviors." **Gated on 6 being trustworthy in real use.**
