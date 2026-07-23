---
description: Configure which abilities repositories the plugin reads from — register a repository by remote (owner/repo, URL) or local clone path, attach/detach a local working copy, or list/change what is configured.
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

## The identity model (read first)

A repository's **identity is its remote** — `source`, stored as `owner/repo`
for GitHub or a full git URL for other hosts. A **local clone path is an
overlay** — optional `localPath`; when present, commands read that working
copy (the authoring loop: adopt from a clone before pushing), when absent
they fetch into a plugin-managed cache. The path never *is* the identity —
adoption records reference `source`, and they travel with the target repo.

The one exception: a local repository with **no remote** has no canonical
identity, so its absolute path is stored as `source`. That entry is
**non-portable** — adoptions from it produce records other machines cannot
resolve. Allowed for experiments, but warn the user before writing it.

Normative details (canonical form, identity matching, cache layout) are in
`"${CLAUDE_PLUGIN_ROOT}"/docs/spec/repository-resolution.md` — read it if a
situation below is underspecified.

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

Config schema (`version` is the schema version, currently 2):

```json
{
  "version": 2,
  "default": "personal",
  "repositories": {
    "personal": {
      "source": "jlopez/claude-abilities-repository",
      "localPath": "/Users/me/git/claude-abilities-repository",
      "addedAt": "2026-07-23"
    },
    "team": {
      "source": "acme/claude-abilities-repository",
      "addedAt": "2026-07-23"
    }
  }
}
```

- `source` — canonical identity: `owner/repo` (GitHub), full git URL
  (non-GitHub hosts), or an absolute path (non-portable entry, see above).
- `localPath` — optional overlay: an absolute path to a local clone.
- `default` — the repository other commands use when none is named. The first
  repository registered becomes the default automatically.

Use `jq` for all reads and writes of this file.

## Flow

1. **Read current state.** If `$CONFIG_DIR/config.json` exists, read it and
   keep its contents in mind; otherwise treat the config as empty.

2. **Migrate version 1 if found.** If the file says `"version": 1` (entries
   have a `type` field), migrate each entry before doing anything else, per
   the migration rules in
   `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/plugin-structure.md`: `type: "git"` →
   keep `source` (normalized), drop `type`; `type: "local"` → path becomes
   `localPath` and `source` is derived from the clone's origin remote
   (`git -C <path> remote get-url origin`, normalized to `owner/repo` or full
   URL). No remote or missing path → `source` stays the path; warn that the
   entry is non-portable. Write the migrated config back as version 2
   (atomically, as in step 6) and tell the user what changed.

3. **No arguments given?** Show the user the currently configured repositories
   — for each: name, `source`, `localPath` if any (or "cache"), and which is
   default — or "none configured yet". Then ask what they want to do:
   register a repository (ask for its remote or clone path), attach or detach
   a `localPath` on an existing entry, change the default, remove an entry,
   or create a brand-new abilities repository from scratch (see *Not
   implemented* below). When removing an entry, also delete its cache
   directory `$CONFIG_DIR/cache/<name>` if present.

4. **Resolve the source and complete the entry** (do this before writing
   anything). The user may hand you either form:
   - **Git remote** (`owner/repo` or URL): verify it is reachable with
     `git ls-remote <url> HEAD` (for `owner/repo` shorthand, try
     `https://github.com/owner/repo.git`). If unreachable, tell the user and
     stop — do not record a dead pointer. Store the normalized form as
     `source`; no `localPath`.
   - **Local path**: expand `~`, make it absolute. It must be an existing
     directory. Derive the identity: `git -C <path> remote get-url origin`,
     normalized (`owner/repo` for github.com, full URL otherwise) → that is
     `source`; the path itself becomes `localPath`. If the directory is not a
     git repository or has no `origin` remote, **warn**: without a remote the
     entry is non-portable and adoptions from it will produce non-portable
     records (allowed, eyes-open). If the user proceeds, store the absolute
     path as `source` and omit `localPath`.
   - **Dedup by identity**: if the resolved `source` canonically matches an
     existing entry (matching rules in `repository-resolution.md`), do not
     create a duplicate — offer to update that entry instead (typically
     attaching the new `localPath` to it, the "clone your team repo locally"
     move).
   - **Deliberately do NOT validate the repository's internal structure.**
     The ability format is its own contract (`docs/spec/ability-format.md`),
     enforced by the commands that read abilities; any repo the user points
     at is accepted here.

5. **Choose a name.** Use `--name` if given; otherwise derive it from the
   repository name in `source` (e.g. `claude-abilities-repository`), offering
   the user a chance to shorten it. If the name already exists in the config
   (and step 4's dedup didn't already resolve this), ask whether to overwrite
   that entry.

6. **Write the config** with `jq`: add/update the entry under `.repositories`
   (omit `localPath` entirely when there is none — no `null`s), set
   `.version = 2`, and if `.default` is empty or this is the first
   repository, set `.default` to this name. Write atomically (write to a temp
   file in `$CONFIG_DIR`, then `mv` over `config.json`).

7. **Confirm.** Show the resulting configuration in plain words: which
   repositories are registered, which is default, and for each whether
   commands will read a local working copy (`localPath`) or the plugin's
   cache. If an entry is non-portable (path-only `source`), repeat that
   caveat once.

## Not implemented yet

**Creating a new abilities repository from scratch** is not implemented. If
the user asks for it, say exactly that and suggest pointing at an existing
repository instead.
