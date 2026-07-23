---
description: Adopt an ability into the current repo — read it from the configured abilities repository, prompt for its config and tracking mode, transpile it into the repo's own native primitives, write the adoption record, and open a PR. Without an id, browse available abilities.
disable-model-invocation: true
argument-hint: "[<ability-id>]"
---

# /abilities:adopt — adopt an ability into this repo

You are the **adopting agent**. Adopting an ability means reading its
`ABILITY.md` — natural-language instructions addressed to you — and compiling
the capability into this repo's own native primitives: `CLAUDE.md` sections,
git hooks, scripts. The result has zero runtime coupling to this plugin;
collaborators need nothing installed. The operation ends in an **adoption
record** under `.claude/abilities/` and a **PR** — a human gate on
machine-written changes.

The normative contracts are in the plugin itself — read them when this file
points at them, they are short:

- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/ability-format.md` — what an ability
  declares and how its body instructs you.
- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/adoption-record.md` — the record you must
  write (worked example in `docs/spec/examples/`).

Arguments given by the user: `$ARGUMENTS`

## Hard constraints (read first)

- **Never write to the target repo's `.claude/settings.json`.** Project-scope
  plugin installs live there (`enabledPlugins`); clobbering it silently
  uninstalls plugins. The adoption record goes in `.claude/abilities/<id>.md`
  — creating that directory is safe; `settings.json` is off-limits.
- **Never perform host-side actions** (repository settings, branch
  protection, anything outside the working tree) **without an explicit yes
  from the user in this session.** See step 7.
- **"Keep faithful" is inviolable.** Adaptation is to form, never to the
  substance that section declares.
- The adoption PR is left **open for human review** — never merge it.
- Do not modify the abilities repository or the plugin's own files.

## 1. Resolve the abilities repository

The plugin config lives at `$CONFIG_DIR/config.json` where:

```bash
CONFIG_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/abilities-claude-abilities}"
```

(If the harness substituted a literal path above, use it as-is.)

Read it with `jq`. Distinguish two failure cases — they get different
answers:

- The file does not exist or `.repositories` is empty → no abilities
  repository is configured; point the user at `/abilities:setup` and
  **stop**.
- The file cannot be read (permission denied — sandboxed and headless
  sessions may not be allowed to read `~/.claude/plugins/data/`) → do **not**
  conclude nothing is configured; tell the user to grant read access to the
  plugin data directory (or re-run and approve the prompt) and **stop**.

Use the `.default` repository unless the user named another one. Resolve its
`source` by `type`:

- **`local`** — the source is a directory path; use it directly.
- **`git`** — shallow-clone to a scratch location and use the clone:

  ```bash
  src=$(mktemp -d)/repo
  git clone --depth 1 <url> "$src"   # owner/repo shorthand → https://github.com/owner/repo.git
  ```

Also determine the **`source` value for the adoption record** — the
`owner/repo` the ability actually came from: for `git` sources derive it from
the URL; for `local` sources ask the clone (`git -C <path> remote get-url
origin`) and fall back to the configured path only if there is no remote.

## 2. Browse mode (no ability id)

If no id was given: for each top-level directory of the repository containing
an `ABILITY.md`, read its frontmatter and list `id`, `name`, `version`, and
`description` in a table. Mark each **installed** (a record exists at
`.claude/abilities/<id>.md` in the current repo) or **installable**. Close by
telling the user to run `/abilities:adopt <id>` to adopt one. **Stop.**

## 3. Preflight (with an ability id)

- The current directory must be inside a git repository — adoption ends in a
  PR. If not, say so and stop.
- If `<src>/<id>/ABILITY.md` does not exist, say so, list the ids that do
  exist, and stop.
- If `.claude/abilities/<id>.md` already exists, this ability is already
  adopted here. Summarize the record (baseline, mode, adoption date) and stop
  — re-adoption is reconciliation, which is `/abilities:update`'s job (not
  yet implemented).
- Read `ABILITY.md` in full. Its body must contain the four required
  sections: *What this ability does*, *Installation*, *Adapt to the repo*,
  *Keep faithful*. If any is missing the ability is malformed — report it and
  stop rather than improvising the missing contract.

## 4. Survey the target repo

Before asking the user anything, learn the repo's idiom — this is what
"adapt" adapts to. Establish at least: the default branch; whether `CLAUDE.md`
exists and its heading/tone conventions; how hooks are managed (husky,
lefthook, pre-commit, an existing `core.hooksPath` dir, or nothing); whether
there is CI; the bootstrap path a collaborator runs (npm `prepare`,
`make setup`, README instructions); and the repo's own merge/PR conventions
(`CLAUDE.md`, `CONTRIBUTING.md`).

## 5. Prompt for config and tracking mode

Ask the user (AskUserQuestion fits; one question per point):

- **Each declared config point**, using its `prompt`, with the declared
  `default` as the recommended option. Record every answer — accepted
  defaults included.
- **Tracking mode** — explain in one line what `faithful` (drift is
  deviation) and `guideline` (drift is evolution) mean here, present the
  ability's recommended `mode` as the recommended option, let the user
  override.

If the session cannot prompt (running non-interactively), use the declared
defaults and the recommended mode, and say so explicitly in the record's
prose notes.

## 6. Transpile

Branch first: off the default branch, up to date with its remote. Name the
branch by the repo's own convention if it has one; otherwise `adopt/<id>`.

Then follow the ability's body:

- **Installation** — execute the steps in order, honoring each step's config
  gate. Steps materialize assets from `<src>/<id>/assets/`.
- **Adapt to the repo** — this section licenses adaptation; exercise it
  against what you learned in step 4. The same ability should land as *this
  repo's* version of the capability, not a foreign paste.
- **Keep faithful** — the invariants every adaptation must preserve. When
  adaptation and an invariant conflict, the invariant wins; if the user asks
  for something that breaks one, stop and explain rather than adopting a
  broken ability.
- **`setup.sh`** — run it (from the repo root) only if installation followed
  the default layout it assumes (stated in its header). If you adapted the
  layout to repo idiom, do not run it — perform the equivalent wiring
  yourself in that idiom.

## 7. Host-side "suggest, don't do" actions

If the ability suggests actions outside the working tree (e.g. `gh repo edit`
to disallow merge commits): surface each to the user with what it changes and
why the ability suggests it. Only perform it on an explicit yes. Whatever the
decision — done, declined, deferred — **record it in the adoption record's
prose notes**: nothing local exists to hash, so the notes are the only trace
a future `diff`/`remove` has.

## 8. Write the adoption record

Read `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/adoption-record.md` now (with its
worked example) and follow it exactly. In particular:

- `.claude/abilities/<id>.md`; frontmatter `id`, `source` (from step 1),
  `baseline` = the adopted `version`, the chosen `mode`, `adopted` = today,
  `config` = all answers, `artifacts` = what adoption actually produced at
  the paths where it actually lives.
- An artifact living inside a shared file (the `CLAUDE.md` section case) gets
  `section:` with the heading line **verbatim as it appears in the target
  file after adaptation**.
- Compute every hash with the plugin's script — never ad-hoc shell:

  ```bash
  "${CLAUDE_PLUGIN_ROOT}"/scripts/artifact-hash <path>                # whole file
  "${CLAUDE_PLUGIN_ROOT}"/scripts/artifact-hash <path> "## Heading"   # section
  ```

- Prose notes: one dated `## YYYY-MM-DD — Adopted at <version>` entry with
  the decisions and their reasons — adaptations made and what substance they
  preserve, artifacts deliberately skipped and why, config rationale,
  host-side decisions from step 7. Write it for the next agent.

## 9. Open the PR

Commit everything (artifacts + record) and open a PR against the default
branch, following the **target repo's own merge conventions** — if its docs
prescribe a PR style or merge method, honor them. The body summarizes what
was **installed**, how it was **adapted** and why, what was **skipped**, and
any host-side decisions. Leave the PR open; tell the user it is ready for
review.
