# claude-abilities

A Claude Code **plugin that is a marketplace of "abilities."**

An **ability is not a plugin**. It is a named, versioned capability — expressed as
natural-language instructions to an agent — that **compiles down into a target
repository's own native primitives** (git hooks, repo scripts, `CLAUDE.md` sections,
optionally `.claude/skills/`) and then gets out of the way. A repo that adopted an
ability works for every collaborator, whether or not they have ever heard of this
system: they just see a normal `CLAUDE.md` rule and a normal git hook.

The load-bearing insight: **an ability is an LLM-mediated transpiler.** Its
"source" is instructions plus canonical assets; its "target" is the repo's own
idiom; the compiler is Claude, reading the ability and adapting it to the repo in
a reviewable PR. Adoption, drift analysis, updating, removal, and upstreaming are
all conversations between the user and an agent grounded in a per-repo adoption
record.

## Architecture: two repositories

| Repo | Role | Contents |
|---|---|---|
| **this one** (`claude-abilities`) | The **plugin** — code | Slash commands (`/abilities.*`), the transpiler-agent instructions, tripwire scripts, formats/schemas |
| `claude-abilities-repository` | An **abilities repository** — content | One directory per ability (instructions, assets, config schema, changelog) |

The plugin is pointed at an abilities repository via `/abilities.setup`; any number
of repositories (personal, team) can serve as marketplaces without changing the
plugin.

## Lifecycle commands (planned)

- `/abilities.setup` — configure/create an abilities repository
- `/abilities.adopt` — adopt an ability into the current repo (config prompts → PR)
- `/abilities.diff` — explain, in plain words, how the repo has drifted from an
  ability (cheap hash tripwire first; LLM analysis only when something changed)
- `/abilities.update` — reconcile upstream changes with local state, conversationally
- `/abilities.remove` — remove an adopted ability via PR
- `/abilities.publish` — upstream a locally evolved ability (PR to the base
  ability, or a brand-new ability)

## Status

**Inception.** Nothing is built yet. The full design is in
[docs/design.md](docs/design.md); the build order is in
[docs/roadmap.md](docs/roadmap.md).
