# Multi-role test matrix

The executable form of the "Logic Traps, State Failures & Access-Control Errors in
Multi-Role Applications" research template. That report ended in a prose checklist;
prose does not catch bugs. This does.

**Source of truth:** [`multi-role-test-matrix.yaml`](multi-role-test-matrix.yaml) —
77 tests across 11 suites, 38 of them ship-blocking. Edit the YAML, never a generated
artifact.

**Runner:** [`scripts/testmatrix.py`](../../scripts/testmatrix.py)

```bash
./scripts/testmatrix.py validate
```

```bash
./scripts/testmatrix.py list --gate blocker --kind negative
```

```bash
./scripts/testmatrix.py md --suite AUTHZ --suite MOB -o /tmp/release-gates.md
```

```bash
./scripts/testmatrix.py issues --repo BeauAccessSolutions/benefits_navigator --gate blocker
```

`issues` is a dry run that prints `gh issue create` commands until you pass `--execute`.
`csv` emits a spreadsheet with empty `result` / `run_by` / `run_on` / `evidence` columns
for a manual pass. `gate` exits non-zero while any parameter behind a blocking test is
unsigned — wire it into a release check.

---

## How the gates work

Every test states a **pass condition** and a **fail condition** separately. That is the
point of the format: a test whose only criterion is "it works" gets marked green by
whoever runs it. A test that says *"fail: the second save wins silently, destroying A's
edit"* has to be actually observed to be dismissed.

| Gate | Meaning |
|---|---|
| `blocker` | Data-loss, data-leak, or regulatory defect. Does not ship. Waiver requires a written, dated risk acceptance. |
| `required` | Must pass before a release is called done. May ship behind a flag with a tracked issue and a named owner. |
| `recommended` | Quality bar. Track, don't block. |

**Negative tests are their own gate.** 54 of the 77 are `kind: negative` (33 of them
ship-blocking) — they assert
that something *fails to happen*. These are the ones a normal QA pass never runs, because
nothing in the product invites you to forge an object ID, kill the network mid-write, or
revoke a caseload while a device is offline. Filter for them explicitly:

```bash
./scripts/testmatrix.py list --gate blocker --kind negative
```

Four of them are worth calling out as the ones most likely to be quietly broken right
now, in any app, without anyone noticing:

- **`MOB-01`** — revocation reaching a device that is offline. Has no web equivalent, so
  no web habit protects you.
- **`TEN-07`** — complementary suppression. Assume it fails: implementing primary
  suppression alone is the near-universal outcome, and it leaves every suppressed value
  recoverable by subtraction from the totals shown next to it.
- **`NAV-01`** — unsaved-changes guards in a client-routed app. `beforeunload` does not
  fire on in-app navigation, so this fails *by default* in React/Vue/Angular until proven
  otherwise.
- **`MOB-07`** — "Saved" shown for a write the server never received.

## Test format

```yaml
- id: AUTHZ-01
  title: BOLA — forged object ID in path, body, or GraphQL variable
  gate: blocker            # blocker | required | recommended
  kind: negative           # negative tests assert an absence
  surfaces: [api]          # web | mobile | api | process
  params: [P1_session_timeouts]   # parameters this test's constants come from
  setup: ...
  steps: [...]
  pass: ...                # the observable success condition
  fail: ...                # the observable failure condition, stated separately
  automation: integration  # e2e | integration | unit | manual | combinations
  refs: [...]
```

Constants are never written into a test. `{P1.idle_default}` in a step resolves at render
time from the parameter block, so changing a timeout in one place changes what every test
asserts. `validate` fails on a placeholder that has no matching parameter field.

---

## Verified: the NIST numbers

The report flagged that SP 800-63B-4 (July 2025) raised the AAL2 ceilings and that most
tooling still cites 800-63B-3's tighter figures. Confirmed against the primary source at
`pages.nist.gov/800-63-4/sp800-63b/` on 2026-07-23:

| | Overall (reauthentication) timeout | Inactivity timeout |
|---|---|---|
| **AAL1** | SHOULD be no more than **30 days** | MAY be applied, not required |
| **AAL2** | SHALL be established; SHOULD be no more than **24 hours** | SHOULD be no more than **1 hour** |
| **AAL3** | **SHALL** be no more than **12 hours** | SHOULD be no more than **15 minutes** |

Verbatim, AAL2: *"A definite reauthentication overall timeout SHALL be established, which
SHOULD be no more than 24 hours at AAL2. The inactivity timeout SHOULD be no more than 1
hour."* AAL3: *"At AAL3, the overall timeout for reauthentication SHALL be no more than 12
hours. The inactivity timeout SHOULD be no more than 15 minutes."*

Two details the synthesis flattened, both of which matter in an audit conversation:

1. **The AAL3 overall timeout is a SHALL, not a SHOULD.** The AAL2 overall timeout is a
   SHALL *to establish one* with a SHOULD on its length. Different obligations.
2. **General session rules live separately from the per-AAL numbers.** The session chapter
   carries the framework — *"Session activity SHALL reset the inactivity timeout, and
   successful reauthentication during a session SHALL reset both timeouts"*, *"When either
   timeout expires, the session SHALL be terminated"*, and in federation, *"the RP SHALL be
   authoritative as to whether the reauthentication requirements have been met."* That last
   one binds each BAS app rather than Keycloak, which is the same division
   [INVARIANTS.md](../../INVARIANTS.md) §1 already draws.

The report's claim holds: 800-63B-4 is more permissive than the ≤30-min/≤12-hr figures
still in circulation. The section numbering the NIST HTML renders is inconsistent between
its own pages, so cite the quoted text and the URL rather than a section number.

---

## The five parameters

All five live in the YAML with their rationale attached — ASVS v5 expects the
justification, not just the value, and the rationale is the part that survives an auditor
asking "why 15 minutes?". Summary:

| | Proposed | Core of the rationale | Status |
|---|---|---|---|
| **P1** session timeouts | 15m idle / 12h absolute; 5m on shared devices; warn at 13m, extend ×10 | Deliberately below the AAL2 ceiling, matching AAL3's shape. Tightening costs nothing **once `SESS-01` passes** — drafts surviving expiry is what makes a short timeout humane. | proposed |
| **P2** small-cell threshold | 11, with complementary suppression required | OCR sets no number; CMS's `<11` is the defensible published anchor, so you never have to defend a home-grown one. | proposed |
| **P3** delegation defaults | Limited view + named actions, 90d, no re-delegation, from grant date forward | Default-deny applied to relationships. Blocking re-delegation avoids chain-revocation rather than solving it. | proposed |
| **P4** offline retention | 7d max cache age; 24h max without a successful auth refresh; wipe on 5 triggers; no cache on shared devices | The 24h bound is the one that actually closes the revocation gap, and it aligns cache death with AAL2 session death so the two don't drift. | proposed |
| **P5** age of majority | 18, configurable per jurisdiction; confidential-category floor 12; auto-revoke on the birthday with 30d notice | Mechanism is safe to build now; **the ages are not settled** — see below. | pending counsel |

The dependency worth stating plainly: **P1's tightness is bought entirely by `SESS-01`.**
If drafts do not survive expiry, 15 minutes is a data-loss policy wearing a security
policy's clothes, and the honest move is a longer timeout, not a shorter one.

`./scripts/testmatrix.py gate` currently exits 1 on all five. That is correct — it is the
gate doing its job, and it will keep failing until each is marked `status: adopted` in the
YAML with the decision recorded.

---

## Open to counsel

P5 is the only parameter that cannot be closed by engineering judgment, and it is the one
with real liability. The questions, narrowed to what a lawyer can actually answer:

1. Under **New York minor-consent law**, at what age may a minor consent to each of SUD
   treatment, mental-health care, reproductive care, and HIV/STI care — and for each, does
   consenting minor status bar parental access to the resulting record, or merely not
   require parental consent to the care?
2. Where a parent holds a portal proxy and the minor has a confidential-category record,
   which **ONC information-blocking exception** applies to withholding it? The report's
   reading is that the *preventing harm* exception does **not** cover adolescent
   confidentiality alone, and that the *privacy* exception (via state minor-consent law) or
   *infeasibility* exception is the operative path. Confirm, and confirm what documentation
   the chosen exception requires us to keep.
3. Given the **2024 Part 2 rule** says segmentation is not required but redisclosure still
   requires consent: if a portal cannot unambiguously segment Part 2 data, is withholding
   mandatory, and does withholding then need an information-blocking exception of its own?
4. On the majority birthday, is **auto-revoking** the parent proxy the required behavior,
   the safe behavior, or over-compliance — and does the now-adult's re-grant need to be a
   fresh written consent or is a portal-recorded affirmation sufficient?
5. What retention obligation attaches to the **consent artifacts themselves** (who
   consented, when, to what scope), independent of the 6-year security-documentation floor?

`DELEG-07` tests the mechanism today with P5's placeholder constants. The mechanism —
boundary-date revocation, advance notice, re-consent rather than silent carry-over — holds
regardless of which ages come back, so it is safe to build against now. Only the numbers
move.

There is a precedent for the format: KindredAccess's counsel brief consolidates D1–D8 the
same way, and `docs/legal/bn-data-posture-counsel-brief.md` is the sibling. These five
belong in whichever brief goes out next rather than in a separate ask.

---

## Which suites apply to which app

A starting assignment, to be confirmed per repo — not every app carries every trap, and
running an irrelevant suite is how a matrix loses credibility.

| Suite | BN | KindredAccess | CIT | Access Atlas | Disability Wiki |
|---|---|---|---|---|---|
| `SESS` session lifecycle | ✅ | ✅ | ✅ | ✅ | — |
| `AUTHZ` access control | ✅ caseload + dual-hat | ✅ moderation roles | partial (single-user) | ✅ moderation | — |
| `TEN` segregation | ✅ | ✅ | ✅ export scoping | ✅ | — |
| `REV` reversibility | ✅ | ✅ | ✅ | ✅ | — |
| `CONC` concurrency | ✅ | ✅ | partial | ✅ | — |
| `MOB` offline/mobile | — | ✅ iOS wrapper | ✅ native clients | ✅ Capacitor | — |
| `NAV` navigation | ✅ | ✅ | ✅ | ✅ (zero-JS: much is N/A) | ✅ |
| `DELEG` delegation | ✅ authorized rep | ✅ guardian/minor | — | — | — |
| `ERR` error handling | ✅ | ✅ | ✅ | ✅ | — |
| `A11Y` a11y of state | ✅ | ✅ | ✅ | ✅ | ✅ |
| `AUDIT` auditability | ✅ | ✅ | ✅ | ✅ | — |

`DELEG` and the dual-hat half of `AUTHZ` are the two suites with the most product surface
and the least existing coverage anywhere in the portfolio — `AUTHZ-05` (case-manager mode
excluding non-caseload records from *search, autocomplete, exports, counts, and
notifications*) is the single highest-value test in the matrix for Benefits Navigator.

---

## Relationship to existing platform docs

- [INVARIANTS.md](../../INVARIANTS.md) §1 (layered sessions, step-up re-auth) is what
  `SESS-04`, `SESS-06`, `SESS-07`, and `SESS-08` verify by behaviour.
- [INVARIANTS.md](../../INVARIANTS.md) §3 (decoupled deletion, durable idempotent fan-out)
  is what `REV-01`, `REV-03`, and `DELEG-04` verify.
- [design-principles.md](../design-principles.md) navigation and target-size standards are
  what `NAV-01`…`NAV-06` and `A11Y-05` verify.

The matrix is deliberately behavioural: it asserts observable outcomes, not
implementations, so it stays valid across the portfolio's Django, Next.js, and Astro apps
without a per-stack fork.
