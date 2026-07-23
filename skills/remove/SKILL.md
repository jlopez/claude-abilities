---
description: Remove an adopted ability from the current repo — reverse exactly what the adoption record says was added (delete whole-file artifacts, excise section-scoped slices, unwind recorded wiring), warn about artifacts edited since adoption, flag anything built on top, surface host-side actions to undo, and land the removal as a PR.
disable-model-invocation: true
argument-hint: "<ability-id>"
---

# /abilities:remove — record-guided reversal

You are the **removing agent**. Adoption dissolved the ability into this
repo's own primitives; the adoption record at `.claude/abilities/<id>.md` is
the complete account of what exists because of it. Removal is that record
played backwards — you remove what it lists and what its notes say was wired,
nothing more — ending in a **PR**: a human gate on machine-written deletions.

The normative contract is
`"${CLAUDE_PLUGIN_ROOT}"/docs/spec/adoption-record.md` — read it when this
file points at it; §3's extraction rule and §5's prose-notes role matter here.

Arguments given by the user: `$ARGUMENTS`

## Hard constraints (read first)

- **The record is the warrant.** Delete only what the record's frontmatter
  lists and what its prose notes describe as wiring added by adoption.
  Anything else that looks ability-related gets *flagged*, never silently
  deleted.
- **Never perform host-side actions** (repository settings, anything outside
  the working tree). Recorded host-side actions are *surfaced* with their undo
  — the user's call, step 6.
- **Never write to the target repo's `.claude/settings.json`** — project-scope
  plugin installs live there; clobbering it uninstalls plugins.
- The removal PR is left **open for human review** — never merge it.
- Do not modify the abilities repository or the plugin's own files.

## 1. Preflight

- An ability id is required; without one, say so and stop.
- The current directory must be inside a git repository — removal ends in a
  PR. If not, say so and stop.
- If `.claude/abilities/<id>.md` does not exist, this ability is not adopted
  here — **nothing to remove**. Say so; if other records exist under
  `.claude/abilities/`, list their ids. Stop.
- Read the record in full — frontmatter *and* every prose entry, top to
  bottom. The notes carry what the frontmatter cannot: wiring that was
  recorded but not hashed, host-side decisions, artifacts deliberately never
  installed (which you must not go hunting for).

## 2. Tripwire: what would removal destroy?

Run the deterministic check first — local half only; upstream is irrelevant to
removal:

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/tripwire --local <id>
```

- Artifacts `changed` since last acknowledged: the user has edited them —
  removing now destroys those edits. **Warn explicitly, naming each changed
  artifact** (path, and section heading if section-scoped), and get the
  user's confirmation before proceeding. Non-interactive sessions must stop
  here rather than assume consent.
- Artifacts `missing`: already gone (or moved — a renamed section heading
  reads as missing). Look before shrugging: if the content moved, that moved
  content is what removal should excise; if it is genuinely gone, note it as
  already-removed in the PR body.
- `clean` artifacts: proceed without ceremony.

## 3. What was built on top?

Before deleting anything, check what would dangle: search the repo for
references to each artifact (the hook's path in configs, CI, or bootstrap
scripts; the section's heading in other docs; scripts sourcing the script).
References that adoption itself created (per the notes) are yours to reverse
in step 4. Anything else — a workflow the user pointed at the hook, a doc
linking the section — is **built on top**: flag it to the user (and in the PR
body) and leave it intact unless they say otherwise. When user edits live
*inside* an artifact (the `changed` case), offer the middle path of keeping
their content while stripping the ability's: show what stays and what goes.

## 4. Reverse the adoption

Branch first: off the default branch, up to date with its remote. Name the
branch by the repo's own convention if it has one; otherwise `remove/<id>`.

Then, guided by the record:

- **Whole-file artifacts** (no `section`): `git rm` the file.
- **Section-scoped artifacts**: excise exactly the block the hash covered —
  the spec §3 extraction rule: from the recorded heading line to just before
  the next ATX heading of the same or shallower depth (or end of file) —
  and leave the rest of the shared file intact. Tidy the seam (no doubled
  blank lines). If the notes say adoption *created* the shared file and
  nothing of substance remains after excision, remove the file and say so in
  the PR.
- **Recorded-but-unhashed wiring**, from the prose notes: reverse it in the
  working tree — the README activation line, the bootstrap step (`prepare`
  script line, `make setup` stanza) that wires `core.hooksPath`, an entry
  added to another doc. Remove each only if nothing else still needs it
  (e.g. leave the hooks bootstrap alone if other hooks remain in that
  directory).
- **Per-clone state you cannot reach by PR** (each collaborator's
  `git config core.hooksPath`, installed hook copies): tell the user the
  undo command to run locally, and have the PR body tell collaborators the
  same. Do not run it yourself unless the user says yes — and never for
  clones that aren't this one.
- **Delete the adoption record itself** (`git rm .claude/abilities/<id>.md`).
  An emptied `.claude/abilities/` directory disappears with it; leave the
  directory alone if other records remain.

## 5. Verify

The branch should now contain no trace the record warranted removing: re-read
each touched shared file (the remaining sections must read whole), and check
nothing listed in the record survives except what the user chose to keep in
step 3. If the repo has tests or linters that cover touched files, run them.

## 6. Host-side actions: surface, don't do

For each host-side action the notes record as **taken** at adoption ("this
repo disabled merge commits"), surface the undo — e.g.
`gh repo edit --enable-merge-commit --enable-rebase-merge` — with one line on
what it restores, and let the user decide; removal of the working-tree
artifacts is complete either way. Actions the notes record as declined or
deferred need nothing — say so only if the user asks. Record in the PR body
what was suggested and what the user decided.

## 7. Open the PR

Commit and open a PR against the default branch, following the **target
repo's own merge conventions** — including, with pleasing irony, any
conventions this very ability installed: they hold until the PR merges. The
body summarizes, in sections: what was **removed** (artifacts and record),
what was **reversed** (wiring from the notes), what was **flagged and kept**
(built-on-top, user-kept content), anything **already missing**, and
**host-side undos** suggested with their decisions. Leave the PR open; tell
the user it is ready for review.
