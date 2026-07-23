---
description: Adopt an ability into the current repo (read ability, prompt for config, transpile into the repo's native primitives, write the adoption record, open a PR). Not implemented yet.
disable-model-invocation: true
argument-hint: "[<ability-id>]"
---

# /abilities:adopt — not implemented yet

Tell the user, plainly and briefly:

> `/abilities:adopt` is not implemented yet — it is **roadmap item 4** and
> depends on the adoption record schema (item 1) and the ability format
> (item 2), which are being finalized.

What it will do (from the design, for context if the user asks): read the
ability from the configured abilities repository, prompt for its config points,
transpile it into this repo's own native primitives (CLAUDE.md sections, hooks,
scripts), write the adoption record under `.claude/abilities/`, and open a PR.
Without an ability id, it will browse the repository, marking installed vs.
installable.

Do not attempt to improvise any of that behavior. If the user wants to prepare,
point them at `/abilities:setup` to configure which abilities repository the
plugin reads from.
