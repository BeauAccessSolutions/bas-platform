# Access Atlas — copy remediation plan

> **Status 2026-07-19: P0–P4 executed** on branch `copy/voice-remediation-2026-07`
> (commit `e4cd623`), not yet merged. P5 (em-dashes) deliberately skipped. Two
> things changed during execution — see "Execution notes" at the bottom before
> reading P0 as written. **One item still needs Zach:** the opening scene of the
> About page, left as a marked TODO in `src/pages/about/index.astro`.

Source: `docs/style-eval-2026-07-19.md` (Voice 3.3/5, Quality 4.3/5, 2,156 words).
Repo: `~/projects/access-directory`. All file:line targets below **verified present**
on 2026-07-19 before this plan was written.

**Framing.** Quality is not the problem — zero style-guide slips, zero filler
intensifiers, structure is genuinely good. Every item here is a voice or
correctness item. Nothing in this plan asks for better craft; it asks the copy to
say who wrote it and where it stands.

---

## Verification notes (read before starting)

Two things the eval got slightly wrong, both in the project's favor:

1. **Place-grounding is not quite absent from user-facing prose.**
   `src/components/ListingEmptyState.astro:78` reads: "Access Atlas is starting in
   Buffalo / Erie County, and every listing comes from a real first-person visit —
   so coverage starts thin and grows as the community adds to it." That is exactly
   the sentence the rest of the site is missing. The eval scoped empty states out,
   and it only renders on zero results, so it scored as absent — but it already
   exists and is good. **Promote it, don't rewrite it.** It is the model for P2.

2. **Privacy closing is at `:75-81`, not `:77-80`.** Same block, same finding.

Everything else — `index.astro:14`/`:17`, `about/help.astro:37`,
`about/accessibility.astro:77`, `docs/design-direction.md:157`, `README.md:98`,
`contribute/submit.astro:105` — is where the eval said it is.

---

## Ordered plan

### P0 — Correctness: the uncited 40% figure
**`src/pages/about/accessibility.astro:76-78`** · ~10 min

Currently: "automated tools catch only about 40% of real barriers".
The project's own `docs/design-direction.md:154-156` says: "automated tools catch
only ~30–40% (GOV.UK cites ~30%; our own docs say ~40%; CI currently runs only
`@axe-core/playwright`)."

The page's whole argument is *check that we mean it*, and its one hard number
cites nobody. Two acceptable fixes; **prefer the first**:

- **Source it inline.** Change to `~30–40%` and link GOV.UK's accessibility-testing
  guidance on the number. This also fixes B5 (hyperlinks-as-citation), the
  portfolio's weakest quality dimension, on the one page where it costs nothing.
- Or soften to "a minority of real barriers — estimates run roughly 30–40%" with no
  link.

Do not leave a bare uncited 40%. Everything else in that paragraph
(`:76-80`) is good and should survive unchanged.

---

### P1 — Write the About page (highest value by a wide margin)
**New file: `src/pages/about/index.astro`** · ~500 words · **2–3 hrs**

This is net-new writing, not editing. It is where A3 (framework→personal),
A4 (place), A5 (disclosure), and B7 (closings) all recover at once — no other
single item on this list moves more than one dimension.

**Outline (~500 w):**

1. **Open on the scene, not the category** (~80 w). A specific Buffalo instance of
   the failure the product exists to fix — a listing that said accessible and
   meant a step at the door. First person. This is the §3 grounding move the whole
   portfolio is missing.
2. **What that generalizes to** (~90 w). The framework: accessibility information
   fails because it is self-reported by people who never have to use it, and
   flattened into one star rating. Framework *after* the personal instance, which
   is the guide's actual ordering.
3. **Who "we" is** (~80 w). Disabled-led, stated plainly, in the first person —
   *us*, not "the people who use it." This is the single highest-leverage sentence
   on the page.
4. **Why Buffalo / Erie County** (~90 w). The geographic scope is a deliberate
   strength (`README.md:98` — "Buffalo/Erie-County-scoped on purpose … Do not seed
   to NYC/nationwide scale") that the public copy has never claimed. Say it: thin
   and true beats national and fabricated.
5. **What we will not do** (~90 w). No single star rating, no medical proof, no
   selling data, no calling self-reported "verified." The negative-space paragraph
   is load-bearing trust copy and there is currently nowhere it lives.
6. **Close forward** (~70 w). What the reader can do next. Model the close on
   `about/accessibility.astro:92-94`, which is already the best closing in the repo.

**Also required with P1:**
- Add `{ href: '/about/', label: 'About' }` to `NAV` in
  `src/layouts/Base.astro:33-40` — likely before `Help`. Note the array is
  currently six items; check the header does not wrap at 320px.
- Add a footer link alongside `src/layouts/Base.astro:109-111`.
- `export const prerender = false;` to match every sibling page (settings cookie).

---

### P2 — Hero: state a stake, not a category
**`src/pages/index.astro:14` (meta description), `:17` (h1), `:19-25` (lead)** · ~45 min

`:17` currently reads "Accessible places & providers, validated by the community" —
a category label. `:14` and `:22-23` say "validated by the people who use it" /
"first-person disabled experience": true, correct, and third person about the
author's own community.

Three directions. **A is the recommendation** — it carries place, stake, and "we"
in one line:

**A — question, place, first person plural**
> **H1:** Which Buffalo places can we actually get into?
> **Lead:** Access Atlas is a directory of accessible places and disabled-led
> providers in Buffalo and Erie County. Every accessibility claim here comes from a
> disabled person who went there and checked — and it is labeled honestly about how
> sure we are. We would rather list ten places truthfully than a thousand on faith.

**B — declarative, keeps closer to the current structure**
> **H1:** Accessible places in Buffalo, checked by us
> **Lead:** …first-person disabled experience…

**C — lead on the failure**
> **H1:** "Wheelchair accessible" should not mean a step at the door
> **Lead:** …

Whichever wins, `:14` must move with it — the meta description is the same
third-person construction and is what search results show.

Search-visibility tradeoff worth naming: A and C drop the literal keyword string
"accessible places & providers" from the h1. For a directory with no listings yet
and a Buffalo-only scope, voice is worth more than that keyword. Revisit if that
changes.

---

### P3 — Third-person references to disabled people
**`src/pages/about/help.astro:37`** and a sweep · ~45 min

`:37` reads "Real people who visit add what they found." The author is one of those
people. This is the central voice finding in miniature.

Do a full pass for the pattern — but **this is a judgment call per instance, not a
find-and-replace.** `help.astro` is deliberately plain-language for cognitive
accessibility, and its glossary entries (`:41-73`) are definitional; "we"/"us" is
right in narrative sentences and wrong in a definition. Change `:37`. Leave the
`<dl>` alone. `:80` ("We never turn accessibility into one star rating. Each fact
stands on its own.") is already correct and is called out in the eval as
worth preserving.

---

### P4 — Privacy closes on boilerplate
**`src/pages/about/privacy.astro:75-81`** · ~20 min

The page currently ends on "Listings are self-reported and community-sourced. We do
not individually verify listings … Reviews belong to the people who write them."
Legally fine, voice-dead, and it is the last thing the reader sees on the page that
explains the trust model.

The model is two files over at `about/accessibility.astro:92-94`. Keep whatever
disclaimer language is actually load-bearing, then add a closing beat that is
addressed to the reader. `:70-72` (ramps break and elevators fail) is the best
image on the page and is already in the right register — consider closing near it
rather than after it.

---

### P5 — Em-dash density: read, don't count
**Whole corpus, 16.0/1k** · ~30 min, optional

The style guide names em-dashes as a genuine signature, so density alone is not a
defect — page-repair scores higher at 17.0. The specific issue is placement: here
they land in short declarative policy sentences (`index.astro:21`, `help.astro:31`,
`privacy.astro:62`) where the guide's own usage is long clause-chaining.

Do this last, by reading, only where a sentence is already short and declarative.
Do **not** set a numeric target. If P1–P4 land and this still reads fine, skip it.

---

## Do not touch

Called out in the eval as already working:

- `about/accessibility.astro:18-19` — "A disability platform that isn't itself
  accessible is a failure. WCAG 2.2 AA is our floor, not our goal."
- `about/accessibility.astro:76-80` — the 40% honesty framing (once sourced, P0).
- `about/accessibility.astro:86-87` — "it describes what is true today, not what we
  hope to build."
- `about/accessibility.astro:92-96` — the closing disclaimer. This is the model.
- `about/privacy.astro:70-72` — ramps break and elevators fail.
- `about/help.astro:80` — no single star rating.
- `ListingEmptyState.astro:75-79` — see verification note 1.

---

## Effort

| Item | Type | Effort |
|---|---|---|
| P0 — source the 40% | correctness | ~10 min |
| P1 — write About page + nav | net-new, ~500 w | **2–3 hrs** |
| P2 — hero rewrite | editing | ~45 min |
| P3 — third-person sweep | editing, judgment | ~45 min |
| P4 — privacy close | editing | ~20 min |
| P5 — em-dash pass | optional | ~30 min |

**Total: ~5 hrs**, of which P1 is more than half and carries most of the score
movement. P0 is independent and can ship on its own today.

**If only one thing gets done: P1.** If only ten minutes: P0.

---

## Execution notes (2026-07-19)

**0. A verification failure worth keeping — stale-build measurements.**
`playwright.config.ts:19` sets `reuseExistingServer: !process.env.CI`, and
`npm run preview` serves the built `dist/`, not source. Once a background preview
server was started to show the page in a browser, every later `playwright test`
run **reused that server instead of rebuilding** — so the "22 passed" reported
after the access-intimacy section and after the ADA link were run against a build
predating both changes, and the "950 words / 11.6 per 1k" measurement was of
older output. The pass results were not wrong so much as *not evidence*.

Caught by an unexplained word-count jump (950 → 1126) that no edit accounted for.
Correct figures are in the notes below; all were re-verified after killing every
preview server and letting Playwright build its own copy, with an inline
`assert` on distinctive strings to prove freshness.

**Rule for this repo:** never leave a preview server running while testing. Either
kill it first, or assert on page content before trusting any measurement taken
through it. A green run against a stale server looks identical to a real one.

**1. P0's premise was wrong, and the fix is better than planned.** The plan said
to source the 40% to GOV.UK or soften it to a 30–40% range. Fetching the actual
source changed the finding: GOV.UK's 2017 study reports ten tools catching **71%
of 143 planted barriers collectively**, **29% missed by every tool**, and **41%
for the best single tool**. It never says 30%. `design-direction.md:157` was
citing the 29%-*missed* number as if it were a detection rate.

Because CI runs exactly one checker (`@axe-core/playwright`), the single-tool
figure is the one that applies — so the *public page was closer to correct than
the internal doc*. The page now states the real numbers with the study linked;
the internal doc is corrected with a dated note. Softening to a range would have
propagated the error.

**2. Adding the About page exposed a latent a11y bug.** Nav matching in
`Base.astro` is prefix-based, and `/about/` is a prefix of `/about/help/` and
`/about/privacy/` — so the new entry lit two items at once, emitting two
`aria-current="page"` nodes in one nav. Fixed with an `exact` flag, plus a
regression test verified by mutation (removing the flag fails exactly 4 tests).
The file's own comment had asserted "no nav href is a prefix of another"; that
invariant is now enforced rather than assumed.

**Test position.** 51 passed (baseline 39) — `/about/` added to the axe, title,
320px-overflow and zero-script suites, plus the new nav tests. The 25 failures
are pre-existing and DB-dependent: identical counts before and after, confirmed
by stashing. Unit 118/118. `astro check` clean.

**P5 skipped.** Em-dash density was never a mechanical target, and after P1–P4
the prose reads fine. Revisit only if it bothers you on a read-through.

**Opening scene — written (commit `b6eebbb`).** Zach supplied the account: New
York, a best friend who used a wheelchair, the same places stopping each of them
for different reasons. It changed the page's structure rather than just filling a
hole. The plural-access observation — two disabled people, same building, same
afternoon, stopped by different things — is a stronger case against single-number
accessibility ratings than the argument the draft had made, so "What goes wrong"
was reordered to pick it up (plurality first, owner-written-intent second), the
lead was repointed at it, and "Why Buffalo" now answers the question the New York
scene raises on its own.

Worth noting as a general lesson: the beat that could only come from the author
did not slot into the outline — it *rearranged* it. Planning the surrounding
argument before having the anecdote produced a structure that was subtly wrong.
