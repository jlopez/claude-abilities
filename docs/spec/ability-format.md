# Ability format

> Status: normative spec, completing roadmap item 2. Refines
> [design §3](../design.md#3-ability-format-skill-shaped-directory); if the two
> disagree, this document wins and design.md should be updated. The reference
> instance is
> [`squash-merge-policy`](https://github.com/jlopez/claude-abilities-repository/tree/main/squash-merge-policy)
> in the abilities repository — the format and that ability were designed
> together, and new format questions should be settled by authoring against it.

An ability is a named, versioned capability expressed as **natural-language
instructions to an adopting agent**, plus the canonical assets those
instructions install. This spec defines the on-disk format an abilities
repository stores them in.

## 1. Directory layout

One directory per ability, at the top level of an abilities repository. The
directory name **is** the ability `id`:

```
<id>/
  ABILITY.md      # frontmatter (declarations) + body (instructions to the adopting agent)
  assets/         # canonical artifacts: hook scripts, CLAUDE.md section text, ...
  setup.sh        # optional: the mechanizable tail (chmod, hook wiring, ...)
```

Nothing else is required. An ability with no mechanizable tail omits
`setup.sh`; an ability whose artifacts are entirely described in prose could in
principle omit `assets/`, but should not — assets are what anchor faithfulness
(§5), so every artifact of substance should have a canonical form there.

## 2. `ABILITY.md` frontmatter

YAML frontmatter declaring what the ability is and what it touches. All fields
below are required unless marked optional.

```yaml
---
id: squash-merge-policy          # kebab-case, equals the directory name
name: Squash-merge policy        # human display name
description: >                   # one line, shown in browse listings
  PR-only, squash-merge-always main with curated commit messages;
  optionally enforced by a pre-push hook.
version: 1.0.0
mode: faithful                   # recommended tracking mode: faithful | guideline
config:
  enforce_hook:
    prompt: Install a pre-push hook that blocks merge commits from reaching main?
    type: boolean
    default: true
artifacts:
  - A "Merging to main" section in CLAUDE.md
  - A pre-push hook rejecting merge commits pushed to the default branch (only if enforce_hook)
changelog:
  - version: 1.0.0
    date: 2026-07-23
    intent: >
      Initial release, extracted from the Scarpa repo's merging policy. ...
---
```

### `id`

Kebab-case identifier, unique within the abilities repository, equal to the
directory name. This is what lifecycle commands take (`/abilities.adopt
squash-merge-policy`) and what the adoption record keys on.

### `name`, `description`

Display strings for browse listings (`/abilities.adopt` with no id, the
eventual browser UI). `description` is one sentence; a reader should be able to
decide "do I want this?" from the listing alone, without opening `ABILITY.md`.

### `version`

Semantic-version string. Precise semver discipline is not the point — the
changelog's prose intent is the real carrier of meaning — but the tiers set
reader expectations:

- **major** — the *substance* changed: a faithful-mode adopter who updates must
  change what their repo does.
- **minor** — additive: new config point, new optional artifact, expanded
  instructions. Existing adoptions remain conformant.
- **patch** — wording, bug fixes in assets, clarifications. No substance change.

The adoption record stores the **baseline version** — the last version the
adopting repo consciously reconciled against. Version comparisons are the cheap
half of the tripwire (design §4).

### `config`

A map of config points, keyed by a snake_case config id. Each entry:

| key | required | meaning |
|---|---|---|
| `prompt` | yes | The question the adopting agent asks the user, verbatim or lightly contextualized. |
| `type` | yes | `boolean`, `string`, or `choice`. |
| `default` | yes | Used when the user accepts defaults or adoption runs non-interactively. |
| `choices` | `choice` only | List of allowed values. |

Config points gate installation steps ("if `enforce_hook`, install the hook;
else skip") and parameterize assets ("substitute the chosen package manager").
The body must say explicitly which steps and artifacts each config value gates
(§4). The user's answers are stored in the adoption record, so future
operations know which branches were taken.

An ability with nothing to configure declares `config: {}` — the field stays
present so its absence is never ambiguous.

### `mode`

The tracking mode (design §5) the author recommends: `faithful` (drift is
deviation) or `guideline` (drift is evolution). The adopting user can override
at adoption; the *chosen* mode lives in the adoption record. Choose `faithful`
when the ability's value is uniformity (policies, enforcement); `guideline`
when its value is a starting point (scaffolds, templates).

### `artifacts`

A **loose inventory** of what the ability touches, as a list of prose strings.
This is a checklist, not a machine contract: it tells `diff` and `remove` where
to look, and tells a human skimming the frontmatter what adoption will do to
their repo. Conditional artifacts note their gate inline: *"(only if
`enforce_hook`)"*.

Realized paths — where these artifacts actually landed in a given repo — belong
to the adoption record, not here. The inventory deliberately does not name
target paths, because adoption is adaptive: the same hook may land in
`.githooks/`, `.husky/`, or a lefthook config depending on repo idiom.

### `changelog`

A list of per-version entries, **newest first**, each with `version`, `date`
(ISO), and `intent` — prose explaining *why* the version exists and what an
adopter should understand about it, not a mechanical delta ("v1.3 generalized
the package manager after Scarpa's fork hardcoded pnpm"). Future
`/abilities.update` conversations explain upstream changes to the user; the
changelog is what they explain *from*. Write each entry for that reader: an
agent mediating between this ability's history and a repo that adopted an older
version.

## 3. Body conventions

The body of `ABILITY.md` is written **to the adopting agent**, in the second
person, as instructions. It is the "source" the LLM-transpiler compiles;
everything the agent needs to install, adapt, and bound the ability must be in
it. Use these sections, in this order (an ability may add sections, but these
four must exist):

1. **What this ability does** — the capability in a paragraph or two, including
   the constraint/judgment split if the ability has one (which half is enforced
   mechanically, which half is instruction text).
2. **Installation** — ordered steps. Each step names the asset it materializes
   (if any) and states its config gate explicitly ("Only if `enforce_hook`:
   …"). Steps that are purely mechanical point at `setup.sh` rather than
   spelling out shell commands.
3. **Adapt to the repo** — what the agent is *expected* to change: wording and
   heading style to match the host file, CI job names, branch names, hook
   wiring to the repo's existing convention, placeholder substitution. This
   section is what makes the same ability land idiomatically in different
   repos.
4. **Keep faithful** — the substance that must survive every adaptation,
   stated as explicit invariants and anchored to the assets. This is the
   section `diff` reads when judging whether local drift is deviation
   (faithful mode) or evolution (guideline mode).

The boundary between sections 3 and 4 *is* the ability's definition of
faithfulness: adapt form, preserve substance. Authors should spend their effort
there.

## 4. `assets/`

Canonical artifacts, one file per artifact of substance: the hook script, the
`CLAUDE.md` section text, the workflow file. Assets serve two roles:

- **At adoption** — the starting material the agent adapts into the repo. The
  body says how each asset may be adapted; anything not licensed by "Adapt to
  the repo" should be carried over as-is.
- **Forever after** — the anchor for "faithful." When `diff` asks whether a
  repo's reworded hook still implements the ability, the comparison is against
  the asset's *substance*, not its bytes. An asset should therefore be written
  to make its substance legible — comments in scripts stating what the check
  guarantees, not just how it works.

Assets use meaningful filenames (`pre-push`, `merging-to-main.md`) and contain
no repository-specific values except clearly marked adaptation points, which
should be conservative defaults that work verbatim (e.g. `protected="main"`),
not template placeholders that fail if unsubstituted.

## 5. `setup.sh`

Optional. The mechanizable tail of installation: `chmod`, hook-path wiring,
symlinks — steps with exactly one correct outcome, where agent freedom adds
risk instead of value. Conventions:

- Run by the adopting agent from the target repo's root, after artifacts are
  materialized, only when installation followed the default layout the script
  assumes (it should state that assumption in a header comment). When the agent
  adapted the layout to repo idiom, the agent adapts or skips the script and
  performs the equivalent wiring itself.
- Idempotent: safe to run twice.
- POSIX sh, no dependencies beyond git and coreutils.

`setup.sh` runs at adoption on the adopter's machine. It does **not** solve
collaborator bootstrap (a fresh clone doesn't run it); if an ability needs
per-clone setup, its body must instruct the agent to wire that into the repo's
existing bootstrap path (package-manager `prepare` script, `make setup`,
README instructions) — see the reference ability for an example.

## 6. Interface with the adoption record

The two specs are halves of one contract (roadmap items 1 and 2). The split:

| the ability format **declares** | the adoption record **stores** |
|---|---|
| config schema (prompts, types, defaults) | the user's config answers |
| loose artifact inventory (prose) | realized artifact paths + tripwire hashes |
| recommended `mode` | the chosen mode |
| `version` + changelog | baseline version last reconciled against |

Nothing in an ability directory ever refers to a specific adoption, and the
adoption record never restates ability content — it points at the ability by
`id` and records only what adoption *realized*. Changes that pressure this
boundary go through both specs deliberately, never by one side drifting.
