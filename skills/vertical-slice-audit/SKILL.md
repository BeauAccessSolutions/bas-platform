---
name: vertical-slice-audit
description: Audit an app end to end — establish what actually ships, diff intended features against implemented ones, run a cheap whole-surface pass, then walk chosen features one at a time through every boundary (entry point → interaction → API → database → read-back → export → deletion → failure recovery). Produces a traceable release gate instead of shipping several features and hoping tests catch the gaps. Trigger when the user says "audit this app/feature", "trace this end to end", "vertical slice", "follow the function start to finish", "build an audit plan", "release gate", "what's the audit order", "is this feature actually complete", "read-only audit", or asks to triage reported breakage before shipping. Works on the CIT web (Next.js + Prisma) and native (Expo Router) apps and on any other app in the portfolio. Not for reviewing an isolated diff (use /code-review) or UI-only critique (use bas-design-review).
---

# Vertical-slice audit

A feature is not "done" because its screen renders. It is done when a single value survives every
boundary: **entry point → control → local draft → request → route handler → authz → database →
read-back → review/timeline → export → deletion → failure recovery.** Each boundary is a place the
value can be dropped, duplicated, mistyped, or silently ignored.

Passing every check does not prove zero bugs. It proves each boundary was inspected and named. That
is the claim to make — never "this feature is bug-free."

**Run the phases in order.** Phases 0–4 are cheap and broad; they exist to make sure the expensive
Phase 5 walk happens on the right code, on the right feature, for the right reason. Skipping them is
how an audit produces a confident P0 about a bug that was fixed upstream a week ago.

---

## Phase 0 — Provenance (BLOCKING; do this before reading any code)

**An audit of the wrong source is worse than no audit.** It reads as coverage and it is fiction.

```bash
git fetch --all --quiet
git rev-parse --short HEAD && git branch --show-current
git merge-base --is-ancestor <shipped-commit> HEAD && echo "HEAD contains shipped" || echo "DIVERGENT"
# BOTH directions. The second one is the one that gets forgotten:
git log --oneline HEAD..origin/<default-branch> | head          # what my checkout lacks
git log --oneline <shipped-commit>..origin/<default-branch>     # what PRODUCTION lacks
```

**Deployment lag is its own finding.** "The checkout contains what ships" is only half the question;
the other half is what ships *doesn't* contain. A production commit that is an ancestor of `main` is
green on the first check and can still be missing every merged fix of the last month — so users are
running code nobody has audited in weeks, and a reviewer reads "provenance ✅ clean" as though
production were current. Report the lag with the count and name the merged-but-undeployed commits.
(Missed exactly this way on KindredAccess, 2026-07-26: reported provenance clean while production
lagged `main` by four merged fixes, one of them a safety audit-log.)

Establish and **write into the report header**:

- the deployed/production commit for each surface (web deploy, EAS build number **and** its commit,
  the active OTA commit — a build number alone is not a source identity);
- whether the local checkout is an ancestor of it, behind it, or divergent;
- the default branch (do not assume `master`; it differs per repo here).

If the checkout is not what ships, **stop and say so.** Either audit the shipped commit directly
(`git show <sha>:path`, worktree, or read-only checkout) or get the user's explicit go-ahead to audit
the local branch, and label every verdict with which source it applies to. Checkout drift is itself a
finding — starting new work from a stale branch regresses shipped fixes.

**Declare a mutation budget in the same breath.** State what this audit may execute and what it may
not. A read-only audit does not run migrations, integration suites that create rows, or production
builds that write artifacts. Name what you skipped for that reason in the report — an unstated skip
reads as coverage.

---

## Phase 1 — Intent inventory (what the app is *meant* to do)

From the **product docs**, not the code: `PROJECT_BRIEF.md`, `docs/TARGET_STATE.md`, `CLAUDE.md`,
free-vs-paid contracts, ADRs, non-negotiables. These are the specification. Enumerate the intended
capability set, grouped by feature area.

Docs describe intent and code describes reality; **the gap between them is the product of this
phase**, not a reason to distrust either. An audit built only from code can never find "this was
promised and does not exist."

---

## Phase 2 — Implementation inventory (what exists)

Enumerate mechanically. Every entry needs a `file:line`.

**Next.js app-router + Prisma (CIT web, `~/Chronic-Illness-Tracker`):**
```bash
find src/app -name 'route.ts' | sort                 # every API surface
find src/app -name 'page.tsx' | sort                 # every screen
grep -n '^model ' prisma/schema.prisma               # every persisted entity
ls prisma/migrations | tail -5                       # schema drift vs deployed
find src/lib src/hooks -type f -name '*.ts*' | sort  # shared logic + drafts
```

**Expo Router native (CIT native, `bas-apps/apps/cit`):**
```bash
find src/app -name '*.tsx' | sort                    # file-based routes = screens
find src/lib -type f | sort                          # session, drafts, API client, dates
grep -rn 'fetch(\|citFetch\|apiFetch' src | sort     # every outbound call site
```

**Any stack — three questions:** what can a user *do* (entry points), what gets *written* (models,
storage keys), what crosses the *wire* (routes, handlers, call sites)?

Before writing "no X exists," apply [`null-result-guard`](../null-result-guard/SKILL.md). An empty
grep is a fact about your pattern. (Observed: a `find … | head -25` truncated the route list and
nearly produced a false "no delete endpoint" finding.)

⚠️ **zsh does not word-split unquoted variables.** `for d in $DIRS` iterates once with the whole
string. Use explicit arguments or `${=DIRS}`, and treat any suspiciously round zero as a shell bug
until disproved.

---

## Phase 3 — Diff intent against implementation

Three buckets, all reported:

| Bucket | Meaning | Audit action |
|---|---|---|
| **Implemented** | in docs and in code | auditable — eligible for Phase 5 |
| **Undocumented** | in code, not in docs | audit anyway — undocumented surfaces are where authz gaps live |
| **NOT-BUILT** | in docs, not in code | a gap, **not a bug** — do not walk it, do not score it |

**This bucket assignment is load-bearing for triage.** When a user reports "the app is broken," the
first question is which bucket. Unfinished parity feels identical to a defect from the outside and is
a completely different problem. Say which one each reported symptom is.

Per surface, too: a feature can be Implemented on web and NOT-BUILT on native. Parity is its own
slice — never fold it into a feature slice.

---

## Phase 4 — Cheap whole-surface pass

Minutes of work, disproportionate yield, and it calibrates which slice deserves the deep walk. Run
what already exists rather than authoring anything:

```bash
npm test / pytest          # existing suites — record exact pass counts
npm run lint && npx tsc --noEmit
npm audit --omit=dev       # production dependencies only
```

Plus read (don't just grep): the logging config and its sinks, error/crash reporting init and its PII
settings, the deployment spec, health-check coverage, and any security-invariant script the repo
already has. Findings that live *between* features — dependency advisories, an export contract that
promises more than it delivers, a draft store not cleared at logout, a scrubber with a blind spot —
surface here and never in a single slice walk.

Record the exact numbers. "473/473 passed" is evidence; "tests pass" is not.

---

## Phase 5 — The slice walk

For each chosen feature, build the link chain. **Every link is a `file:line`.** A link you cannot
locate is a P0 finding, not a hole in your search.

```
1  Entry point      which screen/control exposes it, and its visibility condition
2  Navigation       route target; Back/Cancel path; focus restore on close
3  Initial state    what the controls render with before any input
4  Input            keyboard/paste/voice/assistive; controlled-input identity across rerenders
5  Validation       what is accepted, rejected, and what stays genuinely optional
6  Draft            what survives navigation, backgrounding, app kill — and what clears it
7  Request          method, path, body shape, exactly-once semantics
8  Authz            authentication AND record ownership, enforced server-side
9  Persistence      the model/columns actually written; relations; nullable vs unset
10 Idempotency      retry / double-tap / reconnect creates one row, not two
11 Success feedback announced (not just rendered), and the UI reflects saved state
12 Failure path     input preserved, error legible, retry reachable
13 Read-back        review/timeline/history renders the exact stored value
14 Mutation         edit / status change preserves historical integrity
15 Deletion         removes the intended record and only its joins
16 Export           every structured and freeform field present, escaped, timezone-honest
17 Account deletion the record is actually reachable by the cascade
18 Leakage          no PHI/PII in logs, URLs, telemetry, or crash reports
19 Parity           web/iOS/Android agree wherever parity is intended
20 Tests            happy path, boundary values, failure path
```

Verdicts: **PASS / FAIL / N-A / NOT-BUILT / UNVERIFIED**.

**`UNVERIFIED` is required, not a cop-out.** Use it whenever the answer needs a device, a real network
failure, a second account, or a database.

> **Render-dependent links can never be `PASS` in a static pass.** Links 1, 2, 3 and 11 depend on what
> actually renders, and reading JSX cannot establish that. Learned the hard way: a Cancel button was
> present in the source and marked PASS; a navigator option set from inside the screen suppressed the
> whole header, so it never rendered and users were trapped with no exit. **Presence in JSX is not
> evidence of rendering.** Mark them `UNVERIFIED` and list them for the device pass.

**Boundary values at every numeric or optional field:** unset vs zero (0 severity, 0 wake-ups, 0
spoons are *data*), documented min and max, one past each, empty string vs null, and the
"cleared back to unknown" transition — clearing must delete the row, not store an inferred value.

---

## Phase 6 — Escalate the claims that reading cannot settle

Match the verification to the claim class. Reading is the weakest instrument; use it as a filter,
not a verdict.

- **Persistence & idempotency (links 9, 10, 14):** run it against a **real temporary database** and
  produce the row. ORM update semantics are exactly where reading fails — an ORM treating `undefined`
  as "leave unchanged" is invisible in review and obvious in a result set. Only produced rows settle
  these.
- **Render, focus, keyboard, a11y (links 1–4, 11):** device or simulator. Nothing else counts.
- **A reported symptom whose mechanism is unconfirmed:** ship a **discriminating test**, not a
  confidence label. Enumerate the candidate mechanisms, then give the user a short sequence whose
  outcomes separate them — "type in screen A, then B, then the broken one; if A and B work it's
  screen-specific config, if all three fail it's the shared input component or the installed build."
  A test the user can run in thirty seconds beats a paragraph of hedging.
- **Anything the mutation budget forbids:** name it in Not-covered; never quietly infer it.

---

## Phase 7 — Report

Four parts. All four, every time.

**1. Findings**, severity-ranked, each with a concrete failure scenario — inputs and state → wrong
output. No scenario means it is an observation, not a finding; label it as such. Include the fix.

**2. Slice chains**, per audited feature:

```
## Slice: Reaction now / acute capture     P0     VERIFIED-CODE (static)
Surfaces: native iOS (build 22, commit c57c516; OTA 68ab379) · web parity N-A
  1  Entry     src/app/app/index.tsx:22    UNVERIFIED (render)
  4  Input     src/app/acute.tsx:64        FAIL — F-2
  7  Request   src/lib/cit.ts:120          PASS  isAcuteCapture=true
  16 Export    —                           NOT-BUILT (native export unimplemented)
```

**3. Feature matrix** — every feature from Phase 3, one row each, with its result and surface. This is
what makes "what is the state of the app" answerable. Findings show problems; the matrix shows
coverage. NOT-BUILT rows stay in it.

**4. Verification ledger** — exactly what was executed, with counts and identities:
`489/489 web tests at <commit> · 13/13 against real Postgres · tsc+lint clean on 6/6 packages ·
prod health 200 · protected endpoints 401`. Then **Not covered**, itemized, including everything the
mutation budget excluded.

Close with an explicit gate verdict: **SHIP / BLOCKED / SHIP-WITH-KNOWN-GAPS**, listing the gaps.

---

## Phase 8 — Persist

- BAS apps → `~/projects/bas-platform/docs/testing/<app>-<slice>-audit-<YYYY-MM-DD>.md`
- otherwise → `docs/testing/` in the app's own repo

Then offer, don't auto-run: file P0/P1 findings as tracked work, and run `capture-review-lessons` if
the audit surfaced a transferable lesson.

---

## Discipline rules

- **Provenance before analysis.** Phase 0 is blocking.
- **One slice, finished.** Serialized depth is what this method trades breadth for. Do not open a
  second slice while the first has unresolved links.
- **Evidence or `UNVERIFIED`.** Never from plausibility. Never `PASS` on a render-dependent link in a
  static pass.
- **A missing link is a finding — but search every layer before calling it missing.** Cross-cutting
  controls do not live in the handler. Rate limiting, authn/authz, CSRF, caching, tenancy scoping and
  input caps are routinely implemented in **middleware, decorators, base classes, framework settings,
  the ORM manager, or the web server config** — so grepping the view file and finding nothing proves
  only that it isn't in the view file. Before writing "there is no X," check: middleware stack,
  decorators (including ones applied by a base class or a URL wrapper), framework settings, and the
  reverse proxy. This is [`null-result-guard`](../null-result-guard/SKILL.md) applied to
  *architecture* rather than to a search string.
  > Filed a P2 against KindredAccess claiming report/block had no rate limiting, having grepped only
  > `core/views.py`. `RateLimitMiddleware` gave `/report/` a dedicated 5-writes-per-minute per-user
  > bucket, with a comment naming the exact threat model I "found." Retracted. The same pass
  > overstated a companion finding by missing a global `DATA_UPLOAD_MAX_MEMORY_SIZE` cap in settings.
  > Two errors, one root cause: searching a single layer and reporting absence.
- **NOT-BUILT is not a bug.** Never score an unimplemented feature as a defect.
- **Don't fix while auditing.** Record and keep walking; fixing mid-walk loses the chain and yields a
  half-audit plus an unreviewed patch.
- **Never claim zero bugs.** The deliverable is a traceable gate — say so in those words.
- **Health data:** any log line, URL, analytics event or crash payload carrying a symptom, medication
  or food value is P0 regardless of which slice surfaced it. Check the redaction mechanism's *shape*,
  not just its contents — a field-name allowlist is defeated by renaming at the call site, and a
  schema-driven drift test cannot see log call sites at all.

## Reference

`references/cit-feature-inventory.md` — the 26-feature CIT intent inventory with per-feature checks
and a recommended audit order. Use it as the Phase 1 output for CIT slices (re-verify against code
before trusting it), and as the worked example of inventory shape for other apps.
