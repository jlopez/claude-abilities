# claude-abilities (plugin repo)

Claude Code plugin providing a marketplace of "abilities" — LLM-mediated,
versioned transformations that compile capabilities into a target repo's own
native primitives. This repo is the **plugin (code)**; ability content lives in
`../claude-abilities-repository`.

- **Source of truth for the design:** `docs/design.md`. Discuss and update it
  there *before* diverging in code.
- **Build order:** `docs/roadmap.md`. Items 1–2 (adoption record schema, ability
  format) are the substrate; don't start commands before they're settled.
- **Status:** the full command lifecycle (roadmap items 1–7) is done —
  `setup`, `adopt`, `diff`, `remove`, `update`, and `publish`, plus the shared
  `scripts/tripwire` check and the classify-and-fold reconciliation move
  (`docs/spec/reconciliation.md`). Next: items 8–9 (browser UI; self-updating
  CI, gated on update proving trustworthy in real use).

## Merging to main

Every change reaches `main` through a PR, and merges follow a fixed process so
the history stays linear and the docs stay current:

1. Branch off `main` and open a PR.
2. **Before merging, update the docs** — `docs/design.md` (source of truth,
   discussed there before code diverges), `docs/roadmap.md` (check items off in
   the PR that completes them), and this file — in the same PR as the change
   they describe. Keeping docs current is part of merging, not a follow-up: do
   it in the PR so the docs land with the code they describe.
3. **Merge with a squash merge** — `gh pr merge <n> --squash` — always, never a
   merge commit: **no merge bubbles, ever.** Write a *novel* title and body
   describing the change as a whole; omit the refine/debug/troubleshoot churn
   of the branch (that history stays on the PR). One PR becomes one clean,
   self-contained commit on a linear `main`.

`main` is pushed and shared — never rewrite its history. The no-merge-commit
constraint is enforced by the pre-push hook at `.githooks/pre-push`; each clone
activates it once with `git config core.hooksPath .githooks` (see the README's
Contributing section), and that one setting covers every worktree of the clone
— worktrees share the clone's configuration.
