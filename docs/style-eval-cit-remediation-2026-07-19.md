# Chronic Illness Tracker — copy remediation plan

Derived from `docs/style-eval-2026-07-19.md` (Voice 3.1/5, Quality 4.4/5, 835 words).
Repo: `/Users/zachbeaudoin/Chronic-Illness-Tracker` (symlink: `repos/chronic-illness-tracker`).
All line references verified against the working tree on 2026-07-19.

## Standing constraints

**Two-file rule.** `locales/es.json` mirrors `en.json` key-for-key and is currently
*untranslated* — es.json:646-647 are byte-identical English. Every item below is a change
to both files. Do not fix only the English and leave the Spanish drifting; the current
state is at least honestly stale, a half-updated pair is not.

**Voice contract.** `locales/TRANSLATION_NOTES.md` locks the register: warm, plain, direct;
never cheerful; never gamified; never nudging; empty states assume the user may be unwell.
Every proposed string below is written to survive that contract in translation.

**Preserve list — do not touch.** en.json:668 (`shortVersionBody`), en.json:679
(`neverBody`, the employers/insurers/data-brokers fragment stack), en.json:83
(`foodTrackingExplain`, the concession), en.json:661 (the scare-quoted "wellness journey").
These are the app's best writing. Any edit that makes them more uniform is a regression.

---

## 1. Name the accountable party — BLOCKED ON A HUMAN DECISION

**Severity: trust defect. This is the highest-priority item and cannot be drafted around.**

`locales/en.json:681` (`privacy.questionsBody`), mirrored at `es.json:670`:

> "This policy is written to be readable. If anything is unclear, or you want your data
> handled in a way the app does not yet support, contact the person who gave you access to
> this app."

This is the PHI app. The document's entire job is to earn a stranger's health data, and it
closes by declining to identify who is holding it. "The person who gave you access" also
quietly assumes a distribution model — hand-shared invites — that the signup route
contradicts.

**Grep result: no contact email exists anywhere in the repo.** Not in `README.md`, not in
`package.json`, not in `docs/`. This is not a copy oversight to be patched with a plausible
address; the accountable party has never been decided.

### The decision needed

Who is the named contact, and at what address? Options, in rough order of what the rest of
the portfolio implies:

- **A Beau Access Solutions address** (e.g. a privacy@ or support@ alias on the existing
  domain) with BAS named as operator. Consistent with the other apps; requires the alias to
  actually route somewhere a human reads.
- **A personal address with a personal name.** Most honest for a solo-operated app, and the
  register of this policy can carry it. Costs privacy at the operator end.
- **A named entity with no email, contact via an in-app route.** Weakest — reintroduces the
  same "no accountable party" problem behind an extra click.

Do not ship any of the text below until this is answered. A placeholder here is worse than
the current sentence, because the current sentence at least does not make a promise.

### Proposed text, once the contact exists

`privacy.questionsBody` becomes two keys — the answer and the paper trail:

> **questionsBody:** "This policy is written to be readable. If anything is unclear, or you
> want your data handled in a way the app does not yet support, email {NAME} at {ADDRESS}.
> A person reads that address, and you will get an answer from a person."

> **questionsSourceBody** (new key): "The technical detail behind this policy — how the
> database is encrypted, what is kept out of the logs, how deletion actually works — is
> written up in the security plan, and it changes before this page does."

The second key wants a link. `docs/security/plan.md` already exists, and
`src/app/privacy/page.tsx:11-13` carries a comment naming it as the technical source of
truth — but it has never been surfaced to a user. Publishing it is a separate small task
(decide whether it goes to a public URL or a repo link) and is optional for this item; the
named contact is not.

**Files:** `locales/en.json:681`, `locales/es.json:670`, and a new `<section>` in
`src/app/privacy/page.tsx` after the existing `questionsHeading` block (line 55-58).

**Effort:** 20 minutes once the contact is decided. Indefinite until then.

---

## 2. README license — same fade, lower stakes

`README.md:126` reads `*To be decided.*`

Same failure mode as item 1 in a lower-consequence place: the document declines to commit.
Worth fixing in the same pass because it's a two-minute change once someone picks, and
leaving it perpetuates the impression that nobody is answerable for this codebase either.

**Decision needed:** a license (or an explicit "all rights reserved, not open source",
which is a real answer and better than "to be decided").

**Effort:** 5 minutes after the call. Bundle with item 1.

---

## 3. Write an About page — the largest voice gain available

**This is net-new writing, not editing, and it is the single biggest score move.**

Verified: `src/app/` contains only `(app)/`, `(auth)/`, `api/`, `privacy/`, and the root
`page.tsx`. There is no `about/`, `help/`, or `faq/`. The only unauthenticated prose
surfaces are the landing page (60 lines, ~5 strings) and the privacy page. The corpus is
835 words largely *because* there is nowhere for prose to live — the voice score is
measuring an absence as much as a defect.

An About page is also where the two structural findings below get resolved properly:
place-based grounding (item 5) and sentence rhythm (item 6) both need room the landing page
doesn't have and shouldn't be forced to provide.

**Scope:** a new `src/app/about/page.tsx` following the `privacy/page.tsx` pattern exactly
(server component, `getTranslations`, section stack, back-to-home link), plus an `about`
block in both locale files. 400-600 words. Suggested sections:

- **Why this exists.** The scene the app was built out of. First person is permitted here
  in a way it isn't elsewhere in the product.
- **What it does and does not do.** Can lean on the existing value props without repeating
  them verbatim.
- **Who made it.** Naturally absorbs the accountability problem from item 1 — this page is
  the right home for the named human, with the privacy page pointing at it.
- **What it will never become.** The `neverBody` fragment stack at en.json:679 is the
  strongest writing in the app; an About page can extend that stance to the product rather
  than just the data.

**Dependency:** the "who made it" section needs the same answer as item 1. The other three
sections do not — they can be drafted in parallel.

**Effort:** 2-3 hours of real writing, plus ~30 minutes of route scaffolding and a nav link.
This is a writing task, not an engineering one; do not let the scaffolding estimate set the
expectation.

---

## 4. Landing lead — put a person in it

`locales/en.json:657` (`landing.lead`), mirrored at `es.json:646`:

> "Log symptoms, medications, food, and context. Spot patterns. Prepare for appointments.
> Own your data."

Four imperative fragments, no human in any of them. It opens in the database — a feature
list in the imperative mood — when the reader arriving here is a person who feels bad and
wants to know if this will help. The app's own voice contract says empty states assume the
user may be unwell; the front door should too.

**Proposed:**

> "You know something is going on with your body. This is a place to write it down, so that
> when you finally get in front of a doctor, you have more than memory to offer."

Puts the reader and the room in the first fifteen words, and lands on the appointment —
which is the actual payoff the original buries third in a list. Keeps the plain register.
No exclamation, no journey, no cheer.

**Alternate, shorter, if the lead must stay tight:**

> "Write down what your body is doing, on the days you can, so the pattern is there when you
> need it."

**Files:** `locales/en.json:657`, `locales/es.json:646`.

**Effort:** 15 minutes, plus a read of the rendered page at `src/app/page.tsx:23-25` to
confirm the longer lead still sits well at `text-lg` in the `max-w-lg` column.

---

## 5. Place-based grounding (2/5) — read the diagnosis carefully

`locales/en.json:658` (`landing.audience`) grounds the app in **diagnoses**:

> "Built for people managing complex chronic illness — MCAS, POTS, migraine, autoimmune
> conditions, and everything in between."

**Do not mistake this for grounding, and do not "fix" it by editing this line.** The
condition list is doing correct and necessary work: it tells a reader with MCAS that this
app was built with them in mind, which a generic "chronic illness" would not. It is a
clinical *category*, not a place or a scene — which is precisely why the grounding score is
2/5 despite this line existing.

The fix is not to replace the category with a scene. It is to **add** a scene somewhere the
app currently has none. That surface is the About page (item 3). Grounding wants the
specific room: the pharmacy counter, the 4pm crash, the intake form asking when symptoms
started, the notebook that didn't survive the move.

**Action: no edit to en.json:658. This finding is resolved by item 3 or not at all.**

**Effort:** absorbed into item 3.

---

## 6. Sentence rhythm (2.5/5) — let two or three run, not all of them

**Critical caveat, carried forward from the evaluation:** the clipped register is doing real
accessibility work. Short sentences are what a user can parse on a bad day, and
`TRANSLATION_NOTES.md` encodes that instinct deliberately. **Do not lengthen everything.**
A uniform lengthening pass would trade a stylistic score for a genuine usability loss and
would be a net regression.

The fix is variation, not length. Let two or three sentences run long so the short ones land
as choices rather than as the only available gear.

**Target: `locales/en.json:659-661`** — three value props, each two clipped sentences:

> "Your data is yours. Raw export is always free."
> "Accessibility-first. Designed for use on hard days."
> "No streaks. No guilt. No “wellness journey” language."

**Proposal: lengthen the first two, leave the third exactly as it is.** The third is the
best line on the page — a three-beat fragment stack ending on the scare-quoted "wellness
journey" — and it only works because it is the tightest thing in the group.

> **valueData:** "Your data is yours, which means the raw export is free and complete on the
> day you sign up and on the day you leave, with no upgrade in between."

> **valueAccessibility:** "Built accessibility-first and tested on the days that are hard,
> because a tracker you cannot use when you feel worst is a tracker for nobody."

> **valueNoGuilt:** *(unchanged — en.json:661)*

Two long, one short. The rhythm now resolves on the strongest line.

**Files:** `locales/en.json:659-660`, `locales/es.json` (corresponding lines).

**Effort:** 30 minutes including a rendered check — these sit in a `max-w-sm` left-aligned
stack at `src/app/page.tsx:47-49` and will grow to three or four lines each on mobile.
Verify that's acceptable before committing.

---

## 7. The one sentence that fails a read-aloud

`locales/en.json:670` (`privacy.collectBody1`):

> "Only what you choose to log: symptoms, medications and dose records, and any optional
> dimensions you turn on (food, energy, sleep, stress, cycle, exposures), plus notes and
> tags. Your account needs an email address and a password. We record the IP address and
> browser of each sign-in so you can spot logins that are not yours."

Sentence one is the problem: a colon, three coordinated groups, a six-item parenthetical,
and then a "plus" tail hung off the end. It cannot be read aloud in one breath, which on a
privacy page — the document a suspicious reader reads most carefully — is where clarity
matters most. Sentences two and three are fine and should not be touched.

**Proposed replacement for sentence one only:**

> "Only what you choose to log. That means symptoms and medications, the dose records that
> go with them, and whatever optional dimensions you have turned on — food, energy, sleep,
> stress, cycle, exposures — along with any notes and tags you add."

Breaks the colon-plus-parenthetical pile into two sentences, promotes the six-item list out
of parentheses into em-dashes where it can be read as a list rather than an aside, and drops
the "plus" tail. Same information, same register, survives a read-aloud.

**Files:** `locales/en.json:670`, `locales/es.json` (corresponding line).

**Effort:** 15 minutes.

---

## Ordering and estimates

| # | Item | Blocked? | Effort |
|---|------|----------|--------|
| 1 | Named contact in privacy policy | **Yes — human decision** | 20 min after decision |
| 2 | README license | **Yes — human decision** | 5 min after decision |
| 3 | About page (net-new) | Partially — "who made it" needs #1 | 2-3 hrs writing + 30 min scaffold |
| 4 | Landing lead | No | 15 min |
| 5 | Place grounding | — | absorbed into #3 |
| 6 | Value-prop rhythm | No | 30 min |
| 7 | `collectBody1` read-aloud | No | 15 min |

**Suggested sequence.** Answer the two decisions in items 1-2 first — they are the trust
defect and they gate the most valuable work. While waiting, items 4, 6, and 7 are
independent and total about an hour; they can ship as one small copy PR against both locale
files. Item 3 is the real investment and should be scheduled as writing time, not slotted
into an engineering sprint.

**Do not ship any of this without the es.json counterpart.** The Spanish file is currently
honestly untranslated; a partial sync would make it dishonestly stale.
