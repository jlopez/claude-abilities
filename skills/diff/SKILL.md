---
description: Explain how the repo has drifted from an adopted ability and what changed upstream (cheap hash tripwire first, LLM analysis only if something moved). Not implemented yet.
disable-model-invocation: true
argument-hint: "[<ability-id>] [<version>]"
---

# /abilities:diff — not implemented yet

Tell the user, plainly and briefly:

> `/abilities:diff` is not implemented yet — it is **roadmap item 5** and
> depends on the adoption record schema (item 1), which defines the tripwire
> hashes it compares against.

What it will do (from the design, for context if the user asks): run a cheap
tripwire script (artifact hashes vs. recorded ones, baseline version vs.
upstream latest); only if something moved, produce a plain-words LLM
explanation of what drifted locally and what changed upstream, interpreted
through the ability's tracking mode (faithful vs. guideline).

Do not attempt to improvise any of that behavior.
