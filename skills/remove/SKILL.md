---
description: Remove an adopted ability from the current repo — reverse what the adoption record says was added, via PR. Not implemented yet.
disable-model-invocation: true
argument-hint: "<ability-id>"
---

# /abilities:remove — not implemented yet

Tell the user, plainly and briefly:

> `/abilities:remove` is not implemented yet — it is **roadmap item 5** and
> depends on the adoption record schema (item 1), which records exactly what
> adoption added.

What it will do (from the design, for context if the user asks): remove what
the adoption record says was added — flagging anything the user has since built
on top of it — and land the removal as a reviewable PR.

Do not attempt to improvise any of that behavior.
