# Plugin structure — verified facts & decisions

> Verified 2026-07-23 against the official Claude Code docs (via the
> `claude-code-guide` agent) and confirmed empirically by installing this
> plugin into a scratch repo. Downstream roadmap items (4–7) should rely on
> this file rather than re-deriving harness behavior. Doc sources:
> [plugins](https://code.claude.com/docs/en/plugins.md),
> [plugins-reference](https://code.claude.com/docs/en/plugins-reference.md),
> [plugin-marketplaces](https://code.claude.com/docs/en/plugin-marketplaces.md).

## Verified structure

| Fact | Detail |
|---|---|
| Manifest | `.claude-plugin/plugin.json`; only `name` is required (kebab-case). Everything else (skills, hooks, scripts) lives at the **plugin root**, not inside `.claude-plugin/`. |
| Commands | `skills/<name>/SKILL.md` (recommended; supports bundled assets) or legacy flat `commands/<name>.md`. Frontmatter: `description`, `disable-model-invocation`, `argument-hint`, optional `name`. `$ARGUMENTS` is substituted into the body. |
| Namespacing | Plugin commands are **always** `/plugin-name:command-name`. Dots are not available. Subdirectory nesting does not change the invocation name. |
| Scripts | A plugin can ship scripts anywhere in its tree; reference them as `"${CLAUDE_PLUGIN_ROOT}"/scripts/foo.sh` (the cache-install path makes relative paths useless). Needed for the item-5 tripwire script. |
| Persistent data | `${CLAUDE_PLUGIN_DATA}` → `~/.claude/plugins/data/<plugin>-<marketplace>/`, survives plugin updates. Confirmed: resolves correctly inside a running skill (observed `abilities-claude-abilities`). |
| Hooks | `hooks/hooks.json` (or inline in `plugin.json`); rich event set (SessionStart, PreToolUse, …). Available for future tripwire automation; not used yet. |
| Marketplace | `.claude-plugin/marketplace.json` in the same repo, with `plugins[].source: "."` — **a repo can serve itself as a marketplace**. Confirmed: `claude plugin marketplace add <path-or-github-repo>` then `claude plugin install abilities@claude-abilities` works. |
| userConfig | `plugin.json` may declare `userConfig` options, set at install/`/plugin configure` time, exposed as `${user_config.KEY}`. Considered and rejected for repository config (below). |

## Decision: command surface is `/abilities:<cmd>`

The design (design.md §6) writes `/abilities.setup` etc. The harness **forces
colon namespacing** for plugin commands, so the real surface is
`/abilities:setup`, `/abilities:adopt`, `/abilities:diff`, `/abilities:update`,
`/abilities:remove`, `/abilities:publish` (plugin `name` is `abilities`
precisely so the prefix reads well). Design docs keep the dot form as
shorthand; user-facing text must use the colon form.

## Decision: where `/abilities:setup` config lives

**Plugin-level, in `${CLAUDE_PLUGIN_DATA}/config.json`** (i.e.
`~/.claude/plugins/data/abilities-claude-abilities/config.json`).

Schema (owned by the setup skill; version 2):

```json
{
  "version": 2,
  "default": "personal",
  "repositories": {
    "personal": {
      "source": "owner/repo or full git URL",
      "localPath": "/abs/path (optional)",
      "addedAt": "YYYY-MM-DD"
    }
  }
}
```

- `source` — the repository's **canonical identity**: `owner/repo`
  (GitHub) or a full git URL (other hosts). Required; this is what adoption
  records reference. A remote-less local repository stores its absolute path
  here — a non-portable entry, allowed eyes-open (the user is warned).
- `localPath` — optional overlay. Present → commands read this clone (the
  authoring loop); absent → commands fetch into the plugin-managed cache at
  `${CLAUDE_PLUGIN_DATA}/cache/<name>`. Never part of identity.

Identity matching, cache refresh, and which repository each command uses are
defined in [repository-resolution.md](repository-resolution.md).

**Migration from v1** (which stored `source` as *either* a path or a remote,
disambiguated by `type: "local"|"git"`): any command that reads the config
and finds `"version": 1` migrates every entry, writes the file back as
version 2, and tells the user. Per entry:

- `type: "git"` → keep `source` (normalized to canonical form), drop `type`.
- `type: "local"` → the path becomes `localPath`; `source` is derived from
  the clone's origin remote (`git -C <path> remote get-url origin`,
  normalized). No remote (or the path no longer exists) → `source` stays the
  path and the user is warned the entry is non-portable.

If the session cannot write the config file (sandboxed sessions may be
denied writes to plugin data — gotcha 3 below), migrate in memory, proceed,
and tell the user to run `/abilities:setup` in an interactive session to
persist the migration.

Why this location:

- **Plugin-level, not per-repo** — design §2: repositories are something the
  *plugin* reads from; the same user works across many target repos, and a
  per-repo pointer would be meaningless to collaborators who don't run the
  plugin (the per-repo artifact is the adoption record, roadmap item 1). A
  per-repo *override* can be added later without breaking this schema.
- **`CLAUDE_PLUGIN_DATA` over a hand-rolled dotfile** — it is the
  harness-sanctioned per-plugin storage, survives plugin updates, and needs no
  path invention.
- **Not `userConfig`** — `userConfig` values are set through the install/
  `/plugin configure` flow, not writable by a conversational agent command
  mid-session; design §6 specifies setup as an on-demand *conversation*.
  Revisit if the harness ever lets skills write userConfig.

Setup deliberately does **not** validate the internal structure of a
repository it registers (that's the item-2 format's job) and does **not** end
in a PR (it touches plugin config only, never the target repo).

## Install & E2E test procedure (performed 2026-07-23)

```bash
claude plugin marketplace add <path-to-this-repo>   # or jlopez/claude-abilities
cd <target-repo>
claude plugin install abilities@claude-abilities -s project   # or -s user
claude plugin details abilities        # inventory: 6 skills, ~350 always-on tokens
# in a session in <target-repo>:
#   /abilities:setup <path-to-abilities-repo> --name personal
#   /abilities:setup            → lists configured repositories
#   /abilities:adopt <id>       → honest stub (roadmap item 4)
```

Verified end-to-end: marketplace add from local path; install (project
scope); skill invocation with arguments; source validation (git repo
detection); `${CLAUDE_PLUGIN_DATA}` resolution; config write via the skill's
`jq` flow; no-argument list mode reading the config back; stub commands
answering honestly. `claude plugin validate .` passes (strict mode warns only
that the repo's `CLAUDE.md` is not plugin context — expected; it is
development instructions, not plugin content).

## Harness gotchas discovered (relevant downstream)

1. **Project-scope installs live in the target's `.claude/settings.json`**
   (`enabledPlugins`). Overwriting that file removes the plugin.
2. **Workspace trust gates everything headless.** In an untrusted directory,
   `claude -p` ignores project settings *and does not load project-scoped
   plugins* ("Unknown command"). Trust must be accepted interactively once (or
   pre-seeded in `~/.claude.json`). Directly relevant to item 9 (self-updating
   CI) and any headless testing.
3. **Headless (`-p`) sessions cannot approve permission prompts**, and writes
   to `~/.claude/plugins/data/` are treated as sensitive. Interactive use just
   prompts once; automation needs pre-granted allow rules
   (`Write(//…/plugins/data/abilities-claude-abilities/**)`, `Bash(jq *)`, …)
   in a *trusted* project's settings. Item 9 must budget for this.
   Confirmed during item 4: sandboxed headless sessions may be denied even
   **reads** of `${CLAUDE_PLUGIN_DATA}` — skills that read config there must
   distinguish "unreadable" from "not configured" (adopt does; future
   commands should too).
4. **`claude plugin validate <repo>` validates the marketplace manifest when
   both manifests exist**; point it at `.claude-plugin/plugin.json` to validate
   the plugin itself.
5. **Plugins are cached on install** (`~/.claude/plugins/cache/…`): the whole
   repo is copied, and edits to the source repo do not propagate until
   `claude plugin update`. For skill iteration, use `claude --plugin-dir`.
6. **Headless sessions cannot write under the target repo's `.claude/`
   either** (discovered during item 5's E2E): Write/Edit of
   `.claude/abilities/…` is auto-denied as a sensitive path even with
   explicit absolute `Write(//…/.claude/**)` allow rules; only an
   interactive approval clears it. Skills that write records must therefore
   degrade gracefully — write the proposed content to a non-`.claude`
   fallback path and hand the user the exact landing commands (adopt and
   diff's acknowledge both do). Item 9 must assume record writes need either
   an interactive session or a landing step outside the harness.
