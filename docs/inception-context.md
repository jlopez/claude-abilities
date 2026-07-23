# Project Inception Context — "Abilities" Marketplace for Claude Code

> **⚠️ Historical document.** This was the handoff that seeded the project. It is
> **superseded by [design.md](design.md)** and preserved for the origin story and
> the cognitive-impact analysis (§2). Two things it gets wrong relative to the
> agreed design: abilities are **LLM-mediated, not programmatic** (the
> "transpiler" is an agent following instructions), and the manifest is an
> **adoption record with prose notes**, not a fingerprint lockfile — drift
> detection is semantic, with hashes serving only as a cheap tripwire.

> **Original purpose of this file.** This is a handoff document. The design below emerged from a
> discussion in another repo (Scarpa). We are restarting that discussion in *this* folder,
> which will become the project's own repository. Read this top-to-bottom to resume with
> full context — it is written to be self-contained for a fresh Claude session and for the
> user. Nothing here is built yet; this is **inception / design**, not implementation.
> The example flows are illustrative and **meant to be refined**, not locked.

---

## 0. TL;DR

Build a Claude Code **plugin that is a *marketplace* of "abilities."** An **ability is not a
plugin** — it is a **named, versioned transformation that modifies a target repository in
place** (git hooks, repo scripts, optionally `.claude/skills/`, and `CLAUDE.md` edits), then
gets out of the way. The plugin ships slash commands to browse, adopt, update, diff, and
remove abilities. Every operation lands as a **PR the user reviews and merges**.

The load-bearing insight: **an ability is a transpiler.** It compiles a named capability down
into the target repo's *own native primitives*, so the repo (and its collaborators) need
nothing from the abilities system at runtime. This is what makes it more portable than a
plugin-of-one.

The hard part is **not** the commands — it's **identity**: because an ability dissolves into
the repo, you need a **manifest + per-artifact fingerprints** to know what's installed, at what
version, and whether the user has since hand-edited it. Design that substrate *first*.

---

## 1. Origin story — how we got here

### 1.1 The concrete change that started it
Working in the **Scarpa** repo (a MOOC-style anatomy study app), the user and I codified a
"Merging to main" policy in that repo's `CLAUDE.md`. It went through two iterations:

1. First we wrote a **rebase-only** policy (preserve every commit; no merge bubbles).
2. The user then **amended it to squash-merge-always** with a curated, holistic commit
   message — and had me apply the amendment *through the very process it documents*
   (branch → PR → update `CLAUDE.md` → CI green → **squash-merge with a curated message**).

The final policy text (this is the canonical **example ability** — "squash-merge policy"):

```markdown
## Merging to main

Every change reaches `main` through a PR, and merges follow a fixed process so the
history stays linear and this file stays current:

1. Branch off `main`, open a PR, and make CI pass (the `check` / `build` jobs).
2. Share the PR preview (`scarpa-pr-<n>.jesusla.com`) for review.
3. **Before merging, update this `CLAUDE.md`** so it reflects whatever the PR changed
   (structure, routes, deploy, conventions — including this process itself). Keeping the
   doc current is part of merging, not a follow-up; do it in the PR so the doc lands with
   the code it describes.
4. **Merge with a squash merge** — `gh pr merge <n> --squash` — always, never a merge
   commit: **no merge bubbles, ever.** Write a *novel* title and body describing the
   feature/fix as a whole; omit the refine/debug/troubleshoot churn of the branch (that
   history stays on the PR). One PR becomes one clean, self-contained commit on a linear
   `main`.

`main` is pushed/shared — never rewrite its history (no amend/force-push on the root commit).
```

Note the two *natures* mixed in this one policy — they matter later (§5.6):
- Points 1 & 4's "squash-only / no merge bubbles" is a **constraint** → best *enforced* (hook).
- Point 4's "write a novel, curated message" is **judgment** → inherently *cognitive*.

### 1.2 The meta-question the user asked
> Is putting an ability in `CLAUDE.md` the most **portable/shareable** way to add it — one
> that allows sharing between projects from an **à-la-carte menu** — and the most efficient way
> to **standardize/centralize** a capability across many projects? All for a given **cognitive
> impact**, which is the variable to **maximize above all else** (with the hypothesis that
> `CLAUDE.md` may be *more* cognitively impactful than skills, due to how the harness injects it).

---

## 2. Analysis: extension mechanisms & "cognitive impact"

### 2.1 "Cognitive impact" is a product of three factors
- **Presence** — is the instruction in context at the deciding moment?
- **Framing authority** — how strongly is it wrapped? (`CLAUDE.md` uniquely gets the harness's
  `MUST follow / OVERRIDE default behavior` wrapper.)
- **Non-dilution** — how much else competes for attention around it? (A rule in a 40-line
  `CLAUDE.md` is loud; the same rule in a 400-line file is buried — "lost in the middle.")

**Consequence:** "maximize cognitive impact" does **not** mean "put everything in `CLAUDE.md`."
It means put *always-applies* rules there **and keep it lean** so they stay loud.

### 2.2 The two-axis trade-off (no free lunch)
Every mechanism trades **ambient salience** against **packaged portability**:

| Mechanism | Ambient salience | Portability / packaging | Best for |
|---|---|---|---|
| **`CLAUDE.md`** | Max (always present + override framing) | Min (monolithic, repo-bound, copy-paste to share) | Always-applies rules |
| **Skills** (`.claude/skills/`) | Low ambient (only the 1-line *description* is always in context; body loads on invoke) | High (self-contained dirs; plugin/marketplace-distributable) | On-demand procedures; per-token impact is *higher* when loaded because it's fresh & uncompeted |
| **Plugins** | (delivers skills/commands/hooks) | Highest (versioned bundle, shared via marketplace = a git repo) | Distribution layer — **but ships skills/commands/hooks, NOT `CLAUDE.md` text** |
| **Hooks** (`settings.json` / git) | N/A (deterministic, not cognitive) | Plugin-distributable | *Enforcing* constraints with 100% reliability, zero cognitive cost |

The crux tension: the **highest-impact channel** (`CLAUDE.md`) is the **least packageable**;
the **most packageable channel** (plugins) delivers abilities in forms that, for always-on
rules, **cost salience** (a skill only fires if its trigger is recognized).

### 2.3 The `@import` lever (partial best-of-both)
`CLAUDE.md` supports `@path` imports (incl. home dir, e.g. `@~/.claude/policies/squash.md`).
Imported files are **inlined into the same wrapped block**, inheriting full override framing
and salience. This gives centralization (one source of truth) + à-la-carte (each project
imports what it wants) + full impact. **Caveats:** imports are inlined (no context savings —
still count toward dilution) and live in *your* home dir (centralizes across *your* machine,
not a team). For team/multi-machine distribution you're back to plugins.
> ⚠️ Verify exact `@import` resolution rules and the plugin/hook manifest format against
> current Claude Code docs before relying on them (use the `claude-code-guide` agent).

### 2.4 The hybrid principle (this shaped the whole project idea)
For a rule with both a *constraint* half and a *judgment* half, **enforce the constraint with a
hook and reserve cognition for the judgment.** A hook removes reliance on memory for what can be
mechanized, which *frees cognitive budget* for the part nothing else can do. The goal isn't
"max cognitive impact everywhere" — it's "spend cognition only where it's irreplaceable."

---

## 3. The vision: an Abilities Marketplace (user's proposal)

Not a plugin *per* ability — **one plugin that is a marketplace** of these
"tweaks"/"abilities" (**name TBD**, see §6). It provides slash commands (illustrative,
to be refined):

- **`/abilities.setup`** — *on-demand only.* Configures/creates a "claude abilities repository"
  (the marketplace source).
- **`/abilities.adopt`** — Adopts an ability by ID; **or** opens a browser showing all abilities
  in the configured repository, marking which are installed locally vs. installable. If feasible,
  **click-to-install**; otherwise a **copy-to-clipboard** button that copies the `/abilities.adopt …`
  line to paste into Claude.
- **`/abilities.remove`** — Remove an installed ability; trash icon in the browser if feasible,
  else copy the `/abilities.remove …` line.
- **`/abilities.update`** — Update an installed ability to a newer version; an update button (or
  "copy update instructions") appears when a newer version exists.
- **`/abilities.diff`** — Explain the differences (if any) between the installed ability and a
  given ability version (or latest if omitted).

### 3.1 What an ability *is* (crucial)
- **Not a plugin.** It is **instructions to Claude on how to modify a repository** to implement
  the capability. That may mean: adding **git hooks**, creating **scripts** in the repo,
  **optionally** new **`.claude/skills/`**, and **`CLAUDE.md`** updates (like the merge dictum).
- The instructions tell Claude to make those changes, **then open a PR**. The **user reviews**
  it; on approval it's **merged to main** (per that repo's own merge policy — see dogfooding, §5.5).

### 3.2 Endgame: self-updating via CI
A repo can have a **CI job that keeps a chosen subset of its adopted abilities up to date** —
programmatically checking whether a newer ability version exists and issuing **update PRs**
(effectively running `/abilities.update`) with whatever repo changes bring it current.
Think **"dependabot for behaviors."**

---

## 4. My verdict on the concept

**Strong yes.** It is meaningfully *better* than the plugin-of-one I'd first proposed, for one
reason: **the artifacts an ability produces have zero runtime coupling to the ability system.**
A repo that adopted "squash-merge-policy" still works for a collaborator who's never heard of the
marketplace — they just see a normal `CLAUDE.md` rule and a normal git hook. Uninstall a *plugin*
and its behavior vanishes; an **ability compiles down to the repo's own native primitives and
leaves.** That solves the team-distribution problem that plain plugins and `@import` don't.

---

## 5. Design reactions & decisions (the meat)

### 5.1 The transpiler framing
Treat an ability as a **transpiler**: free-form reasoning about *how* to install, producing a
**bounded, native result** in the target repo. This framing should discipline every command.

### 5.2 ⭐ The hard problem: adopted abilities have no clean identity — **solve first**
A plugin has a manifest; you always know what's installed. An ability **dissolves into the repo**
— after adoption, "squash-merge-policy v1.2" is no longer a discrete thing; it's edits scattered
across `CLAUDE.md`, `.githooks/`, maybe a script. So `update`/`diff`/`remove` all face:
**what is installed, at what version, and has the user since hand-edited it?**

You **cannot** answer by re-scanning + pattern-matching (fragile, permanent false positives).
**You need a manifest** — e.g. `.claude/abilities.lock` — recording per adopted ability:
its **ID**, **installed version**, and a **content hash/fingerprint of each artifact it wrote**.
The manifest is the substrate the entire lifecycle rests on:

- **`/abilities.diff`** = compare recorded version vs. marketplace latest, **and** recorded
  fingerprints vs. current file state → also detects **local drift** ("you edited the installed hook").
- **`/abilities.update`** = a **three-way merge**, not a re-install: reconcile
  (marketplace old → new) against (recorded → current local). This is the genuinely hard case;
  **design for it from day one** because users *will* hand-tune what an ability installed, and a
  naive clobbering update destroys trust after the first bad experience.
- **`/abilities.remove`** = safe **only because** the manifest recorded exactly what was added.
  Still non-trivial (what if the user built on top of it?) → **remove via PR** so it's reviewable.

**Decision: manifest + per-artifact fingerprints is not optional. Build it before any command.**

### 5.3 ⭐ Constrain what an ability may be: declarative artifacts
The user described abilities as free-form "instructions to modify a repo." That flexibility makes
`diff`/`update`/`remove` nearly intractable (you can't cleanly diff/reverse an arbitrary NL
procedure). **Constraint to adopt:** an ability may be **imperative about *how* it installs but
must be declarative about *what* it owns** — it must **declare the set of artifacts it manages**
(files created, **named regions** within shared files like `CLAUDE.md`, hooks registered). Free-form
reasoning to *produce a bounded, declared result* — not free-form results. This single rule keeps
the back half of the lifecycle sane. (Implication: shared-file edits need **delimited managed
regions**, e.g. sentinel comments, so `CLAUDE.md` can host multiple abilities' text without
collisions and support clean removal/update.)

### 5.4 PR-per-operation is the feature, not ceremony
Adopt/update/remove each produce a **reviewable PR** the user approves + merges. Benefits: a human
gate on machine-written repo changes, a natural audit trail, and it **composes with the merge
policy** (see §5.5). Keep this.

### 5.5 It dogfoods itself
These PRs go through the target repo's own squash-merge discipline — the abilities system is
*subject to* the very kind of ability it distributes. Good sign; lean into it.

### 5.6 Hook + cognition split (from §2.4) applies to authored abilities
The example "squash-merge policy" ability should itself install a **hook** for the enforceable
half (block non-squash / merge-commit merges) **and** a `CLAUDE.md`/skill snippet for the
judgment half (curated message). Abilities should be encouraged to make this split.

### 5.7 Browser UI — be realistic about scope
A static page **can't run `/adopt` in the session**, so **copy-the-`/adopt`-line is the realistic
primary path**; true "click-to-install" is mostly aspirational for a plain page. Don't over-invest
early. (A richer v2 could make the page a **Claude Artifact** with a mediated install action —
note it, skip it for now.)

### 5.8 Self-updating CI — most exciting, most dangerous → sequence last
"Dependabot for behaviors" is the natural endgame, but it is **only safe once `/abilities.update`'s
three-way-merge-with-drift-detection is genuinely trustworthy.** Ship it too early and you train the
user to rubber-stamp/ignore update PRs — credibility gone. Build it, but **gate it behind proven update.**

---

## 6. Naming (open)
"Ability" is decent but **overloaded** in the agent world. Since these *compile a capability into a
repo's own primitives and become native*, candidates:
- **grafts** — *(my favorite)* captures the "take and become native / dissolves in" property
- **traits**, **infusions**, **imbue**

Naming can wait; **the manifest can't.**

---

## 7. Open questions to resume on
1. **Marketplace scope:** is the abilities repository **yours alone** to start, or **team-shared**
   from day one? (Determines whether the manifest must handle abilities adopted by *other* people on
   the same target repo — concurrent ownership, drift attribution.)
2. **Update conflict handling:** when the user has locally edited an installed artifact, should
   `/abilities.update` **auto-three-way-merge and flag conflicts**, or **always defer to the human via
   the PR**? *(I have a strong lean here — deferring to the human via PR, with the tool surfacing a
   proposed merge + explicit conflict markers rather than silently resolving — but I asked for the
   user's read first; treat as unresolved.)*

---

## 8. Suggested sequencing (build order)
1. **Manifest + fingerprint schema** — the identity substrate (§5.2). *Nothing works without this.*
2. **Ability definition format** — with the "declare your artifacts" constraint (§5.3) and
   delimited managed regions for shared-file edits.
3. **Core commands** as views over the substrate: `adopt` → `diff`/`remove` → `update`
   (update last among these; it's the hardest).
4. **`setup`** (marketplace bootstrap) — can come early since it's simple, but it's not on the
   critical path for proving the model.
5. **Browser UI** — copy-line first; clickable/Artifact later (§5.7).
6. **Self-updating CI** — last, gated on robust `update` (§5.8).

**First real design task in the new session:** nail down §8.1 and §8.2 (manifest schema + ability
format). Get those right and the commands are straightforward views; get them wrong and no command
polish saves the project.

---

## 9. Meta / process notes
- We are in **inception**. Don't over-build; refine the flows before coding.
- Verify Claude Code harness specifics (`@import` semantics, plugin/hook/skill manifest formats,
  slash-command definition) against **current docs** — the `claude-code-guide` agent can confirm.
- The Scarpa merge-policy text in §1.1 is the **canonical example ability** to build the system
  around first — it exercises both the hook (constraint) and cognitive (judgment) paths.
