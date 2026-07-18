---
name: wrap-up
description: Use when user says "wrap up", "close session", "end session",
  "wrap things up", "close out this task", or invokes /wrap-up — runs
  end-of-session checklist for shipping, memory, failure logging, and
  self-improvement
---

# Session Wrap-Up

Run the phases in order. Each phase is conversational and inline — no
separate documents. All phases auto-apply without asking; present a
consolidated report at the end. Phase 1.5 only runs inside Beau Access
Solutions platform repos and is skipped silently everywhere else.

## Phase 1: Ship It

**Commit:**
1. Run `git status` in each repo directory that was touched during the session
2. If uncommitted changes exist, auto-commit to main with a descriptive message
3. Push to remote

**File placement check:**
4. If any files were created or saved during this session:
   - Verify they follow your naming convention
   - Auto-fix naming violations (rename the file)
   - Verify they're in the correct subfolder per your project structure
   - Auto-move misplaced files to their correct location
5. If any document-type files (.md, .docx, .pdf, .xlsx, .pptx) were created
   at the workspace root or in code directories, move them to the docs folder
   if they belong there

**Deploy:**
6. Check if the project has a deploy skill or script
7. If one exists, run it
8. If not, skip deployment entirely — do not ask about manual deployment

**Task cleanup:**
9. Check the task list for in-progress or stale items
10. Mark completed tasks as done, flag orphaned ones

## Phase 1.5: Sync Platform Docs (Beau Access Solutions apps only)

This phase only applies when the current repo belongs to the Beau Access
Solutions (BAS) platform. The shared docs live in a **hub repo** at
`~/projects/bas-platform`, and each platform app is a **separate git repo**
symlinked into `~/projects/bas-platform/repos/`. Detect membership before
doing anything else:

1. Get the current repo root: `git rev-parse --show-toplevel`
2. Get the hub's app roots (each is a symlink): for each entry under
   `~/projects/bas-platform/repos/`, resolve it with `realpath`
3. This session is in-scope if the current repo root **either** equals
   `~/projects/bas-platform` (working in the hub directly) **or** matches one
   of the resolved app roots from step 2
4. If it matches neither, this is not a BAS platform app — **skip this entire
   phase silently** and continue to Phase 2. (This keeps the skill inert in
   all other projects that also use this global skill.)

When in-scope, first **ground yourself in the real state** rather than
trusting the tracker: run `~/projects/bas-platform/scripts/platform-status.sh`
(add `--no-net` for a fast offline pass). It reports each app's real branch,
push state, ahead/behind, open PRs, and deploy health. Use its output — not
`TRACKER.md`'s current claims — as the source of truth when deciding what to
write.

Then update the shared docs **in the hub repo** (`~/projects/bas-platform`),
not in the app repo. Review each and edit only what this session actually
changed or what the status script shows to be stale — do not rewrite docs that
are still accurate:

- **`TRACKER.md`** — the living status board. Reflect anything that moved:
  app/onboarding status, deploy state, open or merged PRs, blockers. When you
  edit it, bump the `**Last updated:**` date line at the top to today.
- **`PLATFORM.md`** — roadmap / phase status, if a phase advanced.
- **`INVARIANTS.md`** — only if a platform invariant was added or changed.
- **`docs/**`** — the specific file the session bears on: an architecture
  decision → a new or amended ADR under `docs/adr/`; a deploy change → the
  matching `docs/deploy/*.md`; a pricing/business change → `docs/business/`.
  Skip files the session had no bearing on.

If nothing platform-level changed, note "No platform-doc updates needed" and
continue.

**Commit the hub separately:** stage and commit the doc changes in
`~/projects/bas-platform` with a descriptive message, then push. This is a
distinct commit in a distinct repository from the Ship It commit in Phase 1 —
do both. Report what was synced in the consolidated wrap-up summary.

## Phase 2: Remember It

Review what was learned during the session. Decide where each piece of
knowledge belongs in the memory hierarchy:

**Memory placement guide:**
- **Auto memory** (Claude writes for itself) — Debugging insights, patterns
  discovered during the session, project quirks. Tell Claude to save these:
  "remember that..." or "save to memory that..."
- **CLAUDE.md** (instructions for Claude) — Permanent project rules,
  conventions, commands, architecture decisions that should guide all future
  sessions
- **`.claude/rules/`** (modular project rules) — Topic-specific instructions
  that apply to certain file types or areas. Use `paths:` frontmatter to scope
  rules to relevant files (e.g., testing rules scoped to `tests/**`)
- **`CLAUDE.local.md`** (private per-project notes) — Personal WIP context,
  local URLs, sandbox credentials, current focus areas that shouldn't be
  committed
- **`@import` references** — When a CLAUDE.md would benefit from referencing
  another file rather than duplicating its content

**Decision framework:**
- Is it a permanent project convention? → CLAUDE.md or `.claude/rules/`
- Is it scoped to specific file types? → `.claude/rules/` with `paths:`
  frontmatter
- Is it a pattern or insight Claude discovered? → Auto memory
- Is it personal/ephemeral context? → `CLAUDE.local.md`
- Is it duplicating content from another file? → Use `@import` instead

Note anything important in the appropriate location.

## Phase 3: Review & Apply

### Failure Log

Before reviewing general self-improvement findings, scan the full conversation
for any failures — tool errors, wrong outputs, commands that needed retrying,
paths taken that turned out to be dead ends, corrections the user had to make.

The purpose of logging these is to build a searchable history so that patterns
across sessions become visible over time. A one-off mistake isn't worth logging;
a failure that required multiple attempts or a significant course correction is.

**What counts as a failure worth logging:**
- A shell command or tool call that returned an error (even if later fixed)
- An output that was wrong and had to be redone
- A wrong assumption that wasted time
- An approach that was abandoned mid-way after starting

**What doesn't need logging:**
- Minor typos caught immediately
- Expected errors that are part of normal workflow (e.g., `git status` showing
  nothing to commit)
- Things the user asked to undo for unrelated reasons

**Format each failure as:**
```
- [tool/command/task]: what went wrong → how it was resolved
```

**Append to the project's failure log:**
- Default path: `session-failures.md` at the project root
- If the project already has a different log file (e.g., `logs/failures.md`),
  use that instead
- If the file doesn't exist yet, create it

Use this append format:

```markdown
## Session: YYYY-MM-DD

**Project:** [project name or directory]

### Failures
- [item 1]
- [item 2]

---
```

If there were no failures worth logging, append a brief "No failures" entry
so there's a record that the session ran clean. This makes it easy to spot
sessions where something went wrong vs. sessions where everything worked.

### Self-Improvement Findings

Analyze the conversation for self-improvement findings. If the session was
short or routine with nothing notable, say "Nothing to improve" and proceed
to Phase 4.

**Auto-apply all actionable findings immediately** — do not ask for approval
on each one. Apply the changes, commit them, then present a summary of what
was done.

**Finding categories:**
- **Skill gap** — Things Claude struggled with, got wrong, or needed multiple
  attempts
- **Friction** — Repeated manual steps, things user had to ask for explicitly
  that should have been automatic
- **Knowledge** — Facts about projects, preferences, or setup that Claude
  didn't know but should have
- **Automation** — Repetitive patterns that could become skills, hooks, or
  scripts

**Action types:**
- **CLAUDE.md** — Edit the relevant project or global CLAUDE.md
- **Rules** — Create or update a `.claude/rules/` file
- **Auto memory** — Save an insight for future sessions
- **Skill / Hook** — Document a new skill or hook spec for implementation
- **CLAUDE.local.md** — Create or update per-project local memory

Present a summary after applying, in two sections — applied items first,
then no-action items:

Findings (applied):

1. ✅ Skill gap: Cost estimates were wrong multiple times
   → [CLAUDE.md] Added token counting reference table

2. ✅ Knowledge: Worker crashes on 429/400 instead of retrying
   → [Rules] Added error-handling rules for worker

3. ✅ Automation: Checking service health after deploy is manual
   → [Skill] Created post-deploy health check skill spec

Failure log:

4. 📋 Logged 2 failures to session-failures.md

---
No action needed:

5. Knowledge: Discovered X works this way
   Already documented in CLAUDE.md

## Phase 4: Publish It

After all other phases are complete, review the full conversation for material
that could be published. Look for:

- Interesting technical solutions or debugging stories
- Community-relevant announcements or updates
- Educational content (how-tos, tips, lessons learned)
- Project milestones or feature launches

**If publishable material exists:**

Draft the article(s) for the appropriate platform and save to a drafts folder.
Present suggestions with the draft:

All wrap-up steps complete. I also found potential content to publish:

1. "Title of Post" — 1-2 sentence description of the content angle.
   Platform: Reddit
   Draft saved to: Drafts/Title-Of-Post/Reddit.md

Wait for the user to respond. If they approve, post or prepare per platform.
If they decline, the drafts remain for later.

**If no publishable material exists:**

Say "Nothing worth publishing from this session" and you're done.

**Scheduling considerations:**
- If the session produced multiple publishable items, do not post them all
  at once
- Space posts at least a few hours apart per platform
- If multiple posts are needed, post the most time-sensitive one now and
  present a schedule for the rest
