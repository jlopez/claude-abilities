---
description: Configure which abilities repositories the plugin reads from — register a local path or a git repo as an abilities repository source, or list/change what is configured.
disable-model-invocation: true
argument-hint: "[<path-or-repo>] [--name <name>]"
---

# /abilities:setup — configure abilities repositories

You are configuring the **abilities plugin**. An *abilities repository* is a
content repo holding one directory per ability (see the plugin's design,
`docs/design.md` §2 in the plugin repo). This command registers which
repositories the other `/abilities:*` commands read from. It touches **only
plugin-level configuration** — never the current project repo — so it does not
end in a PR.

Arguments given by the user: `$ARGUMENTS`

## Where configuration lives

The config file is `config.json` inside the plugin's persistent data directory,
which for this installation is:

`${CLAUDE_PLUGIN_DATA}`

**Resolve the data directory first.** Run:

```bash
CONFIG_DIR="${CLAUDE_PLUGIN_DATA}"
```

If the literal text `CLAUDE_PLUGIN_DATA` still appears above (the harness did
not substitute it), fall back to the environment variable, then to the default
location:

```bash
CONFIG_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/abilities-claude-abilities}"
```

Then `mkdir -p "$CONFIG_DIR"` and work with `$CONFIG_DIR/config.json`.

Config schema (`version` is the schema version, currently 1):

```json
{
  "version": 1,
  "default": "personal",
  "repositories": {
    "personal": {
      "source": "/Users/me/git/claude-abilities-repository",
      "type": "local",
      "addedAt": "2026-07-23"
    },
    "team": {
      "source": "acme/claude-abilities-repository",
      "type": "git",
      "addedAt": "2026-07-23"
    }
  }
}
```

- `source` — absolute local path (`type: "local"`), or a git remote as
  `owner/repo` shorthand or full URL (`type: "git"`).
- `default` — the repository other commands use when none is named. The first
  repository registered becomes the default automatically.

Use `jq` for all reads and writes of this file.

## Flow

1. **Read current state.** If `$CONFIG_DIR/config.json` exists, read it and keep
   its contents in mind; otherwise treat the config as empty.

2. **No arguments given?** Show the user the currently configured repositories
   (name, source, which is default — or "none configured yet") and ask what
   they want to do: register an existing repository (ask for its path or repo),
   change the default, remove an entry, or create a brand-new abilities
   repository from scratch (see *Not implemented* below).

3. **Resolve and validate the source** (do this before writing anything):
   - **Local path**: expand `~`, make it absolute. It must be an existing
     directory. If it is not a git repository, mention that but allow it.
   - **Git remote** (`owner/repo` or URL): verify it is reachable with
     `git ls-remote <url> HEAD` (for `owner/repo` shorthand, try
     `https://github.com/owner/repo.git`). If unreachable, tell the user and
     stop — do not record a dead pointer.
   - **Deliberately do NOT validate the repository's internal structure.** The
     ability format is defined by roadmap item 2 and this command must not
     depend on it. Any directory/repo the user points at is accepted.

4. **Choose a name.** Use `--name` if given; otherwise derive it from the
   basename of the path/repo (e.g. `claude-abilities-repository`), offering the
   user a chance to shorten it. If the name already exists in the config, ask
   whether to overwrite that entry.

5. **Write the config** with `jq`: add/update the entry under `.repositories`,
   set `.version = 1`, and if `.default` is empty or this is the first
   repository, set `.default` to this name. Write atomically (write to a temp
   file in `$CONFIG_DIR`, then `mv` over `config.json`).

6. **Confirm.** Show the resulting configuration to the user in plain words:
   which repositories are registered and which is the default. Remind them that
   `/abilities:adopt` (roadmap item 4) will be the first command to read it.

## Not implemented yet

**Creating a new abilities repository from scratch** is not implemented — the
ability format it would scaffold is being defined in roadmap item 2. If the
user asks for it, say exactly that and suggest pointing at an existing
repository instead.
