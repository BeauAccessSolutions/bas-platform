# Marketing site — remediation plan

**Source:** `docs/style-eval-2026-07-19.md` (Voice 2.9/5, Quality 3.4/5, 3,957 words)
**Repo:** `beau-access-solutions` (symlinked at `repos/marketing-site`)
**Live at:** https://beaccessolutions.com — every change here is production-facing
**Date:** 2026-07-19
**Status:** proposal only. Nothing in this plan has been applied.

---

## Verification pass

Every file:line in the eval was checked against the working tree before planning. All
targets exist and say what the eval says they say. Two claims needed adjusting, and
external fact-checking turned up two things the eval did not have. Both are in §0.

The two-layer thesis is confirmed by `git log`, with one correction:

| Layer | Commits | Files |
|---|---|---|
| **January** (weak) | `732adc4` 2026-01-28, `8615a94` 2026-03-14 | 3 blog posts, `why-accessibility.astro`, `services.astro`, `about.astro` |
| **July** (benchmark) | `a86ee88` → `5d88556`, 2026-07-16 → 07-19 | `apps.astro`, `apps/*.astro`, `index.astro` hero + "How we help" |

**Correction to the eval:** the July layer *did* touch all three blog posts — commit
`5d88556` ("cut em-dash density 10.7 → 3.5 per 1k"). That was a mechanical
search-and-replace, not a rewrite, so the two-writers finding stands. But it means the
blog posts are not untouched January artifacts, and the em-dash gate in CI now applies to
them. Any rewrite has to stay under that gate or the build fails.

**Also worth knowing:** the three posts render with `date:` values of 2025-11-24,
2025-11-24, and 2025-11-15 (`blog/index.astro:9,15,21`) — publicly dated eight months
ago. This matters for the retire-vs-rewrite call in §4: a visibly stale dateline makes a
factual error read as neglect rather than as a typo.

---

## §0 — What external checking changed

Two of the eval's recommendations are wrong on the facts. Both would have made the site
worse if applied as written.

### 0.1 The WCAG fix is not "2.2 superseded 2.1"

The eval frames `wcag-conformance-levels.astro:25-26` as a simple staleness bug. It is
staler and subtler than that:

- WCAG 2.2 became a W3C Recommendation **5 October 2023**, and the current Recommendation
  is the **12 December 2024** update. "Recently released" is roughly three years stale.
- **But WCAG 2.2 does not supersede 2.1.** The spec says so directly: "The publication of
  WCAG 2.2 does not deprecate or supersede WCAG 2.0 or WCAG 2.1."
- So the post's *second* sentence — "Most legal requirements and organizational policies
  reference WCAG 2.1" — **is still true**, and the DOJ Title II rule confirms it: it
  adopts **WCAG 2.1 Level AA**, not 2.2.

This means `index.astro:26` and `apps.astro:115` are **not actually contradicting** the
blog post. Selling "WCAG 2.2 AA as a floor" while the law requires 2.1 AA is a coherent
and defensible position — it is a claim to exceed the legal minimum. The site has never
said that out loud, which is why it reads as a contradiction.

**The fix is therefore an upgrade, not a patch.** Say the true and more interesting thing:
the law asks for 2.1 AA, we build to 2.2 AA, here is why. That converts the site's worst
correctness liability into its clearest differentiator.

### 0.2 The "1 in 4" statistic is not just uncited — it is out of date

The eval says to cite CDC for "1 in 4". Current CDC data does not say 1 in 4:

- **28.7% of US adults** report a functional disability — an estimated **70 million**
  people (2022 BRFSS).
- "1 in 4" (~26%) is the **2018** CDC figure, now on CDC's archive site.

So `who-benefits:111`'s "25%" is not merely a formatting inconsistency with the "1 in 4"
elsewhere — it is **understated by nearly four points** against current data. Adding a CDC
link to the existing numbers would cite a source that contradicts them.

Correct move: standardize on **"more than 1 in 4 US adults (28.7%)"**, linked to CDC, in
all three places.

### 0.3 A live content gap the eval could not have seen

DOJ published an **Interim Final Rule on 20 April 2026** extending the Title II compliance
deadlines to **26 April 2027** (populations 50,000+) and **26 April 2028** (under 50,000
and special districts). That is three months old and nothing on the site mentions it.

This is not a style defect, so it is out of the eval's scope — but for an accessibility
consultant selling to public agencies, a current-deadline page is the single highest-value
piece of content the site does not have. Flagged as an opportunity in §5, not as a fix.

---

## §1 — Correctness (do first, ship alone)

Ship this as its own commit, before any style work. It is small, it is unambiguous, and it
should not wait behind rewrite decisions.

### 1.1 `blog/wcag-conformance-levels.astro:25-26` — **P0**

Current:

> The current version is WCAG 2.1, though WCAG 2.2 was recently released. Most legal
> requirements and organizational policies reference WCAG 2.1.

Proposed:

> WCAG 2.2 has been a W3C Recommendation since October 2023, and it is now an ISO standard
> (ISO/IEC 40500:2025). It does not replace WCAG 2.1 — the W3C is explicit that 2.2
> neither deprecates nor supersedes it. That is why most legal requirements still point at
> 2.1: the Justice Department's Title II rule, for one, adopts WCAG 2.1 Level AA.
>
> We build to 2.2 AA anyway. The nine criteria 2.2 adds — larger click targets, visible
> focus, no drag-only interactions, accessible authentication — are the ones that decide
> whether someone can actually finish a task. Meeting the legal floor and building
> something usable are different jobs.

Links to add: [WCAG 2.2](https://www.w3.org/TR/WCAG22/),
[W3C announcement](https://www.w3.org/WAI/news/2023-10-05/wcag22rec/),
[DOJ rule](https://www.ada.gov/resources/2024-03-08-web-rule/).

This single edit fixes the defect, adds the site's first three citations, and states the
2.1-vs-2.2 position that makes `index.astro:26` and `apps.astro:115` coherent.

**Effort: 30 min.**

### 1.2 `blog/ada-demand-letter.astro:68` — **P2**

Says "A thorough audit against WCAG 2.1 Level AA standards". Verified — and given §0.1,
this is **correct as written**, since a demand letter will be argued against the legal
standard. Recommend leaving the standard alone and adding one clause: *"…against WCAG 2.1
Level AA, the standard a demand letter will be argued against — though fixing to 2.2 AA
costs little more and dates better."* **Effort: 10 min.**

### 1.3 The disability statistic — three files — **P1**

| File:line | Current | Proposed |
|---|---|---|
| `why-accessibility.astro:63` | "the 1 in 4 adults who have some form of disability" | "the **more than 1 in 4** US adults — 28.7%, about 70 million people — who report a disability" + CDC link |
| `blog/who-benefits…:23` | "Approximately 1 in 4 adults in the United States has some form of disability." | "More than a quarter of US adults — 28.7%, roughly 70 million people — report a disability." + CDC link |
| `blog/who-benefits…:111` | "Don't exclude 25% of potential users" | rewritten entirely in §3.1; the number leaves with the framing |

Source: [CDC, Disability Impacts All of Us](https://www.cdc.gov/disability-and-health/articles-documents/disability-impacts-all-of-us-infographic.html)
(2022 BRFSS). **Effort: 20 min.**

---

## §2 — The About page — **P0, but needs a human decision first**

`about.astro:15-16` promises lived experience:

> I bring both professional credentials and lived experience as a disabled professional to
> my work in digital access and inclusive workplace practices.

`about.astro:39-42` delivers:

> My career has spanned universities, public agencies, and community organizations,
> handling accommodations, managing public processes, and seeing firsthand where
> institutional systems fail to serve disabled people effectively.

No place. No institution. No story. The promise in the hero is never paid off, and the one
page built to carry disclosure-as-evidence declines to use it.

### This is your call, not mine

How much of your own disability is public is a decision about your life, not a style
score. I am not going to pick a level for you. **The structural move is the same at every
level of disclosure:** replace the abstract claim with one concrete scene in which a
system failed, and let the analysis come out of it. What changes is whose failure the
scene describes.

Three versions, ordered by how much they disclose. Pick one, or tell me a fourth shape.

**Version A — no personal disclosure.** Cut the "lived experience" claim from the hero and
ground in place and institution instead. Costs the A5 disclosure dimension entirely, but
it stops the site promising something it does not deliver.

> I have spent my career inside the institutions that are supposed to make accommodation
> work — universities, public agencies, community organizations — usually as the person the
> request landed on. The pattern I kept meeting was not hostility. It was a form that had
> nowhere to put the thing someone actually needed, and a manager with no authority to
> change the form.

**Version B — disclosed, undetailed (recommended).** Keeps the hero promise, pays it off
once, does not name a diagnosis.

> I am a disabled professional, and I have spent my career inside the institutions that are
> supposed to make accommodation work. That means I have sat on both sides of the same
> table: the one where you administer the process, and the one where you are the person
> waiting on it. The second seat teaches you things the first one cannot. You learn that
> the delay is rarely anyone's decision — it is four people each waiting for a different
> form — and that knowing this does not make the waiting shorter.

**Version C — disclosed, with a specific scene.** Highest voice score, most exposure.
Requires a real detail from you: a place, an institution, an accommodation, what happened.
The structure:

> [One scene, 2–3 sentences: where you were, what you needed, what the system did.]
> [One sentence naming what the scene shows about how these systems fail.]
> That is the failure mode I build against.

I would need that detail from you to draft it — I am not inventing a scene about your
life.

**Recommendation: Version B.** It pays off the hero's promise, it is the only version that
earns the "lived experience" line already on the page, and it discloses no more than the
hero already does. C scores highest but should only happen if you actively want that scene
public.

**Effort: 1 hr once you have chosen. Blocked on your decision.**

---

## §3 — The justice-lens inversion — **P1**

The site already has the right frame and then undercuts it. `why-accessibility.astro:14-16`
opens with genuine op-ed register — "dignity: removing barriers that were never necessary
in the first place, so that using something well doesn't depend on which body you happen to
have" — and then six cards below argue market share and SEO.

### 3.1 `blog/who-benefits…:105-114` — the market-share list

Currently frames disabled people as an addressable market: "Larger audience: Don't exclude
25% of potential users". Proposed replacement for the list intro and that bullet:

> These are not side effects. Every one of them is the same fact seen from a different
> angle: an interface that does not assume a particular body is simply a better interface.
>
> - **Legal exposure drops**, because the barrier that generates the demand letter is gone.
> - **Your reach is not a market segment.** Building for disabled people is not audience
>   expansion. It is the reason the work is worth doing — the rest of this list is what
>   happens to fall out of it.
> - **Your code gets cleaner.** Semantic markup and real focus management are just better
>   engineering.

### 3.2 `why-accessibility.astro:85` — "Improves SEO Performance"

An SEO card sitting under a dignity paragraph is the single clearest instance of the
January register overwriting the July one. Two options:

- **Cut it.** Six cards become five. Cheapest, and the page loses nothing it needs.
- **Demote it.** Keep the fact, drop it to a one-line aside under the cards: *"Accessible
  markup also happens to rank better. That is a side effect, not a reason."*

**Recommend cutting.** If a client needs the SEO argument to say yes, the SEO argument is
not what will keep them accessible six months later.

### 3.3 `why-accessibility.astro:62` — "Reaches Wider Audiences"

Same inversion, same card grid. Retitle to **"The people it is for"** and rewrite the body
with the corrected CDC figure from §1.3.

**Effort for all of §3: 2 hrs.**

---

## §4 — The three blog posts: rewrite or retire

The eval asks for a per-post call. Mine, with reasoning:

### `wcag-conformance-levels.astro` (177 lines) — **REWRITE**

The only post whose subject you own outright, and after §1.1 it carries the site's clearest
position. The A/AA/AAA explainer below the fold is solid and does not need touching. Rewrite
is confined to the §1.1 edit plus a real closing. **Effort: already counted in §1.1, +30
min for the close.**

### `who-benefits-from-accessible-website.astro` (131 lines) — **REWRITE, restructured**

Worth saving because the site already wrote its best paragraph and then failed to use it.
`index.astro:269` promotes this exact post with a line the post itself never contains:

> Curb cuts were built for wheelchairs. Everyone uses them.

That is the whole argument in nine words, sitting on the homepage as a teaser for a post
that opens with a statistic instead. **Lead with it.** The curb-cut frame also does the §3.1
work automatically: it makes universal benefit an *argument for* disability-first design
rather than a substitute for it. Then apply §1.3 and §3.1.

**Effort: 2 hrs.**

### `ada-demand-letter.astro` (147 lines) — **RETIRE, or rewrite at real cost**

The structural problem is confirmed: `h2 → 1–2 sentence stub → bullets`, five times
(lines 16/29/46/64/79, plus a Q&A and a close). It is a listicle wearing an article's
clothes. But that is not the reason to retire it:

1. **It is the one post whose subject you are not the authority on**, and it says so at
   line 60: "I'm not an attorney, and this article is not legal advice." A post that
   disclaims its own expertise in the middle is structurally weak no matter how well it is
   written.
2. **It is the most legally exposed page on the site** — it advises people mid-dispute.
3. **It is the most staleness-sensitive**, and per §0.3 it is already stale: it predates
   the April 2026 DOJ deadline extension and does not mention it. It has been publicly
   wrong-by-omission for three months.

**Recommendation: retire the post, redirect `/blog/ada-demand-letter` → `/services`, and
recycle the good part.** The genuinely useful content is the "conduct an audit" step, which
is a service you sell — it belongs on `services.astro`, not in a legal explainer.

**If you want to keep it**, the rewrite is not a light edit: it needs the April 2026
deadlines, an attorney-reviewed framing, and prose in place of five bullet stubs. Budget
4–5 hrs and a legal read. I would not spend that before §2 and §3 are done.

**Effort: 30 min to retire (redirect + remove from `blog/index.astro`). 4–5 hrs + legal
review to rewrite.**

---

## §5 — Sourcing floor and the rest

### 5.1 Sourcing — **P1**

13 outbound links, verified: 12 to cal.com, 1 to Access Atlas. Zero citations. The rule
worth adopting, matching the eval's portfolio recommendation: **any sentence asserting a
rate, trend, or magnitude gets an inline link or gets softened.**

Sections §1.1 and §1.3 already add five citations. The remaining uncited assertions:

| File:line | Claim | Action |
|---|---|---|
| `why-accessibility.astro:73` | "ADA lawsuits and demand letters are increasing" | Cite a lawsuit-tracking source, or soften to "have risen sharply over the last decade" |
| `blog/who-benefits…:110` | same claim, same page-set | same |

**Effort: 45 min**, contingent on picking a defensible lawsuit-count source — most public
trackers are published by vendors selling overlay products, which is a sourcing problem in
itself. Softening is the honest fallback.

### 5.2 `services.astro` and the rest of `about.astro` — **P3**

The eval scores these as January-layer. Spot-checked: `services.astro` is mostly deliverable
lists and scope commitments, which is the one place the flat register is *correct*. A client
reading "Risk snapshot in 1 week" wants exactly that sentence. **Recommend leaving it**
until §1–§4 land, then revisiting only the section intros.

### 5.3 The DOJ deadline page — **new content, P2**

Per §0.3. A short page stating the April 2027 / April 2028 Title II deadlines, who they
bind, and what "WCAG 2.1 AA" concretely requires would be the most useful page on the site
for public-agency clients — and it is exactly the July-layer register. **Effort: 3 hrs.**
Not remediation; flagged because it competes well against rewriting `ada-demand-letter`.

### 5.4 Em-dashes — **no action**

4.5/1k, within range. Note that `5d88556` added a CI gate; any new copy must pass it.

---

## Ordered plan

| # | Item | Priority | Effort | Blocked on |
|---|---|---|---|---|
| 1 | §1.1 WCAG fix + first citations | P0 | 30 min | — |
| 2 | §1.3 CDC statistic, 3 files | P1 | 20 min | — |
| 3 | §1.2 demand-letter clause | P2 | 10 min | — |
| 4 | §2 About page rewrite | P0 | 1 hr | **your disclosure decision** |
| 5 | §3 Justice-lens fixes | P1 | 2 hrs | — |
| 6 | §4 who-benefits rewrite | P1 | 2 hrs | 2, 5 |
| 7 | §4 retire ada-demand-letter | P2 | 30 min | **your call** |
| 8 | §5.1 remaining sourcing | P1 | 45 min | source choice |
| 9 | §5.3 DOJ deadline page | P2 | 3 hrs | — |
| 10 | §5.2 services/about remainder | P3 | — | 1–8 |

**Items 1–3 ship together as one correctness commit, today, independent of everything
else.** Total through item 8: roughly 7–8 hours. Adding item 9: ~11.

Two decisions are yours before I touch anything: **the About disclosure level (§2)** and
**whether `ada-demand-letter` is retired or rewritten (§4)**.
