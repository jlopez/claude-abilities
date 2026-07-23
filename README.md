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

## Lifecycle commands

> The harness namespaces plugin commands with a colon, so the surface is
> `/abilities:<cmd>` (see
> [docs/spec/plugin-structure.md](docs/spec/plugin-structure.md)).

- `/abilities:setup` — **implemented.** Configure which abilities repositories
  the plugin reads from (local path or git repo); config lives in the plugin's
  persistent data directory
- `/abilities:adopt` — **implemented.** Adopt an ability into the current repo:
  browse mode without an id; with one, config prompts → repo-adapted artifacts
  → adoption record → PR
- `/abilities:diff` — **implemented.** Explain, in plain words, how the repo
  has drifted from an ability (cheap hash tripwire first; LLM analysis only
  when something changed); in guideline mode can *acknowledge* legitimate
  local evolution
- `/abilities:update` — **implemented.** Reconcile upstream changes with
  local state, conversationally — grouped by version, explained from the
  changelog's intent, every substance decision the user's; ends in a PR and
  an advanced baseline
- `/abilities:remove` — **implemented.** Remove an adopted ability —
  record-guided reversal, via PR
- `/abilities:publish` — **implemented.** Upstream local work as a generalized
  ability: evolve an adopted ability into a new version PR'd against its
  pinned source, or author a brand-new ability from scratch

## Install

This repo is both the plugin and the marketplace that serves it:

```bash
claude plugin marketplace add jlopez/claude-abilities   # or a local checkout path
cd <your-repo>
claude plugin install abilities@claude-abilities -s project   # or -s user
```

Then, in a Claude Code session in that repo:

```
/abilities:setup <path-or-git-repo-of-an-abilities-repository>
```

To iterate on the plugin locally without installing:
`claude --plugin-dir <path-to-this-repo>`.

## Contributing

Merges to `main` follow the squash-merge policy in [CLAUDE.md](CLAUDE.md),
adopted from the `squash-merge-policy` ability (record:
`.claude/abilities/squash-merge-policy.md`). One-time setup per clone to
activate the enforcing pre-push hook:

```bash
git config core.hooksPath .githooks
```

## Status

**Roadmap items 1–7 done — the full command lifecycle is complete**: the
substrate specs (adoption record, ability format), the installable plugin
skeleton with `/abilities:setup`, and the `adopt` → `diff` → `update` →
`remove` → `publish` lifecycle, proven by dogfooding — both this repo and the
abilities repository adopted `squash-merge-policy` through it, and `publish`
sent v1.0.1 upstream from a clarification discovered during this repo's own
adoption. Next: the browser UI (item 8) and self-updating CI (item 9).
Verified harness facts and the config-location decision are in
[docs/spec/plugin-structure.md](docs/spec/plugin-structure.md). The full
design is in [docs/design.md](docs/design.md); the build order is in
[docs/roadmap.md](docs/roadmap.md).
