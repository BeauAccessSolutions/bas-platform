# Benefits Navigator — data-posture brief for counsel

Status: **awaiting legal determination** · Prepared 2026-07-08 · For: BAS LLC counsel
Anchor: [ADR-005](../adr/005-benefits-navigator-data-posture.md)

**Purpose.** This is an internal fact-gathering package to let counsel answer the one
open question gating Benefits Navigator (BN) from platform *Candidate* → *Member*:
**which regime governs BN's data, and does it impose obligations beyond the
HIPAA-grade handling BN is already engineered to?** This document is **not** legal
advice and reaches no conclusion — it lays out the facts and the specific questions a
determination must answer.

## Factual record (what BN actually does with data)

**Two user flows:**
- **Path A — Veterans (B2C).** A veteran works *their own* VA claim: uploads documents,
  gets AI analysis of a VA decision, denial decoding, and drafted statements.
- **Path B — VSOs (B2B).** A Veterans Service Officer / advocate acts on *another
  identified veteran's* claim — shared documents, veteran invitations.

**Data collected / stored:**
- Identifiers: `va_file_number`, `date_of_birth` — stored with `EncryptedCharField`
  (app-level encryption at rest, `core/encryption.py`).
- Uploaded VA correspondence (decision letters, claim documents) provided **by the user**.
- AI-derived analysis of the user's claim (via the AI Gateway; raw PII prompts/responses
  are not persisted).
- Account + billing data (Stripe subscriptions).

**Data provenance — pivotal fact:** BN receives claim documents **from the veteran
uploading their own copies**, not from a VA system feed. BN has **no direct integration
with VA systems of records** today. (Counsel should confirm this framing and flag if any
current or planned integration changes it.)

**Hosting / processing:** DigitalOcean App Platform (US/NYC), Django + Postgres +
Celery/Redis; Anthropic Claude API as a subprocessor for analysis.

## The regimes in question (for counsel to rule on)

1. **HIPAA.** BN is not a covered entity (not a provider, plan, or clearinghouse). Working
   assumption: **does not bind directly.** *Question 1: Confirm BN is neither a covered
   entity nor a business associate under any customer/partner arrangement (e.g. if a VSO
   organization that is a covered entity uses Path B).*

2. **Privacy Act of 1974 (5 U.S.C. § 552a).** Binds federal agencies and their systems of
   records; BN is a private LLC. Working assumption: **does not bind directly.**
   *Question 2: Does any Privacy Act obligation flow down to BN by contract, by data
   provenance (data originating from VA records), or through a future VA integration?*

3. **VA claimant confidentiality — 38 U.S.C. § 5701; 38 CFR §§ 1.500–1.527.** The regime
   most specific to BN's data. *Question 3 (the crux): Do these provisions reach a
   third-party tool that helps a veteran with their **own** claim using documents the
   **veteran** supplies — as opposed to a tool that receives records **from** VA? If they
   reach BN, what specifically attaches (disclosure limits, consent, retention)?*

4. **Path B specifics.** A VSO handling a third party's claim data through BN.
   *Question 4: Any VSO-accreditation or agent/representative obligations (e.g. 38 CFR
   part 14) that BN's Path B design must accommodate — consent capture, access scoping?*

5. **State law.** BN serves US veterans across states. *Question 5: Do CCPA/CPRA or other
   state privacy/health-data laws add obligations (BN already ships self-service
   export + deletion), and is there a most-restrictive baseline to standardize on?*

## What a determination should produce

- [ ] **Applicability ruling** on regimes 1–5 (binds / doesn't / flows-down-if).
- [ ] **Delta list**: any obligation **beyond** BN's current CIT-tier handling (layered
  sessions, encrypted PII, decoupled export/delete, contribution-boundary isolation) —
  e.g. specific retention limits, disclosure accounting, breach-notification timelines,
  consent artifacts for Path B.
- [ ] **Provenance guardrail**: written condition under which the ruling would change
  (e.g. "if BN ever ingests data directly from a VA system, re-assess under § 5701").
- [ ] **Promotion decision**: with the above, BN moves Candidate → Member in the tracker;
  any deltas become follow-up ADR(s) + BN-repo TODOs.

## Notes for whoever routes this

- BN is **already engineered to the conservative (CIT sensitive-resource-server) tier**,
  so no code is blocked on this answer — only the *Member* label and any incremental
  obligations from the delta list.
- Related platform decisions counsel may want as context: [ADR-001](../adr/001-platform-architecture-and-identity.md)
  (identity), [ADR-003](../adr/003-pairwise-subject-identifiers.md) (no cross-app
  correlation), [ADR-004](../adr/004-existing-user-migration.md) (user migration).
