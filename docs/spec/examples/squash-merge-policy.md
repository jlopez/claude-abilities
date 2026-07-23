---
id: squash-merge-policy
source: jlopez/claude-abilities-repository
baseline: 1.3.0
mode: faithful
adopted: 2026-05-14
config:
  enforce_hook: true
artifacts:
  - path: CLAUDE.md
    section: "## Merging to main"
    hash: sha256:9f3c2a71e8b04d5c6a1f0e9d8c7b6a5493827160f5e4d3c2b1a09876e5d4c3b2
    description: judgment half — PR-only merges to main, curated squash messages
  - path: .githooks/pre-push
    hash: sha256:41d7b6c5a4938271e0f9d8c7b6a5493827160fe5d4c3b2a19087f6e5d4c3b2a1
    description: constraint half — rejects pushes that put merge commits on main
---

## 2026-05-14 — Adopted at 1.1.0

Adopted in **faithful** mode (the ability's recommendation; tidewater is a
young repo and the team wants the policy enforced, not suggested).
`enforce_hook: true` for the same reason.

Decisions:

- The `CLAUDE.md` section was adapted to tidewater's existing voice and
  references `gh pr merge --squash` explicitly, since the team merges from
  the CLI. Substance (PR-only, squash-only, novel curated message, linear
  `main`) is unchanged from the ability's canonical text.
- The hook was installed at `.githooks/pre-push` and wired via
  `git config core.hooksPath .githooks` (done by the ability's `setup.sh`;
  each collaborator's clone needs that one-time config — the `CLAUDE.md`
  section tells them to run it). The config setting itself is not an
  artifact; only the hook script is.
- **Skipped the optional CI linear-history check** — tidewater has no CI
  yet. Revisit if CI is added; the ability's assets include the workflow
  snippet.

## 2026-07-02 — Reconciled 1.1.0 → 1.3.0

Upstream moved twice since our baseline; both versions reviewed with the
user:

- **1.2.0** hardened the pre-push hook to detect merge commits anywhere in
  the pushed range, not just at the tip. **Taken** — `.githooks/pre-push`
  replaced with the new canonical script; no local adaptations existed to
  preserve.
- **1.3.0** rewrote the CI linear-history check after a fork found it
  passing on shallow checkouts. **Not applicable** — we still skip the CI
  artifact (still no CI in tidewater), so nothing to reconcile; noting it
  here so the next agent doesn't re-derive this.

Hashes refreshed for both artifacts. The `CLAUDE.md` section was untouched
by this reconcile — upstream's text didn't change and neither did ours.
