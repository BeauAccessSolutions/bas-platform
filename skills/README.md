# Platform Claude Code skills & commands

Canonical, version-controlled source for the Beau Access Solutions platform's
custom Claude Code **skills** (`skills/`) and **slash commands** (`../commands/`).

These were authored locally under `~/.claude/`, which is **not** a git repo — so
they existed on one machine only and were lost if it died. This directory is the
backup and the source of truth. Edit here, commit, then re-install.

## What's here

| Item | Kind | Purpose |
|---|---|---|
| `bas-design-review/` | skill | Review a UI change against the platform design + a11y standard (`docs/design-principles.md`). |
| `capture-review-lessons/` | skill | Sweep a completed review/audit and record transferable lessons into the three-tier lessons system. |
| `prune-lessons/` | skill | Prune/consolidate the shared `LESSONS.md` files when they grow past budget. |
| `vertical-slice-audit/` | skill | End-to-end app audit: provenance → intent-vs-implemented diff → cheap whole-surface pass → per-feature boundary walk. Ships a CIT intent inventory in `references/`. |
| `wrap-up.skill` | skill (packaged `.skill` zip) | End-of-session wrap-up workflow. |
| `../commands/platform-status.md` | command | `/platform-status` — reconcile `TRACKER.md` against real repo/PR/deploy state (drives `scripts/platform-status.sh`). |
| `../commands/lesson.md` | command | `/lesson` — capture one cross-project lesson into the shared lessons file. |

Not included (deliberately): plugin-sourced skills (Cloudflare, wrangler,
workers-best-practices, etc.) are re-installable from their plugins, and
machine-personal skills (`style-eval`, `fec-duckdb-port`) that aren't platform
tooling.

## Install / update on a machine

Copy (don't symlink — committed cross-repo symlinks dangle on clone, per the
repo's own convention):

```sh
# from the repo root
cp -R skills/bas-design-review skills/capture-review-lessons skills/prune-lessons skills/vertical-slice-audit ~/.claude/skills/
cp skills/wrap-up.skill ~/.claude/skills/
cp commands/platform-status.md commands/lesson.md ~/.claude/commands/
```

After editing a skill under `~/.claude/`, copy it back here and commit so the
source of truth stays current.
