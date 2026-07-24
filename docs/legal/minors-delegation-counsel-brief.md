# Minors, delegation, and Part 2 — brief for counsel

Status: **awaiting legal determination** · Prepared 2026-07-23 · For: BAS LLC counsel
Anchor: parameter **P5** in [`docs/testing/multi-role-test-matrix.yaml`](../testing/multi-role-test-matrix.yaml)
Sibling: [bn-data-posture-counsel-brief.md](bn-data-posture-counsel-brief.md)

**Purpose.** Five questions that engineering cannot answer and should not guess at. They
gate one parameter — the age of majority and the confidential-category floor — which in
turn gates the delegation and proxy behaviour in any BAS app that carries a guardian
relationship. This document reaches no conclusion; it states what we have built, what we
have assumed, and what a determination must settle.

**Why this can't be closed internally.** The interaction of three bodies of law — the 2024
42 CFR Part 2 Final Rule, the ONC Cures Act information-blocking exceptions, and New York
minor-consent law — is the one area in a 40-page research pass where the sources genuinely
conflict on operational questions, and it is the area with real liability. A research
synthesis produced a defensible reading of each in isolation and could not reconcile them.

## What is already built (and holds regardless of the answers)

The delegation mechanism is written against a **configurable** age, not a constant:

- Age of majority is a configuration value per jurisdiction, defaulting to 18.
- A confidential-category floor (placeholder: 12) governs SUD treatment, mental health,
  reproductive health, and HIV/STI records separately from the general age.
- Parent/guardian proxy access **auto-revokes on the majority birthday** with 30 days'
  advance notice to both parties.
- Continued access after that date requires the now-adult's fresh consent; it does not
  carry over silently.
- Delegates see records **from the grant date forward** for sensitive categories, not
  retroactively.
- Re-delegation is disallowed by default.

Test `DELEG-07` exercises the boundary — day before, birthday, day after — against the
placeholder constants today. **The mechanism is safe to build now; only the numbers move.**

## The questions

**Q1 — New York minor-consent ages, and what consent implies for access.**
At what age may a minor consent to each of: SUD treatment, mental-health care, reproductive
care, HIV/STI care? For each: does the minor's consenting status *bar* parental access to
the resulting record, or does it only remove the requirement of parental consent to the
care? These are different, and only the first has a data-model consequence.

**Q2 — Which information-blocking exception covers withholding from a parent proxy.**
Where a parent holds a portal proxy and the minor has a confidential-category record, our
working reading is that the **preventing-harm** exception does *not* cover adolescent
confidentiality on its own, and that the operative path is the **privacy** exception (via
state minor-consent law) or the **infeasibility** exception. Please confirm or correct —
and specify what documentation the chosen exception obliges us to retain, since that is a
schema question, not a policy question.

**Q3 — Part 2 segmentation vs. withholding.**
The 2024 rule states that segmenting Part 2 records is *not required*, while redisclosure
still requires consent. If a portal cannot unambiguously segment Part 2 data, is withholding
it **mandatory**? And if we withhold, does that withholding itself need an
information-blocking exception, or does the Part 2 obligation pre-empt the question?

**Q4 — Is auto-revocation on the majority birthday required, safe, or over-compliance?**
We auto-revoke. Is that the required behaviour, merely the safe one, or does it create its
own problem (e.g. abruptly cutting off a guardian of an adult with a continuing
disability — a population BAS specifically serves)? And when the now-adult re-grants
access, must that be a fresh written consent, or does a portal-recorded affirmation suffice?

**Q5 — Retention of the consent artifacts themselves.**
Independent of the 6-year security-documentation floor (45 CFR 164.316(b)(2)(i)): what
retention attaches to the consent records — who consented, when, to what scope, and the
revocation event? These outlive the underlying access grant and we currently have no
separate policy for them.

## What we are doing in the meantime

P5 is marked `status: proposed_pending_counsel` in the matrix, and
`./scripts/testmatrix.py gate` exits non-zero while it stays that way, so no app can be
called release-ready on this parameter by default. Engineering will not mark it `adopted`
on its own judgment.

Q4 has a BAS-specific edge worth flagging to counsel directly: several BAS apps serve adults
with continuing disabilities where a guardianship persists past 18. A clean
"revoke at majority" rule that is correct for a general-population portal may be actively
wrong here, and the answer likely needs to distinguish age-based proxy termination from
guardianship-based proxy continuation. That distinction, if it exists, is a data-model
change and not a config value.
