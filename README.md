# Beau Access Solutions — Platform Governance

The umbrella that owns the **overarching decisions** for Beau Access Solutions LLC's
portfolio of accessibility/disability-focused apps. This repo holds the cross-cutting
architecture, invariants, and decision records; the apps themselves live in their own
repos (a governance **org**, not a mono-repo — trust boundary = repo boundary).

> Local dir is `bas-platform/`; the GitHub repo is `Beaudoin0zach/Beau-Access-Solutions`.
> (The marketing site at beauaccesssolutions.com is a **separate** repo.)

## What's here

- **[TRACKER.md](TRACKER.md)** — living status board: every repo, the PR rollout, roadmap, and open blockers. Start here.
- **[PLATFORM.md](PLATFORM.md)** — the architecture: standalone Keycloak identity,
  layered sessions, the shared Expo/RN-Web design system, sequencing.
- **[INVARIANTS.md](INVARIANTS.md)** — the five platform invariants, enforced by construction.
- **[docs/adr/](docs/adr/)** — architecture decision records:
  - [ADR-001](docs/adr/001-platform-architecture-and-identity.md) — shared platform + standalone Keycloak identity.
  - [ADR-002](docs/adr/002-umbrella-org-and-repo-topology.md) — the BAS umbrella, repo topology, no committed cross-repo symlinks.
  - [ADR-003](docs/adr/003-pairwise-subject-identifiers.md) — pairwise subject identifiers, so no two apps can correlate a shared user.
  - [ADR-004](docs/adr/004-existing-user-migration.md) — migrating existing per-app users into Keycloak without a mass reset.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — how apps join the platform; the PHI contribution boundary.
- **[.github/CODEOWNERS](.github/CODEOWNERS)** — decisions require owner review.

## The portfolio (each in its own repo)

| App | Stack | Platform role |
|---|---|---|
| Chronic Illness Tracker (CIT) | Next.js + Postgres (PHI) | **App #1** — resource server, mints its own data-access session |
| KindredAccess | Django + Channels | **App #2** — resource server; its 2FA informs step-up |
| VA Benefits Navigator | Django + AI | Candidate member; sensitive data → same PHI treatment |
| Access Atlas (access-directory) | Astro | **Identity member** — Keycloak gates *contribution* (pseudonymous); browsing stays account-free; zero-JS surface, no RN rewrite. Repo `Beaudoin0zach/access-atlas` |
| a11y-probe | Reddit Devvit | Likely standalone; can feed shared CI a11y gates |
| page-repair | Browser extension | Not an identity member; patterns inform shared `ui` |
| Marketing site | Astro + Netlify | beauaccesssolutions.com — company site, not a platform app |

## Status (2026-07-07)

Planning / foundation. Identity = self-hosted Keycloak (decided). No shared code
or identity service stood up yet. `repos/` (gitignored) holds local symlinks to
each property for convenience.
