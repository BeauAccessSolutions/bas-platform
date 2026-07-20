# Portfolio Writing-Style Evaluation — 2026-07-19

Eight BAS apps evaluated against the locked personal writing style guide
(`Zach Beaudoin — Writing Style Guide.md`, 🔒 v1.0, 2026-06-07), §9 rubric.

**Method.** One independent evaluator per app. Each read the guide in full (not from
memory), located that repo's prose surfaces, and scored Axis A (Voice, A1–A8) and Axis B
(Quality, B1–B7), 1–5 each, averaged per axis.

**Scope — prose surfaces only.** Landing/marketing body copy, About/mission narrative,
help and FAQ content, editorial and policy prose, article bodies, README landing prose.

**Explicitly out of scope.** Button labels, form labels, error strings, empty states, nav
items, alt text, meta tags, code comments, config, migrations, test fixtures. The guide's
seven registers are all prose; none is UI microcopy, and scoring a 40-character error
string on "framework→personal hook" would produce a meaningless number. Evaluators were
instructed to refuse to score thin material rather than manufacture a scorecard.

---

## 1. Scorecard

| App | Voice | Quality | Prose evaluated | Em-dashes /1k |
|---|---|---|---|---|
| page-repair | **3.9** | **4.6** | 2,123 w | 17.0 |
| Access Atlas | 3.3 | 4.3 | 2,156 w | 16.0 |
| KindredAccess | 3.1 | 3.9 | 4,490 w | 3.7 |
| Chronic Illness Tracker | 3.1 | 4.4 | 835 w | 7.2 |
| Marketing site | 2.9 | 3.4 | 3,957 w | 4.5 |
| Benefits Navigator | 2.2 | 3.5 | 37,379 w | 0.0 |
| Disability Wiki | 1.9 | 3.7 | 441,100 w | 4.5 |
| a11y-probe | — | — | 0 w | n/a |

a11y-probe was not scored. It has zero qualifying prose: the README is unmodified Devvit
starter boilerplate (single commit, `5787497`), and the only author-written English is
~161 words of in-app test instructions. "Nothing to score" is the finding, not a low score.

---

## 2. Cross-app findings

### 2.1 Quality exceeds Voice in every app, without exception

Quality lands 3.4–4.6; Voice lands 1.9–3.9. Eight independent evaluators, same split.
§7 slips are essentially absent portfolio-wide — no "Which…" fragments, no homophone
swaps, no dropped words, no double parens, across roughly 490,000 words. Intensifier
discipline scored 5/5 in four apps.

**The gap is not a skill gap.** It is the difference between prose that is careful and
prose that is identifiably one person's.

### 2.2 The two most distinctive moves in the guide are the two lowest-scoring dimensions

A4 (place-based grounding) and A3 (framework→personal hook) sit at or near the floor in
all seven scored apps. A4 scored 1–3 everywhere; 1.0 in Disability Wiki, 1.0 in
KindredAccess, 1.5 on the marketing site.

The apps ground themselves in **categories** — diagnoses, conditions, user segments,
citations — where the guide grounds in a **place or a scene**. "MCAS, POTS, migraine"
(CIT) is a clinical list, not §3 grounding. page-repair maps its frameworks onto research
citations rather than onto a life. Buffalo appears once in the entire portfolio, in a
README (`access-directory/README.md:98`).

### 2.3 The surface built to carry voice is missing or empty

- **Access Atlas** — no About page. `src/pages/about/` contains accessibility, help, and
  privacy only.
- **Chronic Illness Tracker** — no `about/`, `help/`, or `faq/` route exists.
- **Benefits Navigator** — no About page, no FAQ template, no onboarding narrative.
- **Marketing site** — has an About page that declines to disclose. `about.astro:15-16`
  promises "lived experience as a disabled professional"; `:39-42` delivers "My career has
  spanned universities, public agencies, and community organizations."

§2 identifies disclosure-as-analytic-evidence as one of the most distinctive and effective
moves in the corpus. The pages designed to carry it either do not exist or decline to use it.

### 2.4 Hyperlinks-as-citation is absent portfolio-wide

B5 is the weakest Axis B dimension nearly everywhere. §6 names source appraisal as a
standout habit and hyperlinks-as-citation as the signature public-facing device. Neither
appears. The marketing site has 13 outbound links total: 12 to a booking page, 1 to Access
Atlas. Load-bearing statistics run uncited across at least four apps (see §3).

### 2.5 Closings fade

B7 is low nearly everywhere. Disclaimers, legal boilerplate, or programmatically stamped
footers occupy the final slot on almost every surface in the portfolio. Disability Wiki has
223 files closing with a byte-identical sentence, stamped by `bulk_update_footer.py`.

### 2.6 There is no portfolio em-dash norm — and the metric did not behave as expected

Density ranges 0.0 to 17.0 per 1,000 words. An early hypothesis that density tracks
inversely with corpus size **did not survive the full data set** — CIT is the smallest
scored corpus (835 w) and sits mid-range at 7.2.

The better-supported read is **register**: persuasive product copy runs 16–17 (page-repair,
Access Atlas), reference and service copy runs 3.7–4.5 (KindredAccess, Disability Wiki,
marketing site). This is a plausible explanation, not a proven one — seven data points.

**Benefits Navigator's 0.0 is a different phenomenon entirely.** Zero true em-dashes in
37,379 words, with 435 spaced ASCII hyphens (` - `) doing em-dash work. That is a
character-level convention, not stylistic restraint, and it should not be read as the
bottom of a trend.

No portfolio-wide em-dash target should be set from this data.

---

## 3. Correctness defects

Surfaced by the style pass; **not style issues**. Ranked by severity.

| # | App | Defect | Location |
|---|---|---|---|
| 1 | KindredAccess | Child-safety rule is self-contradictory: "Photos of minors (unless you are the minor and 18+)" | `templates/guidelines.html:207` |
| 2 | page-repair | Ship-blocker: unresolved placeholder in the required Web Store privacy-policy URL field | `STORE_LISTING.md:95` |
| 3 | Chronic Illness Tracker | Privacy policy names no accountable party — closes with "contact the person who gave you access to this app". This is the PHI app. License also "To be decided" (`README.md:126`) | `locales/en.json:681` |
| 4 | Marketing site | WCAG version contradiction: a blog post calls 2.2 "recently released" (W3C Recommendation since Oct 2023) while two other pages sell 2.2 AA as a floor | `blog/wcag-conformance-levels.astro:25-26` vs `index.astro:26`, `apps.astro:115` |
| 5 | Benefits Navigator | Landing page advertises both 4 and 15 exam guides | `templates/core/home.html:50` vs `:307` |
| 6 | Benefits Navigator | Three load-bearing statistics uncited: 30% underrating, ~50% appeal success, ~93% contractor exams | `home.html:20`, `appeals_home.html:18`, `exam_guides.json:9` |
| 7 | Disability Wiki | Unclosed italic renders a literal asterisk on the landing page; a hand-written `## Footer` block sits above an automated footer, stacking two | `home.md:246`, `:236-244`, `:250` |
| 8 | Disability Wiki | Editorial policy mandates person-first language while 274 files correctly use identity-first; also British "-centred" against US spelling elsewhere | `glossary/editorial-guidelines.md:17` |
| 9 | KindredAccess | Dark mode listed as shipped on two pages, "coming soon" on the accessibility page | `accessibility_info.html:244` vs `help.html:284`, `features.html:242` |
| 10 | KindredAccess | Three different contact domains (`.com` and `.org` mixed) — at least one is likely dead mail | `guidelines.html:223`, `accessibility_info.html:259`, `help.html:379` |
| 11 | Access Atlas | The "40%" automated-tooling figure is uncited and contradicts internal docs ("GOV.UK cites ~30%; our own docs say ~40%") | `about/accessibility.astro:77` vs `docs/design-direction.md:157` |
| 12 | a11y-probe | README is unmodified upstream boilerplate; instructs the reader to create the project that already exists | `README.md:1-16` |

---

## 4. Two low scores that should NOT be "fixed"

**Disability Wiki (Voice 1.9).** The evaluator argued this is an eighth register not in §1 —
an anonymous institution addressing a stranger in need — and that it is correct for a crisis
wiki. Someone reading `crisis/index.md` mid-emergency needs scannable, unornamented,
hierarchy-first text. Register discipline scored 5/5. **The actionable number here is the
Quality 3.7**, dragged down by stamped closings and uneven sourcing, not by bad writing.

Provenance note: git shows only two committer identities, both Zach, so history cannot
separate hand-written from AI-drafted content. Internal evidence (zero authorial presence in
223 articles, byte-identical stamped footers, institutional "we") indicates house-voice
reference material that was never trying to be personal prose.

**Benefits Navigator (Voice 2.2) — partially.** The service-guidance corpus (95% of the
words) is well-judged plain-language writing for veterans and should largely stay as it is.
The exception is editorial, not stylistic: the hero sells a disability claim as a payday
("Stop Leaving Money on the Table" / "The average veteran is underrated by 30%"). That is a
direct-response sales register the guide never reaches for, aimed at an audience §2 would
treat by foregrounding the person. **Change that on editorial grounds regardless of
voice-matching.**

---

## 5. Highest-leverage work, portfolio-wide

1. **Write the missing About pages** (Access Atlas, CIT, Benefits Navigator) and rewrite the
   marketing site's. This single class of work recovers A3, A4, A5, and B7 simultaneously —
   it is not editing, it is ~500 words per app that do not currently exist.
2. **Fix the twelve correctness defects in §3**, starting with the KindredAccess minors
   clause and the page-repair ship-blocker.
3. **Set a sourcing floor.** Any sentence asserting a rate, trend, or magnitude gets an
   inline link or gets softened. This lifts B5 — the weakest B dimension — across every app.
4. **Replace faded closings.** Especially Disability Wiki's 223 stamped footers, where a
   forward-looking close serves the reader (what to do next), not just the style guide.

---

## Appendix — dependency worth knowing

Benefits Navigator's ALL-CAPS and ` - ` conventions appear in its **AI system prompts** as
well as its templates (`claims/services/ai_service.py:32-45`, `:191-204`; also
`agents/services.py`, `agents/ai_gateway.py`,
`claims/services/rating_analysis_service.py`). Normalizing the templates without touching
the prompts will leave generated output stylistically out of sync with the pages around it.
