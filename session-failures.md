# Session Failure Log

Append-only record of things that went wrong, so patterns become visible across sessions.

---

## Session: 2026-07-18

**Project:** bas-platform (DO App Platform secrets/DB hardening on benefits-navigator-staging)

### Failures

- **Wrong-platform assumption (Keycloak):** proposed "apply the bindable-DB pattern to the Keycloak
  app" and only discovered on inspection that Keycloak is Docker Compose on a droplet, not an App
  Platform app — bindable refs don't exist there → had to walk the recommendation back to the user.
  Lesson: confirm *where* a service runs before recommending a platform-specific pattern. **The
  answer was already written down** — `TRACKER.md` §5's hosting table names Keycloak "DigitalOcean
  (Droplet)". Read §5 before proposing any host-specific change; `doctl apps list` is the live
  cross-check, not the primary source.
- **`doctl apps update --format ActiveDeployment.Phase`:** `Error: unknown column` → the app *was*
  updated before the format error; re-queried deployment state with `doctl apps list-deployments`.
  Lesson: an output-format error can mask that the mutation already succeeded — check state, don't
  assume the whole command failed and retry it.
- **`doctl apps spec validate` on a live spec:** rejected with "secret env value must not be
  encrypted before app is created" because the spec contained `EV[...]` blobs → validated a scrubbed
  copy instead and applied the real spec via `update`. Now documented in the
  `do-app-platform-debug` skill.
- **zsh parameter substitution with escaped slashes:** `${URI/\/defaultdb/\/benefits_navigator}`
  produced a mangled URI (`invalid integer value "25060\"` for port) → dropped the backslashes
  (`${URI/defaultdb/benefits_navigator}`). Cost one debugging round-trip inspecting the URI.
- **BSD vs GNU tool assumptions (twice):** `cat -A` → "illegal option" (used `cat -vet`);
  `timeout 120 ...` → "command not found" on macOS. Lesson: this is a Mac — no `timeout`, and
  `cat`/`sed` are BSD variants.
- **Classifier blocks on infra commands (3×):** `doctl databases firewalls append`,
  and `git push origin main` were denied by the auto-mode permission classifier. The firewall one
  the user ran manually; the push is left pending. Recurring friction — worth a permission rule.
- **Connection-attribution probe returned nothing:** attempted to catch in-flight app DB
  connections by user via `pg_stat_activity` while curling the app; the pooled connections closed
  too fast to sample → verified the new DB user a better way (migrate job log + the fact that the
  binding is the app's only `DATABASE_URL` source).

---

---

## Session: 2026-07-18

**Project:** bas-platform (memory + skills audit)

### Failures

- **Reported transient eval artifacts as cruft to delete:** an `ls` of `~/.claude/commands/` showed
  11 hash-suffixed `do-app-platform-debug-skill-*.md` files; called them accidental re-saves and
  proposed deleting them → they were `skill-creator` description-optimization artifacts from a run
  minutes earlier and had already self-cleaned. Lesson: before proposing deletion of files you did
  not create, find what *writes* them (`~/.claude/skill-workspaces/` was the answer).
- **Declared a doc "nonexistent" after checking only the working tree:** `docs/deploy/benefits-navigator-oidc-integration.md`
  was absent from `main`, so I edited memory to say it doesn't exist → it exists as 93 lines in
  `b50c0d3` on the unmerged branch `claude/elegant-banach-721970`. Had to revert the memory edit.
  Lesson: "not in the working tree" ≠ "not in the repo" — check `git log --all` / branches before
  recording an absence as fact.
- **Miscounted worktrees in a delete proposal (highest-severity):** claimed 4 sat at `main`'s SHA
  with only 1 differing → actually 3 were no-ops and **2 held 6 unmerged commits** (BN OIDC scope
  doc, IdP-migration lessons, `bootstrap.sh`, `platform-status.sh`). A blanket "remove the stale
  worktrees" would have destroyed them. Lesson: never propose bulk worktree/branch removal from a
  `git worktree list` SHA glance — run `git log main..<branch>` per entry first.
- **False-positive Keycloak client probe:** discriminated client existence by grepping the page for
  the themed `Sign in to bas` title → Keycloak's *error* page carries the identical `<title>`, so a
  nonexistent client read as present. Fixed by using HTTP status (302 = exists, 400 + "Client not
  found" = absent). The bad heuristic was in memory and has been corrected there.
- **Asserted "marketplace-installed, reinstalling is one command"** about 4 Cloudflare skills →
  they were not plugin-managed and not in the marketplace cache, so deletion would have been
  one-way. Switched from delete to archive under `~/.claude/skills-archive/`.
- **zsh `nomatch` silently faked empty results (twice):** `grep -r --include=*.jsonl` and
  `md5 do-app*.md` aborted with "no matches found", which I nearly read as "0 usages" and
  "files already gone". Lesson: on zsh an unmatched glob kills the command *before* it runs —
  a zero count from a failed glob is not evidence.
- **`timeout 90 ...` → "command not found":** macOS has no GNU `timeout`. This exact lesson was
  already the last entry in this file from the prior session, and I hit it anyway.

---
## Session: 2026-07-18

**Project:** bas-platform (+ page-repair, disability-wiki, benefits-navigator)

### Failures

**Cross-cutting pattern worth naming:** four separate times a bug in *my own test
harness* presented as a product bug. Each cost a debugging detour into correct
product code. When a brand-new harness reports a failure, suspect the harness first.

- **`timeout 60 node --test` → exit 127 (THIRD occurrence).** macOS has no GNU
  `timeout`. Logged in the two prior sessions and hit again → prose in this file is
  not working as a control. Escalated to memory this session; see
  the "shell assumptions fail silently" entry in `~/.claude/shared/LESSONS.md`.
- **Promise-adoption deadlock (harness):** `startStream()` was `async` and returned
  the in-flight submit promise, so `await startStream(t)` *adopted* it — every BN
  test waited for the stream to finish before it could push the frame that finishes
  it. All 5 hung at 15s with no error. → Return the promise wrapped (`{ p }`).
- **Abort-ignoring SSE stub (harness):** the stub reader kept reading after
  `stop()`, so the client fell through to "stream closed without done" and reported
  a spurious error. Read as a product bug at first. → Honour `opts.signal` and throw
  `AbortError`, like real fetch.
- **Bare `fetch` hit the real network (harness):** the UMD module resolves `fetch`
  from Node's global, not the jsdom window, so early runs made real requests and
  surfaced as `stream_interrupted`. → Set `globalThis.fetch` to the stub.
- **`pretendToBeVisual: true` hung the run (harness):** starts a rAF loop that keeps
  the Node event loop alive; `node --test` never exited. → Drop it; nothing needed rAF.
- **Cross-realm array comparison:** `vm.runInContext('PRECACHE')` returns an array
  carrying the vm realm's prototype, so `assert.deepStrictEqual([], [])` FAILED
  across the boundary. → Copy into a host array (`[...]`) before asserting.
- **Reported CI green while jobs were still running (twice).** My poll filtered on
  `state=="PENDING"` but `gh` reports `IN_PROGRESS`, so the until-loop exited
  immediately. Told the user "all four green" before BN had finished — and it then
  failed. → Filter `IN_PROGRESS|PENDING|QUEUED`; never report a run from a loop that
  might not have waited.
- **Pushed a lint failure to CI:** `black --check` rejected my new test file. I had
  run the tests locally but not the repo lint. Compounding: BN's Lint step runs
  *before* my new jsdom step, so the gate I had just added never executed in CI. →
  Run the exact lint CI runs (`ruff check .` && `black --check .`) before pushing.
- **`set -- $spec` in zsh does not word-split** an unquoted variable, so a
  four-repo status loop ran with `$2` empty and errored four times. → Use a function
  with explicit args.
- **Two overreaching assertions, both caught by their own failure:** counted *all*
  inline `<script>` on the BN page (base.html legitimately has its own), and used
  `assistant-caret` as a "JS is inline" marker when it is a CSS class in the inline
  `<style>`. → Assert about the thing you actually changed, not the whole document.
- **Introduced a real bug mid-refactor:** extracting BN's inline script broke
  `{% static %}` because `{% load static %}` is not inherited from `base.html` — a
  `TemplateSyntaxError` on a page whose JS suite was fully green. Caught by the
  render tests I then added; those tests exist because of this.
- **Blocked action:** `gh pr merge --admin` denied by the permission classifier.
  Stopped and handed the command to the user rather than routing around it. Recorded
  in [[bas-infra-access]] so the round trip isn't repeated.

---
