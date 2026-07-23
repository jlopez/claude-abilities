# Design

> Status: agreed direction as of inception (2026-07-23). This document is the
> source of truth for the design; refine it here before diverging in code.

## 1. What an ability is

An ability is a **named, versioned capability expressed as natural-language
instructions to an agent**, plus supporting assets. Adopting it means an agent
(Claude) reads those instructions and **compiles the capability into the target
repo's own native primitives**: `CLAUDE.md` sections, git hooks, scripts in
`scripts/`, optionally `.claude/skills/`. The result has **zero runtime coupling**
to this system — collaborators need nothing installed.

Key properties:

- **LLM-mediated, not programmatic.** The "transpiler" is an agent following
  instructions like "add this section to `CLAUDE.md`," "write a script in
  `scripts/` that does X," "register a git hook of type Y that does Z." Purely
  mechanizable steps (e.g. wiring a hook path) live in a `setup.sh` the agent
  runs. Consequence: adoption is adaptive — the same ability produces
  repo-idiomatic results in different repos. That is a feature, and it is anchored
  by the ability's canonical assets (see §3).
- **Configurable.** An ability declares config points; the adopting agent prompts
  the user for them and parts of the instructions are gated on the answers
  ("if `enforce_hook`, install the pre-push hook; else skip").
- **PR-per-operation.** Adopt/update/remove each land as a reviewable PR. This is
  the feature, not ceremony: a human gate on machine-written changes, an audit
  trail, and it composes with the target repo's own merge policy (the system
  dogfoods the kind of ability it distributes).
- **Constraint + judgment split.** Where a capability has an enforceable half and
  a judgment half, abilities should enforce the constraint with a hook (100%
  reliable, zero cognitive cost) and reserve `CLAUDE.md`/skill text for the
  judgment nothing else can do. The canonical first ability — the squash-merge
  policy (§8) — exercises both paths.

## 2. Two-repo architecture

- **Plugin repo** (this repo): the `/abilities.*` slash commands, the agent
  instructions behind them, the tripwire scripts, and the schemas for the ability
  format and adoption record. Code; versions slowly.
- **Abilities repository** (first instance: `../claude-abilities-repository`,
  published as `jlopez/claude-abilities-repository`): one directory per ability.
  Content; versions often. `/abilities.setup` points the plugin at one (or,
  later, several). Team sharing = pointing at a shared abilities repository;
  no plugin changes required.

## 3. Ability format (skill-shaped directory)

> Specified normatively in [spec/ability-format.md](spec/ability-format.md);
> this section is the summary.

One directory per ability in the abilities repository:

```
squash-merge-policy/
  ABILITY.md      # frontmatter + instructions to the adopting agent
  assets/         # canonical artifacts: hook script, CLAUDE.md section text, ...
  setup.sh        # optional: the mechanizable tail (chmod, hook wiring, ...)
```

`ABILITY.md` frontmatter declares:

- `id`, `name`, `version`, and a one-line `description` (so browse listings
  don't require opening `ABILITY.md`)
- `config` — the config points, each with a prompt, type, and default
- `mode` — recommended tracking mode (§5), overridable at adoption
- `artifacts` — a **loose inventory** of what the ability touches ("a `CLAUDE.md`
  section about merging; a pre-push hook; a script in `scripts/`"). Not a machine
  contract — a checklist that tells `diff`/`remove` where to look.
- `changelog` — per-version entries carrying **prose intent**, not just deltas
  ("v1.3 generalized the package manager after Scarpa's fork hardcoded pnpm").
  Future update conversations *explain* upstream changes; the changelog is what
  they explain from.

The body is written **to the adopting agent**: how to install, what to adapt to
the repo's idiom, what is gated on which config value, what must stay faithful to
the assets. The assets anchor what "faithful" means (§5) — adaptation is to form,
not substance.

## 4. Adoption record (the manifest)

The identity problem is unavoidable: an adopted ability dissolves into the repo,
so without a record, every later operation starts with archaeology — fragile
pattern-matching over whether this repo even uses the ability. **A per-repo
adoption record is not optional.** But it is an *adoption record*, not a
lockfile: its reader is as much a future LLM as a script.

Finalized shape (normative spec: [spec/adoption-record.md](spec/adoption-record.md),
with a worked example in [spec/examples/](spec/examples/squash-merge-policy.md)):
one file per adopted ability under `.claude/abilities/`, markdown with YAML
frontmatter:

- **Structured fields** (frontmatter): ability `id`; the `source` abilities
  repository it was adopted from; **baseline version** — the last upstream
  version consciously reconciled against (merge-base semantics, §5); tracking
  `mode`; the adoption date; the **config answers** given at adoption; the
  artifact inventory as realized in *this* repo; **tripwire hashes** of those
  artifacts. Artifacts that live inside a shared file (a `CLAUDE.md` section)
  are `section`-scoped so unrelated edits to the file don't trip the wire.
- **Prose notes** (body): the adoption-time decisions, written for the next agent
  — "skipped the CI portion because this repo has no CI; user rejected the
  pre-push hook as too aggressive; chose pnpm." Appended to on every
  update/reconcile: an **LLM changelog** of this repo's relationship with the
  ability.

**Tripwire hashes** exist for one purpose: letting `/abilities.diff` (and the
eventual CI job) answer "did anything change on either side?" with a cheap plugin
script — comparing artifact hashes against recorded ones, and the baseline version
against upstream latest — so expensive LLM analysis runs only when something
actually moved. They are *not* the drift verdict; the LLM is. Hashes record the
**last acknowledged state** of the artifacts, not upstream's canonical state:
they refresh only on conscious operations (adopt, update/reconcile, or an
explicit guideline-mode *acknowledge* that records local evolution without
advancing the baseline) — otherwise legitimate evolution would leave the wire
permanently tripped.

## 5. Tracking modes: faithful vs. guideline

Chosen **per adoption** (ability recommends a default) and recorded in the
adoption record:

- **Faithful**: drift is deviation. `diff` flags it; `update` proposes restoring/
  reconciling toward upstream. Faithfulness is to the spec's *substance* (as
  anchored by the assets), not to bytes — a reworded-but-equivalent section is
  not drift.
- **Guideline**: drift is *evolution*. `diff` is informational — "here's how
  you've diverged; here's what upstream changed since your baseline." `update` is
  a conversation about which upstream changes to take. The recorded **baseline
  version advances only when the user consciously reconciles**, not when upstream
  releases.

This split resolves the update-conflict question: there is no silent three-way
merge anywhere. The agent proposes, explains, and the human decides — in
conversation and then in the PR.

## 6. Lifecycle commands

All are agent conversations grounded in the adoption record; adopt/update/remove
end in a PR.

> **Naming note (2026-07-23):** the harness namespaces plugin commands with a
> colon, so the implemented surface is `/abilities:setup` etc. The dot form
> below is kept as design shorthand. See
> [spec/plugin-structure.md](spec/plugin-structure.md).

- **`/abilities.setup`** — on-demand only. Configure (or create) the abilities
  repository this plugin reads from.
- **`/abilities.adopt <id>`** — read the ability, prompt for config, transpile
  into the repo, write the adoption record, open a PR. Without an id: browse
  available abilities, marking installed vs. installable.
- **`/abilities.diff [<id>] [<version>]`** — tripwire first; if tripped, an LLM
  explanation in plain words of what drifted locally and what changed upstream,
  interpreted through the tracking mode.
- **`/abilities.update <id>`** — a reconciliation conversation: which upstream
  changes to take, how they interact with local evolution; ends in a PR and an
  advanced baseline + appended prose notes.
- **`/abilities.remove <id>`** — remove what the record says was added (flagging
  anything the user built on top); via PR.
- **`/abilities.publish`** — the inverse transpile: from this repo's evolved
  artifacts, author a generalized ability. **Parameter: PR against the base
  ability, or a brand-new ability.** The agent proposes config points during
  generalization ("this script hardcodes pnpm — parameterize the package
  manager?").

## 7. Endgame: self-updating CI

A repo can run a CI job — "dependabot for behaviors" — that uses the tripwire
script to detect movement and opens update PRs for a chosen subset of adopted
abilities. **Gated on `/abilities.update` being genuinely trustworthy first**:
shipping it early trains users to rubber-stamp update PRs, and credibility does
not come back. Sequenced last.

## 8. Canonical first ability: squash-merge policy

The merge policy born in the Scarpa repo: every change reaches `main` via PR;
docs updated in the PR they describe; **squash-merge always** (no merge bubbles)
with a novel, curated commit message. It is the ideal proving ground because it
has:

- a **constraint half** → enforce via hook (block merge commits),
- a **judgment half** → `CLAUDE.md` text (curate the message),
- an obvious **config point** → `enforce_hook: yes/no`.

## 9. Open questions

- **Naming.** "Ability" is a working name and overloaded in the agent world.
  Leading alternative: **grafts** — captures "takes and becomes native," and in
  guideline mode, "grows with the tree." Decide before publishing publicly;
  it renames the commands.
- **Team scope.** The first abilities repository is personal. Team-shared
  repositories raise concurrent-adoption questions (multiple people adopting/
  updating on the same target repo) — revisit when a second person exists.

## 10. Known costs (accepted, eyes-open)

- **Non-determinism**: the same ability yields different artifacts in different
  repos. Feature in guideline mode; in faithful mode, held to the substance bar
  anchored by assets.
- **Every deep operation costs an agent run.** Acceptable interactively; the
  tripwire keeps the automated paths cheap in the common no-change case.
