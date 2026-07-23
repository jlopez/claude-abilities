# claude-abilities (plugin repo)

Claude Code plugin providing a marketplace of "abilities" — LLM-mediated,
versioned transformations that compile capabilities into a target repo's own
native primitives. This repo is the **plugin (code)**; ability content lives in
`../claude-abilities-repository`.

- **Source of truth for the design:** `docs/design.md`. Discuss and update it
  there *before* diverging in code.
- **Build order:** `docs/roadmap.md`. Items 1–2 (adoption record schema, ability
  format) are the substrate; don't start commands before they're settled.
- **Status:** inception — prefer refining formats over building surface area.

## Merging to main

Every change reaches `main` through a PR. Update the docs (`design.md`,
`roadmap.md`, this file) in the same PR as the change they describe. **Merge
with a squash merge** (`gh pr merge <n> --squash`) — never a merge commit — with
a novel, curated title and body describing the change as a whole. `main` is
linear; never rewrite its history.

*(This section is the seed of the canonical "squash-merge-policy" ability; once
the plugin works, this repo should adopt it through the plugin itself.)*
