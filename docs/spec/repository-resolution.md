# Repository identity & resolution

> Normative companion to the config schema in
> [plugin-structure.md](plugin-structure.md) (which owns the schema and its
> migration). This file defines what a repository's *identity* is, how two
> identities are matched, how commands obtain a readable checkout, and which
> repository each command uses when several are registered. Item 5 (`diff`/
> `remove`) and item 7 (`publish`) build on these rules; don't re-derive them.

## Identity model: the remote is the identity, the local path is an overlay

A registered repository entry has two fields that matter here:

- **`source`** — the repository's canonical identity: `owner/repo` for
  GitHub-hosted repositories, a full git URL for other hosts. This is what
  adoption records reference (`source` in
  [adoption-record.md](adoption-record.md)), so it must be meaningful on any
  machine. Required.
- **`localPath`** — optional. When present, commands read from this clone —
  the authoring loop: adopt from a working copy before pushing. When absent,
  commands fetch into a plugin-managed cache (below). Presence or absence of
  `localPath` never changes the repository's identity.

**Non-portable escape hatch:** a local repository with *no remote* has no
canonical identity; its `source` is its absolute path. Adoptions from it
produce non-portable records — allowed for experiments, with the user warned
at registration and again at adoption (see adoption-record.md §`source`).

## Canonical form & matching

Two sources refer to the same repository iff their **canonical forms** are
equal. To canonicalize any source string:

1. Strip the protocol (`https://`, `ssh://`, `git://`) and user info
   (`git@`, `user@`). Rewrite scp-style `git@host:path` as `host/path`.
2. Strip a trailing `.git` and any trailing slash.
3. Lowercase the host. Compare the path case-insensitively (GitHub treats
   `Owner/Repo` and `owner/repo` as the same repository) but preserve the
   stored spelling.
4. If the host is `github.com`, the canonical form is `owner/repo`;
   otherwise it is `host/path`.

So `jlopez/claude-abilities-repository`,
`https://github.com/jlopez/claude-abilities-repository.git`, and
`git@github.com:jlopez/claude-abilities-repository` all match. An absolute
path (non-portable entry) canonicalizes to itself and matches only the
identical path.

**Fetch URL:** to fetch an `owner/repo` source, use
`https://github.com/owner/repo.git`. Full URLs are used as given.

## Obtaining a readable checkout

Every command that reads ability content resolves the entry to a directory:

- **`localPath` present** → read that working tree directly. It may contain
  uncommitted or unpushed work — that is the point (the authoring loop);
  adopt notes ahead-of-remote state in the record's prose notes.
- **`localPath` absent** → use the plugin-managed cache at
  `${CLAUDE_PLUGIN_DATA}/cache/<name>` (`<name>` = the entry's key in
  `repositories`). If the directory does not exist:

  ```bash
  git clone --depth 1 <fetch-url> "$CONFIG_DIR/cache/<name>"
  ```

  If it exists, refresh it on demand — once per command run, before reading:

  ```bash
  git -C "$CONFIG_DIR/cache/<name>" fetch --depth 1 origin HEAD
  git -C "$CONFIG_DIR/cache/<name>" reset --hard FETCH_HEAD
  ```

  The cache is disposable: on any inconsistency, delete the directory and
  re-clone. When setup removes a registered entry, it also removes that
  entry's cache directory.
- **Path-only (non-portable) entry** → read the path directly; there is no
  upstream to fetch.

## Which repository a command uses

- **`/abilities:setup`** — manages the entries themselves; no resolution.
- **`/abilities:adopt <id> --repo <name>`** — the named entry, exactly. An
  unknown name is an error (list the registered names). The flag form is
  `--repo <name>`, deliberately not a `repo:id` prefix — colon syntax
  collides visually with the `/abilities:` command namespace.
- **`/abilities:adopt <id>`** (no qualifier) — with a single registered
  repository, use it. With several, check each registered repository for the
  id (localPath or refreshed cache):
  - found in exactly one → use it; if that is not the default repository,
    say which one it came from;
  - found in more than one → **ask the user which to adopt from — never
    guess**, even if one of them is the default;
  - found in none → report not-found against every registered repository.
- **Browse mode** (`/abilities:adopt` with no id) — list across **all**
  registered repositories, grouped by repository (default first), marking
  each ability's origin and installed state. Installed means a record exists
  at `.claude/abilities/<id>.md` *and* its `source` matches this
  repository's identity (canonical match); if the record's source matches a
  *different* registered repository, mark it "installed from `<name>`"
  instead.
- **`/abilities:diff` / `/abilities:update` / `/abilities:publish`** (to a
  base ability) — never ambiguous: the adoption record's `source` pins
  upstream permanently. Resolve `source` → the registered entry whose
  canonical identity matches, and read through that entry (its `localPath`
  overlay applies). If no registered entry matches, **offer to register it**
  (the setup flow, pre-filled with that source); if the user declines, the
  command may proceed for this run from a temporary shallow clone, but
  nothing is persisted. `publish` as a *brand-new* ability has no pinning
  record — it targets the default repository unless the user names another.
