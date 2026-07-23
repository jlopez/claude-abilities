---
description: Publish local work upstream as a generalized ability — evolve an adopted ability into a new version PR'd against its pinned source repository, or author a brand-new ability from this repo's capabilities. The inverse transpile.
disable-model-invocation: true
argument-hint: "[<ability-id>] [--repo <name>]"
---

# /abilities:publish — the inverse transpile

You are the **publishing agent**. Adoption compiles an ability into a repo's
native primitives; publish runs the compiler backwards: from this repo's
evolved artifacts — and from the lessons its adoption carried — author a
**generalized ability**, as a PR to an abilities repository. Two modes:

- **Evolve an adopted ability** — the repo adopted an ability, lived with it,
  and some of what it learned generalizes. Publish the delta as a new version,
  PR'd against the record's pinned `source` repository.
- **New ability from scratch** — the repo has a capability worth extracting
  that no ability declares yet. Author the full directory; PR it to the
  default (or named) repository.

Either way the repo keeps its local idiom; only the *general* form of the
improvement goes upstream, where every other adopter can get it.

The normative contracts are in the plugin itself — read them when this file
points at them, they are short:

- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/ability-format.md` — the format you
  author **into**: frontmatter fields, the four body sections, the
  assets-anchor-substance rule, semver tiers, changelog-with-intent.
- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/adoption-record.md` — the record you
  read (never write) in evolve mode; §6 gives the reading order.
- `"${CLAUDE_PLUGIN_ROOT}"/docs/spec/repository-resolution.md` — how the
  record's `source` pins upstream, identity matching, and which repository a
  brand-new ability targets.

Arguments given by the user: `$ARGUMENTS`

## Hard constraints (read first)

- **Publish writes nothing to the current repo.** No baseline advance, no
  hash refresh, no prose note, no artifact edit — the adoption record's next
  entry belongs to `/abilities:update`, through its own reconcile
  conversation. After the upstream PR merges, this repo is intentionally
  *behind its own contribution*; step 6 says how to handle that honestly.
- **Repo-specifics must not leak upstream.** Assets contain no
  repository-specific values except clearly marked adaptation points with
  conservative defaults that work verbatim (format spec §4). The
  generalization pass (step 4) is where this is enforced.
- **The upstream PR is left open for human review — never merge it**, and
  never push to the abilities repository's default branch. Follow that
  repository's own merge conventions — it may itself have adopted a merge
  policy; read its `CLAUDE.md`/`CONTRIBUTING.md` before opening.
- **Never author inside the plugin cache** (`$CONFIG_DIR/cache/<name>`): it
  is disposable and gets hard-reset on refresh. Author in a `localPath`
  clone (on a fresh branch — see step 6) or a temporary full clone.
- **Don't disturb a `localPath` clone's checkout**: it may be dirty or parked
  on a branch the user cares about. A temporary `git worktree` of that clone
  gives you a fresh branch without touching its state.
- Never write to the current repo's `.claude/settings.json` (as always).

## 1. Choose the mode

- `<id>` given and `.claude/abilities/<id>.md` exists → **evolve** that
  ability (steps 2–6). `--repo` does not apply here — the record's `source`
  pins the destination; if the user passed one that names a different
  repository, say so and stop rather than splitting the lineage.
- `<id>` given, no record → nothing adopted here under that name. Offer it
  as the proposed id for a **new ability** (step 7) — but first list the ids
  that *do* have records, in case this was a typo for an evolve.
- No id → ask: list the adopted abilities (from `.claude/abilities/*.md`) as
  evolution candidates, plus "a new ability from scratch".

If the session cannot ask (non-interactive) and the mode is not already
unambiguous from the arguments, stop — mode is a user decision, never a
guess.

## 2. Evolve: gather the local state

Read in the record spec's §6 order:

1. **Record frontmatter** — `source` (the pinned destination), `baseline`,
   mode, config answers, realized artifact inventory.
2. **Prose notes, top to bottom.** They are half the input: adoption-time
   decisions distinguish an *adaptation* (repo-specific — stays here) from an
   *improvement* (publishable), and deliberate omissions explain artifacts
   you would otherwise misread as drift.
3. **The realized artifacts** at the recorded paths, as they stand now.
4. **Upstream at its latest** — resolve `source` per
   `repository-resolution.md` (registered entry by canonical identity;
   `localPath` overlay applies; unmatched → offer to register, or proceed
   from a temporary shallow clone without persisting anything). Read the
   current `ABILITY.md` — body, *Adapt to the repo*, *Keep faithful*,
   changelog — and `assets/`.

Also run the tripwire —
`"${CLAUDE_PLUGIN_ROOT}"/scripts/tripwire <id>` (the `--map` optimization
from the diff skill applies) — for an honest statement of what moved. Two
readings matter:

- **A clean wire does not mean nothing to publish.** Hashes record the last
  *acknowledged* state, and publishable material also lives in the prose
  notes and in the user's head — an improvement discovered during adoption
  may never have touched a local artifact at all (a bug in an upstream
  asset, a missing instruction, wording that misled the adopting agent).
- **A `behind` baseline changes the arithmetic.** The publishable delta must
  be computed against upstream's *latest*, not the baseline — otherwise you
  republish what upstream already did. Say so, and note that reconciling
  first (`/abilities:update`) may be the cleaner order; the user decides
  whether to publish anyway.

## 3. Evolve: propose the publishable delta

For each difference between the local artifacts and upstream's latest
canonical form, plus each improvement surfaced by the notes or the
conversation, classify:

- **Repo idiom** — an adaptation the ability's *Adapt to the repo* section
  licensed (heading style, CI names, folded-in local process). Stays here;
  not a finding.
- **Generalizable improvement** — a fix or clarification any adopter would
  want: a bug in an asset, clearer wording, an instruction adoption proved
  missing or misleading. Publish.
- **A new dimension** — the local change reveals variation upstream
  hardcodes: "this repo needed X where the ability assumes Y." Propose a
  **config point** (prompt, type, conservative default that preserves
  today's behavior) rather than swapping one hardcoded value for another.
- **Already upstream** — present in latest (someone else published it, or
  it landed between baseline and latest). Drop, and say so.

Present the classification and let the user decide what goes in. Nothing
publishable → say so plainly and stop. If the session cannot ask, proceed
only with what the invocation explicitly asked to publish — never guess the
scope of someone else's contribution.

## 4. Generalize

Strip the publishable changes back out of this repo's idiom:

- Repo-specific values (branch names, tool names, paths, job names) become
  the conservative defaults the format spec requires — values that work
  verbatim in a default repo, marked as adaptation points, never template
  placeholders that fail if unsubstituted.
- Wording addressed to this repo becomes wording addressed to the adopting
  agent of *any* repo.
- Each accepted config point gets declared in frontmatter (`prompt`, `type`,
  `default`, `choices` for `choice`) and its gate stated explicitly in the
  body — the format spec requires the body to say which steps and artifacts
  each config value gates.

## 5. Author the new version

Write the change in the ability's own format — every piece it touches:

- **Assets** — updated canonical artifacts, still written to make their
  substance legible (comments state what a check guarantees, not just how).
- **Body** — the four sections stay in order; update the ones the change
  touches. If the change moved the line between what adapts and what must
  survive, **rewrite *Adapt to the repo* / *Keep faithful* deliberately** —
  that boundary is the ability's definition of faithfulness, and it is what
  every future `diff` judges against.
- **Version** — bump per the format spec's tiers, and write the reasoning
  down (it goes in the PR body): **major** = substance changed, a
  faithful-mode adopter who updates must change what their repo does;
  **minor** = additive, new config point or optional artifact or expanded
  instructions, existing adoptions remain conformant; **patch** = wording,
  asset bug fixes, clarifications — no substance change.
- **Changelog** — a new entry, **newest first**, with `version`, `date`,
  and `intent` prose that explains the *why* to the future
  `/abilities:update` conversations that will explain it to other adopters.
  Name the provenance: which repo's adoption surfaced this, and what went
  wrong or was missing ("discovered adopting into a worktree-based
  checkout, where …").

## 6. Open the upstream PR

Author on a fresh branch off the **remote default branch** of the pinned
`source`:

- `localPath` present → `git fetch origin` there, then a temporary worktree
  (`git worktree add <scratch-dir> -b publish/<id>-<version> origin/<default>`)
  so the clone's own checkout is untouched; remove the worktree when done.
- No `localPath` → a fresh temporary clone of the fetch URL (not the plugin
  cache).

Commit following the destination repository's conventions, push the branch,
and open the PR against its default branch. The PR body carries: what
changed and why, the version-bump reasoning from step 5, the provenance
(which repo, which adoption, what it revealed), and anything deliberately
*not* generalized and why. Leave it **open**.

Then close honestly. Once that PR merges, this repo is intentionally behind
its own contribution: the record's `baseline` still names the old version,
and the next tripwire run will report `behind`. That is correct — do not
"fix" it here. Tell the user the follow-up is **`/abilities:update <id>`**,
whose reconciliation will find these changes already effectively present
locally and advance the baseline through its own conversation.

## 7. New ability from scratch

No record exists; the capability lives only in this repo's primitives.

**Interview the user** (AskUserQuestion fits) until you can answer: which
capability, and why is it worth other repos adopting? Which artifacts
realize it here — files, `CLAUDE.md` sections, hooks, scripts, CI jobs?
Where is the **constraint/judgment split** — what could a hook or script
enforce mechanically, and what needs instruction text (design §1 wants the
constraint half enforced when one exists)? What would *vary* in another repo
(config candidates)? Which tracking mode should the ability recommend —
`faithful` for uniformity (policies, enforcement), `guideline` for starting
points? If the session cannot ask, stop — a from-scratch extraction without
a user is guesswork.

Then run the same generalization pass (step 4) over the identified
artifacts, and author the **complete directory** per the format spec:

- `ABILITY.md` frontmatter: `id` (kebab-case, equal to the directory name,
  unique in the destination repository — check), `name`, one-line
  `description` a browse listing can decide from, `version: 1.0.0`,
  recommended `mode`, `config` (every point with prompt/type/default; `{}`
  if none), `artifacts` (loose prose inventory — say when one is expected to
  live inside a shared file, note config gates inline), `changelog` with the
  initial entry's intent naming where the capability was extracted from.
- The four body sections, in order: *What this ability does*,
  *Installation* (each step names its asset and states its config gate),
  *Adapt to the repo*, *Keep faithful*. The 3/4 boundary is where the
  authoring effort belongs.
- `assets/` — one file per artifact of substance, meaningful filenames.
- `setup.sh` only if there is a genuinely mechanizable tail (idempotent,
  POSIX sh, header stating the layout it assumes).

**Destination**: a brand-new ability has no pinning record — it targets the
**default** repository unless the user named one (`--repo <name>`, or by
answer during the interview). Resolve the entry per
`repository-resolution.md`; read the config as the adopt skill does
(`$CONFIG_DIR/config.json`, migrating v1 → v2 per
`"${CLAUDE_PLUGIN_ROOT}"/docs/spec/plugin-structure.md` if needed;
unreadable config is *not* "not configured" — say so and stop). Then step
6's PR discipline applies unchanged.

One honest coda: the source repo itself has no adoption record for what it
just published, so nothing here tracks the ability's future evolution. If
the user wants this repo held to the published form, the follow-up — after
the PR merges — is a normal `/abilities:adopt <id>`, which will reconcile
with the existing content and land a record at the published baseline.
