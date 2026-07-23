---
id: squash-merge-policy
source: jlopez/claude-abilities-repository
baseline: 1.0.0
mode: faithful
adopted: 2026-07-23
config:
  enforce_hook: true
artifacts:
  - path: CLAUDE.md
    section: "## Merging to main"
    hash: sha256:902ecd12564639ac94ffb3714857f220fa7656f60390983a7c2c992bf7924a5f
    description: judgment half — PR-only merges, docs in the same PR, curated squash messages
  - path: .githooks/pre-push
    hash: sha256:d7c07bb658b0cc567dee0ff87c67fef0058d4bcb16e4f3cd56a6c612994486fa
    description: constraint half — rejects pushes that put merge commits on main
---

## 2026-07-23 — Adopted at 1.0.0

Adopted in **faithful** mode with `enforce_hook: true` — both the ability's
declared defaults, taken as the spec provides because the run was
non-interactive (autonomous dogfooding session for issue #12); the human gate
is the adoption PR. This repo is the *plugin* that performed the adoption —
the second half of the bootstrap circle the abilities repository's own
adoption started.

This was an **adopt-over-existing-content** run: `CLAUDE.md` already carried a
hand-written "Merging to main" seed section (the very text the canonical
ability was extracted from, via Scarpa). The adapted section is the canonical
asset's structure reconciled with the seed's repo-specifics:

- From the canonical asset: the numbered process, the "no merge bubbles, ever"
  framing, one-PR-one-commit, and the never-rewrite closing line.
- From the seed: the concrete docs enumeration — `docs/design.md` (with this
  repo's design-first discipline), `docs/roadmap.md` (with its check-off-in-PR
  convention), and `CLAUDE.md` itself — folded into the docs step.
- Dropped: the seed's "*(this section is the seed…)*" parenthetical — this
  adoption is the event it foretold — and the canonical "make CI pass" clause
  (this repo has no CI; revisit if that changes).
- **Not** folded in: the top-of-file "substrate before commands" build-order
  bullet. Issue #12 suggested folding it here, but it is orientation about
  build order, not merge process; placing non-merge guidance inside this
  section would put it under this artifact's hash and trip the wire on
  unrelated edits. It stays in the file's intro bullets, outside the section.
- Appended: a pointer to the pre-push hook and its per-clone activation, so
  the section names both halves of the policy.

The hook is the canonical `assets/pre-push` **verbatim** (default
`protected="main"` already correct), at the default layout
`.githooks/pre-push`, wired by the ability's `setup.sh` (`core.hooksPath` →
`.githooks`). That config is per-clone and this repo has no scripted
bootstrap (no package manager, no Makefile — the `.envrc` only sets a gh
profile), so per the ability's fallback the README gained a **Contributing**
section with the one-time activation command. The README line is wiring, not
a tracked artifact; if it goes stale, this note is the trace.

`source` was derived from the configured local clone's `origin` remote. The
clone sat on a non-default branch (`adopt/squash-merge-policy`), so the
ability's content was verified byte-identical to `origin/main` before
recording — baseline 1.0.0 exists on the upstream default branch.

**Host-side suggestion (suggest, don't do): deferred.** At adoption the
GitHub repo still allows merge commits and rebase merges
(`mergeCommitAllowed: true`, `rebaseMergeAllowed: true`). The ability's
suggested `gh repo edit --enable-merge-commit=false
--enable-rebase-merge=false --enable-squash-merge` is surfaced in the
adoption PR for the repo admin; it was not executed because host-side actions
require an explicit yes, which a non-interactive run cannot obtain.

## 2026-07-23 — Host-side suggestion executed

The merge-settings change deferred at adoption was run by the repo admin
while this PR was open (`gh repo edit jlopez/claude-abilities
--enable-merge-commit=false --enable-rebase-merge=false`); verified state is
`allow_merge_commit: false`, `allow_rebase_merge: false`,
`allow_squash_merge: true`. The no-merge-commits constraint is now enforced
server-side (covering the PR-merge path the pre-push hook cannot see) as
well as locally by the hook. The adoption entry's "deferred" bullet above is
history — this entry supersedes it.
