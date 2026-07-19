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

## Session: 2026-07-18

**Project:** bas-platform (BN OIDC client-secret rotation → DO SECRET conversion)

### Failures

- **Leaked a freshly-rotated secret into the transcript (highest severity, self-inflicted).**
  Piped the new client secret from `secrets.env` into an inline *heredoc* Python script; the
  heredoc body wasn't valid in that context, so the shell echoed the secret back inside a
  `SyntaxError: invalid decimal literal` message. The rotation meant to *end* an exposure
  created a new one → had to rotate a **second** time and re-verify. Lesson: never pipe a
  credential into an inline heredoc. Write the script to a file first, pass the secret on
  **stdin**, and assert on its *shape* (length/charset) — a parse error prints its input.
- **Told the user two vars were "still plaintext" after checking only the `type:` field.**
  `DATABASE_URL`/`REDIS_URL` read `type: general`, so I reported them unconverted — they had
  actually become **bindable references** (`${db.DATABASE_URL}`), which is *stronger* than
  SECRET and also reads as `general`. Had to correct myself unprompted. Lesson: for DO env vars
  read the **value**, not just the type; a `${...}` ref and a plaintext credential look
  identical by type alone.
- **Propagated the false-positive Keycloak probe into a user-facing claim.** Used
  `grep "<title>Sign in to bas</title>"` as proof Keycloak accepted the client/redirect — the
  *error* page carries the identical title (logged by a peer session the same day). The
  conclusion was right, but only because a **token-endpoint** test (`invalid_grant` vs
  `unauthorized_client`) independently proved it. Re-verified by HTTP status at wrap-up.
  Lesson: when a cheap signal and a definitive one are both available, report the definitive one.
- **Browser automation dead end:** `read_page` returned an empty tree and a coordinate click on
  the allauth "Continue" button silently did nothing (2 attempts) → abandoned the browser and
  drove the form with `curl` + a cookie jar, which was better evidence anyway (it proved the
  `sessionid` cookie persisted — the exact Redis write that had been failing).
- **Classifier blocks (3×):** an `ssh` command that grepped for credential *variable names*, and
  `doctl apps update --spec` twice. Same recurring friction the peer session logged — a
  permission rule is overdue.
- **zsh `echo ===` → `(eval):2: == not found`:** a bare `===` token is parsed, not echoed.

---
## Session: 2026-07-18

**Project:** bas-platform (TestFlight round: 3 rebuilds + BN/DW first builds)

### Failures
- **[investigation] Concluded "BN has no prod domain" from guessed DNS names → wrong; wrapper 1.0(1) shipped against the `ondigitalocean.app` URL where the Keycloak callback isn't registered (login dead-ends).** Probed `benefits.beauaccesssolutions.com`-style guesses and `doctl apps list` DefaultIngress, never read the app spec's `domains:` block — `vabenefitsnavigator.org` was PRIMARY all along. Caught same-day via a tracker row from the rotation session; superseded by 1.0(2) on the prod URL. Fix pattern: `doctl apps spec get | grep -A4 domains:` is the domain inventory, not DNS guessing.
- **[cap add ios] CocoaPods crashed (Unicode/ASCII-8BIT)** → `LANG=en_US.UTF-8`. Then **xcodebuild "requires Xcode"** (xcode-select → bare CLT) → per-process `DEVELOPER_DIR`. Both now in LESSONS + mobile doc.
- **[xcodebuild archive] Signed archive failed twice** — first "No Accounts" (no Xcode Apple ID session), then "team has no devices" (automatic signing wants a dev profile at archive). → unsigned archive + `-exportArchive -allowProvisioningUpdates` (distribution profiles need no devices).
- **[upload] Access Atlas "Redundant Binary Upload"** — ASC already held a 1.0(2) no doc knew about; local regenerated project said 1.0(1). → bump past ASC's number; ASC is the only source of truth.
- **[gh] `pr create` "must be a collaborator"** — active account was LangworthyWatch. → `gh auth switch -u Beaudoin0zach`, work, switch back (now in bas-infra-access memory).
- **[eas-cli] No `submission:list`/`submission:view` in any version; first Expo GraphQL guess (`submission` root field) invalid** → `submissions.byId` query with the `~/.expo/state.json` session token works for submission status.
- **[monitoring] Piped `xcodebuild … | tail` into the task output** swallowed failure diagnostics twice → redirect full output to a log file, grep the log.

---
## Session: 2026-07-18 (CIT numeric-PHI scrub-list fix, PR #41)

**Project:** chronic-illness-tracker (worktree `jovial-snyder-c3f316`)

### Failures
- **[Read] `src/lib/logger.ts` did not exist** — the handoff prompt cited `src/lib/logger.ts:36-76`; the real path is `src/lib/logger/index.ts`. Cheap to recover (the tool suggested the directory), but a reminder that a cited path in a handoff note is a claim, not a fact — the line numbers were right, the file wasn't.
- **[tsc] 40+ phantom type errors in a fresh worktree** (`Property 'status' does not exist on type '{}'`, waves of implicit-`any`) — read as "my change broke the build" for a moment. Cause: the worktree had no generated Prisma client (`node_modules/.prisma` absent; CIT generates to `src/generated/prisma`). → `npx prisma generate`, then 0 errors. **Diagnosis that saved it:** typechecking the *unmodified* sibling checkout showed 0 errors, isolating it to worktree state, not the diff. New worktrees of a codegen-dependent repo need their generate step before any typecheck result is meaningful.
- **[gh] Account flipped to `LangworthyWatch` twice in one session** — once before `pr create` (caught by `gh auth status`), and again silently before `platform-status.sh`, which then reported CIT `open PRs: 0` while #41 was open. The second one is worse than a failed command: it produced a **confident wrong answer** in the status board. → `gh auth switch --user Beaudoin0zach`; hazard now documented in TRACKER.md §1b. The script should distinguish "0 PRs" from "cannot see repo" and fail loudly.
- **[wrap-up] Phase 1 "auto-commit and push to main" was not safe to follow literally** — `~/.claude` held 76 uncommitted changes, 75 of them a prior session's in-flight skill reorg into `skills-archive/`; CIT's own work belongs on a review-gated PR branch, not `main`. → Committed nothing outside my own edits and surfaced the rest. A blanket auto-commit step needs a "only what this session touched" guard.

---

---

## Session: 2026-07-18 (cont. — merge + skill hardening)

**Project:** bas-platform (memory/skills audit, part 2)

### Failures

- **Wrote a worktree-cleanup procedure that was itself unsafe, then caught it by running it.** New
  `wrap-up` step 8 removed any worktree that was clean with zero unmerged commits. On the very next
  run all four qualified — but two had been recreated by live peer sessions at 09:11–09:12, minutes
  after I removed their predecessors at 09:00. A worktree in active use is indistinguishable from an
  abandoned one by those two checks alone. → Added a liveness check (directory mtime; and if a
  worktree reappears under a different random name on the same branch, stop removing entirely).
  Lesson: a cleanup rule needs a "someone is using this right now" test, not just "is it finished".
- **Near-miss: almost merged a lesson entry that taught a disproven heuristic.** The incoming
  `LESSONS.md` section from `claude/elegant-banach-721970` instructed verifying a Keycloak client by
  looking for the themed "Sign in to bas" page — the exact false positive disproved earlier the same
  day (the error page carries an identical `<title>`). A clean `git merge` would have committed it
  verbatim into the file that loads into every session. → Read incoming content on merge, don't just
  resolve textual conflicts; a conflict-free hunk can still be factually wrong.
- **Assumed the push was mine to make; a peer had already done it.** `c7d2b39` was pushed by another
  session between my commit and my push check. Harmless here, but the branch state you reasoned
  about seconds ago may already be stale in a multi-session repo.

---

## Session: 2026-07-18 (cont. — skill-eval harness debugging)

**Project:** bas-platform (description optimizer for `do-app-platform-debug`)

### Failures

- **Read a degenerate metric as a real result and iterated on it for 5 rounds.** The description
  optimizer reported `trigger_rate 0.00` on all 20 queries with the score frozen at exactly 50%; I
  treated it as "the description triggers poorly" and let it generate candidates. The candidates were
  never under test at all: the harness installs a hash-named *clone* of the skill, but the
  already-installed real skill shadowed it, so the model triggered the incumbent and detection —
  keyed on the clone's name — scored every correct trigger as a miss. → Quarantine the installed
  skill for the run. An all-zero or exactly-50% score is an instrument failure; reproduce one case
  end-to-end against the raw trace before believing any aggregate.
- **Then believed the *plausible* wrong number.** With shadowing fixed, results read
  `precision=100% recall=6%` — which looks like a genuine finding about an over-narrow description.
  It was a 30s/query timeout: generous solo (6.4s to first tool call) but a coin flip under 10
  parallel subprocesses. Caught only by noticing iteration wall-time implied ~28s/run. → Cross-check
  scores against wall-clock; the impossible number is easy to spot, the plausible one is not.
- **Told the user a branch was unmerged when it had already been merged.** Asserted that
  `claude/elegant-banach-721970` was stranded and its BN OIDC doc existed only there — both false at
  the time; a peer had merged it ~15 min earlier. I reasoned from a session-start snapshot instead of
  checking. → `git log origin/main..<branch>` before any claim about merge state.
  **Note the real gap:** `LESSONS.md` *already* carried an entry for this exact mistake ("the working
  tree is not the repo", citing this same 93-line doc), loaded in-session, and it did not fire. A
  lesson that isn't consulted at the moment of asserting is not a control.
- **Runner script failed on first launch** — `mv` into a `.quarantine` dir the script never created.
  Failed safe (skill untouched); added `mkdir -p`. → Scripts that relocate live assets should create
  their destination, and must fail before touching the source.
- **Background job killed mid-run when this session's worktree was recycled** by a peer. The restore
  trap fired correctly and the skill came back intact. → Long background jobs that mutate shared
  state need a trap, and verifying the restore is not optional.
- Minor: `timeout` is not present on macOS (GNU coreutils only).

---
## Session: 2026-07-18 (PM — TestFlight distribution + DW router + icons)

**Project:** bas-platform / disability-wiki / benefits-navigator

### Failures
- **[TestFlight] "Ready to Test" builds never reached the phone** — walked the user through 3 rounds of ASC screens (Users & Access ≠ tester enrollment ≠ build attachment) before getting an API key and *reading the actual state*: the two new app records had **no beta groups at all**, and AA build 3 was withheld on an unanswered compliance flag. → With `scripts/asc-api.py`: created groups, enrolled tester, PATCHed `usesNonExemptEncryption` on every build. Lesson shape: screen-walking is guessing; get API access and read state.
- **[scratchpad] Session reset wiped the scratchpad mid-flight** — killed a chained archive→upload task after the archive step (DW 1.0(2) sat unuploaded while logs claimed nothing), and destroyed the icon SVG masters. → Verified upload state via ASC API (not local logs), re-ran export; icons regenerated from context into `design/app-icons/` (git, not scratchpad, for session work products).
- **[xcodebuild] DW export failed "server with the specified hostname could not be found"** — transient DNS on Apple's upload endpoint → plain retry succeeded.
- **[icons] Two design mis-reads shipped to review** — KA split-seam heart read as a *broken* heart; stroked hands read as handset hooks. → Caught by rasterizing and *looking* before sending; fix was concept change, not tweaks.
- **[preview pane] Static-snapshot pages can't be screenshotted** (navigate → "No site is open") → `qlmanage -t` raster + Read the PNG instead.

---
## Session: 2026-07-18 (PM — www→apex canonical-host redirects)

**Project:** bas-platform / benefits-navigator / kindredaccess

### Failures
- **[shell] `timeout` again** — used `timeout 180 ./platform-status.sh` on a call that *already had* the Bash tool's native `timeout` param set. macOS has no GNU `timeout`; exit 127. → Dropped the shell word, kept the tool param. 4th occurrence; the shared lesson was sharpened from "prefer the tool's own flag" to "the word `timeout` in a command string is always wrong here."
- **[DO web console] Console button opens an unreachable popup, and sessions drop mid-task** — the dashboard's "Web Console" button spawns a window the browser extension can't see; the console then disconnected once mid-edit. → Navigate the same tab straight to `/droplets/<id>/terminal/ui/?os_user=root`; keep each command atomic so a drop never lands between a write and its validation.
- **[nginx] Live droplet config ≠ the repo's `deploy/` mirror** — nearly patched from the committed conf, which documents an idealized layout; the droplet runs certbot's rewrite with different socket paths and `if ($host = …)` blocks. Patching from the mirror would have clobbered working TLS config. → Mapped the live file with `grep -n` first, patched that, re-synced the mirror separately.
- **[git] Hub push timed out at 2m** after the commit succeeded — looked like a failed commit. → Re-ran `git push` alone; it went through. Commit and push are separate outcomes when they're chained with `&&`.
- Minor: `doctl apps spec validate` rejects a spec pulled from a live app (encrypted `EV[...]` secrets are "not allowed before app is created"); `doctl apps propose --app <id>` is the validator that works on an existing app — and its `--output json` is what proves an ingress field parsed rather than being silently dropped.

---
## Session: 2026-07-18 (evening — lessons prune + concurrency gates)

**Project:** bas-platform / ~/.claude

### Failures
- **[git] Published a peer session's commits twice in one evening** — `git push` in the shared bas-platform checkout carried `b3c70f1`, then an hour later `bbfcc67`, both a peer's icon work. The second happened *after* I'd written the "push only your own commits" rule into LESSONS.md, which is the finding: peers commit into the same local working copy, not just the same remote, and a once-per-session ownership check goes stale immediately. → Built a `pre-push` gate gating on ambiguity (>1 outgoing commit) rather than identity, since every session commits as the same git user.
- **[git] Swept a peer's two LESSONS.md entries into my own commit** — `git add shared/LESSONS.md` staged their appended entries alongside my edit. The pre-push gate could not see this; by then it was one commit. → Built a `pre-commit` gate on hunk count for shared docs. Left their content intact and disclosed it in the commit message rather than stripping it.
- **[hooks] First pre-commit gate previewed a blank line instead of the peer's entry text** — it printed each hunk's first added line, and the peer's append began with a newline, hiding the one thing that makes a foreign edit recognizable. Caught only because the test used the real failure shape. → Skip to the first line with actual content.
- **[hooks] Near-miss: setting `core.hooksPath` globally would have silently disabled every repo's own hooks** — including public-ledger's publication validator, CIT's sensitive-file check, and 4 repos' conventional-commit hooks. Caught by scanning `.git/hooks` across all repos *before* setting it. → Dispatcher chains to each repo's own hook; gates scoped to a designated-repo list.
- **[prune] Index jumped 40→42 entries mid-pass** — read as a bug in my own pruning before checking `git diff`; it was the peer's two new entries landing in the file.
- Minor: `doctl apps spec validate` can't validate a spec pulled from a live app (encrypted `EV[...]` secrets); `doctl apps propose --app <id> --output json` is the one that works and also proves a field parsed rather than being dropped.

---
## Session: 2026-07-18 (evening — BN icon iteration, link-trap audit, content seeding)

**Project:** bas-platform / benefits-navigator / disability-wiki

### Failures
- **[icons] Three failed passes at the helmet ear cutout before abandoning it.** Full-width scallop ate the bottom half of the shell; softened version read as a decorative wave; asymmetric 3/4 version arched through the middle again. → The modern-helmet read comes from dome proportion + rim tightness + strap hardware, NOT the ear notch. Recorded in the commit so it isn't retried a fourth time. Lesson: at icon scale, anatomical fidelity and legibility actively trade off — rasterize and LOOK after every attempt rather than reasoning about the path data.
- **[git] Branched off a stale `origin/main` ref** — created `fix/seed-documentation-content` from a fetch that predated my own merged PR #35, so the branch lacked the glossary fix I'd just landed. Caught by a system reminder showing the file without my edit. → `git fetch` immediately before branching, and verify with `git show origin/main:<path>`. This is the "working tree is not the repo" trap from LESSONS, hit again.
- **[content extraction] Two bad selectors nearly reported a false success.** Verifying the seeded glossary, my first grep pulled nav links ("Skip to main content") and the second pulled 89× "View full details" — both would have let me claim success off a broken selector. → Only the third (h2/h3 headings) showed real terms. Assert on the *content you expect to see*, not on a count that happens to match.
- **[spec edit] String-replace against YAML failed silently-ish** — `doctl apps spec get` folds long plain scalars across lines, so an exact-match replace of the `run_command` found 0 matches. → Parse with PyYAML, mutate the field, dump, then diff the loaded object trees to prove exactly one field changed. Safer than text surgery on generated YAML.
- **[permissions] `doctl apps update` blocked by the classifier** (twice, for both spec changes) → prepared the spec, saved outside the scratchpad (which was wiped earlier today), handed the exact command to the user.
- **[network] Apple upload endpoint unreachable mid-round** (`appstoreconnect.apple.com` returning 000) → archive survived on disk; polled until reachable and re-ran only the export step rather than rebuilding.

---

---
## Session: 2026-07-18 (night — marketing site: app links, voice, a11y gate)

**Project:** bas-platform / beau-access-solutions (bas-website)

### Failures
- **[review] My first contrast pass reported "3 blocking" and was incomplete.** I tested every token against white, cream, and the warm neutrals — but not against the *tinted* section backgrounds (`bg-sage-light/30`, `bg-terracotta-light/20`). A real 3.93:1 failure on the blog CTA was live the whole time and I called the sweep done. → Alpha-composite every translucent background before comparing, and enumerate pairs from actual markup rather than from the palette. Now enforced by `test/contrast.mjs`; recorded in LESSONS C4.
- **[review] Reported a 29-failure contrast matrix that was mostly noise.** Cross-producting every foreground against every background generated combinations that never occur (e.g. a dark-section text colour tested on white). Would have sent me fixing phantom problems. → Filtered to pairs that actually appear in markup: 29 → 3 real. Inflating a finding count is its own failure; a review that cries wolf gets ignored.
- **[deploy verify] Polled the live site for 3 minutes and wrongly reported the deploy as not landed.** `curl` without `-L` against `/apps` returned the 301 redirect stub, so my `grep` for new content found nothing ten times running. The deploy had almost certainly succeeded on attempt 1. → Always `-L` when asserting on page *content*; and when a probe returns 3xx, treat that as "my probe is wrong" before "the deploy is broken."
- **[test] Wrote a fail-closed test that crashed instead of diagnosing.** The undefined-token check ran *after* the contrast pair table was constructed, so a missing token threw `unknown colour:` from `c()` with a stack trace — technically fail-closed (exit 1), but it reported a symptom rather than the cause. Found only because I injected the regression instead of assuming the test worked. → Reordered so the token scan runs and exits first. Lesson: verify a new gate against the failure it exists to catch, not just against green.
- **[env] Two shell failures from my own commands** — `grep --include` with an unquoted glob under zsh (`no matches found`), and `grep -c ... | paste -sd+ | bc` for counting matches (paste rejected the args, printing usage into what I was reading as counts). → Quote globs; use `grep -o | wc -l` rather than a pipeline that can fail mid-way and still print something that looks like output.
- **Minor:** first background `grep` for antithesis constructions was killed rather than returning; re-ran in the foreground. `npx serve` looked dead at 4s but had actually started — a hand-rolled static server then hit `EADDRINUSE`, which was the evidence it was up.

### Went right
- The concurrency pre-commit gate on the hub fired correctly on a 3-region `TRACKER.md` stage and made me verify each region was mine before `STAGE_OK=3`. Working as designed.

---

---
## Session: 2026-07-18 (evening — §4 C3 gate, gate audit, CIT native announcements)

**Project:** bas-platform / page-repair / bas-apps

### Failures
- **[audit] Reported CIT as "not checked out locally" after searching one directory tree.** I globbed `~/projects/` for a Prisma schema, found nothing, and recorded that as *the repo does not exist here* — then committed it to the public hub in `docs/design-principles.md` §4.1. It is checked out at `~/Chronic-Illness-Tracker`, and the hub's own `repos/` registry symlinks it. A peer session caught it (`572f0c0`); the same wrong claim survived in design-principles.md until this wrap-up. → **A null result is a claim about your search, not about the world.** For BAS specifically: enumerate `bas-platform/repos/` — the canonical app registry — before concluding any app is absent. (A machine-wide `null-result-guard` skill now exists for this class.)
- **[review] Accepted the task brief's premise instead of checking it.** The brief said C3 had "no test anywhere"; KindredAccess had shipped `test_visible_status_nodes_are_at_silent` in the same commit that fixed the original bug, running in CI. I built on that premise and committed "KindredAccess remains unenforced" — false — to a public repo. Caught only when a later question made me test *"would this gate have caught the bug it was written for?"* → Verify the gap before building the thing that fills it. The brief even warned that citations here have been wrong; I verified the paths I cited but not the load-bearing absence claim.
- **[review] Nearly propagated a peer's correction without checking it.** `572f0c0` said CIT's `a11y-css.test.ts` "doesn't cover both themes." It does — it splits `:root` and the dark block and asserts 3:1 and 4.5:1 in each. Verifying before writing turned a wrong "partial" into the portfolio's strongest C4 gate. → Peer corrections need the same verification as one's own claims, in both directions: their fix under-credited what was there.
- **[git] Rebase resolution would have produced misleading history.** Folding all three of my commits' LESSONS.md changes into commit 1 left it titled "C3 now has a gate — page-repair only" while containing text saying KindredAccess *was* gated. Aborted and rebuilt as one honest commit on `origin/main`. → When a rebase forces you to fold corrections into the commit they correct, squash and rewrite the message rather than preserving a count.
- **[docs] Blew a budget a peer had just deliberately set.** My first LESSONS.md resolution came to 100 lines against the ~85 ceiling `b8365b6` established minutes earlier; redone tersely to 95, still over, and flagged rather than hidden. → When rebasing onto a compression pass, adopt its budget as a constraint on the resolution, not an afterthought.
- **[test] The new static gate failed on its own documentation.** `check-status-announcements.mjs` flagged the comments in `live-region.tsx` that *describe* the anti-pattern. → Skip comment lines and exempt the announcer's own source; a gate that flags its own docs trains people to ignore it.
- **[env] Two rounds of monorepo module resolution before typecheck ran.** Symlinking the worktree's `node_modules` at the root wasn't enough — `apps/cit/node_modules` shadows it and resolved `@bas/ui` to the *main* checkout, so `tsc` reported the new export missing while the file plainly had it. → In a pnpm workspace, rewire the `@scope` dir at **every** level that has one, not just the root.
- **[env] `node --test <dir>` is not the same as `node --test <glob>`.** Passing the directory made Node treat it as a single test file and fail with MODULE_NOT_FOUND, which reads exactly like a broken import. The tests were fine.
- **[env] Worktree under `/tmp` was cleaned out mid-session.** `/private/tmp/claude-501/cit-fix` vanished between two turns; the commit survived only because worktrees share the main repo's object store. → Put worktrees under the repo's `.claude/worktrees/`, not `/tmp`.
- **[gh] The active account kept reverting to `LangworthyWatch`.** PR creation failed twice — "Could not resolve to a Repository" on the private `bas-apps`, then "must be a collaborator" on `bas-platform` (`push=false`). `gh auth switch` worked but did not hold between calls, most likely because a concurrent session was switching it too. → Check `gh api user --jq .login` immediately before a PR, not `gh auth status`; and note that this global state is contested when sessions run in parallel.
- **[ci] Nearly shipped a workflow pinned to Node 22** for a `.ts` test that needs native type stripping. Caught before push; set to 24.
- **Minor:** an unquoted `--include=*.js` glob aborted under zsh (recurring — same as the previous session's entry); `timeout` is not present on macOS.

### Went right
- Both new gates were verified against the bug they exist to catch, not just against green: a `role="status"` toast injected into shipped `apply.js`, the original markup restored in `log-note.tsx`, and `IOS_SETTLE_MS=0`. All three failed as intended, which is the only reason the gates can be trusted.
- Checked RN semantics against the official docs before changing 14 call sites, rather than relying on recall — the docs confirmed the bug was worse than assumed (silent on *both* platforms, not just iOS).
- Adopted the peer's LESSONS.md structure on rebase instead of forcing my own through, after reading the commit message that explained their intent.
- Left six worktrees untouched: all clean with zero unmerged commits, but two sat at 09:11–09:12 — exactly the recreation window the wrap-up skill documents — with a peer session committing 14 minutes prior.

---
## Session: 2026-07-19 (CIT lockfile drift — 5-day silent production freeze)

**Project:** chronic-illness-tracker

### Failures
- **[analysis] Asserted "a PHI app has been shipping to production with no CI verification for four days" — backwards.** It had not been shipping at all; production was frozen on the 2026-07-14 container. I inferred continuous deployment from `deploy_on_push` + a 200 health check without running `doctl apps list-deployments`. That check took one command and I ran it only after merging. **A trigger config plus a healthy endpoint is not evidence that deploys are landing — read the deployment list.**
- **[merge] Merged #41 into a repo whose CI could not run, and the merge did not ship.** Merging was authorized and the diff locally verified, but it produced a false sense of completion: the fix sat on `main`, unreachable by production, for the same reason CI was red. **When install-step CI is broken, "merged" and "shipped" decouple — check the deploy path before treating a merge as done.**
- **[docker] First `npm install --package-lock-only` exited 127** (`prisma generate && ./scripts/install-hooks.sh`) because the scratch dir held only `package.json` + lockfile, not `prisma/` or `scripts/`. Artifact of my own setup, but it briefly read as a real dependency failure. → `--ignore-scripts` when regenerating a lockfile in isolation.
- **[tooling] Several `Bash` calls failed with "claude-opus-4-8 is temporarily unavailable"** mid-deploy-watch and again at commit time. Transient; retried successfully. Noted only because it interrupted a poll loop watching a production deploy.

---

---
## Session: 2026-07-19 (marketing site: contact form + real dark mode)

**Project:** bas-platform / beau-access-solutions (bas-website)

### Failures
- **[sed] A 181-usage class migration reported success and changed nothing.** `sed -i '' 's/\btext-gray-900\b/text-ink/g'` across 10 files — **BSD sed does not support `\b`**, so every pattern matched zero times while sed still rewrote each file byte-identically. The mtime bump even made the harness announce "modified 10 files," which read as confirmation. Caught only because the verifying grep returned counts *identical* to the pre-run counts. → `perl -pi -e` for anything with a word boundary; and treat "command succeeded" as unverified until a re-count or diff proves the content changed. Logged to shared LESSONS under the existing macOS/GNU-tooling entry.
- **[test] The contrast gate broke the moment dark tokens landed, and blamed the wrong thing.** Its token parser took the *last* `--color-X` match in the file; once the dark block existed that was the dark value, so it compared dark text against light backgrounds and reported 7 confident failures that were all artifacts. → Rewrote to parse `@theme` and the `prefers-color-scheme` block separately and evaluate pairs by token *name* per theme. A parser that assumes one value per token cannot survive a second theme.
- **[perl] Multi-line insertion via `perl -pi -e` with `\n` in the replacement produced three bare `,` lines** in the pairs table, which then failed to parse. → Structural edits to a source file belong in Edit, not a regex one-liner; regex is for the repetitive single-line substitutions.
- **[browser] Three tool failures in a row on the visual check** — `computer{scroll}` timed out twice at 30s, `scrollIntoView` silently reset scrollY to 2, and one screenshot returned a fully blank dark frame mid-transition. → Fell back to reading `getComputedStyle` for every surface, which is the stronger evidence anyway: it states the actual colour rather than my reading of a picture.
- **[near-miss] Almost "fixed" a bug that did not exist.** A light-mode screenshot taken mid-theme-switch showed the wordmark washed out to near-cream on white. Checked `getComputedStyle` before touching it — `rgb(17,24,39)`, correct; the frame was a stale composite. Editing on the strength of that screenshot would have broken working code. Same discipline that was *missing* from the earlier `curl` deploy check, applied in time here.
- **[env] Repeated classifier unavailability** stalled commit/push for several minutes across two windows; work was already staged and verified, so nothing was lost — but the first Monitor-based wait was reported as "stopped" with no completion record, and the commit had silently not landed. → Re-check `git log` before assuming a queued commit went through.

### Went right
- The both-theme gate paid for itself on first run: 4 real failures, one of them a **pre-existing light-mode** defect (logo at 3.98:1) that had survived a full design review and two contrast passes.
- Staging discipline held under a live peer session: 4 files (`env.d.ts` + 3 blog posts) that were mode-flip noise rather than my edits were caught by a `--numstat` zero-zero check and unstaged before commit.

---
## Session: 2026-07-19

**Project:** disability-wiki (app announcement banner, ES crisis parity, abuse-page merge review)

### Failures

- **Reported work as "not pushed" when it was already live in production.** Told the user twice the
  banner work was safe on a branch. It had reached `main` because a *different* branch
  (`fix/app-mpa-router`) had been cut from it and merged, carrying both commits along. In a repo
  where merge-to-main publishes with no review gate, "it's on a branch" is not the same as "it is
  unpublished." Lesson: before claiming anything is unpublished, run `git branch -a --contains
  <sha>` — the branch you are standing on does not tell you where its commits have travelled.
- **Astro silently drops whitespace between an expression and an adjacent element.** Source read
  `{t.text} <a href=…>`, with a literal space; the rendered HTML had none, and
  "on the way.How to install" shipped to production. Survived review precisely because the *source*
  is correct — only the built output shows it. Fixed with an explicit `{' '}`. Lesson: for
  templating languages, verify the rendered artifact, not the template.
- **Three false-negative verification checks in one session** — each time the page was correct and
  my check was wrong: (a) grepped `restraining`/`know your rights`, concluded a life-safety page had
  lost its legal-rights content, when it had survived reworded as "protection order"/"accessible
  shelter"; (b) polled a hashed CSS URL captured *once*, so a deploy renamed the asset and the poll
  reported "not live" for 9 minutes on a change that had already shipped; (c) ran an ordering
  assertion over whole-page HTML, where Starlight's on-this-page nav repeats every heading, so
  heading positions came from the nav and the phone number from the body. Root cause for all three:
  grepping raw HTML with boolean pattern-matches instead of scoping to rendered content and
  comparing sets. Fixed mechanically — `scripts/verify_page.py` (PR #54), each subcommand tested
  against the case it got wrong *and* given a negative control. Worth noting the direction: all were
  false negatives (cried wolf); the dangerous direction on a crisis site is a check that passes on a
  broken page.
- **`wrangler pages dev` failed to start twice.** First with a hardcoded
  `--compatibility-date=2026-07-18` the installed workerd binary could not support (max 2026-06-18);
  then, after removing the flag, with today's date for the same reason — `pages dev` does *not* read
  `compatibility_date` from the root `wrangler.jsonc`. Cost two restarts before pinning
  `2026-06-01`. The first failure also silently killed an earlier `preview_start` whose error I did
  not read at the time.
- **Built and reverted a `MarkdownContent` override.** Added an offline note to all 56 crisis pages,
  verified it rendering correctly, *then* measured its position — median 1,111 words into the page,
  never above 400. Nobody would see it. Reverted. Lesson: measure whether a change can achieve its
  purpose *before* building it, not after it passes verification; "renders correctly" and "works"
  are different claims.
- **Wrote skill guidance that was wrong within the hour.** First draft of
  `.claude/skills/verify/SKILL.md` said to retire URLs via `astro.config.mjs` `redirects`. That
  covers the trailing-slash form but emits a meta-refresh page (200, not 301). Corrected to
  `_redirects` with both URL forms. Lesson: a rule inferred from one observed example is a
  hypothesis; test the alternative before writing it down as guidance.
- **`gh pr create` failed twice with `must be a collaborator`** while `git push` over SSH kept
  working — the active `gh` account had flipped to `LangworthyWatch` (`pull:true, push:false`).
  Easy to misread as a GitHub outage since pushes succeed. Resolved on retry with no intervention.
  Recorded in `TRACKER.md` as a second symptom of the known account-flip hazard.
- **Env, not my error:** the browser screenshot tool returned a blank white frame every time the
  page was scrolled away from the top (`scrollIntoView`, `End`, anchor navigation all reproduced
  it). Top-of-page captures worked fine. Worked around it by asserting on rendered text instead,
  which is better evidence for a prose change anyway — but it means no visual record of the restored
  sections.
- **Near-miss, caught by a hook:** a concurrent session's commit landed on my checked-out branch and
  my `git add`/commit of `TRACKER.md` in the hub was blocked by a pre-commit guard warning the file
  had 3 independent staged regions. Verified all three were mine via `git diff --cached` before
  overriding with `STAGE_OK=3`. The paired `git push` in that chain was a no-op (0 ahead), so no
  peer work was published — but chaining `commit && push` is how that would have happened.

---

## Session: 2026-07-19 (cont. — gate scope + peer-commit push decision)

**Project:** bas-platform / ~/.claude

### Failures
- **[infra] Bash tool unavailable for several minutes** (safety classifier down), blocking a one-command commit across four attempts. Not a code failure, but worth recording: read-only tools kept working, so the right move was to use Read to review the pending diff and stage the exact command, then run it immediately on recovery — rather than idling or retrying blind.
- **[review] The diff I was about to commit had grown while I was blocked** — `skills/wrap-up/SKILL.md` went 9 → 15 insertions, picking up a second peer hunk dated the next day. Committing the version I'd reviewed the night before would have shipped an unreviewed change. → Re-read the diff after any interruption; "I already reviewed this" expires.
- **[gate coverage] `SKILL.md` was not in the pre-commit `SHARED_FILES` list**, so the gate built specifically for peer-edit collisions did not cover the file where the collision was actually visible (two peer hunks accumulated over two days). → Added it, accepting that it fires more often since skill edits are commonly multi-region.
- **[git] Could not isolate my own commit for pushing** — mine sat on top of two peer commits, so no targeted `<sha>:main` push existed. Unlike the previous night, the history was genuinely interleaved. → Handed the decision to the owner with the list rather than guessing; pushed all five on explicit instruction.

---

## Session: 2026-07-19 (cont. — a11y-probe README)

**Project:** a11y-probe (+ bas-platform hub docs)

### Failures
- **[handoff] Three technical claims in the inherited task brief were wrong against source.** The brief described the app as "six static test sections" in an "iframe" and did not mention the splash screen. Source disagreed on all three: tests 2–5 are interactive (`game.tsx` counter, assertive region, `focus()`, debounced input echo), the iframe framing only holds on desktop web (the Reddit mobile apps use a native WebView), and `splash.tsx:24-26` carries a **Test 0** that gates everything after it. → Caught only because the brief itself said to verify against source. A confidently-specific handoff reads like a finished finding; the specificity is not evidence.
- **[search] `grep '^## .*a11y' TRACKER.md` returned nothing and I nearly read it as "a11y-probe is untracked."** The tracker records apps as **table rows**, not headings — the app was on lines 20, 79, 92, 260. → The null-result hook fired and forced the corrected search. Structure assumptions are search assumptions.

### Clean
- No tool errors, no retries, no abandoned approaches. `npm run type-check` passed first run; branch pushed clean.

---

---
## Session: 2026-07-19 (marketing site: caching, web-perf, style-eval pass)

**Project:** bas-platform / beau-access-solutions (bas-website)

### Failures
- **[measurement] Reported an em-dash density of 8.9/1k when the real figure was 10.7 — then "fixed" the parser and was still wrong.** The extractor stripped `.astro` frontmatter wholesale, and `/apps` keeps most of its copy in a JS array there, so the densest page on the site was measured as page chrome (177 words for a seven-card page — the implausible number is what prompted the recheck). The corrected parser still under-counted ~1/page versus the built HTML. → Measure the artifact the build emits, not the source. `test/prose.mjs` reads `dist/`. Logged to shared LESSONS as an extension of the "green suite proves the module imports" entry.
- **[copy] Two self-inflicted defects during the em-dash pass, both from regex-substituting prose.** One left a verbless sentence on a live page ("Page Repair asks a language model It then gates…"); the other, worse, **reversed a claim** — "aren't *just* inconvenient" became "aren't inconvenient", i.e. inaccessible sites are *not* inconvenient. Caught by reading the rendered sentences, not the diff. → Bulk regex is for mechanical substitutions; anything that changes a clause boundary needs Edit and a read-back of the output. No gate catches a negation flip.
- **[skill prerequisite] `web-perf` could not run** — its required `chrome-devtools` MCP server isn't configured, so `performance_start_trace` and the LCP/CLS insight API were unavailable. → Followed the skill's own stop instruction, ran the measurable subset via the browser's timing APIs, and reported FCP/LCP/INP/TBT as **unmeasured** rather than estimating them.
- **[premise] The user asked to import a skill from a repo that does not contain it.** `style-eval` has been installed machine-wide since June; public-ledger only *used* it. Verified with four searches before saying so (no `.claude/skills/`, no `SKILL.md`, no grep hits, `skills/*` refs are feature branches) rather than reporting absence from one negative result. The useful thing was adjacent: `BOOK_STYLE_SHEET.md`, a binding standard that lived in one repo and nothing outside it read.
- **[concurrency] A peer session switched this checkout's branch out from under me mid-session.** At wrap-up the repo was on `copy/wcag-cdc-corrections-and-about` with a commit **3 seconds** old and four in 11 minutes, none mine. Caught by the branch check a peer had just added to the wrap-up skill. My work was already committed and pushed to `main`, verified by `merge-base --is-ancestor` per commit. → Nothing staged, nothing pushed, branch left as found.
- **[env] Classifier unavailability stalled edits and commits repeatedly**, across several windows. One Monitor-based wait reported "stopped" with no completion record and the commit had silently not landed. → Re-check `git log` before assuming a queued commit went through.

### Went right
- The em-dash budget from the newly-imported book style sheet found a real, quantified defect on its first run, on a site three prior review passes had called clean.
- Staged a lesson into `~/.claude/shared/LESSONS.md` as a **single isolated hunk** while a peer had two unrelated entries in flight in the same file — extracted my hunk by content and `git apply --cached`, leaving theirs untouched.

---
